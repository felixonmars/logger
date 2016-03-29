{-# LANGUAGE OverloadedStrings, BangPatterns, CPP #-}

module FastLoggerSpec where

#if __GLASGOW_HASKELL__ < 709
import Control.Applicative ((<$>))
#endif
import Control.Exception (finally)
import Control.Monad (when)
import qualified Data.ByteString.Char8 as BS
import Data.Monoid ((<>))
import System.Directory (doesFileExist, removeFile)
import System.Log.FastLogger
import Test.Hspec

spec :: Spec
spec = describe "pushLogMsg" $ do
    it "is safe for a large message" $ safeForLarge [
        100
      , 1000
      , 10000
      , 100000
      , 1000000
      ]
    it "logs all messages" logAllMsgs

nullLogger :: IO LoggerSet
nullLogger = newFileLoggerSet 4096 "/dev/null"

safeForLarge :: [Int] -> IO ()
safeForLarge ns = mapM_ safeForLarge' ns

safeForLarge' :: Int -> IO ()
safeForLarge' n = flip finally (cleanup tmpfile) $ do
    cleanup tmpfile
    lgrset <- newFileLoggerSet defaultBufSize tmpfile
    let xs = toLogStr $ BS.pack $ take (abs n) (cycle ['a'..'z'])
        lf = "x"
    pushLogStr lgrset $ xs <> lf
    flushLogStr lgrset
    rmLoggerSet lgrset
    bs <- BS.readFile tmpfile
    bs `shouldBe` BS.pack (take (abs n) (cycle ['a'..'z']) <> "x")
    where
        tmpfile = "test/temp"

cleanup :: FilePath -> IO ()
cleanup file = do
    exist <- doesFileExist file
    when exist $ removeFile file

logAllMsgs :: IO ()
logAllMsgs = logAll "LICENSE" `finally` cleanup tmpfile
  where
    tmpfile = "test/temp"
    logAll file = do
        cleanup tmpfile
        lgrset <- newFileLoggerSet 512 tmpfile
        src <- BS.readFile file
        let bs = (<> "\n") . toLogStr <$> BS.lines src
        mapM_ (pushLogStr lgrset) bs
        flushLogStr lgrset
        rmLoggerSet lgrset
        dst <- BS.readFile tmpfile
        dst `shouldBe` src
