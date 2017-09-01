{-| Prostate cancer prediction data -}
module Data.Prostate where

import Control.Applicative
import Data.Attoparsec.Text (Parser)
import Data.Either (partitionEithers)

import qualified Data.Attoparsec.Text as Parse
import qualified Data.Text.IO as Text

import Linear
import Statistics.Regression.Linear


data Train a = Train a | Test a
  deriving (Foldable, Functor, Show, Traversable)

data Prostate =
  Prostate
  { lcavol :: Double
  , lweight :: Double
  , age :: Double
  , lbph :: Double
  , svi :: Double
  , lcp :: Double
  , gleason :: Double
  , pgg45 :: Double
  , lpsa :: Double
  }
  deriving (Show)

inputs :: Prostate -> V Double
inputs (Prostate {..}) =
  fromList [lcavol, lweight, age, lbph, svi, lcp, gleason, pgg45]

output :: Prostate -> Double
output (Prostate {..}) = lpsa

parseHeader :: Parser ()
parseHeader = do
  mapM_ (\h -> Parse.skipSpace >> Parse.string h) headers
  Parse.skipSpace
  where
    headers =
      [ "lcavol"
      , "lweight"
      , "age"
      , "lbph"
      , "svi"
      , "lcp"
      , "gleason"
      , "pgg45"
      , "lpsa"
      , "train"
      ]

parseRow :: Parser (Train Prostate)
parseRow = do
  _ <- Parse.decimal :: Parser Integer
  [lcavol, lweight, age, lbph, svi, lcp, gleason, pgg45, lpsa]
    <- Parse.count 9 (Parse.skipSpace >> Parse.double)
  Parse.skipSpace
  train <- (pure Train <* Parse.char 'T') <|> (pure Test <* Parse.char 'F')
  Parse.endOfLine
  pure (train Prostate {..})

parse :: Parser [Train Prostate]
parse = parseHeader *> Parse.many1 parseRow

parseFile :: FilePath -> IO ([Prostate], [Prostate])
parseFile file = do
  r <- Parse.parseOnly parse <$> Text.readFile file
  case r of
    Left err -> error err
    Right dat -> pure (partition dat)
  where
    partition = partitionEithers . map trainEither
    trainEither (Train x) = Left x
    trainEither (Test x) = Right x

linearRegression :: [Prostate] -> LLS
linearRegression dat =
  let
    inp = (fromRows . map inputs) dat
    outp = (fromList . map output) dat
  in
    fit inp outp
