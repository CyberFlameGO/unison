{- ORMOLU_DISABLE -} -- Remove this when the file is ready to be auto-formatted
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Unison.Test.Ucm
  ( initCodebase,
    deleteCodebase,
    runTranscript,
    lowLevel,
    CodebaseFormat (..),
    Transcript,
    unTranscript,
    Codebase (..),
  )
where

import Control.Monad (when)
import qualified Data.Text as Text
import System.Directory (removeDirectoryRecursive)
import System.FilePath ((</>))
import qualified System.IO.Temp as Temp
import U.Util.String (stripMargin)
import Unison.Codebase (CodebasePath)
import qualified Unison.Codebase as Codebase
import qualified Unison.Codebase.Init as Codebase.Init
import qualified Unison.Codebase.SqliteCodebase as SC
import qualified Unison.Codebase.TranscriptParser as TR
import Unison.Prelude (traceM)
import qualified Unison.PrettyTerminal as PT
import qualified Unison.Util.Pretty as P
import Unison.Parser.Ann (Ann)
import Unison.Symbol (Symbol)
import Unison.Codebase.Init.CreateCodebaseError (CreateCodebaseError(..))

data CodebaseFormat = CodebaseFormat2 deriving (Show, Enum, Bounded)

data Codebase = Codebase CodebasePath CodebaseFormat deriving (Show)

-- newtype Transcript = Transcript {unTranscript :: Text}
--   deriving (IsString, Show, Semigroup) via Text
type Transcript = String
unTranscript :: a -> a
unTranscript = id

type TranscriptOutput = String

debugTranscriptOutput :: Bool
debugTranscriptOutput = False

initCodebase :: CodebaseFormat -> IO Codebase
initCodebase fmt = do
  let cbInit = case fmt of CodebaseFormat2 -> SC.init
  tmp <-
    Temp.getCanonicalTemporaryDirectory
      >>= flip Temp.createTempDirectory "ucm-test"
  result <- Codebase.Init.withCreatedCodebase cbInit "ucm-test" tmp (const $ pure ())
  case result of
    Left CreateCodebaseAlreadyExists -> fail $ P.toANSI 80 "Codebase already exists"
    Left (CreateCodebaseOther p) -> fail $ P.toANSI 80 p
    Right _ -> pure $ Codebase tmp fmt

deleteCodebase :: Codebase -> IO ()
deleteCodebase (Codebase path _) = removeDirectoryRecursive path

runTranscript :: Codebase -> Transcript -> IO TranscriptOutput
runTranscript (Codebase codebasePath fmt) transcript = do
  -- this configFile ought to be optional
  configFile <- do
    tmpDir <-
      Temp.getCanonicalTemporaryDirectory
        >>= flip Temp.createTempDirectory ("ucm-test")
    pure $ tmpDir </> ".unisonConfig"
  let err err = fail $ "Parse error: \n" <> show err
      cbInit = case fmt of CodebaseFormat2 -> SC.init
  result <- Codebase.Init.withOpenCodebase cbInit "transcript" codebasePath \codebase -> do
    Codebase.installUcmDependencies codebase
    -- parse and run the transcript
    output <-
      flip (either err) (TR.parse "transcript" (Text.pack . stripMargin $ unTranscript transcript)) $ \stanzas ->
        fmap Text.unpack $
          TR.run "Unison.Test.Ucm.runTranscript Invalid Version String"
            codebasePath
            configFile
            stanzas
            codebase
    when debugTranscriptOutput $ traceM output
    pure output
  case result of
    Left e -> fail $ P.toANSI 80 (P.shown e)
    Right x -> pure x

lowLevel :: Codebase -> (Codebase.Codebase IO Symbol Ann -> IO a) -> IO a
lowLevel (Codebase root fmt) action = do
  let cbInit = case fmt of CodebaseFormat2 -> SC.init
  result <- Codebase.Init.withOpenCodebase cbInit "lowLevel" root action
  case result of
    Left e -> PT.putPrettyLn (P.shown e) *> pure (error "This really should have loaded")
    Right a -> pure a
