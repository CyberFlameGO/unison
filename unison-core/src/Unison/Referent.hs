{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}

module Unison.Referent
  ( Referent,
    pattern Ref,
    pattern Con,
    ConstructorId,
    Id,
    pattern RefId,
    pattern ConId,
    fold,
    toReference,
    fromText,

    -- * ShortHash helpers
    isPrefixOf,
    toShortHash,
    toText,
    toString,
    patternShortHash,
  )
where

import qualified Data.Char as Char
import qualified Data.Text as Text
import Unison.ConstructorType (ConstructorType)
import qualified Unison.ConstructorType as CT
import Unison.DataDeclaration.ConstructorId (ConstructorId)
import Unison.Prelude hiding (fold)
import Unison.Reference (Reference)
import qualified Unison.Reference as R
import Unison.Referent' (Referent' (..), toReference')
import Unison.ShortHash (ShortHash)
import qualified Unison.ShortHash as SH

-- | Specifies a term.
--
-- Either a term 'Reference', a data constructor, or an effect constructor.
--
-- Slightly odd naming. This is the "referent of term name in the codebase",
-- rather than the target of a Reference.
type Referent = Referent' Reference

pattern Ref :: Reference -> Referent
pattern Ref r = Ref' r

pattern Con :: Reference -> ConstructorId -> ConstructorType -> Referent
pattern Con r i t = Con' r i t

{-# COMPLETE Ref, Con #-}

-- | By definition, cannot be a builtin.
type Id = Referent' R.Id

pattern RefId :: R.Id -> Unison.Referent.Id
pattern RefId r = Ref' r

pattern ConId :: R.Id -> ConstructorId -> ConstructorType -> Unison.Referent.Id
pattern ConId r i t = Con' r i t

{-# COMPLETE RefId, ConId #-}

-- referentToTerm moved to Term.fromReferent
-- termToReferent moved to Term.toReferent

-- todo: move these to ShortHash module
toShortHash :: Referent -> ShortHash
toShortHash = \case
  Ref r -> R.toShortHash r
  Con r i _ -> patternShortHash r i

-- also used by HashQualified.fromPattern
patternShortHash :: Reference -> Int -> ShortHash
patternShortHash r i = (R.toShortHash r) { SH.cid = Just . Text.pack $ show i }

toText :: Referent -> Text
toText = \case
  Ref r        -> R.toText r
  Con r cid ct -> R.toText r <> "#" <> ctorTypeText ct <> Text.pack (show cid)

ctorTypeText :: CT.ConstructorType -> Text
ctorTypeText CT.Effect = EffectCtor
ctorTypeText CT.Data = DataCtor

pattern EffectCtor = "a"
pattern DataCtor = "d"

toString :: Referent -> String
toString = Text.unpack . toText

toReference :: Referent -> Reference
toReference = toReference'

isPrefixOf :: ShortHash -> Referent -> Bool
isPrefixOf sh r = SH.isPrefixOf sh (toShortHash r)

-- #abc[.xy][#<T>cid]
fromText :: Text -> Maybe Referent
fromText t = either (const Nothing) Just $
  -- if the string has just one hash at the start, it's just a reference
  if Text.length refPart == 1 then
    Ref <$> R.fromText t
  else if Text.all Char.isDigit cidPart then do
    r <- R.fromText (Text.dropEnd 1 refPart)
    ctorType <- ctorType
    let cid = read (Text.unpack cidPart)
    pure $ Con r cid ctorType
  else
    Left ("invalid constructor id: " <> Text.unpack cidPart)
  where
    ctorType = case Text.take 1 cidPart' of
      EffectCtor  -> Right CT.Effect
      DataCtor    -> Right CT.Data
      _otherwise  ->
        Left ("invalid constructor type (expected '"
          <> EffectCtor <> "' or '" <> DataCtor <> "'): " <> Text.unpack cidPart')
    refPart = Text.dropWhileEnd (/= '#') t
    cidPart' = Text.takeWhileEnd (/= '#') t
    cidPart = Text.drop 1 cidPart'

fold :: (r -> a) -> (r -> Int -> ConstructorType -> a) -> Referent' r -> a
fold fr fc = \case
  Ref' r -> fr r
  Con' r i ct -> fc r i ct
