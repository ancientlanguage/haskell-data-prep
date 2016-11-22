module Hebrew where

import Data.Map (Map)
import qualified Data.Map as Map
import Prepare
import Prepare.Tanach.IndexParser (index)
import Prepare.Tanach.HeaderParser (header)
import Prepare.Tanach.TanachParser (tanach)

loadIndex :: IO ()
loadIndex = do
  let indexFilePath = "./data/xml-tanach/books/TanachIndex.xml"
  result <- loadParse indexFilePath index emptyLog
  case result of
    Left e -> putStrLn $ "Error loading index:\n" ++ e
    Right _ -> putStrLn "Success!"

loadHeader :: IO ()
loadHeader = do
  let headerFilePath = "./data/xml-tanach/books/TanachHeader.xml"
  result <- loadParse headerFilePath header emptyLog
  case result of
    Left e -> putStrLn $ "Error loading header:\n" ++ e
    Right _ -> putStrLn "Success!"

loadSingle :: IO ()
loadSingle = do
  let singleFilePath = "./data/xml-tanach/books/Amos.xml"
  result <- loadParse singleFilePath tanach emptyLog
  case result of
    Left e -> putStrLn $ "Error loading tanach:\n" ++ e
    Right _ -> putStrLn "Success!"

commands :: Map String (IO ())
commands = Map.fromList
  [ ("load-index", loadIndex)
  , ("load-header", loadHeader)
  , ("load-single", loadSingle)
  ]
