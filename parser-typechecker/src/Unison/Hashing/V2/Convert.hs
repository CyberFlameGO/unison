{-# LANGUAGE ViewPatterns #-}

module Unison.Hashing.V2.Convert
  ( ResolutionResult,
    hashDecls,
    hashClosedTerm,
    hashTermComponents,
    hashTypeComponents,
    typeToReference,
    typeToReferenceMentions,
  )
where

import Control.Lens (over, _3)
import qualified Control.Lens as Lens
import Data.Map (Map)
import Data.Set (Set)
import qualified Data.Set as Set
import qualified Unison.ABT as ABT
import qualified Unison.DataDeclaration as Memory.DD
import qualified Unison.Hashing.V2.DataDeclaration as Hashing.DD
import qualified Unison.Hashing.V2.Pattern as Hashing.Pattern
import qualified Unison.Hashing.V2.Reference as Hashing.Reference
import qualified Unison.Hashing.V2.Referent as Hashing.Referent
import qualified Unison.Hashing.V2.Term as Hashing.Term
import qualified Unison.Hashing.V2.Type as Hashing.Type
import Unison.Names.ResolutionResult (ResolutionResult)
import qualified Unison.Pattern as Memory.Pattern
import qualified Unison.Reference as Memory.Reference
import qualified Unison.Referent as Memory.Referent
import qualified Unison.Term as Memory.Term
import qualified Unison.Type as Memory.Type
import Unison.Var (Var)

typeToReference :: Var v => Memory.Type.Type v a -> Memory.Reference.Reference
typeToReference = h2mReference . Hashing.Type.toReference . m2hType . Memory.Type.removeAllEffectVars

typeToReferenceMentions :: Var v => Memory.Type.Type v a -> Set Memory.Reference.Reference
typeToReferenceMentions = Set.map h2mReference . Hashing.Type.toReferenceMentions . m2hType . Memory.Type.removeAllEffectVars

hashTypeComponents :: Var v => Map v (Memory.Type.Type v a) -> Map v (Memory.Reference.Id, Memory.Type.Type v a)
hashTypeComponents = fmap h2mTypeResult . Hashing.Type.hashComponents . fmap m2hType
  where
    h2mTypeResult :: Ord v => (Hashing.Reference.Id, Hashing.Type.Type v a) -> (Memory.Reference.Id, Memory.Type.Type v a)
    h2mTypeResult (id, tp) = (h2mReferenceId id, h2mType tp)

hashTermComponents :: Var v => Map v (Memory.Term.Term v a) -> Map v (Memory.Reference.Id, Memory.Term.Term v a)
hashTermComponents = fmap h2mTermResult . Hashing.Term.hashComponents . fmap m2hTerm
  where
    h2mTermResult :: Ord v => (Hashing.Reference.Id, Hashing.Term.Term v a) -> (Memory.Reference.Id, Memory.Term.Term v a)
    h2mTermResult (id, tm) = (h2mReferenceId id, h2mTerm tm)

hashClosedTerm :: Var v => Memory.Term.Term v a -> Memory.Reference.Id
hashClosedTerm = h2mReferenceId . Hashing.Term.hashClosedTerm . m2hTerm

m2hTerm :: Ord v => Memory.Term.Term v a -> Hashing.Term.Term v a
m2hTerm = ABT.transform \case
  Memory.Term.Int i -> Hashing.Term.Int i
  Memory.Term.Nat n -> Hashing.Term.Nat n
  Memory.Term.Float d -> Hashing.Term.Float d
  Memory.Term.Boolean b -> Hashing.Term.Boolean b
  Memory.Term.Text t -> Hashing.Term.Text t
  Memory.Term.Char c -> Hashing.Term.Char c
  Memory.Term.Blank b -> Hashing.Term.Blank b
  Memory.Term.Ref r -> Hashing.Term.Ref (m2hReference r)
  Memory.Term.Constructor r i -> Hashing.Term.Constructor (m2hReference r) i
  Memory.Term.Request r i -> Hashing.Term.Request (m2hReference r) i
  Memory.Term.Handle x y -> Hashing.Term.Handle x y
  Memory.Term.App f x -> Hashing.Term.App f x
  Memory.Term.Ann e t -> Hashing.Term.Ann e (m2hType t)
  Memory.Term.List as -> Hashing.Term.List as
  Memory.Term.And p q -> Hashing.Term.And p q
  Memory.Term.If c t f -> Hashing.Term.If c t f
  Memory.Term.Or p q -> Hashing.Term.Or p q
  Memory.Term.Lam a -> Hashing.Term.Lam a
  Memory.Term.LetRec isTop bs body -> Hashing.Term.LetRec isTop bs body
  Memory.Term.Let isTop b body -> Hashing.Term.Let isTop b body
  Memory.Term.Match scr cases -> Hashing.Term.Match scr (fmap m2hMatchCase cases)
  Memory.Term.TermLink r -> Hashing.Term.TermLink (m2hReferent r)
  Memory.Term.TypeLink r -> Hashing.Term.TypeLink (m2hReference r)

m2hMatchCase :: Memory.Term.MatchCase a a1 -> Hashing.Term.MatchCase a a1
m2hMatchCase (Memory.Term.MatchCase pat m_a1 a1) = Hashing.Term.MatchCase (m2hPattern pat) m_a1 a1

m2hPattern :: Memory.Pattern.Pattern a -> Hashing.Pattern.Pattern a
m2hPattern = \case
  Memory.Pattern.Unbound loc -> Hashing.Pattern.Unbound loc
  Memory.Pattern.Var loc -> Hashing.Pattern.Var loc
  Memory.Pattern.Boolean loc b -> Hashing.Pattern.Boolean loc b
  Memory.Pattern.Int loc i -> Hashing.Pattern.Int loc i
  Memory.Pattern.Nat loc n -> Hashing.Pattern.Nat loc n
  Memory.Pattern.Float loc f -> Hashing.Pattern.Float loc f
  Memory.Pattern.Text loc t -> Hashing.Pattern.Text loc t
  Memory.Pattern.Char loc c -> Hashing.Pattern.Char loc c
  Memory.Pattern.Constructor loc r i ps -> Hashing.Pattern.Constructor loc (m2hReference r) i (fmap m2hPattern ps)
  Memory.Pattern.As loc p -> Hashing.Pattern.As loc (m2hPattern p)
  Memory.Pattern.EffectPure loc p -> Hashing.Pattern.EffectPure loc (m2hPattern p)
  Memory.Pattern.EffectBind loc r i ps k -> Hashing.Pattern.EffectBind loc (m2hReference r) i (fmap m2hPattern ps) (m2hPattern k)
  Memory.Pattern.SequenceLiteral loc ps -> Hashing.Pattern.SequenceLiteral loc (fmap m2hPattern ps)
  Memory.Pattern.SequenceOp loc l op r -> Hashing.Pattern.SequenceOp loc (m2hPattern l) (m2hSequenceOp op) (m2hPattern r)

m2hSequenceOp :: Memory.Pattern.SeqOp -> Hashing.Pattern.SeqOp
m2hSequenceOp = \case
  Memory.Pattern.Cons -> Hashing.Pattern.Cons
  Memory.Pattern.Snoc -> Hashing.Pattern.Snoc
  Memory.Pattern.Concat -> Hashing.Pattern.Concat

m2hReferent :: Memory.Referent.Referent -> Hashing.Referent.Referent
m2hReferent = \case
  Memory.Referent.Ref ref -> Hashing.Referent.Ref (m2hReference ref)
  Memory.Referent.Con ref n ct -> Hashing.Referent.Con (m2hReference ref) n ct

h2mTerm :: Ord v => Hashing.Term.Term v a -> Memory.Term.Term v a
h2mTerm = ABT.transform \case
  Hashing.Term.Int i -> Memory.Term.Int i
  Hashing.Term.Nat n -> Memory.Term.Nat n
  Hashing.Term.Float d -> Memory.Term.Float d
  Hashing.Term.Boolean b -> Memory.Term.Boolean b
  Hashing.Term.Text t -> Memory.Term.Text t
  Hashing.Term.Char c -> Memory.Term.Char c
  Hashing.Term.Blank b -> Memory.Term.Blank b
  Hashing.Term.Ref r -> Memory.Term.Ref (h2mReference r)
  Hashing.Term.Constructor r i -> Memory.Term.Constructor (h2mReference r) i
  Hashing.Term.Request r i -> Memory.Term.Request (h2mReference r) i
  Hashing.Term.Handle x y -> Memory.Term.Handle x y
  Hashing.Term.App f x -> Memory.Term.App f x
  Hashing.Term.Ann e t -> Memory.Term.Ann e (h2mType t)
  Hashing.Term.List as -> Memory.Term.List as
  Hashing.Term.If c t f -> Memory.Term.If c t f
  Hashing.Term.And p q -> Memory.Term.And p q
  Hashing.Term.Or p q -> Memory.Term.Or p q
  Hashing.Term.Lam a -> Memory.Term.Lam a
  Hashing.Term.LetRec isTop bs body -> Memory.Term.LetRec isTop bs body
  Hashing.Term.Let isTop b body -> Memory.Term.Let isTop b body
  Hashing.Term.Match scr cases -> Memory.Term.Match scr (h2mMatchCase <$> cases)
  Hashing.Term.TermLink r -> Memory.Term.TermLink (h2mReferent r)
  Hashing.Term.TypeLink r -> Memory.Term.TypeLink (h2mReference r)

h2mMatchCase :: Hashing.Term.MatchCase a b -> Memory.Term.MatchCase a b
h2mMatchCase (Hashing.Term.MatchCase pat m_b b) = Memory.Term.MatchCase (h2mPattern pat) m_b b

h2mPattern :: Hashing.Pattern.Pattern a -> Memory.Pattern.Pattern a
h2mPattern = \case
  Hashing.Pattern.Unbound loc -> Memory.Pattern.Unbound loc
  Hashing.Pattern.Var loc -> Memory.Pattern.Var loc
  Hashing.Pattern.Boolean loc b -> Memory.Pattern.Boolean loc b
  Hashing.Pattern.Int loc i -> Memory.Pattern.Int loc i
  Hashing.Pattern.Nat loc n -> Memory.Pattern.Nat loc n
  Hashing.Pattern.Float loc f -> Memory.Pattern.Float loc f
  Hashing.Pattern.Text loc t -> Memory.Pattern.Text loc t
  Hashing.Pattern.Char loc c -> Memory.Pattern.Char loc c
  Hashing.Pattern.Constructor loc r i ps -> Memory.Pattern.Constructor loc (h2mReference r) i (h2mPattern <$> ps)
  Hashing.Pattern.As loc p -> Memory.Pattern.As loc (h2mPattern p)
  Hashing.Pattern.EffectPure loc p -> Memory.Pattern.EffectPure loc (h2mPattern p)
  Hashing.Pattern.EffectBind loc r i ps k -> Memory.Pattern.EffectBind loc (h2mReference r) i (h2mPattern <$> ps) (h2mPattern k)
  Hashing.Pattern.SequenceLiteral loc ps -> Memory.Pattern.SequenceLiteral loc (h2mPattern <$> ps)
  Hashing.Pattern.SequenceOp loc l op r -> Memory.Pattern.SequenceOp loc (h2mPattern l) (h2mSequenceOp op) (h2mPattern r)

h2mSequenceOp :: Hashing.Pattern.SeqOp -> Memory.Pattern.SeqOp
h2mSequenceOp = \case
  Hashing.Pattern.Cons -> Memory.Pattern.Cons
  Hashing.Pattern.Snoc -> Memory.Pattern.Snoc
  Hashing.Pattern.Concat -> Memory.Pattern.Concat

h2mReferent :: Hashing.Referent.Referent -> Memory.Referent.Referent
h2mReferent = \case
  Hashing.Referent.Ref ref -> Memory.Referent.Ref (h2mReference ref)
  Hashing.Referent.Con ref n ct -> Memory.Referent.Con (h2mReference ref) n ct

hashDecls ::
  Var v =>
  Map v (Memory.DD.DataDeclaration v a) ->
  ResolutionResult v a [(v, Memory.Reference.Id, Memory.DD.DataDeclaration v a)]
hashDecls memDecls = do
  let hashingDecls = fmap m2hDecl memDecls
  hashingResult <- Hashing.DD.hashDecls hashingDecls
  pure $ map h2mDeclResult hashingResult
  where
    h2mDeclResult :: Ord v => (v, Hashing.Reference.Id, Hashing.DD.DataDeclaration v a) -> (v, Memory.Reference.Id, Memory.DD.DataDeclaration v a)
    h2mDeclResult (v, id, dd) = (v, h2mReferenceId id, h2mDecl dd)

m2hDecl :: Ord v => Memory.DD.DataDeclaration v a -> Hashing.DD.DataDeclaration v a
m2hDecl (Memory.DD.DataDeclaration mod ann bound ctors) =
  Hashing.DD.DataDeclaration (m2hModifier mod) ann bound $ fmap (Lens.over _3 m2hType) ctors

m2hType :: Ord v => Memory.Type.Type v a -> Hashing.Type.Type v a
m2hType = ABT.transform \case
  Memory.Type.Ref ref -> Hashing.Type.Ref (m2hReference ref)
  Memory.Type.Arrow a1 a1' -> Hashing.Type.Arrow a1 a1'
  Memory.Type.Ann a1 ki -> Hashing.Type.Ann a1 ki
  Memory.Type.App a1 a1' -> Hashing.Type.App a1 a1'
  Memory.Type.Effect a1 a1' -> Hashing.Type.Effect a1 a1'
  Memory.Type.Effects a1s -> Hashing.Type.Effects a1s
  Memory.Type.Forall a1 -> Hashing.Type.Forall a1
  Memory.Type.IntroOuter a1 -> Hashing.Type.IntroOuter a1

m2hReference :: Memory.Reference.Reference -> Hashing.Reference.Reference
m2hReference = \case
  Memory.Reference.Builtin t -> Hashing.Reference.Builtin t
  Memory.Reference.DerivedId d -> Hashing.Reference.DerivedId (m2hReferenceId d)

m2hReferenceId :: Memory.Reference.Id -> Hashing.Reference.Id
m2hReferenceId (Memory.Reference.Id h i _n) = Hashing.Reference.Id h i _n

h2mModifier :: Hashing.DD.Modifier -> Memory.DD.Modifier
h2mModifier = \case
  Hashing.DD.Structural -> Memory.DD.Structural
  Hashing.DD.Unique text -> Memory.DD.Unique text

m2hModifier :: Memory.DD.Modifier -> Hashing.DD.Modifier
m2hModifier = \case
  Memory.DD.Structural -> Hashing.DD.Structural
  Memory.DD.Unique text -> Hashing.DD.Unique text

h2mDecl :: Ord v => Hashing.DD.DataDeclaration v a -> Memory.DD.DataDeclaration v a
h2mDecl (Hashing.DD.DataDeclaration mod ann bound ctors) =
  Memory.DD.DataDeclaration (h2mModifier mod) ann bound (over _3 h2mType <$> ctors)

h2mType :: Ord v => Hashing.Type.Type v a -> Memory.Type.Type v a
h2mType = ABT.transform \case
  Hashing.Type.Ref ref -> Memory.Type.Ref (h2mReference ref)
  Hashing.Type.Arrow a1 a1' -> Memory.Type.Arrow a1 a1'
  Hashing.Type.Ann a1 ki -> Memory.Type.Ann a1 ki
  Hashing.Type.App a1 a1' -> Memory.Type.App a1 a1'
  Hashing.Type.Effect a1 a1' -> Memory.Type.Effect a1 a1'
  Hashing.Type.Effects a1s -> Memory.Type.Effects a1s
  Hashing.Type.Forall a1 -> Memory.Type.Forall a1
  Hashing.Type.IntroOuter a1 -> Memory.Type.IntroOuter a1

h2mReference :: Hashing.Reference.Reference -> Memory.Reference.Reference
h2mReference = \case
  Hashing.Reference.Builtin t -> Memory.Reference.Builtin t
  Hashing.Reference.DerivedId d -> Memory.Reference.DerivedId (h2mReferenceId d)

h2mReferenceId :: Hashing.Reference.Id -> Memory.Reference.Id
h2mReferenceId (Hashing.Reference.Id h i n) = Memory.Reference.Id h i n
