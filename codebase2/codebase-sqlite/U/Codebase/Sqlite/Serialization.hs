{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RecordWildCards #-}

module U.Codebase.Sqlite.Serialization where

import Data.Bits (Bits)
import Data.Bytes.Get (MonadGet, getWord8)
import Data.Bytes.Put (MonadPut, putWord8)
import Data.Bytes.Serial (SerialEndian (serializeBE), deserialize, deserializeBE, serialize)
import Data.Bytes.VarInt (VarInt (VarInt), unVarInt)
import Data.Int (Int64)
import Data.List (elemIndex)
import qualified Data.Set as Set
import U.Codebase.Kind (Kind)
import Data.Word (Word64)
import qualified U.Codebase.Kind as Kind
import U.Codebase.Reference (Reference' (ReferenceBuiltin, ReferenceDerived))
import qualified U.Codebase.Reference as Reference
import U.Codebase.Referent (Referent')
import qualified U.Codebase.Referent as Referent
import U.Codebase.Sqlite.LocalIds
import qualified U.Codebase.Sqlite.Term.Format as TermFormat
import qualified U.Codebase.Term as Term
import qualified U.Codebase.Type as Type
import qualified U.Core.ABT as ABT
import U.Util.Serialization
import Prelude hiding (getChar, putChar)

putABT ::
  (MonadPut m, Foldable f, Functor f, Ord v) =>
  (v -> m ()) ->
  (a -> m ()) ->
  (forall x. (x -> m ()) -> f x -> m ()) ->
  ABT.Term f v a ->
  m ()
putABT putVar putA putF abt =
  putFoldable putVar fvs *> go (annotateBound abt)
  where
    fvs = Set.toList $ ABT.freeVars abt
    go (ABT.Term _ (a, env) abt) = putA a *> case abt of
      ABT.Var v -> putWord8 0 *> putVarRef env v
      ABT.Tm f -> putWord8 1 *> putF go f
      ABT.Abs v body -> putWord8 2 *> putVar v *> go body
      ABT.Cycle body -> putWord8 3 *> go body
    annotateBound :: (Ord v, Functor f, Foldable f) => ABT.Term f v a -> ABT.Term f v (a, [v])
    annotateBound = go []
      where
        go env t =
          let a = (ABT.annotation t, env)
           in case ABT.out t of
                ABT.Abs v body -> ABT.abs a v (go (v : env) body)
                ABT.Cycle body -> ABT.cycle a (go env body)
                ABT.Tm f -> ABT.tm a (go env <$> f)
                ABT.Var v -> ABT.annotatedVar a v
    putVarRef env v = case v `elemIndex` env of
      Just i -> putWord8 0 *> putVarInt i
      Nothing -> case v `elemIndex` fvs of
        Just i -> putWord8 1 *> putVarInt i
        Nothing -> error "impossible: var not free or bound"

getABT ::
  (MonadGet m, Foldable f, Functor f, Ord v) =>
  m v ->
  m a ->
  (forall x. m x -> m (f x)) ->
  m (ABT.Term f v a)
getABT getVar getA getF = getList getVar >>= go []
  where
    go env fvs = do
      a <- getA
      tag <- getWord8
      case tag of
        0 -> do
          tag <- getWord8
          case tag of
            0 -> ABT.annotatedVar a . (env !!) <$> getVarInt
            1 -> ABT.annotatedVar a . (fvs !!) <$> getVarInt
            _ -> unknownTag "getABT.Var" tag
        1 -> ABT.tm a <$> getF (go env fvs)
        2 -> do
          v <- getVar
          body <- go (v : env) fvs
          pure $ ABT.abs a v body
        3 -> ABT.cycle a <$> go env fvs
        _ -> unknownTag "getABT" tag

{-
Write/Read
- [x][x] term component
- [x][ ] types of terms
- [ ][ ] decl component
- [ ][ ] causal
- [ ][ ] full branch
- [ ][ ] diff branch
- [ ][ ] full patch
- [ ][ ] diff patch

- [ ] add to dependents index
- [ ] add to type index
- [ ] add to type mentions index
-}

putLocalIds :: MonadPut m => LocalIds -> m ()
putLocalIds LocalIds {..} = do
  putFoldable putVarInt textLookup
  putFoldable putVarInt objectLookup

getLocalIds :: MonadGet m => m LocalIds
getLocalIds =
  LocalIds
    <$> getVector getVarInt
    <*> getVector getVarInt

putUnit :: Applicative m => () -> m ()
putUnit _ = pure ()

getUnit :: Applicative m => m ()
getUnit = pure ()

putTermFormat :: MonadPut m => TermFormat.TermFormat -> m ()
putTermFormat = \case
  TermFormat.Term c -> putWord8 0 *> putTermComponent c

getTermFormat :: MonadGet m => m TermFormat.TermFormat
getTermFormat = getWord8 >>= \case
  0 -> TermFormat.Term <$> getTermComponent
  other -> unknownTag "getTermFormat" other

putTermComponent ::
  MonadPut m =>
  TermFormat.LocallyIndexedComponent ->
  m ()
putTermComponent TermFormat.LocallyIndexedComponent {..} = do
  putLocalIds lookup
  putFramedArray putTermElement component
  where
    putF :: MonadPut m => (a -> m ()) -> TermFormat.F a -> m ()
    putF putChild = \case
      Term.Int n ->
        putWord8 0 *> putInt n
      Term.Nat n ->
        putWord8 1 *> putNat n
      Term.Float n ->
        putWord8 2 *> putFloat n
      Term.Boolean b ->
        putWord8 3 *> putBoolean b
      Term.Text t ->
        putWord8 4 *> putVarInt t
      Term.Ref r ->
        putWord8 5 *> putRecursiveReference r
      Term.Constructor r cid ->
        putWord8 6 *> putReference r *> putVarInt cid
      Term.Request r cid ->
        putWord8 7 *> putReference r *> putVarInt cid
      Term.Handle h a ->
        putWord8 8 *> putChild h *> putChild a
      Term.App f arg ->
        putWord8 9 *> putChild f *> putChild arg
      Term.Ann e t ->
        putWord8 10 *> putChild e *> putType putReference putSymbol t
      Term.Sequence vs ->
        putWord8 11 *> putFoldable putChild vs
      Term.If cond t f ->
        putWord8 12 *> putChild cond *> putChild t *> putChild f
      Term.And x y ->
        putWord8 13 *> putChild x *> putChild y
      Term.Or x y ->
        putWord8 14 *> putChild x *> putChild y
      Term.Lam body ->
        putWord8 15 *> putChild body
      Term.LetRec bs body ->
        putWord8 16 *> putFoldable putChild bs *> putChild body
      Term.Let b body ->
        putWord8 17 *> putChild b *> putChild body
      Term.Match s cases ->
        putWord8 18 *> putChild s *> putFoldable (putMatchCase putChild) cases
      Term.Char c ->
        putWord8 19 *> putChar c
      Term.TermLink r ->
        putWord8 20 *> putReferent r
      Term.TypeLink r ->
        putWord8 21 *> putReference r
    putTermElement :: MonadPut m => TermFormat.Term -> m ()
    putTermElement = putABT putSymbol putUnit putF
    putSymbol :: MonadPut m => TermFormat.Symbol -> m ()
    putSymbol (TermFormat.Symbol n t) = putVarInt n >> putText t
    putReferent :: MonadPut m => Referent' TermFormat.TermRef TermFormat.TypeRef -> m ()
    putReferent = \case
      Referent.Ref r -> do
        putWord8 0
        putRecursiveReference r
      Referent.Con r i -> do
        putWord8 1
        putReference r
        putVarInt i
    putMatchCase :: MonadPut m => (a -> m ()) -> Term.MatchCase TermFormat.LocalTextId TermFormat.TypeRef a -> m ()
    putMatchCase putChild (Term.MatchCase pat guard body) =
      putPattern pat *> putMaybe putChild guard *> putChild body
      where
        putPattern :: MonadPut m => Term.Pattern TermFormat.LocalTextId TermFormat.TypeRef -> m ()
        putPattern p = case p of
          Term.PUnbound -> putWord8 0
          Term.PVar -> putWord8 1
          Term.PBoolean b -> putWord8 2 *> putBoolean b
          Term.PInt n -> putWord8 3 *> putInt n
          Term.PNat n -> putWord8 4 *> putNat n
          Term.PFloat n -> putWord8 5 *> putFloat n
          Term.PConstructor r cid ps ->
            putWord8 6
              *> putReference r
              *> putVarInt cid
              *> putFoldable putPattern ps
          Term.PAs p -> putWord8 7 *> putPattern p
          Term.PEffectPure p -> putWord8 8 *> putPattern p
          Term.PEffectBind r cid args k ->
            putWord8 9
              *> putReference r
              *> putVarInt cid
              *> putFoldable putPattern args
              *> putPattern k
          Term.PSequenceLiteral ps ->
            putWord8 10 *> putFoldable putPattern ps
          Term.PSequenceOp l op r ->
            putWord8 11
              *> putPattern l
              *> putSeqOp op
              *> putPattern r
          Term.PText t -> putWord8 12 *> putVarInt t
          Term.PChar c -> putWord8 13 *> putChar c
          where
            putSeqOp :: MonadPut m => Term.SeqOp -> m ()
            putSeqOp Term.PCons = putWord8 0
            putSeqOp Term.PSnoc = putWord8 1
            putSeqOp Term.PConcat = putWord8 2

getTermComponent :: MonadGet m => m TermFormat.LocallyIndexedComponent
getTermComponent =
  TermFormat.LocallyIndexedComponent
    <$> getLocalIds <*> getFramedArray getTermElement
  where
    getF :: MonadGet m => m a -> m (TermFormat.F a)
    getF getChild = getWord8 >>= \case
      0 -> Term.Int <$> getInt
      1 -> Term.Nat <$> getNat
      2 -> Term.Float <$> getFloat
      3 -> Term.Boolean <$> getBoolean
      4 -> Term.Text <$> getVarInt
      5 -> Term.Ref <$> getRecursiveReference
      6 -> Term.Constructor <$> getReference <*> getVarInt
      7 -> Term.Request <$> getReference <*> getVarInt
      8 -> Term.Handle <$> getChild <*> getChild
      9 -> Term.App <$> getChild <*> getChild
      10 -> Term.Ann <$> getChild <*> getType getReference
      11 -> Term.Sequence <$> getSequence getChild
      12 -> Term.If <$> getChild <*> getChild <*> getChild
      13 -> Term.And <$> getChild <*> getChild
      14 -> Term.Or <$> getChild <*> getChild
      15 -> Term.Lam <$> getChild
      16 -> Term.LetRec <$> getList getChild <*> getChild
      17 -> Term.Let <$> getChild <*> getChild
      18 ->
        Term.Match
          <$> getChild
          <*> getList
            (Term.MatchCase <$> getPattern <*> getMaybe getChild <*> getChild)
      19 -> Term.Char <$> getChar
      20 -> Term.TermLink <$> getReferent
      21 -> Term.TypeLink <$> getReference
      tag -> unknownTag "getTerm" tag
    getTermElement :: MonadGet m => m TermFormat.Term
    getTermElement = getABT getSymbol getUnit getF
    getReferent :: MonadGet m => m (Referent' TermFormat.TermRef TermFormat.TypeRef)
    getReferent = getWord8 >>= \case
      0 -> Referent.Ref <$> getRecursiveReference
      1 -> Referent.Con <$> getReference <*> getVarInt
      x -> unknownTag "getTermComponent" x
    getPattern :: MonadGet m => m (Term.Pattern TermFormat.LocalTextId TermFormat.TypeRef)
    getPattern = getWord8 >>= \case
      0 -> pure Term.PUnbound
      1 -> pure Term.PVar
      2 -> Term.PBoolean <$> getBoolean
      3 -> Term.PInt <$> getInt
      4 -> Term.PNat <$> getNat
      5 -> Term.PFloat <$> getFloat
      6 -> Term.PConstructor <$> getReference <*> getVarInt <*> getList getPattern
      7 -> Term.PAs <$> getPattern
      8 -> Term.PEffectPure <$> getPattern
      9 ->
        Term.PEffectBind
          <$> getReference
          <*> getVarInt
          <*> getList getPattern
          <*> getPattern
      10 -> Term.PSequenceLiteral <$> getList getPattern
      11 ->
        Term.PSequenceOp
          <$> getPattern
          <*> getSeqOp
          <*> getPattern
      12 -> Term.PText <$> getVarInt
      13 -> Term.PChar <$> getChar
      x -> unknownTag "Pattern" x
      where
        getSeqOp :: MonadGet m => m Term.SeqOp
        getSeqOp = getWord8 >>= \case
          0 -> pure Term.PCons
          1 -> pure Term.PSnoc
          2 -> pure Term.PConcat
          tag -> unknownTag "SeqOp" tag

getType :: MonadGet m => m r -> m (Type.TypeR r TermFormat.Symbol)
getType getReference = getABT getSymbol getUnit go
  where
    go getChild = getWord8 >>= \case
      0 -> Type.Ref <$> getReference
      1 -> Type.Arrow <$> getChild <*> getChild
      2 -> Type.Ann <$> getChild <*> getKind
      3 -> Type.App <$> getChild <*> getChild
      4 -> Type.Effect <$> getChild <*> getChild
      5 -> Type.Effects <$> getList getChild
      6 -> Type.Forall <$> getChild
      7 -> Type.IntroOuter <$> getChild
      tag -> unknownTag "getType" tag
    getKind :: MonadGet m => m Kind
    getKind = getWord8 >>= \case
      0 -> pure Kind.Star
      1 -> Kind.Arrow <$> getKind <*> getKind
      tag -> unknownTag "getKind" tag

getSymbol :: MonadGet m => m TermFormat.Symbol
getSymbol = TermFormat.Symbol <$> getVarInt <*> getText

putReference ::
  (MonadPut m, Integral t, Bits t, Integral r, Bits r) =>
  Reference' t r ->
  m ()
putReference = \case
  ReferenceBuiltin t ->
    putWord8 0 *> putVarInt t
  ReferenceDerived (Reference.Id r index) ->
    putWord8 1 *> putVarInt r *> putVarInt index

getReference ::
  (MonadGet m, Integral t, Bits t, Integral r, Bits r) =>
  m (Reference' t r)
getReference = getWord8 >>= \case
  0 -> ReferenceBuiltin <$> getVarInt
  1 -> ReferenceDerived <$> (Reference.Id <$> getVarInt <*> getVarInt)
  x -> unknownTag "getRecursiveReference" x

putRecursiveReference ::
  (MonadPut m, Integral t, Bits t, Integral r, Bits r) =>
  Reference' t (Maybe r) ->
  m ()
putRecursiveReference = \case
  ReferenceBuiltin t ->
    putWord8 0 *> putVarInt t
  ReferenceDerived (Reference.Id r index) ->
    putWord8 1 *> putMaybe putVarInt r *> putVarInt index

getRecursiveReference ::
  (MonadGet m, Integral t, Bits t, Integral r, Bits r) =>
  m (Reference' t (Maybe r))
getRecursiveReference = getWord8 >>= \case
  0 -> ReferenceBuiltin <$> getVarInt
  1 -> ReferenceDerived <$> (Reference.Id <$> getMaybe getVarInt <*> getVarInt)
  x -> unknownTag "getRecursiveReference" x

putInt :: MonadPut m => Int64 -> m ()
putInt = serializeBE

getInt :: MonadGet m => m Int64
getInt = deserializeBE

putNat :: MonadPut m => Word64 -> m ()
putNat = serializeBE

getNat :: MonadGet m => m Word64
getNat = deserializeBE

putFloat :: MonadPut m => Double -> m ()
putFloat = serializeBE

getFloat :: MonadGet m => m Double
getFloat = deserializeBE

putBoolean :: MonadPut m => Bool -> m ()
putBoolean False = putWord8 0
putBoolean True = putWord8 1

getBoolean :: MonadGet m => m Bool
getBoolean = getWord8 >>= \case
  0 -> pure False
  1 -> pure True
  x -> unknownTag "Boolean" x

putType ::
  (MonadPut m, Ord v) =>
  (r -> m ()) ->
  (v -> m ()) ->
  Type.TypeR r v ->
  m ()
putType putReference putVar = putABT putVar putUnit go
  where
    go putChild t = case t of
      Type.Ref r -> putWord8 0 *> putReference r
      Type.Arrow i o -> putWord8 1 *> putChild i *> putChild o
      Type.Ann t k -> putWord8 2 *> putChild t *> putKind k
      Type.App f x -> putWord8 3 *> putChild f *> putChild x
      Type.Effect e t -> putWord8 4 *> putChild e *> putChild t
      Type.Effects es -> putWord8 5 *> putFoldable putChild es
      Type.Forall body -> putWord8 6 *> putChild body
      Type.IntroOuter body -> putWord8 7 *> putChild body
    putKind :: MonadPut m => Kind -> m ()
    putKind k = case k of
      Kind.Star -> putWord8 0
      Kind.Arrow i o -> putWord8 1 *> putKind i *> putKind o

putChar :: MonadPut m => Char -> m ()
putChar = serialize . VarInt . fromEnum

getChar :: MonadGet m => m Char
getChar = toEnum . unVarInt <$> deserialize

putMaybe :: MonadPut m => (a -> m ()) -> Maybe a -> m ()
putMaybe putA = \case
  Nothing -> putWord8 0
  Just a -> putWord8 1 *> putA a

getMaybe :: MonadGet m => m a -> m (Maybe a)
getMaybe getA = getWord8 >>= \tag -> case tag of
  0 -> pure Nothing
  1 -> Just <$> getA
  _ -> unknownTag "Maybe" tag

unknownTag :: (MonadGet m, Show a) => String -> a -> m x
unknownTag msg tag =
  fail $
    "unknown tag " ++ show tag
      ++ " while deserializing: "
      ++ msg