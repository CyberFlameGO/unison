module Unison.Util.Set
  ( difference1,
    mapMaybe,
    symmetricDifference,
    Unison.Util.Set.traverse,
    flatMap,
    filterM,
  )
where

import Data.Functor ((<&>))
import qualified Data.Maybe as Maybe
import Data.Set (Set)
import qualified Data.Set as Set
import Unison.Util.Monoid (foldMapM)

-- | Set difference, but return @Nothing@ if the difference is empty.
difference1 :: Ord a => Set a -> Set a -> Maybe (Set a)
difference1 xs ys =
  if null zs then Nothing else Just zs
  where
    zs = Set.difference xs ys

symmetricDifference :: Ord a => Set a -> Set a -> Set a
symmetricDifference a b = (a `Set.difference` b) `Set.union` (b `Set.difference` a)

mapMaybe :: Ord b => (a -> Maybe b) -> Set a -> Set b
mapMaybe f = Set.fromList . Maybe.mapMaybe f . Set.toList

traverse :: (Applicative f, Ord b) => (a -> f b) -> Set a -> f (Set b)
traverse f = fmap Set.fromList . Prelude.traverse f . Set.toList

flatMap :: Ord b => (a -> Set b) -> Set a -> Set b
flatMap f = Set.unions . fmap f . Set.toList

filterM :: (Ord a, Monad m) => (a -> m Bool) -> Set a -> m (Set a)
filterM p =
  foldMapM \x ->
    p x <&> \case
      False -> Set.empty
      True -> Set.singleton x