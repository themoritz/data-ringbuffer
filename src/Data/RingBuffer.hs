module Data.RingBuffer
    ( -- * Types
      Barrier
    , Consumer
    , Transformer
    , Sequence
    , Sequencer

    -- * Value Constructors
    , newSequencer
    , newConsumer
    , newTransformer
    , newBarrier

    -- * Concurrent Access, aka Disruptor API
    , claim
    , nextSeq
    , nextBatch
    , waitFor
    , publish

    -- * Util
    , consumerSeq
    , transformerSeq
    )
where

import           Control.Applicative        ((*>))
import           Control.Concurrent         (yield)
import           Data.RingBuffer.Internal
import           Data.RingBuffer.Types


--
-- Value Constructors
--

type ConsOrTrans a b = Either (Consumer a) (Transformer a b)

newSequencer :: [ConsOrTrans a b] -> IO Sequencer
newSequencer conss = do
    curs <- mkSeq
    return $! Sequencer curs (map gate conss)

gate :: ConsOrTrans a b -> Sequence
gate (Left (Consumer _ sq)) = sq
gate (Right (Transformer _ sq)) = sq

newBarrier :: Sequencer -> [ConsOrTrans a b] -> Barrier
newBarrier (Sequencer curs _) conss = Barrier curs $ map gate conss

newConsumer :: (a -> IO ()) -> IO (Consumer a)
newConsumer fn = do
    sq <- mkSeq
    return $! Consumer fn sq

newTransformer :: (a -> IO b) -> IO (Transformer a b)
newTransformer fn = do
    sq <- mkSeq
    return $! Transformer fn sq

--
-- Disruptor API
--

-- | Claim the given position in the sequence for publishing
claim :: Sequencer
      -> Int
      -- ^ position to claim
      -> Int
      -- ^ buffer size
      -> IO Int
claim (Sequencer _ gates) sq bufsize = await gates sq bufsize

-- | Claim the next available position in the sequence for publishing
nextSeq :: Sequencer
        -> Sequence
        -- ^ sequence to increment for next position
        -> Int
        -- ^ buffer size
        -> IO Int
nextSeq sqr sq bufsize = nextBatch sqr sq 1 bufsize

-- | Claim a batch of positions in the sequence for publishing
nextBatch :: Sequencer
          -> Sequence
          -- ^ sequence to increment by requested batch
          -> Int
          -- ^ batch size
          -> Int
          -- ^ buffer size
          -> IO Int
          -- ^ the largest position claimed
nextBatch sqr sq n bufsize = do
    next <- addAndGet sq n
    claim sqr next bufsize

-- | Wait for the given sequence value to be available for consumption
waitFor :: Barrier -> Int -> IO Int
waitFor b@(Barrier sq deps) i = do
    avail <- if null deps then readSeq sq else minSeq deps

    --print $ "avail " ++ show avail

    if avail >= i
        then return avail
        else yield *> waitFor b i

-- | Make the given sequence visible to consumers
publish :: Sequencer -> Int -> Int -> IO ()
publish s@(Sequencer sq _) i batchsize = do
    let expected = i - batchsize
    curr <- readSeq sq

    --print $ "expected " ++ show expected ++ ", curr " ++ show curr

    if expected == curr
        then writeSeq sq i
        else publish s i batchsize


--
-- Util
--

consumerSeq :: Consumer a -> IO Int
consumerSeq (Consumer _ sq) = readSeq sq
{-# INLINE consumerSeq #-}

transformerSeq :: Transformer a b -> IO Int
transformerSeq (Transformer _ sq) = readSeq sq
{-# INLINE transformerSeq #-}

-- vim: set ts=4 sw=4 et:
