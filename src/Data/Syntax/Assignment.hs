{-# LANGUAGE DataKinds, GADTs, TypeFamilies #-}
module Data.Syntax.Assignment
( Assignment
, symbol
, source
, children
, Rose(..)
, RoseF(..)
, Result(..)
, assignAll
, runAssignment
) where

import Control.Monad.Free.Freer
import Data.Functor.Classes
import Data.Functor.Foldable
import Data.Record
import Data.Text (unpack)
import Range
import Prologue hiding (Alt)
import Source (Source())
import SourceSpan
import Text.Parser.TreeSitter.Language
import Text.Show hiding (show)

-- | Assignment from an AST with some set of 'symbol's onto some other value.
--
--   This is essentially a parser.
type Assignment symbol = Freer (AssignmentF symbol)

data AssignmentF symbol a where
  Symbol :: symbol -> AssignmentF symbol ()
  Source :: AssignmentF symbol ByteString
  Children :: Assignment symbol a -> AssignmentF symbol a
  Alt :: a -> a -> AssignmentF symbol a
  Empty :: AssignmentF symbol a

-- | Zero-width match of a node with the given symbol.
--
--   Since this is zero-width, care must be taken not to repeat it without chaining on other rules. I.e. 'many (rule A *> b)' is fine, but 'many (rule A)' is not.
symbol :: symbol -> Assignment symbol ()
symbol s = Symbol s `Then` return

-- | A rule to produce a node’s source as a ByteString.
source :: Assignment symbol ByteString
source = Source `Then` return

-- | Match a node by applying an assignment to its children.
children :: Assignment symbol a -> Assignment symbol a
children forEach = Children forEach `Then` return


-- | A rose tree.
data Rose a = Rose { roseValue :: !a, roseChildren :: ![Rose a] }
  deriving (Eq, Functor, Show)


-- | The result of assignment, possibly containing an error.
data Result a = Result a | Error [Text]
  deriving (Eq, Foldable, Functor, Traversable)


-- | Run an assignment of nodes in a grammar onto terms in a syntax, discarding any unparsed nodes.
assignAll :: (Symbol grammar, Eq grammar, Show grammar) => Assignment grammar a -> Source -> [Rose (Record '[grammar, Range, SourceSpan])] -> Result a
assignAll assignment source nodes = case runAssignment assignment source nodes of
  Result (rest, a) -> case dropAnonymous rest of
    [] -> Result a
    c:_ -> Error ["Expected end of input, but got: " <> show c]
  Error e -> Error e

-- | Run an assignment of nodes in a grammar onto terms in a syntax.
runAssignment :: (Symbol grammar, Eq grammar, Show grammar) => Assignment grammar a -> Source -> [Rose (Record '[grammar, Range, SourceSpan])] -> Result ([Rose (Record '[grammar, Range, SourceSpan])], a)
runAssignment = iterFreer (\ assignment yield source nodes -> case (assignment, dropAnonymous nodes) of
  -- Nullability: some rules, e.g. 'pure a' and 'many a', should match at the end of input. Either side of an alternation may be nullable, ergo Alt can match at the end of input.
  (Alt a b, nodes) -> yield a source nodes <|> yield b source nodes -- FIXME: Symbol `Alt` Symbol `Alt` Symbol is inefficient, should build and match against an IntMap instead.
  (assignment, node@(Rose (nodeSymbol :. _) children) : rest) -> case assignment of
    Symbol symbol -> guard (symbol == nodeSymbol) >> yield () source nodes
    Source -> yield "" source rest
    Children childAssignment -> do
      c <- assignAll childAssignment source children
      yield c source rest
    _ -> Error ["No rule to match " <> show node]
  (Symbol symbol, []) -> Error [ "Expected " <> show symbol <> " but got end of input." ]
  (Source, []) -> Error [ "Expected leaf node but got end of input." ]
  (Children _, []) -> Error [ "Expected branch node but got end of input." ]
  _ -> Error ["No rule to match at end of input."])
  . fmap (\ a _ rest -> Result (rest, a))

dropAnonymous :: Symbol grammar => [Rose (Record '[grammar, Range, SourceSpan])] -> [Rose (Record '[grammar, Range, SourceSpan])]
dropAnonymous = dropWhile ((/= Regular) . symbolType . rhead . roseValue)


instance Alternative (Assignment symbol) where
  empty = Empty `Then` return
  (<|>) = (wrap .) . Alt

instance Show symbol => Show1 (AssignmentF symbol) where
  liftShowsPrec sp sl d a = case a of
    Symbol s -> showsUnaryWith showsPrec "Symbol" d s . showChar ' ' . sp d ()
    Source -> showString "Source" . showChar ' ' . sp d ""
    Children a -> showsUnaryWith (liftShowsPrec sp sl) "Children" d a
    Alt a b -> showsBinaryWith sp sp "Alt" d a b
    Empty -> showString "Empty"

type instance Base (Rose a) = RoseF a

data RoseF a f = RoseF a [f]
  deriving (Eq, Foldable, Functor, Show, Traversable)

instance Recursive (Rose a) where project (Rose a as) = RoseF a as
instance Corecursive (Rose a) where embed (RoseF a as) = Rose a as

instance Show1 Result where
  liftShowsPrec _ _ d (Error es) = showsUnaryWith (const (foldr ((.) . (showString . unpack)) identity)) "Error" d es
  liftShowsPrec sp _ d (Result a) = showsUnaryWith sp "Result" d a

instance Show a => Show (Result a) where
  showsPrec = showsPrec1

instance Applicative Result where
  pure = Result
  Error a <*> Error b = Error (a <> b)
  Error a <*> _ = Error a
  _ <*> Error b = Error b
  Result f <*> Result a = Result (f a)

instance Alternative Result where
  empty = Error []
  Result a <|> _ = Result a
  _ <|> Result b = Result b
  Error a <|> Error b = Error (a <> b)

instance Monad Result where
  return = pure
  Error a >>= _ = Error a
  Result a >>= f = f a
