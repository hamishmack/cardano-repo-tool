{-# LANGUAGE OverloadedStrings #-}

import           Control.Monad (unless)

import           Data.Monoid ((<>))

import qualified Data.Text.IO as Text

import           Options.Applicative (Parser, ParserInfo, ParserPrefs)
import qualified Options.Applicative as Opt

import           RepoTool (RepoDirectory (..), gitCloneRepo, gitRepoStatuses, renderRepoHash,
                    updateAllRepoGitHashes, updateGitRepo, updateRepoGitHash)

import           System.Directory (doesDirectoryExist)
import           System.Environment (getProgName)
import           System.Exit (exitFailure)


main :: IO ()
main =
  Opt.customExecParser p opts >>= runRepoTool
  where
    opts :: ParserInfo Command
    opts = Opt.info (Opt.helper <*> pVersion <*> pCommand)
      ( Opt.fullDesc
      <> Opt.header "cardano-repo-tool - A tool for managing the Cardano repos."
      )

    p :: ParserPrefs
    p = Opt.prefs Opt.showHelpOnEmpty

-- -----------------------------------------------------------------------------

data Command
  = CmdCloneRepos
  | CmdPrintGitHashes
  | CmdListRepos
  | CmdRepoStatus
  | CmdUpdateGitHash RepoDirectory
  | CmdUpdateGitHashes
  | CmdUpdateGitRepos

-- -----------------------------------------------------------------------------

pVersion :: Parser (a -> a)
pVersion =
  Opt.infoOption "cabal-repo-tool version 0.1.0.0"
    (  Opt.long "version"
    <> Opt.short 'v'
    <> Opt.help "Print the version and exit"
    )

pCommand :: Parser Command
pCommand =
  Opt.subparser
    ( Opt.command "clone-repos"
       ( Opt.info (pure CmdCloneRepos)
       $ Opt.progDesc "Clone any missing repos into the current directory."
       )
    <> Opt.command "print-hashes"
       ( Opt.info (pure CmdPrintGitHashes)
       $ Opt.progDesc "Print the git hashes for the relevant repos."
       )
    <> Opt.command "list-repos"
       ( Opt.info (pure CmdListRepos)
       $ Opt.progDesc "List the repos expected by this tool."
       )
    <> Opt.command "repo-status"
       ( Opt.info (pure CmdRepoStatus)
       $ Opt.progDesc "List the statuses of each repo."
       )
    <> Opt.command "update-hash"
       ( Opt.info (CmdUpdateGitHash <$> pRepoDirectory)
       $ Opt.progDesc "Get the latest git hashes, and update the stack.yaml and cabal.project file for the specified repo."
       )
    <> Opt.command "update-hashes"
       ( Opt.info (pure CmdUpdateGitHashes)
       $ Opt.progDesc "Get the latest git hashes, and update all stack.yaml and cabal.project files."
       )
    <> Opt.command "update-repos"
       ( Opt.info (pure CmdUpdateGitRepos)
       $ Opt.progDesc "Run 'git checkout master && git pull --rebase' on all repos."
       )
    )

pRepoDirectory :: Parser RepoDirectory
pRepoDirectory =
  RepoDirectory <$>
    Opt.strOption
      (  Opt.long "repo"
      <> Opt.short 'r'
      <> Opt.help "A specific repo."
      )

-- -----------------------------------------------------------------------------

runRepoTool :: Command -> IO ()
runRepoTool cmd =
  case cmd of
    CmdCloneRepos -> cloneRepos
    CmdPrintGitHashes -> validateRepos >> mapM_ (\ r -> Text.putStrLn =<< renderRepoHash r) repos
    CmdListRepos -> listRepos
    CmdRepoStatus -> gitRepoStatuses repos
    CmdUpdateGitHash repo -> validateRepos >> updateRepoGitHash repos repo
    CmdUpdateGitHashes -> validateRepos >> updateAllRepoGitHashes repos
    CmdUpdateGitRepos -> validateRepos >> mapM_ updateGitRepo repos

cloneRepos :: IO ()
cloneRepos =
  mapM_ cloneIfNeeded repos
 where
  cloneIfNeeded rd@(RepoDirectory fpath) = do
    e <- doesDirectoryExist fpath
    unless e $
      gitCloneRepo rd

listRepos :: IO ()
listRepos = do
  putStrLn "Expect the following repos:\n"
  mapM_ (\ r -> putStrLn $ "  " ++ unRepoDirectory r) repos
  putStrLn ""

validateRepos :: IO ()
validateRepos = do
  mapM_ exists repos
 where
  exists (RepoDirectory fpath) = do
    e <- doesDirectoryExist fpath
    unless e $ do
      progName <- getProgName
      mapM_ putStrLn $
        [ "Error:"
        , "  Git repository " ++ fpath ++ " does not exit in the current directory."
        , "  It should be possible to clone it using the command:"
        , "    git clone https://github.com/input-output-hk/"
        , "  Alternatively, you could just run:"
        , "    " ++ progName ++ " clone"
        , "  which would clone repos as needed."
        , ""
        ]
      exitFailure

-- -----------------------------------------------------------------------------

repos :: [RepoDirectory]
repos =
  map RepoDirectory
    [ "cardano-base"
    , "cardano-crypto"
    , "cardano-ledger"
    , "cardano-ledger-specs"
    , "cardano-node"
    , "cardano-prelude"
    , "cardano-shell"
    , "cardano-sl-x509"
    , "iohk-monitoring-framework"
    , "ouroboros-network"
    ]

