{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE PartialTypeSignatures #-}

-- | Find a computation of type '{IO} () in the codebase.
module Unison.Codebase.MainTerm where

import Unison.Prelude

import Unison.Parser.Ann (Ann)
import qualified Unison.Term                   as Term
import           Unison.Term                    ( Term )
import           Unison.Var                     ( Var )
import qualified Unison.Builtin.Decls          as DD
import qualified Unison.HashQualified          as HQ
import qualified Unison.Referent               as Referent
import           Unison.Name                    ( Name )
import qualified Unison.Names3                 as Names3
import           Unison.Reference               ( Reference )
import qualified Unison.Type                   as Type
import           Unison.Type                    ( Type )
import qualified Unison.Typechecker as Typechecker
import qualified Unison.Parser.Ann as Parser.Ann

data MainTerm v
  = NotAFunctionName String
  | NotFound String
  | BadType String (Maybe (Type v Ann))
  | Success (HQ.HashQualified Name) (Term v Ann) (Type v Ann)

getMainTerm
  :: (Monad m, Var v)
  => (Reference -> m (Maybe (Type v Ann)))
  -> Names3.Names0
  -> String
  -> Type.Type v Ann
  -> m (MainTerm v)
getMainTerm loadTypeOfTerm parseNames0 mainName mainType =
  case HQ.fromString mainName of
    Nothing -> pure (NotAFunctionName mainName)
    Just hq -> do
      let refs = Names3.lookupHQTerm hq (Names3.Names parseNames0 mempty)
      let a = Parser.Ann.External
      case toList refs of
        [Referent.Ref ref] -> do
          typ <- loadTypeOfTerm ref
          case typ of
            Just typ ->
              if Typechecker.isSubtype typ mainType then do
                let tm = DD.forceTerm a a (Term.ref a ref)
                return (Success hq tm typ)
              else pure (BadType mainName $ Just typ)
            _ -> pure (BadType mainName Nothing)
        _ -> pure (NotFound mainName)

-- '{io2.IO, Exception} ()
builtinMain :: Var v => a -> Type.Type v a
builtinMain a = Type.arrow a (Type.ref a DD.unitRef) io
  where io = Type.effect a [Type.builtinIO a, DD.exceptionType a] (Type.ref a DD.unitRef)

-- [Result]
resultArr :: Ord v => a -> Type.Type v a
resultArr a = Type.app a (Type.ref a Type.listRef) (Type.ref a DD.testResultRef)

builtinResultArr :: Ord v => a -> Type.Type v a
builtinResultArr a = Type.effect a [Type.builtinIO a, DD.exceptionType a] (resultArr a)

-- '{io2.IO} [Result]
builtinTest :: Ord v => a -> Type.Type v a
builtinTest a
  = Type.arrow a (Type.ref a DD.unitRef) (builtinResultArr a)
