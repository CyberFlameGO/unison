{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE RankNTypes #-}

module Unison.Codebase.Branch
  ( -- * Branch types
    Branch(..)
  , BranchDiff(..)
  , UnwrappedBranch
  , Branch0(..)
  , Raw(..)
  , Star
  , Hash
  , EditHash
  , pattern Hash
  -- * Branch construction
  , branch0
  , one
  , cons
  , uncons
  , empty
  , empty0
  , discardHistory0
  , toCausalRaw
  , transform
  -- * Branch tests
  , isEmpty
  , isEmpty0
  , isOne
  , before
  , lca
  -- * diff
  , diff0
  -- * properties
  , head
  , headHash
  , children
  , deepEdits'
  , toList0
  -- * step
  , stepManyAt
  , stepManyAtM
  , stepManyAt0
  , stepEverywhere
  -- *
  , addTermName
  , addTypeName
  , deleteTermName
  , deleteTypeName
  , setChildBranch
  , replacePatch
  , deletePatch
  , getMaybePatch
  , getPatch
  , modifyPatches
  -- ** Children queries
  , getAt
  , getAt'
  , getAt0
  , modifyAt
  , modifyAtM
  -- * Branch terms/types/edits
  -- ** Term/type/edits lenses
  , terms
  , types
  , edits
    -- ** Term/type queries
  , deepReferents
  , deepTypeReferences
  -- * Branch serialization
  , cachedRead
  , Cache
  , sync
  ) where

import Unison.Prelude hiding (empty)

import           Prelude                  hiding (head,read,subtract)

import           Control.Lens            hiding ( children, cons, transform, uncons )
import qualified Control.Monad.State           as State
import           Control.Monad.State            ( StateT )
import           Data.Bifunctor                 ( second )
import qualified Data.Map                      as Map
import qualified Data.Map.Merge.Lazy           as Map
import qualified Data.Set                      as Set
import qualified Unison.Codebase.Patch         as Patch
import           Unison.Codebase.Patch          ( Patch )
import qualified Unison.Codebase.Causal        as Causal
import           Unison.Codebase.Causal         ( Causal
                                                , pattern RawOne
                                                , pattern RawCons
                                                , pattern RawMerge
                                                )
import           Unison.Codebase.Path           ( Path(..) )
import qualified Unison.Codebase.Path          as Path
import           Unison.NameSegment             ( NameSegment )
import qualified Unison.NameSegment            as NameSegment
import qualified Unison.Codebase.Metadata      as Metadata
import qualified Unison.Hash                   as Hash
import           Unison.Hashable                ( Hashable )
import qualified Unison.Hashable               as H
import           Unison.Name                    ( Name(..) )
import qualified Unison.Name                   as Name
import           Unison.Reference               ( Reference )
import           Unison.Referent                ( Referent )

import qualified U.Util.Cache             as Cache
import qualified Unison.Util.Relation          as R
import           Unison.Util.Relation            ( Relation )
import qualified Unison.Util.Relation4         as R4
import qualified Unison.Util.Star3             as Star3
import qualified Unison.Util.List as List

-- | A node in the Unison namespace hierarchy
-- along with its history.
newtype Branch m = Branch { _history :: UnwrappedBranch m }
  deriving (Eq, Ord)
type UnwrappedBranch m = Causal m Raw (Branch0 m)

type Hash = Causal.RawHash Raw
type EditHash = Hash.Hash

type Star r n = Metadata.Star r n

-- | A node in the Unison namespace hierarchy.
--
-- '_terms' and '_types' are the declarations at this level.
-- '_children' are the nodes one level below us.
-- '_edits' are the 'Patch's stored at this node in the code.
--
-- The @deep*@ fields are derived from the four above.
data Branch0 m = Branch0
  { _terms :: Star Referent NameSegment
  , _types :: Star Reference NameSegment
  , _children :: Map NameSegment (Branch m)
    -- ^ Note the 'Branch' here, not 'Branch0'.
    -- Every level in the tree has a history.
  , _edits :: Map NameSegment (EditHash, m Patch)
  -- names and metadata for this branch and its children
  -- (ref, (name, value)) iff ref has metadata `value` at name `name`
  , deepTerms :: Relation Referent Name
  , deepTypes :: Relation Reference Name
  , deepTermMetadata :: Metadata.R4 Referent Name
  , deepTypeMetadata :: Metadata.R4 Reference Name
  , deepPaths :: Set Path
  , deepEdits :: Map Name EditHash
  }

-- Represents a shallow diff of a Branch0.
-- Each of these `Star`s contain metadata as well, so an entry in
-- `added` or `removed` could be an update to the metadata.
data BranchDiff = BranchDiff
  { addedTerms :: Star Referent NameSegment
  , removedTerms :: Star Referent NameSegment
  , addedTypes :: Star Reference NameSegment
  , removedTypes :: Star Reference NameSegment
  , changedPatches :: Map NameSegment Patch.PatchDiff
  } deriving (Eq, Ord, Show)

instance Semigroup BranchDiff where
  left <> right = BranchDiff
    { addedTerms     = addedTerms left <> addedTerms right
    , removedTerms   = removedTerms left <> removedTerms right
    , addedTypes     = addedTypes left <> addedTypes right
    , removedTypes   = removedTypes left <> removedTypes right
    , changedPatches =
        Map.unionWith (<>) (changedPatches left) (changedPatches right)
    }

instance Monoid BranchDiff where
  mappend = (<>)
  mempty = BranchDiff mempty mempty mempty mempty mempty

-- The raw Branch
data Raw = Raw
  { _termsR :: Star Referent NameSegment
  , _typesR :: Star Reference NameSegment
  , _childrenR :: Map NameSegment Hash
  , _editsR :: Map NameSegment EditHash
  }

makeLenses ''Branch
makeLensesFor [("_edits", "edits")] ''Branch0

deepReferents :: Branch0 m -> Set Referent
deepReferents = R.dom . deepTerms

deepTypeReferences :: Branch0 m -> Set Reference
deepTypeReferences = R.dom . deepTypes

terms :: Lens' (Branch0 m) (Star Referent NameSegment)
terms = lens _terms (\Branch0{..} x -> branch0 x _types _children _edits)

types :: Lens' (Branch0 m) (Star Reference NameSegment)
types = lens _types (\Branch0{..} x -> branch0 _terms x _children _edits)

children :: Lens' (Branch0 m) (Map NameSegment (Branch m))
children = lens _children (\Branch0{..} x -> branch0 _terms _types x _edits)

-- creates a Branch0 from the primary fields and derives the others.
branch0 :: Metadata.Star Referent NameSegment
        -> Metadata.Star Reference NameSegment
        -> Map NameSegment (Branch m)
        -> Map NameSegment (EditHash, m Patch)
        -> Branch0 m
branch0 terms types children edits =
  Branch0 terms types children edits
          deepTerms' deepTypes'
          deepTermMetadata' deepTypeMetadata'
          deepPaths' deepEdits'
  where
  nameSegToName = Name.unsafeFromText . NameSegment.toText
  deepTerms' = (R.mapRan nameSegToName . Star3.d1) terms
    <> foldMap go (Map.toList children)
   where
    go (nameSegToName -> n, b) =
      R.mapRan (Name.joinDot n) (deepTerms $ head b) -- could use mapKeysMonotonic
  deepTypes' = (R.mapRan nameSegToName . Star3.d1) types
    <> foldMap go (Map.toList children)
   where
    go (nameSegToName -> n, b) =
      R.mapRan (Name.joinDot n) (deepTypes $ head b) -- could use mapKeysMonotonic
  deepTermMetadata' = R4.mapD2 nameSegToName (Metadata.starToR4 terms)
    <> foldMap go (Map.toList children)
   where
    go (nameSegToName -> n, b) =
      R4.mapD2 (Name.joinDot n) (deepTermMetadata $ head b)
  deepTypeMetadata' = R4.mapD2 nameSegToName (Metadata.starToR4 types)
    <> foldMap go (Map.toList children)
   where
    go (nameSegToName -> n, b) =
      R4.mapD2 (Name.joinDot n) (deepTypeMetadata $ head b)
  deepPaths' = Set.map Path.singleton (Map.keysSet children)
    <> foldMap go (Map.toList children)
    where go (nameSeg, b) = Set.map (Path.cons nameSeg) (deepPaths $ head b)
  deepEdits' = Map.mapKeys nameSegToName (Map.map fst edits)
    <> foldMap go (Map.toList children)
   where
    go (nameSeg, b) =
      Map.mapKeys (nameSegToName nameSeg `Name.joinDot`) . deepEdits $ head b

head :: Branch m -> Branch0 m
head (Branch c) = Causal.head c

headHash :: Branch m -> Hash
headHash (Branch c) = Causal.currentHash c

-- | a version of `deepEdits` that returns the `m Patch` as well.
deepEdits' :: Branch0 m -> Map Name (EditHash, m Patch)
deepEdits' b = go id b where
  -- can change this to an actual prefix once Name is a [NameSegment]
  go :: (Name -> Name) -> Branch0 m -> Map Name (EditHash, m Patch)
  go addPrefix Branch0{..} =
    Map.mapKeysMonotonic (addPrefix . Name.fromSegment) _edits
      <> foldMap f (Map.toList _children)
    where
    f :: (NameSegment, Branch m) -> Map Name (EditHash, m Patch)
    f (c, b) =  go (addPrefix . Name.joinDot (Name.fromSegment c)) (head b)

-- Discards the history of a Branch0's children, recursively
discardHistory0 :: Applicative m => Branch0 m -> Branch0 m
discardHistory0 = over children (fmap tweak) where
  tweak b = cons (discardHistory0 (head b)) empty

-- `before b1 b2` is true if `b2` incorporates all of `b1`
before :: Monad m => Branch m -> Branch m -> m Bool
before (Branch b1) (Branch b2) = Causal.before b1 b2

pattern Hash h = Causal.RawHash h

-- | what does this do? —AI
toList0 :: Branch0 m -> [(Path, Branch0 m)]
toList0 = go Path.empty where
  go p b = (p, b) : (Map.toList (_children b) >>= (\(seg, cb) ->
    go (Path.snoc p seg) (head cb) ))

instance Eq (Branch0 m) where
  a == b = view terms a == view terms b
    && view types a == view types b
    && view children a == view children b
    && (fmap fst . view edits) a == (fmap fst . view edits) b

-- This type is a little ugly, so we wrap it up with a nice type alias for
-- use outside this module.
type Cache m = Cache.Cache (Causal.RawHash Raw) (UnwrappedBranch m)

-- Can use `Cache.nullCache` to disable caching if needed
cachedRead :: forall m . MonadIO m
           => Cache m
           -> Causal.Deserialize m Raw Raw
           -> (EditHash -> m Patch)
           -> Hash
           -> m (Branch m)
cachedRead cache deserializeRaw deserializeEdits h =
 Branch <$> Causal.cachedRead cache d h
 where
  fromRaw :: Raw -> m (Branch0 m)
  fromRaw Raw {..} = do
    children <- traverse go _childrenR
    edits <- for _editsR $ \hash -> (hash,) . pure <$> deserializeEdits hash
    pure $ branch0 _termsR _typesR children edits
  go = cachedRead cache deserializeRaw deserializeEdits
  d :: Causal.Deserialize m Raw (Branch0 m)
  d h = deserializeRaw h >>= \case
    RawOne raw      -> RawOne <$> fromRaw raw
    RawCons  raw h  -> flip RawCons h <$> fromRaw raw
    RawMerge raw hs -> flip RawMerge hs <$> fromRaw raw

sync
  :: Monad m
  => (Hash -> m Bool)
  -> Causal.Serialize m Raw Raw
  -> (EditHash -> m Patch -> m ())
  -> Branch m
  -> m ()
sync exists serializeRaw serializeEdits b = do
  _written <- State.execStateT (sync' exists serializeRaw serializeEdits b) mempty
  -- traceM $ "Branch.sync wrote " <> show (Set.size written) <> " namespace files."
  pure ()

-- serialize a `Branch m` indexed by the hash of its corresponding Raw
sync'
  :: forall m
   . Monad m
  => (Hash -> m Bool)
  -> Causal.Serialize m Raw Raw
  -> (EditHash -> m Patch -> m ())
  -> Branch m
  -> StateT (Set Hash) m ()
sync' exists serializeRaw serializeEdits b = Causal.sync exists
                                                         serialize0
                                                         (view history b)
 where
  serialize0 :: Causal.Serialize (StateT (Set Hash) m) Raw (Branch0 m)
  serialize0 h b0 = case b0 of
    RawOne b0 -> do
      writeB0 b0
      lift $ serializeRaw h $ RawOne (toRaw b0)
    RawCons b0 ht -> do
      writeB0 b0
      lift $ serializeRaw h $ RawCons (toRaw b0) ht
    RawMerge b0 hs -> do
      writeB0 b0
      lift $ serializeRaw h $ RawMerge (toRaw b0) hs
   where
    writeB0 :: Branch0 m -> StateT (Set Hash) m ()
    writeB0 b0 = do
      for_ (view children b0) $ \c -> do
        queued <- State.get
        when (Set.notMember (headHash c) queued) $
          sync' exists serializeRaw serializeEdits c
      for_ (view edits b0) (lift . uncurry serializeEdits)

  -- this has to serialize the branch0 and its descendants in the tree,
  -- and then serialize the rest of the history of the branch as well

toRaw :: Branch0 m -> Raw
toRaw Branch0 {..} =
  Raw _terms _types (headHash <$> _children) (fst <$> _edits)

toCausalRaw :: Branch m -> Causal.Raw Raw Raw
toCausalRaw = \case
  Branch (Causal.One _h e)           -> RawOne (toRaw e)
  Branch (Causal.Cons _h e (ht, _m)) -> RawCons (toRaw e) ht
  Branch (Causal.Merge _h e tls)     -> RawMerge (toRaw e) (Map.keysSet tls)

-- returns `Nothing` if no Branch at `path` or if Branch is empty at `path`
getAt :: Path
      -> Branch m
      -> Maybe (Branch m)
getAt path root = case Path.uncons path of
  Nothing -> if isEmpty root then Nothing else Just root
  Just (seg, path) -> case Map.lookup seg (_children $ head root) of
    Just b -> getAt path b
    Nothing -> Nothing

getAt' :: Path -> Branch m -> Branch m
getAt' p b = fromMaybe empty $ getAt p b

getAt0 :: Path -> Branch0 m -> Branch0 m
getAt0 p b = case Path.uncons p of
  Nothing -> b
  Just (seg, path) -> case Map.lookup seg (_children b) of
    Just c -> getAt0 path (head c)
    Nothing -> empty0

empty :: Branch m
empty = Branch $ Causal.one empty0

one :: Branch0 m -> Branch m
one = Branch . Causal.one

empty0 :: Branch0 m
empty0 =
  Branch0 mempty mempty mempty mempty mempty mempty mempty mempty mempty mempty

isEmpty0 :: Branch0 m -> Bool
isEmpty0 = (== empty0)

isEmpty :: Branch m -> Bool
isEmpty = (== empty)

step :: Applicative m => (Branch0 m -> Branch0 m) -> Branch m -> Branch m
step f = \case
  Branch (Causal.One _h e) | e == empty0 -> Branch (Causal.one (f empty0))
  b -> over history (Causal.stepDistinct f) b

stepM :: (Monad m, Monad n) => (Branch0 m -> n (Branch0 m)) -> Branch m -> n (Branch m)
stepM f = \case
  Branch (Causal.One _h e) | e == empty0 -> Branch . Causal.one <$> f empty0
  b -> mapMOf history (Causal.stepDistinctM f) b

cons :: Applicative m => Branch0 m -> Branch m -> Branch m
cons = step . const

isOne :: Branch m -> Bool
isOne (Branch Causal.One{}) = True
isOne _ = False

uncons :: Applicative m => Branch m -> m (Maybe (Branch0 m, Branch m))
uncons (Branch b) = go <$> Causal.uncons b where
  go = over (_Just . _2) Branch

stepManyAt :: (Monad m, Foldable f)
           => f (Path, Branch0 m -> Branch0 m) -> Branch m -> Branch m
stepManyAt actions = step (stepManyAt0 actions)

stepManyAtM :: (Monad m, Monad n, Foldable f)
            => f (Path, Branch0 m -> n (Branch0 m)) -> Branch m -> n (Branch m)
stepManyAtM actions = stepM (stepManyAt0M actions)

-- starting at the leaves, apply `f` to every level of the branch.
stepEverywhere
  :: Applicative m => (Branch0 m -> Branch0 m) -> (Branch0 m -> Branch0 m)
stepEverywhere f Branch0 {..} = f (branch0 _terms _types children _edits)
  where children = fmap (step $ stepEverywhere f) _children

-- Creates a function to fix up the children field._1
-- If the action emptied a child, then remove the mapping,
-- otherwise update it.
-- Todo: Fix this in hashing & serialization instead of here?
getChildBranch :: NameSegment -> Branch0 m -> Branch m
getChildBranch seg b = fromMaybe empty $ Map.lookup seg (_children b)

setChildBranch :: NameSegment -> Branch m -> Branch0 m -> Branch0 m
setChildBranch seg b = over children (updateChildren seg b)

getPatch :: Applicative m => NameSegment -> Branch0 m -> m Patch
getPatch seg b = case Map.lookup seg (_edits b) of
  Nothing -> pure Patch.empty
  Just (_, p) -> p

getMaybePatch :: Applicative m => NameSegment -> Branch0 m -> m (Maybe Patch)
getMaybePatch seg b = case Map.lookup seg (_edits b) of
  Nothing -> pure Nothing
  Just (_, p) -> Just <$> p

modifyPatches
  :: Monad m => NameSegment -> (Patch -> Patch) -> Branch0 m -> m (Branch0 m)
modifyPatches seg f = mapMOf edits update
 where
  update m = do
    p' <- case Map.lookup seg m of
      Nothing     -> pure $ f Patch.empty
      Just (_, p) -> f <$> p
    let h = H.accumulate' p'
    pure $ Map.insert seg (h, pure p') m

replacePatch :: Applicative m => NameSegment -> Patch -> Branch0 m -> Branch0 m
replacePatch n p = over edits (Map.insert n (H.accumulate' p, pure p))

deletePatch :: NameSegment -> Branch0 m -> Branch0 m
deletePatch n = over edits (Map.delete n)

updateChildren ::NameSegment
               -> Branch m
               -> Map NameSegment (Branch m)
               -> Map NameSegment (Branch m)
updateChildren seg updatedChild =
  if isEmpty updatedChild
  then Map.delete seg
  else Map.insert seg updatedChild

-- Modify the Branch at `path` with `f`, after creating it if necessary.
-- Because it's a `Branch`, it overwrites the history at `path`.
modifyAt :: Applicative m
  => Path -> (Branch m -> Branch m) -> Branch m -> Branch m
modifyAt path f = runIdentity . modifyAtM path (pure . f)

-- Modify the Branch at `path` with `f`, after creating it if necessary.
-- Because it's a `Branch`, it overwrites the history at `path`.
modifyAtM
  :: forall n m
   . Functor n
  => Applicative m -- because `Causal.cons` uses `pure`
  => Path
  -> (Branch m -> n (Branch m))
  -> Branch m
  -> n (Branch m)
modifyAtM path f b = case Path.uncons path of
  Nothing -> f b
  Just (seg, path) -> do -- Functor
    let child = getChildBranch seg (head b)
    child' <- modifyAtM path f child
    -- step the branch by updating its children according to fixup
    pure $ step (setChildBranch seg child') b

-- stepManyAt0 consolidates several changes into a single step
stepManyAt0 :: forall f m . (Monad m, Foldable f)
           => f (Path, Branch0 m -> Branch0 m)
           -> Branch0 m -> Branch0 m
stepManyAt0 actions =
  runIdentity . stepManyAt0M [ (p, pure . f) | (p,f) <- toList actions ]

stepManyAt0M :: forall m n f . (Monad m, Monad n, Foldable f)
             => f (Path, Branch0 m -> n (Branch0 m))
             -> Branch0 m -> n (Branch0 m)
stepManyAt0M actions b = go (toList actions) b where
  go :: [(Path, Branch0 m -> n (Branch0 m))] -> Branch0 m -> n (Branch0 m)
  go actions b = let
    -- combines the functions that apply to this level of the tree
    currentAction b = foldM (\b f -> f b) b [ f | (Path.Empty, f) <- actions ]

    -- groups the actions based on the child they apply to
    childActions :: Map NameSegment [(Path, Branch0 m -> n (Branch0 m))]
    childActions =
      List.multimap [ (seg, (rest,f)) | (seg :< rest, f) <- actions ]

    -- alters the children of `b` based on the `childActions` map
    stepChildren :: Map NameSegment (Branch m) -> n (Map NameSegment (Branch m))
    stepChildren children0 = foldM g children0 $ Map.toList childActions
      where
      g children (seg, actions) = do
        -- Recursively applies the relevant actions to the child branch
        -- The `findWithDefault` is important - it allows the stepManyAt
        -- to create new children at paths that don't previously exist.
        child <- stepM (go actions) (Map.findWithDefault empty seg children0)
        pure $ updateChildren seg child children
    in do
      c2 <- stepChildren (view children b)
      currentAction (set children c2 b)

instance Hashable (Branch0 m) where
  tokens b =
    [ H.accumulateToken (_terms b)
    , H.accumulateToken (_types b)
    , H.accumulateToken (headHash <$> _children b)
    , H.accumulateToken (fst <$> _edits b)
    ]

-- todo: consider inlining these into Actions2
addTermName
  :: Referent -> NameSegment -> Metadata.Metadata -> Branch0 m -> Branch0 m
addTermName r new md =
  over terms (Metadata.insertWithMetadata (r, md) . Star3.insertD1 (r, new))

addTypeName
  :: Reference -> NameSegment -> Metadata.Metadata -> Branch0 m -> Branch0 m
addTypeName r new md =
  over types (Metadata.insertWithMetadata (r, md) . Star3.insertD1 (r, new))

deleteTermName :: Referent -> NameSegment -> Branch0 m -> Branch0 m
deleteTermName r n b | Star3.memberD1 (r,n) (view terms b)
                     = over terms (Star3.deletePrimaryD1 (r,n)) b
deleteTermName _ _ b = b

deleteTypeName :: Reference -> NameSegment -> Branch0 m -> Branch0 m
deleteTypeName r n b | Star3.memberD1 (r,n) (view types b)
                     = over types (Star3.deletePrimaryD1 (r,n)) b
deleteTypeName _ _ b = b

lca :: Monad m => Branch m -> Branch m -> m (Maybe (Branch m))
lca (Branch a) (Branch b) = fmap Branch <$> Causal.lca a b

diff0 :: Monad m => Branch0 m -> Branch0 m -> m BranchDiff
diff0 old new = do
  newEdits <- sequenceA $ snd <$> _edits new
  oldEdits <- sequenceA $ snd <$> _edits old
  let diffEdits = Map.merge (Map.mapMissing $ \_ p -> Patch.diff p mempty)
                            (Map.mapMissing $ \_ p -> Patch.diff mempty p)
                            (Map.zipWithMatched (const Patch.diff))
                            newEdits
                            oldEdits
  pure $ BranchDiff
    { addedTerms     = Star3.difference (_terms new) (_terms old)
    , removedTerms   = Star3.difference (_terms old) (_terms new)
    , addedTypes     = Star3.difference (_types new) (_types old)
    , removedTypes   = Star3.difference (_types old) (_types new)
    , changedPatches = diffEdits
    }

transform :: Functor m => (forall a . m a -> n a) -> Branch m -> Branch n
transform f b = case _history b of
  causal -> Branch . Causal.transform f $ transformB0s f causal
  where
  transformB0 :: Functor m => (forall a . m a -> n a) -> Branch0 m -> Branch0 n
  transformB0 f b =
    b { _children = transform f <$> _children b
      , _edits    = second f    <$> _edits b
      }

  transformB0s :: Functor m => (forall a . m a -> n a)
               -> Causal m Raw (Branch0 m)
               -> Causal m Raw (Branch0 n)
  transformB0s f = Causal.unsafeMapHashPreserving (transformB0 f)
