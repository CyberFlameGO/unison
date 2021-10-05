{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# Language DeriveFoldable #-}
{-# Language DeriveTraversable #-}
{-# Language OverloadedStrings #-}
{-# Language PatternSynonyms #-}
{-# Language ViewPatterns #-}

module Unison.DataDeclaration.Names (bindNames, dataDeclToNames', effectDeclToNames') where

import Unison.Prelude

import Unison.DataDeclaration (DataDeclaration (DataDeclaration), EffectDeclaration)
import qualified Unison.DataDeclaration as DD


import qualified Unison.Util.Relation as Rel
import           Prelude                 hiding ( cycle )
import qualified Unison.Name                   as Name
import qualified Unison.Reference              as Reference
import qualified Unison.Referent               as Referent
import qualified Unison.Type.Names as Type.Names
import           Unison.Var                     ( Var )
import           Unison.Names3                 (Names0)
import qualified Unison.Names3                 as Names
import qualified Unison.Names.ResolutionResult as Names
import qualified Unison.ConstructorType as CT

-- implementation of dataDeclToNames and effectDeclToNames
toNames0 :: Var v => CT.ConstructorType -> v -> Reference.Id -> DataDeclaration v a -> Names0
toNames0 ct typeSymbol (Reference.DerivedId -> r) dd =
  -- constructor names
  foldMap names (DD.constructorVars dd `zip` [0 ..])
  -- name of the type itself
  <> Names.names0 mempty (Rel.singleton (Name.fromVar typeSymbol) r)
  where
  names (ctor, i) =
    Names.names0 (Rel.singleton (Name.fromVar ctor) (Referent.Con r i ct)) mempty

dataDeclToNames :: Var v => v -> Reference.Id -> DataDeclaration v a -> Names0
dataDeclToNames = toNames0 CT.Data

effectDeclToNames :: Var v => v -> Reference.Id -> EffectDeclaration v a -> Names0
effectDeclToNames typeSymbol r ed = toNames0 CT.Effect typeSymbol r $ DD.toDataDecl ed

dataDeclToNames' :: Var v => (v, (Reference.Id, DataDeclaration v a)) -> Names0
dataDeclToNames' (v, (r,d)) = dataDeclToNames v r d

effectDeclToNames' :: Var v => (v, (Reference.Id, EffectDeclaration v a)) -> Names0
effectDeclToNames' (v, (r, d)) = effectDeclToNames v r d

bindNames :: Var v
          => Set v
          -> Names0
          -> DataDeclaration v a
          -> Names.ResolutionResult v a (DataDeclaration v a)
bindNames keepFree names (DataDeclaration m a bound constructors) = do
  constructors <- for constructors $ \(a, v, ty) ->
    (a,v,) <$> Type.Names.bindNames keepFree names ty
  pure $ DataDeclaration m a bound constructors

