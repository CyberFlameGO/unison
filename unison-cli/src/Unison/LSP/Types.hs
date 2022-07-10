{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE PolyKinds #-}

module Unison.LSP.Types where

import Colog.Core
import Control.Lens hiding (List)
import Control.Monad.Except
import Control.Monad.Reader
import qualified Data.HashMap.Strict as HM
import Data.IntervalMap.Lazy (IntervalMap)
import qualified Ki
import qualified Language.LSP.Logging as LSP
import Language.LSP.Server
import Language.LSP.Types
import Language.LSP.Types.Lens
import Language.LSP.VFS
import Unison.Codebase
import Unison.Codebase.Editor.Command (LexedSource)
import Unison.Codebase.Runtime (Runtime)
import qualified Unison.Codebase.Runtime as Runtime
import Unison.LSP.Orphans ()
import Unison.NamesWithHistory (NamesWithHistory)
import Unison.Parser.Ann
import Unison.Prelude
import Unison.PrettyPrintEnvDecl (PrettyPrintEnvDecl)
import Unison.Result (Note)
import qualified Unison.Server.Backend as Backend
import Unison.Symbol
import qualified Unison.UnisonFile as UF
import UnliftIO

-- | A custom LSP monad wrapper so we can provide our own environment.
newtype Lsp a = Lsp {runLspM :: ReaderT Env (LspM Config) a}
  deriving newtype (Functor, Applicative, Monad, MonadIO, MonadUnliftIO, MonadReader Env, MonadLsp Config)

-- | Log an info message to the client's LSP log.
logInfo :: Text -> Lsp ()
logInfo msg = do
  let LogAction log = LSP.defaultClientLogger
  log (WithSeverity msg Info)

-- | Log an error message to the client's LSP log, this will be shown to the user in most LSP
-- implementations.
logError :: Text -> Lsp ()
logError msg = do
  let LogAction log = LSP.defaultClientLogger
  log (WithSeverity msg Error)

-- | Environment for the Lsp monad.
data Env = Env
  { -- contains handlers for talking to the client.
    lspContext :: LanguageContextEnv Config,
    codebase :: Codebase IO Symbol Ann,
    parseNamesCache :: IO NamesWithHistory,
    ppeCache :: IO PrettyPrintEnvDecl,
    vfsVar :: MVar VFS,
    runtime :: Runtime Symbol,
    -- The information we have for each file, which may or may not have a valid parse or
    -- typecheck.
    checkedFilesVar :: TVar (Map Uri FileAnalysis),
    dirtyFilesVar :: TVar (Set Uri),
    scope :: Ki.Scope
  }

-- | A monotonically increasing file version tracked by the lsp client.
type FileVersion = Int32

data FileAnalysis = FileAnalysis
  { fileUri :: Uri,
    fileVersion :: FileVersion,
    lexedSource :: LexedSource,
    parsedFile :: Maybe (UF.UnisonFile Symbol Ann),
    typecheckedFile :: Maybe (UF.TypecheckedUnisonFile Symbol Ann),
    -- This is memoized using `once`
    evaluatedFile :: Maybe (IO (Runtime.WatchResults Symbol Ann)),
    notes :: Seq (Note Symbol Ann),
    diagnostics :: IntervalMap Position [Diagnostic],
    codeActions :: IntervalMap Position [CodeAction]
  }

instance Show FileAnalysis where
  show (FileAnalysis fileUri fileVersion lexedSource parsedFile typecheckedFile evaluatedFile notes diagnostics codeActions) =
    let fields =
          [ ("fileUri", show @Uri fileUri),
            ("fileVersion", show @FileVersion fileVersion),
            ("lexedSource", show @LexedSource lexedSource),
            ("parsedFile", show @(Maybe (UF.UnisonFile Symbol Ann)) parsedFile),
            ("typecheckedFile", show @(Maybe (UF.TypecheckedUnisonFile Symbol Ann)) typecheckedFile),
            ("notes", show @(Seq (Note Symbol Ann)) notes),
            ("diagnostics", show @(IntervalMap Position [Diagnostic]) diagnostics),
            ("codeActions", show @(IntervalMap Position [CodeAction]) codeActions),
            ("evaluatedFile", maybe "Nothing" (const $ "Just (IO <evaluated_file>)") evaluatedFile)
          ]
            & foldMap \(field, contents) -> field <> " = " <> contents <> ",\n"
     in "FileAnalysis\n  { " <> fields <> "  }"

globalPPE :: (MonadReader Env m, MonadIO m) => m PrettyPrintEnvDecl
globalPPE = asks ppeCache >>= liftIO

getParseNames :: Lsp NamesWithHistory
getParseNames = asks parseNamesCache >>= liftIO

data Config = Config

-- | Lift a backend computation into the Lsp monad.
lspBackend :: Backend.Backend IO a -> Lsp (Either Backend.BackendError a)
lspBackend = liftIO . runExceptT . flip runReaderT (Backend.BackendEnv False) . Backend.runBackend

sendNotification :: forall (m :: Method 'FromServer 'Notification). (Message m ~ NotificationMessage m) => NotificationMessage m -> Lsp ()
sendNotification notif = do
  sendServerMessage <- asks (resSendMessage . lspContext)
  liftIO $ sendServerMessage $ FromServerMess (notif ^. method) (notif)

data RangedCodeAction = RangedCodeAction
  { -- All the ranges the code action applies
    _codeActionRanges :: [Range],
    _codeAction :: CodeAction
  }
  deriving stock (Eq, Show)

instance HasCodeAction RangedCodeAction CodeAction where
  codeAction = lens _codeAction (\rca ca -> rca {_codeAction = ca})

rangedCodeAction :: Text -> [Diagnostic] -> [Range] -> RangedCodeAction
rangedCodeAction title diags ranges =
  RangedCodeAction ranges $
    CodeAction
      { _title = title,
        _kind = Nothing,
        _diagnostics = Just . List $ diags,
        _isPreferred = Nothing,
        _disabled = Nothing,
        _edit = Nothing,
        _command = Nothing,
        _xdata = Nothing
      }

-- | Provided ranges must not intersect.
includeEdits :: Uri -> Text -> [Range] -> RangedCodeAction -> RangedCodeAction
includeEdits uri replacement ranges rca =
  let edits = do
        r <- ranges
        pure $ TextEdit r replacement
      workspaceEdit =
        WorkspaceEdit
          { _changes = Just $ HM.singleton uri (List edits),
            _documentChanges = Nothing,
            _changeAnnotations = Nothing
          }
   in rca & codeAction . edit ?~ workspaceEdit
