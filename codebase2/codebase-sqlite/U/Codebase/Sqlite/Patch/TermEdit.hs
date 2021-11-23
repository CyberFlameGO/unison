module U.Codebase.Sqlite.Patch.TermEdit where

import Data.Bifoldable (Bifoldable (bifoldMap))
import Data.Bifunctor (Bifunctor (bimap))
import Data.Bitraversable (Bitraversable (bitraverse))
import U.Codebase.Reference (Reference')
import qualified U.Codebase.Referent as Referent
import qualified U.Codebase.Sqlite.DbId as Db
import U.Codebase.Sqlite.LocalIds (LocalDefnId, LocalTextId)

type TermEdit = TermEdit' Db.TextId Db.ObjectId

type LocalTermEdit = TermEdit' LocalTextId LocalDefnId

type GReferent t h = Referent.GReferent (Reference' t h) (Reference' t h)

data TermEdit' t h = Replace (GReferent t h) Typing | Deprecate
  deriving (Eq, Ord, Show)

-- Replacements with the Same type can be automatically propagated.
-- Replacements with a Subtype can be automatically propagated but may result in dependents getting more general types, so requires re-inference.
-- Replacements of a Different type need to be manually propagated by the programmer.
data Typing = Same | Subtype | Different
  deriving (Eq, Ord, Show)

instance Bifunctor TermEdit' where
  bimap f g (Replace r t) = Replace (bimap (bimap f g) (bimap f g) r) t
  bimap _ _ Deprecate = Deprecate

instance Bifoldable TermEdit' where
  bifoldMap f g (Replace r _t) = bifoldMap (bifoldMap f g) (bifoldMap f g) r
  bifoldMap _ _ Deprecate = mempty

instance Bitraversable TermEdit' where
  bitraverse f g (Replace r t) = Replace <$> bitraverse (bitraverse f g) (bitraverse f g) r <*> pure t
  bitraverse _ _ Deprecate = pure Deprecate
