module Main where

import EasyTest
import System.Random (Random)
import qualified Unison.Util.Relation as Relation
import Unison.Util.Relation3 (Relation3)
import qualified Unison.Util.Relation3 as Relation3
import Unison.Util.Relation4 (Relation4)
import qualified Unison.Util.Relation4 as Relation4

main :: IO ()
main =
  run do
    scope "Relation3" do
      scope "d12 works" do
        r3 <- randomR3 @Char @Char @Char 1000
        let d12 = Relation.fromList . map (\(a, b, _) -> (a, b)) . Relation3.toList
        expectEqual (Relation3.d12 r3) (d12 r3)

      scope "d13 works" do
        r3 <- randomR3 @Char @Char @Char 1000
        let d13 = Relation.fromList . map (\(a, _, c) -> (a, c)) . Relation3.toList
        expectEqual (Relation3.d13 r3) (d13 r3)

    scope "Relation4" do
      scope "d124 works" do
        r4 <- randomR4 @Char @Char @Char @Char 1000
        let d124 = Relation3.fromList . map (\(a, b, _, d) -> (a, b, d)) . Relation4.toList
        expectEqual (Relation4.d124 r4) (d124 r4)

randomR3 :: (Ord a, Random a, Ord b, Random b, Ord c, Random c) => Int -> Test (Relation3 a b c)
randomR3 n =
  Relation3.fromList <$> listOf n tuple3

randomR4 :: (Ord a, Random a, Ord b, Random b, Ord c, Random c, Ord d, Random d) => Int -> Test (Relation4 a b c d)
randomR4 n =
  Relation4.fromList <$> listOf n tuple4
