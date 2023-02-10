-- | The main module of the CLI interface app.
module Docs.Search.Main where

import Docs.Search.Config as Config
import Docs.Search.IndexBuilder as IndexBuilder
import Docs.Search.Interactive as Interactive
import Docs.Search.Types (PackageName(..))

import Prelude

import Data.Generic.Rep (class Generic)
import Data.List as List
import Data.List.NonEmpty as NonEmpty
import Data.Maybe (Maybe, fromMaybe, optional)
import Data.Newtype (unwrap)
import Data.Show.Generic (genericShow)
import Data.Unfoldable (class Unfoldable)
import Effect (Effect)
import Effect.Console (log)
import Options.Applicative (Parser, command, execParser, flag, fullDesc, help, helper, info, long, metavar, progDesc, strOption, subparser, value, (<**>))
import Options.Applicative as CA


main :: Effect Unit
main = do

  args <- getArgs
  let defaultCommands = Search { docsFiles: defaultDocsFiles
                               , bowerFiles: defaultBowerFiles
                               , packageName: Config.defaultPackageName
                               , sourceFiles: defaultSourceFiles
                               }

  case fromMaybe defaultCommands args of
    BuildIndex cfg -> IndexBuilder.run cfg
    Search cfg -> Interactive.run cfg
    Version -> log Config.version

getArgs :: Effect (Maybe Commands)
getArgs = execParser opts
  where
    opts =
      info (commands <**> helper)
      ( fullDesc
     <> progDesc "Search frontend for the documentation generated by the PureScript compiler."
      )

data Commands
  = BuildIndex IndexBuilder.Config
  | Search Interactive.Config
  | Version

derive instance genericCommands :: Generic Commands _

instance showCommands :: Show Commands where
  show = genericShow

commands :: Parser (Maybe Commands)
commands = optional $ subparser
  ( command "build-index"
    ( info (buildIndex <**> helper)
      ( progDesc "Build the index used to search for definitions and patch the generated docs so that they include a search field."
      )
    )
 <> command "search"
    ( info (startInteractive <**> helper)
      ( progDesc "Run the search engine."
      )
    )
 <> command "version"
    ( info (pure Version <**> helper)
      ( progDesc "Show purescript-docs-search version."
      )
    )
  )


buildIndex :: Parser Commands
buildIndex = ado
  docsFiles <- docsFilesOption
  bowerFiles <- bowerFilesOption
  packageName <- packageNameOption
  sourceFiles <- sourceFilesOption
  generatedDocs <- strOption
    ( long "generated-docs"
   <> metavar "DIR"
   <> value "./generated-docs/"
   <> help "Path to the generated documentation HTML that will be patched. Search app will be injected into each HTML document."
    )
  noPatch <- flag false true
    ( long "no-patch"
   <> help "Do not patch the HTML docs, only build indices"
    )
  in BuildIndex { docsFiles, bowerFiles, generatedDocs, noPatch, packageName, sourceFiles }


startInteractive :: Parser Commands
startInteractive = ado
  docsFiles <- docsFilesOption
  bowerFiles <- bowerFilesOption
  packageName <- packageNameOption
  sourceFiles <- sourceFilesOption
  in Search { docsFiles, bowerFiles, packageName, sourceFiles }

docsFilesOption :: Parser (Array String)
docsFilesOption = fromMaybe defaultDocsFiles <$>
   optional
   ( some
     ( strOption
       ( long "docs-files"
      <> metavar "GLOB"
      <> help "Glob that captures `docs.json` files that should be used to build the index"
       )
     )
   )

bowerFilesOption :: Parser (Array String)
bowerFilesOption = fromMaybe defaultBowerFiles <$>
   optional
   ( some
     ( strOption
       ( long "bower-jsons"
      <> metavar "GLOB"
      <> help "Glob that captures `bower.json` files. These files are used to build dependency trees to compute package popularity scores based on how many dependants a package has."
       )
     )
   )

packageNameOption :: Parser PackageName
packageNameOption =
  PackageName <$> strOption
  ( long "package-name"
 <> metavar "PACKAGE"
 <> value (unwrap Config.defaultPackageName)
 <> help "Local package name as it should appear in the search results"
  )

sourceFilesOption :: Parser (Array String)
sourceFilesOption = fromMaybe defaultSourceFiles <$>
   optional
   ( some
     ( strOption
       ( long "source-files"
      <> metavar "GLOB"
      <> help "Path to project source files, used for more precise module indexing (see #62). Default: src/**/*.purs"
       )
     )
   )

defaultDocsFiles :: Array String
defaultDocsFiles = [ "output/**/docs.json" ]

defaultBowerFiles :: Array String
defaultBowerFiles = [ ".spago/*/*/bower.json", "bower_components/purescript-*/bower.json" ]

defaultSourceFiles :: Array String
defaultSourceFiles = [ "src/**/*.purs" ]

many :: forall a f. Unfoldable f => Parser a -> Parser (f a)
many x = CA.many x <#> List.toUnfoldable

some :: forall a f. Unfoldable f => Parser a -> Parser (f a)
some x = CA.some x <#> NonEmpty.toUnfoldable
