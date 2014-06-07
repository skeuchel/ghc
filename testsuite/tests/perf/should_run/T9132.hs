
module Main where

{-# INLINE sumTakeWhile #-}
sumTakeWhile :: (Int -> Bool) -> [Int] -> Int
sumTakeWhile p = sum . takeWhile p

main :: IO ()
main = sumTakeWhile (<10000) [0..1000000] `seq` return ()
