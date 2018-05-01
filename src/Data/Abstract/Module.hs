module Data.Abstract.Module
( Module(..)
, ModuleInfo(..)
, ModulePath
, moduleForBlob
) where

import Data.Blob
import Prologue
import System.FilePath.Posix

type ModulePath = FilePath

newtype ModuleInfo = ModuleInfo { modulePath :: FilePath }
  deriving (Eq, Ord, Show)

data Module term = Module { moduleInfo :: ModuleInfo, moduleBody :: term }
  deriving (Eq, Foldable, Functor, Ord, Traversable)

instance Show (Module term) where
  showsPrec _ Module{..} = shows moduleInfo


-- | Construct a 'Module' for a 'Blob' and @term@, relative to some root 'FilePath'.
moduleForBlob :: Maybe FilePath -- ^ The root directory relative to which the module will be resolved, if any.
              -> Blob           -- ^ The 'Blob' containing the module.
              -> term           -- ^ The @term@ representing the body of the module.
              -> Module term    -- ^ A 'Module' named appropriate for the 'Blob', holding the @term@, and constructed relative to the root 'FilePath', if any.
moduleForBlob rootDir Blob{..} = Module info
  where root = fromMaybe (takeDirectory blobPath) rootDir
        info = ModuleInfo (makeRelative root blobPath)
