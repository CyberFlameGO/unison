{-# language DataKinds #-}
{-# language PatternGuards #-}
{-# language NamedFieldPuns #-}
{-# language PatternSynonyms #-}
{-# language RecordWildCards #-}
{-# language ParallelListComp #-}
{-# language OverloadedStrings #-}
{-# language ScopedTypeVariables #-}

module Unison.Runtime.Interface
  ( startRuntime
  , standalone
  , runStandalone
  , readCompiledHeader
  , StoredCache
  ) where

import GHC.Stack (HasCallStack)

import Unison.Prelude (reportBug, maybeToList)
import Control.Concurrent.STM as STM
import Control.Exception (try, catch)
import Control.Monad

import Data.Bits (shiftL, shiftR, (.|.), (.&.))
import Data.Bytes.Serial
import Data.Bytes.Get (runGetS)
import Data.Bytes.Put (runPutS)
import qualified Data.ByteString as B
import Data.Compact (compactWithSharing)
import Data.Compact.Serialize (hPutCompact)
import Data.Bifunctor (first,second)
import Data.Functor ((<&>))
import Data.IORef
import Data.Foldable
import Data.Set as Set
  (Set, (\\), singleton, map, notMember, filter, fromList)
import Data.Map.Strict (Map)
import Data.Traversable (for)
import Data.Text (Text, isPrefixOf, unpack)
import Data.Word (Word64)

import qualified Data.Map.Strict as Map

import System.IO (IOMode(WriteMode), withFile, Handle)
import System.Info (os, arch)

import qualified Unison.ABT as Tm (substs)
import qualified Unison.Term as Tm

import Unison.DataDeclaration (declFields, declDependencies, Decl)
import qualified Unison.HashQualified as HQ
import qualified Unison.Builtin.Decls as RF
import qualified Unison.LabeledDependency as RF
import Unison.Reference (Reference)
import qualified Unison.Referent as RF (pattern Ref)
import qualified Unison.Reference as RF

import Unison.Util.EnumContainers as EC

import Unison.Codebase.CodeLookup (CodeLookup(..))
import Unison.Codebase.Runtime (Runtime(..), Error)
import Unison.Codebase.MainTerm (builtinMain, builtinTest)

import Unison.Parser.Ann (Ann(External))
import Unison.PrettyPrintEnv
import Unison.Util.Pretty as P
import Unison.Symbol (Symbol)
import Unison.TermPrinter

import Unison.Runtime.ANF
import Unison.Runtime.Builtin
import Unison.Runtime.Decompile
import Unison.Runtime.Exception
import Unison.Runtime.Machine
  ( apply0, eval0
  , CCache(..), cacheAdd, cacheAdd0, baseCCache
  , refNumTm, refNumsTm, refNumsTy, refLookup
  )
import Unison.Runtime.MCode
  ( Combs, combDeps, combTypes, Args(..), Section(..), Instr(..)
  , RefNums(..), emptyRNs, emitComb)
import Unison.Runtime.Pattern
import Unison.Runtime.Stack
import qualified Unison.Hashing.V2.Convert as Hashing

type Term v = Tm.Term v ()

data EvalCtx
  = ECtx
  { dspec :: DataSpec
  , decompTm :: Map.Map Reference (Map.Map Word64 (Term Symbol))
  , ccache :: CCache
  }

uncurryDspec :: DataSpec -> Map.Map (Reference,Int) Int
uncurryDspec = Map.fromList . concatMap f . Map.toList
  where
  f (r,l) = zipWith (\n c -> ((r,n),c)) [0..] $ either id id l

cacheContext :: CCache -> EvalCtx
cacheContext
  = ECtx builtinDataSpec
  . Map.fromList
  $ Map.keys builtinTermNumbering
     <&> \r -> (r, Map.singleton 0 (Tm.ref () r))

baseContext :: IO EvalCtx
baseContext = cacheContext <$> baseCCache

resolveTermRef
  :: CodeLookup Symbol IO ()
  -> RF.Reference
  -> IO (Term Symbol)
resolveTermRef _  b@(RF.Builtin _)
  = die $ "Unknown builtin term reference: " ++ show b
resolveTermRef cl r@(RF.DerivedId i)
  = getTerm cl i >>= \case
      Nothing -> die $ "Unknown term reference: " ++ show r
      Just tm -> pure tm

allocType
  :: EvalCtx
  -> RF.Reference
  -> Either [Int] [Int]
  -> IO EvalCtx
allocType _ b@(RF.Builtin _) _
  = die $ "Unknown builtin type reference: " ++ show b
allocType ctx r cons
  = pure $ ctx { dspec = Map.insert r cons $ dspec ctx }

recursiveDeclDeps
  :: Set RF.LabeledDependency
  -> CodeLookup Symbol IO ()
  -> Decl Symbol ()
  -> IO (Set Reference, Set Reference)
recursiveDeclDeps seen0 cl d = do
    rec <- for (toList newDeps) $ \case
      RF.DerivedId i -> getTypeDeclaration cl i >>= \case
        Just d -> recursiveDeclDeps seen cl d
        Nothing -> pure mempty
      _ -> pure mempty
    pure $ (deps, mempty) <> fold rec
  where
  deps = declDependencies d
  newDeps = Set.filter (\r -> notMember (RF.typeRef r) seen0) deps
  seen = seen0 <> Set.map RF.typeRef deps

categorize :: RF.LabeledDependency -> (Set Reference, Set Reference)
categorize
  = either ((,mempty) . singleton) ((mempty,) . singleton)
  . RF.toReference

recursiveTermDeps
  :: Set RF.LabeledDependency
  -> CodeLookup Symbol IO ()
  -> Term Symbol
  -> IO (Set Reference, Set Reference)
recursiveTermDeps seen0 cl tm = do
    rec <- for (RF.toReference <$> toList (deps \\ seen0)) $ \case
      Left (RF.DerivedId i) -> getTypeDeclaration cl i >>= \case
        Just d -> recursiveDeclDeps seen cl d
        Nothing -> pure mempty
      Right r -> recursiveRefDeps seen cl r
      _ -> pure mempty
    pure $ foldMap categorize deps <> fold rec
  where
  deps = Tm.labeledDependencies tm
  seen = seen0 <> deps

recursiveRefDeps
  :: Set RF.LabeledDependency
  -> CodeLookup Symbol IO ()
  -> Reference
  -> IO (Set Reference, Set Reference)
recursiveRefDeps seen cl (RF.DerivedId i)
  = getTerm cl i >>= \case
      Just tm -> recursiveTermDeps seen cl tm
      Nothing -> pure mempty
recursiveRefDeps _ _ _ = pure mempty

collectDeps
  :: CodeLookup Symbol IO ()
  -> Term Symbol
  -> IO ([(Reference, Either [Int] [Int])], [Reference])
collectDeps cl tm = do
  (tys, tms) <- recursiveTermDeps mempty cl tm
  (, toList tms) <$> traverse getDecl (toList tys)
  where
  getDecl ty@(RF.DerivedId i) =
    (ty,) . maybe (Right []) declFields
      <$> getTypeDeclaration cl i
  getDecl r = pure (r,Right [])

collectRefDeps
  :: CodeLookup Symbol IO ()
  -> Reference
  -> IO ([(Reference, Either [Int] [Int])], [Reference])
collectRefDeps cl r = do
  tm <- resolveTermRef cl r
  (tyrs, tmrs) <- collectDeps cl tm
  pure (tyrs, r:tmrs)

backrefAdd
  :: Map.Map Reference (Map.Map Word64 (Term Symbol))
  -> EvalCtx -> EvalCtx
backrefAdd m ctx@ECtx{ decompTm }
  = ctx { decompTm = m <> decompTm }

loadDeps
  :: CodeLookup Symbol IO ()
  -> PrettyPrintEnv
  -> EvalCtx
  -> [(Reference, Either [Int] [Int])]
  -> [Reference]
  -> IO EvalCtx
loadDeps cl ppe ctx tyrs tmrs = do
  p <- refNumsTy (ccache ctx) <&> \m (r,_) -> case r of
    RF.DerivedId{} -> r `Map.notMember` dspec ctx
                   || r `Map.notMember` m
    _ -> False
  q <- refNumsTm (ccache ctx) <&> \m r -> case r of
    RF.DerivedId{} -> r `Map.notMember` m
    _ -> False
  ctx <- foldM (uncurry . allocType) ctx $ Prelude.filter p tyrs
  rtms <- traverse (\r -> (,) r <$> resolveTermRef cl r)
            $ Prelude.filter q tmrs
  let (rgrp, rbkr) = intermediateTerms ppe ctx rtms
      tyAdd = Set.fromList $ fst <$> tyrs
  backrefAdd rbkr ctx <$ cacheAdd0 tyAdd rgrp (ccache ctx)

backrefLifted
  :: Term Symbol
  -> [(Symbol, Term Symbol)]
  -> Map.Map Word64 (Term Symbol)
backrefLifted tm@(Tm.LetRecNamed' bs _) dcmp
  = Map.fromList . ((0,tm):) $
  [ (ix, dc)
  | ix <- ixs
  | (v, _) <- reverse bs
  , dc <- maybeToList $ Prelude.lookup v dcmp
  ]
  where
  ixs = fmap (`shiftL` 16) [1..]
backrefLifted tm _ = Map.singleton 0 tm

intermediateTerms
  :: HasCallStack
  => PrettyPrintEnv
  -> EvalCtx
  -> [(Reference, Term Symbol)]
  -> ( [(Reference, SuperGroup Symbol)]
     , Map.Map Reference (Map.Map Word64 (Term Symbol))
     )
intermediateTerms ppe ctx rtms
  = ((fmap.second) fst rint, Map.fromList $ (fmap.second) snd rint)
  where
  rint = rtms <&> \(ref, tm) ->
    (ref, intermediateTerm ppe ref ctx tm)

intermediateTerm
  :: HasCallStack
  => PrettyPrintEnv
  -> Reference
  -> EvalCtx
  -> Term Symbol
  -> (SuperGroup Symbol, Map.Map Word64 (Term Symbol))
intermediateTerm ppe ref ctx tm
  = final
  . lamLift
  . splitPatterns (dspec ctx)
  . addDefaultCases tmName
  . saturate (uncurryDspec $ dspec ctx)
  . inlineAlias
  $ tm
  where
  final (ll, dcmp) = (superNormalize ll, backrefLifted ll dcmp)
  tmName = HQ.toString . termName ppe $ RF.Ref ref

prepareEvaluation
  :: HasCallStack
  => PrettyPrintEnv
  -> Term Symbol
  -> EvalCtx
  -> IO (EvalCtx, Word64)
prepareEvaluation ppe tm ctx = do
  missing <- cacheAdd rgrp (ccache ctx)
  when (not . null $ missing) . fail $
    reportBug "E029347" $ "Error in prepareEvaluation, cache is missing: " <> show missing
  (,) (backrefAdd rbkr ctx) <$> refNumTm (ccache ctx) rmn
  where
  (rmn, rtms)
    | Tm.LetRecNamed' bs mn0 <- tm
    , hcs <- fmap (first RF.DerivedId)
           . Hashing.hashTermComponents $ Map.fromList bs
    , mn <- Tm.substs (Map.toList $ Tm.ref () . fst <$> hcs) mn0
    , rmn <- RF.DerivedId $ Hashing.hashClosedTerm mn
    = (rmn , (rmn, mn) : Map.elems hcs)

    | rmn <- RF.DerivedId $ Hashing.hashClosedTerm tm
    = (rmn, [(rmn, tm)])

  (rgrp, rbkr) = intermediateTerms ppe ctx rtms

watchHook :: IORef Closure -> Stack 'UN -> Stack 'BX -> IO ()
watchHook r _ bstk = peek bstk >>= writeIORef r

backReferenceTm
  :: EnumMap Word64 Reference
  -> Map.Map Reference (Map.Map Word64 (Term Symbol))
  -> Word64 -> Word64 -> Maybe (Term Symbol)
backReferenceTm ws rs c i = do
  r <- EC.lookup c ws
  bs <- Map.lookup r rs
  Map.lookup i bs

evalInContext
  :: PrettyPrintEnv
  -> EvalCtx
  -> Word64
  -> IO (Either Error (Term Symbol))
evalInContext ppe ctx w = do
  r <- newIORef BlackHole
  crs <- readTVarIO (combRefs $ ccache ctx)
  let hook = watchHook r
      decom = decompile (backReferenceTm crs (decompTm ctx))
      prettyError (PE _ p) = p
      prettyError (BU nm c) = either id (bugMsg ppe nm) $ decom c
  result <- traverse (const $ readIORef r)
          . first prettyError
        <=< try $ apply0 (Just hook) (ccache ctx) w
  pure $ decom =<< result

executeMainComb
  :: Word64
  -> CCache
  -> IO ()
executeMainComb init cc
  = eval0 cc
  . Ins (Pack RF.unitRef 0 ZArgs)
  $ Call True init (BArg1 0)

bugMsg :: PrettyPrintEnv -> Text -> Term Symbol -> Pretty ColorText

bugMsg ppe name tm
  | name == "blank expression" = P.callout icon . P.lines $
  [ P.wrap ("I encountered a" <> P.red (P.text name)
      <> "with the following name/message:")
  , ""
  , P.indentN 2 $ pretty ppe tm
  , ""
  , sorryMsg
  ]
  | "pattern match failure" `isPrefixOf` name
  = P.callout icon . P.lines $
  [ P.wrap ("I've encountered a" <> P.red (P.text name)
      <> "while scrutinizing:")
  , ""
  , P.indentN 2 $ pretty ppe tm
  , ""
  , "This happens when calling a function that doesn't handle all \
    \possible inputs"
  , sorryMsg
  ]
  | name == "builtin.raise" = P.callout icon . P.lines $
  [ P.wrap ("The program halted with an unhandled exception:")
  , ""
  , P.indentN 2 $ pretty ppe tm
  ]
bugMsg ppe name tm = P.callout icon . P.lines $
  [ P.wrap ("I've encountered a call to" <> P.red (P.text name)
      <> "with the following value:")
  , ""
  , P.indentN 2 $ pretty ppe tm
  , ""
  , sorryMsg
  ]
  where
icon, sorryMsg  :: Pretty ColorText
icon = "💔💥"
sorryMsg
  = P.wrap
  $ "I'm sorry this message doesn't have more detail about"
  <> "the location of the failure."
  <> "My makers plan to fix this in a future release. 😢"

catchInternalErrors
  :: IO (Either Error a)
  -> IO (Either Error a)
catchInternalErrors sub = sub `catch` \(CE _ e) -> pure $ Left e

compiledHeader :: String -> Text -> B.ByteString
compiledHeader version hash
  = nb <> str
  where
  n = B.length str
  f i = fromIntegral $ (n `shiftR` i) .&. 0xff
  nb = B.pack . fmap (f . (*8)) $ [0..3]
  str = runPutS $ do
    serialize version
    serialize os
    serialize arch
    serialize (unpack hash)

readCompiledHeader
  :: Handle -> IO (Either String (String, String, String, String))
readCompiledHeader h = do
  bl <- B.hGet h 4
  let l = foldr g 0 (B.unpack bl)
  bs <- B.hGet h l
  pure . flip runGetS bs $
    (,,,) <$> deserialize <*> deserialize <*> deserialize <*> deserialize
  where
  g i r = fromIntegral i .|. (r `shiftL` 8)

startRuntime :: String -> IO (Runtime Symbol)
startRuntime version = do
  ctxVar <- newIORef =<< baseContext
  pure $ Runtime
       { terminate = pure ()
       , evaluate = \cl ppe tm -> catchInternalErrors $ do
           ctx <- readIORef ctxVar
           (tyrs, tmrs) <- collectDeps cl tm
           ctx <- loadDeps cl ppe ctx tyrs tmrs
           (ctx, init) <- prepareEvaluation ppe tm ctx
           writeIORef ctxVar ctx
           evalInContext ppe ctx init
       , compileTo = \cl ppe rf path -> tryM $ do
           ctx <- readIORef ctxVar
           (tyrs, tmrs) <- collectRefDeps cl rf
           ctx <- loadDeps cl ppe ctx tyrs tmrs
           let cc = ccache ctx
           Just w <- Map.lookup rf <$> readTVarIO (refTm cc)
           sto <- standalone cc w
           cmp <- compactWithSharing (w, sto)
           withFile path WriteMode $ \h -> do
             B.hPut h $ compiledHeader version (RF.showShort 8 rf)
             hPutCompact h cmp
       , mainType = builtinMain External
       , ioTestType = builtinTest External
       }

tryM :: IO () -> IO (Maybe Error)
tryM = fmap (either (Just . extract) (const Nothing)) . try
  where
  extract (PE _ e) = e
  extract (BU _ _) = "impossible"

runStandalone :: StoredCache -> Word64 -> IO ()
runStandalone sc init
  = restoreCache sc >>= executeMainComb init

data StoredCache
  = SCache
      (EnumMap Word64 Combs)
      (EnumMap Word64 Reference)
      (EnumMap Word64 Reference)
      Word64
      Word64
      (Map Reference (SuperGroup Symbol))
      (Map Reference Word64)
      (Map Reference Word64)

restoreCache :: StoredCache -> IO CCache
restoreCache (SCache cs crs trs ftm fty int rtm rty)
  = CCache builtinForeigns
      <$> newTVarIO (cs <> combs)
      <*> newTVarIO (crs <> builtinTermBackref)
      <*> newTVarIO (trs <> builtinTypeBackref)
      <*> newTVarIO ftm
      <*> newTVarIO fty
      <*> newTVarIO int
      <*> newTVarIO (rtm <> builtinTermNumbering)
      <*> newTVarIO (rty <> builtinTypeNumbering)
  where
  rns = emptyRNs { dnum = refLookup "ty" builtinTypeNumbering }
  combs
    = mapWithKey
        (\k v -> emitComb @Symbol rns k mempty (0,v))
        numberedTermLookup

traceNeeded
  :: Word64
  -> EnumMap Word64 Combs
  -> IO (EnumMap Word64 Combs)
traceNeeded init src = fmap (`withoutKeys` ks) $ go mempty init where
  ks = keysSet (numberedTermLookup @Symbol)
  go acc w
    | hasKey w acc = pure acc
    | Just co <- EC.lookup w src
    = foldlM go (mapInsert w co acc) (foldMap combDeps co)
    | otherwise = die $ "traceNeeded: unknown combinator: " ++ show w

buildSCache
  :: EnumMap Word64 Combs
  -> EnumMap Word64 Reference
  -> EnumMap Word64 Reference
  -> Word64
  -> Word64
  -> Map Reference (SuperGroup Symbol)
  -> Map Reference Word64
  -> Map Reference Word64
  -> StoredCache
buildSCache cs crsrc trsrc ftm fty intsrc rtmsrc rtysrc
  = SCache cs crs trs
      ftm fty
      (restrictTmR intsrc)
      (restrictTmR rtmsrc)
      (restrictTyR rtysrc)
  where
  combKeys = keysSet cs
  crs = restrictTmW crsrc
  termRefs = foldMap Set.singleton crs

  typeKeys = setFromList $ (foldMap.foldMap) combTypes cs
  trs = restrictTyW trsrc
  typeRefs = foldMap Set.singleton trs

  restrictTmW m = restrictKeys m combKeys
  restrictTmR m = Map.restrictKeys m termRefs

  restrictTyW m = restrictKeys m typeKeys
  restrictTyR m = Map.restrictKeys m typeRefs

standalone :: CCache -> Word64 -> IO StoredCache
standalone cc init =
  buildSCache
    <$> (readTVarIO (combs cc) >>= traceNeeded init)
    <*> readTVarIO (combRefs cc)
    <*> readTVarIO (tagRefs cc)
    <*> readTVarIO (freshTm cc)
    <*> readTVarIO (freshTy cc)
    <*> readTVarIO (intermed cc)
    <*> readTVarIO (refTm cc)
    <*> readTVarIO (refTy cc)
