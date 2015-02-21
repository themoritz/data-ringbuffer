module Data.RingBuffer.Types
    ( -- * Types
      Barrier(..)
    , Consumer(..)
    , Sequence(..)
    , Sequencer(..)
    , Transformer(..)
    )
where

import           Data.IORef


newtype Sequence = Sequence (IORef Int)


data Sequencer = Sequencer !Sequence
                           -- ^ cursor
                           ![Sequence]
                           -- ^ gating (aka consumer) sequences

data Barrier = Barrier !Sequence
                       -- ^ cursor (must point to the same sequence as the
                       -- corresponding 'Sequencer')
                       ![Sequence]
                       -- ^ dependent sequences (optional)

data Consumer a = Consumer (a -> IO ())
                           -- ^ consuming function
                           !Sequence
                           -- ^ consumer sequence

data Transformer a b = Transformer (a -> IO b) !Sequence

-- vim: set ts=4 sw=4 et:
