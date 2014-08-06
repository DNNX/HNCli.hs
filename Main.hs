{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Aeson
import Control.Applicative ((<$>), (<*>))
import Control.Monad (mzero, liftM4)
import Network.HTTP.Conduit
import qualified Data.ByteString.Lazy as L
import Text.Printf (printf)
import Data.List (isInfixOf)
import Data.Char (toLower)
import Control.Exception (catch)
import System.IO (stderr, hPutStrLn)
import Prelude hiding (mapM_)
import Data.Foldable (mapM_)

data Item = Item { title        :: String
                 , url          :: String
                 , id           :: Float
                 , commentCount :: Int
                 , points       :: Int
                 , postedAgo    :: Maybe String
                 , postedBy     :: Maybe String
                 } deriving (Show)

data Feed = Feed { nextId      :: Maybe String
                 , items       :: [Item]
                 , version     :: String
                 , cachedOnUTC :: String
                 } deriving (Show)

instance FromJSON Item where
    parseJSON (Object v) = Item
                           <$> v .: "title"
                           <*> v .: "url"
                           <*> v .: "id"
                           <*> v .: "commentCount"
                           <*> v .: "points"
                           <*> v .: "postedAgo"
                           <*> v .: "postedBy"

    parseJSON _          = mzero

instance FromJSON Feed where
    parseJSON (Object v) = Feed
                           <$> v .: "nextId"
                           <*> v .: "items"
                           <*> v .: "version"
                           <*> v .: "cachedOnUTC"

    parseJSON _          = mzero

statusExceptionHandler ::  HttpException -> IO L.ByteString
statusExceptionHandler (StatusCodeException status _ _) =
    hPutStrLn stderr "An error occured during download: "
    >> print status
    >> return L.empty
statusExceptionHandler exception =
    hPutStrLn stderr "An error occured during download: "
    >> print exception
    >> return L.empty

jsonData :: IO L.ByteString
jsonData = simpleHttp "http://api.ihackernews.com/page" `catch` statusExceptionHandler

formattedLine :: Item -> String
formattedLine = liftM4 (printf "\n%-3d (%-3d) %s\n          %s\n") points commentCount title url

lowercasedTitle :: Item -> String
lowercasedTitle = map toLower . title

interestingKeywords :: [String]
interestingKeywords  = [ "haskell"
                       , "clojure"
                       , "arduino"
                       , "raspberry"
                       ]

isInteresting :: Item -> Bool
isInteresting item  = any (`isInfixOf` lowercasedTitle item) interestingKeywords

formatFeed :: Feed -> String
formatFeed = concatMap formattedLine . filter isInteresting . items

main :: IO ()
main = jsonData >>= mapM_ (putStr . formatFeed) . decode
