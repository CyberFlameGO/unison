{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module Unison.Builtin.Terms
  ( builtinTermsRef
  , builtinTermsSrc
  ) where

import Data.Map (Map)
import qualified Data.Map as Map
import Data.Text (Text)
import qualified Unison.Builtin.Decls as Decls
import qualified Unison.Hashing.V2.Convert as H
import qualified Unison.Reference as Reference
import Unison.Term (Term)
import qualified Unison.Term as Term
import Unison.Type (Type)
import qualified Unison.Type as Type
import Unison.Var (Var)
import qualified Unison.Var as Var

builtinTermsSrc :: Var v => a -> [(v, Term v a, Type v a)]
builtinTermsSrc ann =
  [ ( v "metadata.isPropagated",
      Term.constructor ann Decls.isPropagatedRef Decls.isPropagatedConstructorId,
      Type.ref ann Decls.isPropagatedRef
    ),
    ( v "metadata.isTest",
      Term.constructor ann Decls.isTestRef Decls.isTestConstructorId,
      Type.ref ann Decls.isTestRef
    )
  ]

v :: Var v => Text -> v
v = Var.named

builtinTermsRef :: Var v => Map v Reference.Id
builtinTermsRef =
  fmap (\(refId, _, _) -> refId)
    . H.hashTermComponents
    . Map.fromList
    . fmap (\(v, tm, tp) -> (v, (tm, tp)))
    $ builtinTermsSrc ()
