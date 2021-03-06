module Algebra.CAS.Solve where

import Algebra.CAS.Base
import qualified Data.Map as M
import Control.Applicative
import Data.List

-- | compare a pair of formula and output matched variables
-- >>> let [a,b,c] = map CV ["a","b","c"]
-- >>> let [x,y,z] = map V ["x","y","z"]
-- >>> match (a*x+b) (2*x+3)
-- Just [(b,3),(a,2)]
-- >>> match (a*x^2+b) (2*x^2+3)
-- Just [(b,3),(a,2)]
-- >>> match (a*x^2+b*x+c) (2*x^2+4*x+3)
-- Just [(c,3),(b,4),(a,2)]
-- >>> match (a*x^2+b*x+c) (4*x+3)
-- Nothing
match :: Formula -- ^ pattern
      -> Formula -- ^ matched formula
      -> Maybe [(Formula,Formula)] -- ^ matched variable pairs
match a b = match' a b []
  where
    match' :: Formula
           -> Formula
           -> [(Formula,Formula)]
           -> Maybe [(Formula,Formula)]
    match' (a0:^:b0) (a1:^:b1) lst = do
      v1 <- match' a0 a1 lst
      case (b0,b1) of
        (c0@(C _),c1@(C _)) ->
          if c0 == c1
          then return lst
          else Nothing
        _ -> match' b0 b1 v1
    match' (a0:*:b0) (a1:*:b1) lst = do
      v <- match' b0 b1 lst
      match' a0 a1 v
    match' (a0:+:b0) (a1:+:b1) lst = do
      v <- match' b0 b1 lst
      match' a0 a1 v
    match' (a0:/:b0) (a1:/:b1) lst = do
      v <- match' b0 b1 lst
      match' a0 a1 v
    match' (_:^:_) _ _ = Nothing
    match' (a0:+:b0) a1 lst = do
      v <- match' b0 a1 lst
      match' a0 0 v
    match' (a0:*:b0) a1 lst = do
      v <- match' b0 a1 lst
      match' a0 1 v
    match' (_:/:_) _ _ = Nothing
    match' (V x) (V y) lst | x == y = Just $ lst
                           | otherwise = Nothing
    match' a0@(CV _) a1 lst = Just $ (a0,a1):lst
    match' _ _ _ = Nothing
  
solve1 :: Formula -> Formula -> Maybe [Formula]
solve1 f v = do
  let [a,b] = map CV ["a","b"]
  list <- match (a*v+b) f
  let m = M.fromList list
  return [- (m M.! b /  m M.! a)]

solve2 :: Formula -> Formula -> Maybe [Formula]
solve2 f v = abc <|> ac
  where
    ac = do 
      let [a,b,c] = map CV ["a","b","c"]
      list <- (match (a*v**2+c) f)
      let m = M.fromList ((b,0):list)
      let [a',b',c'] = map (m M.!) [a,b,c]
      anser a' b' c'
    abc = do 
      let [a,b,c] = map CV ["a","b","c"]
      list <- (match (a*v**2+b*v+c) f)
      let m = M.fromList list
      let [a',b',c'] = map (m M.!) [a,b,c]
      anser a' b' c'
    anser a' b' c' = do
      let a2= 2*a'
      let sq=sqrt $ expand (b'**2-4*a'*c')
      return $ [(sq-b')/a2,(-sq-b')/a2]

solve :: Formula -- ^ formula
      -> Formula -- ^ variable
      -> Maybe [Formula] -- ^ answer
solve f v = solve2 f v <|> solve1 f v

-- | solve linear equations
-- >>> let [a0,a1,a2,a3,a4,a5,a6,a7,a8,a9] = reverse $ genVars "a" 10
-- >>> let equations = [a6,2*a9,-1 + a8 + (-1)*a1,(-1)*a7,(-1)*a4,a3 + a7,a8,(-2)*a2 + 2*a5,a4]
-- >>> equations
-- [a6,2*a9,-1 + (-1)*a1 + a8,(-1)*a7,(-1)*a4,a3 + a7,a8,(-2)*a2 + 2*a5,a4]
-- >>> linsolve [head equations]
-- Just [(a6,0)]
-- >>> linsolve $ equations ++ [a0,a2]
-- Just [(a0,0),(a1,-1),(a2,0),(a3,0),(a4,0),(a5,0),(a6,0),(a7,0),(a8,0),(a9,0)]
linsolve :: [Formula] -- ^ formulas
         -> Maybe [(Formula,Formula)] -- ^ answer (varible,value)
linsolve fs = if length a == length variables' then Just (sort a) else Nothing
  where
    r = reverse $ lReductions $ reverse $ sort fs
    a = rSolve r
    variables' = nub $ foldr (++) [] $ map variables fs

-- | try to reduce a variable.
-- >>> let [a,b,c] = map CV ["a","b","c"]
-- >>> let [x,y,z] = map V ["x","y","z"]
-- >>> let [f0,f1] = [(2*x+4*y+4),(x-2*y+1)]
-- >>> lReduction f0 f1
-- 3 + 2*x
-- >>> headV (2*a*x+4*b*y+4*c)
-- (4*b,y)
-- >>> headV (a*x-2*b*y+c)
-- ((-2)*b,y)
-- >>> (a*x-2*b*y+c) - ((-2*b)/(4*b))*(2*a*x+4*b*y+4*c)
-- c + a*x + (-2)*b*y + (-1)*(((-2)*b)/(4*b))*(4*c + 2*a*x + 4*b*y)
lReduction :: Formula
           -> Formula
           -> Formula
lReduction f0 f1 =
  if t0 == t1
  then expand $ f1 - (c1/c0)*f0
  else f1
  where
    (c0,t0) = headV f0
    (c1,t1) = headV f1


lReductions :: [Formula]
            -> [Formula]
lReductions [] = []
lReductions (f:fs) = f: (reverse $ sort $ lReductions (flist f fs))
  where
    flist :: Formula -> [Formula] -> [Formula]
    flist f' fs' =  map (lReduction f') fs'

rSolve :: [Formula] -> [(Formula,Formula)]
rSolve [] = []
rSolve (f:fs) =
  case variables f of
    [] -> rSolve fs
    v':_ ->
      case solve1 f v' of
        Just [a'] -> (v',a'): rSolve (map (subst [(v',a')]) fs)
        Just _ -> error "error"
        Nothing -> []
