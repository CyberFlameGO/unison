{- ORMOLU_DISABLE -} -- Remove this when the file is ready to be auto-formatted
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE QuasiQuotes #-}

module Unison.Test.CodebaseInit where

import EasyTest
import qualified Unison.Codebase.Init as CI
import Unison.Codebase.Init
    ( CodebaseInitOptions(..)
    , Init(..)
    , SpecifiedCodebase(..)
    )
import qualified System.IO.Temp as Temp

-- keep it off for CI, since the random temp dirs it generates show up in the
-- output, which causes the test output to change, and the "no change" check
-- to fail
writeTranscriptOutput :: Bool
writeTranscriptOutput = False

test :: Test ()
test = scope "Codebase.Init" $ tests
  [ scope "*without* a --codebase flag" $ tests
    [ scope "a v2 codebase should be opened" do
        tmp <- io (Temp.getCanonicalTemporaryDirectory >>= flip Temp.createTempDirectory "ucm-test")
        cbInit <- io initMockWithCodebase
        res <- io (CI.openOrCreateCodebase cbInit "ucm-test" (Home tmp))
        case res of 
          CI.OpenedCodebase _ _ -> expect True
          _ -> expect False
    , scope "a v2 codebase should be created when one does not exist" do
        tmp <- io (Temp.getCanonicalTemporaryDirectory >>= flip Temp.createTempDirectory "ucm-test")
        cbInit <- io initMockWithoutCodebase
        res <- io (CI.openOrCreateCodebase cbInit "ucm-test" (Home tmp))
        case res of 
          CI.CreatedCodebase _ _ -> expect True
          _ -> expect False
    ] 
  , scope "*with* a --codebase flag" $ tests
    [ scope "a v2 codebase should be opened" do
        tmp <- io (Temp.getCanonicalTemporaryDirectory >>= flip Temp.createTempDirectory "ucm-test")
        cbInit <- io initMockWithCodebase
        res <- io (CI.openOrCreateCodebase cbInit "ucm-test" (Specified (DontCreateWhenMissing tmp)))
        case res of 
          CI.OpenedCodebase _ _ -> expect True
          _ -> expect False
    , scope "a v2 codebase should be *not* created when one does not exist at the Specified dir" do
        tmp <- io (Temp.getCanonicalTemporaryDirectory >>= flip Temp.createTempDirectory "ucm-test")
        cbInit <- io initMockWithoutCodebase
        res <- io (CI.openOrCreateCodebase cbInit "ucm-test" (Specified (DontCreateWhenMissing tmp)))
        case res of 
          CI.Error _ CI.NoCodebaseFoundAtSpecifiedDir -> expect True
          _ -> expect False
    ] 
  , scope "*with* a --codebase-create flag" $ tests
    [  scope "a v2 codebase should be created when one does not exist at the Specified dir" do
        tmp <- io (Temp.getCanonicalTemporaryDirectory >>= flip Temp.createTempDirectory "ucm-test")
        cbInit <- io initMockWithoutCodebase
        res <- io (CI.openOrCreateCodebase cbInit "ucm-test" (Specified (CreateWhenMissing tmp))) 
        case res of 
          CI.CreatedCodebase _ _ -> expect True
          _ -> expect False
      , 
      scope "a v2 codebase should be opened when one exists" do
        tmp <- io (Temp.getCanonicalTemporaryDirectory >>= flip Temp.createTempDirectory "ucm-test")
        cbInit <- io initMockWithCodebase
        res <- io (CI.openOrCreateCodebase cbInit "ucm-test" (Specified (CreateWhenMissing tmp)))
        case res of 
          CI.OpenedCodebase _ _ -> expect True
          _ -> expect False
    ] 
  ]

-- Test helpers

initMockWithCodebase ::  IO (Init IO v a)
initMockWithCodebase = do
  let codebase = error "did we /actually/ need a Codebase?"
  pure $ Init {
    -- DebugName -> CodebasePath -> m (Either Pretty (m (), Codebase m v a)),
    openCodebase = \_ _ -> pure ( Right (pure (), codebase)),
    -- DebugName -> CodebasePath -> m (Either CreateCodebaseError (m (), Codebase m v a)),
    createCodebase' = \_ _ -> pure (Right (pure (), codebase)),
    -- CodebasePath -> CodebasePath
    codebasePath = id
  }

initMockWithoutCodebase ::  IO (Init IO v a)
initMockWithoutCodebase = do
  let codebase = error "did we /actually/ need a Codebase?"
  pure $ Init {
    -- DebugName -> CodebasePath -> m (Either Pretty (m (), Codebase m v a)),
    openCodebase = \_ _ -> pure (Left "no codebase found"),
    -- DebugName -> CodebasePath -> m (Either CreateCodebaseError (m (), Codebase m v a)),
    createCodebase' = \_ _ -> pure (Right (pure (), codebase)),
    -- CodebasePath -> CodebasePath
    codebasePath = id
  }