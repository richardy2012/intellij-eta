module IntelliJ.Plugin.Eta.Lang.Lexer.EtaLexer
 ( EtaLexer(..)
 , newEtaParsingLexer
 ) where

import P
import Data.IORef
import Foreign.StablePtr
import System.Environment
import qualified System.IO.Unsafe as Unsafe

import FFI.Com.IntelliJ.Lexer.Lexer (Lexer, getTokenText)
import FFI.Com.IntelliJ.OpenApi.Util.Text.StringUtil (lineColToOffset)
import FFI.Com.IntelliJ.Psi.Tree (IElementType)
import qualified FFI.Com.IntelliJ.Psi.TokenType as T
import FFI.Com.TypeLead.IntelliJ.Plugin.Eta.Lang.Psi.EtaTokenTypes (tokenToIElementType)

import qualified Language.Eta.Parser.Lexer as L
import Language.Eta.BasicTypes.SrcLoc
import Language.Eta.Main.DynFlags
import Language.Eta.Utils.FastString (mkFastString)
import Language.Eta.Utils.StringBuffer

import IntelliJ.Plugin.Eta.Lang.Utils

data AbstractEtaLexer = AbstractEtaLexer
  @com.typelead.intellij.plugin.eta.lang.lexer.AbstractEtaLexer
  deriving Class

type instance Inherits AbstractEtaLexer = '[Object, Lexer]

data EtaLexer = EtaLexer
  @com.typelead.intellij.plugin.eta.lang.lexer.EtaLexer
  deriving Class

type instance Inherits EtaLexer = '[AbstractEtaLexer]

newEtaParsingLexer :: Java a EtaLexer
newEtaParsingLexer = unsafeNewEtaLexer

-- We'll use EtaSyntaxHighlightingLexer instead.
-- newEtaSyntaxHighlightingLexer :: Java a EtaLexer
-- newEtaSyntaxHighlightingLexer = do
--   lexer <- unsafeNewEtaLexer
--   lexer <.> setSkipVirtual True
--   return lexer

foreign import java unsafe "@new" unsafeNewEtaLexer :: Java a EtaLexer

foreign import java unsafe "@field myPStatePtr" getMyPStatePtr :: Java EtaLexer (StablePtr (IORef L.PState))
foreign import java unsafe "@field myPStatePtr" setMyPStatePtr :: StablePtr (IORef L.PState) -> Java EtaLexer ()

foreign import java unsafe "@field done" getDone :: Java EtaLexer Bool
foreign import java unsafe "@field done" setDone :: Bool -> Java EtaLexer ()

foreign import java unsafe "@field myState" getMyState :: Java EtaLexer Int
foreign import java unsafe "@field myState" setMyState :: Int -> Java EtaLexer ()

foreign import java unsafe "@field myTokenStart" getMyTokenStart :: Java EtaLexer Int
foreign import java unsafe "@field myTokenStart" setMyTokenStart :: Int -> Java EtaLexer ()

foreign import java unsafe "@field myTokenEnd" getMyTokenEnd :: Java EtaLexer Int
foreign import java unsafe "@field myTokenEnd" setMyTokenEnd :: Int -> Java EtaLexer ()

foreign import java unsafe "@field myBuffer" getMyBuffer :: Java EtaLexer CharSequence
foreign import java unsafe "@field myBuffer" setMyBuffer :: CharSequence -> Java EtaLexer ()

foreign import java unsafe "@field myBufferEnd" getMyBufferEnd :: Java EtaLexer Int
foreign import java unsafe "@field myBufferEnd" setMyBufferEnd :: Int -> Java EtaLexer ()

foreign import java unsafe "@field myTokenType" getMyTokenType :: Java EtaLexer IElementType
foreign import java unsafe "@field myTokenType" setMyTokenType :: IElementType -> Java EtaLexer ()

foreign import java unsafe "@field myNextTokenType" getMyNextTokenType :: Java EtaLexer IElementType
foreign import java unsafe "@field myNextTokenType" setMyNextTokenType :: IElementType -> Java EtaLexer ()

foreign import java unsafe "@field myNextTokenStart" getMyNextTokenStart :: Java EtaLexer Int
foreign import java unsafe "@field myNextTokenStart" setMyNextTokenStart :: Int -> Java EtaLexer ()

foreign import java unsafe "@field myNextTokenEnd" getMyNextTokenEnd :: Java EtaLexer Int
foreign import java unsafe "@field myNextTokenEnd" setMyNextTokenEnd :: Int -> Java EtaLexer ()

foreign export java start :: CharSequence -> Int -> Int -> Int -> Java EtaLexer ()
start buf startOffset endOffset initialState = do
  -- debugTokenStream pState
  setMyPStatePtr =<< mkPtr
  -- For now, let's not use `initialState` so intellij has to start from the beginning.
  -- If intellij sees a state zero then it will assume it can always start the lexer over
  -- from that position.
  setMyState 1
  setDone False
  setMyTokenStart startOffset
  setMyTokenEnd startOffset
  setMyBuffer buf
  setMyBufferEnd endOffset
  setMyTokenType unsafeJNull
  setMyNextTokenType unsafeJNull
  setMyNextTokenStart (-1)
  setMyNextTokenEnd (-1)
  advance
  where
  -- TODO: Do we need to freeStablePtr when we're done and/or before setting this one?
  mkPtr = io $ newIORef pState >>= newStablePtr
  pState = L.mkPState flags stringBuf srcLoc
  flags = defaultFlags
  -- TODO: We're appending a newline since the lexer may not be able to lex
  -- the final ITvccurly and ITsemi if the file doesn't end with one or if
  -- intellij strips it (which seems to be an issue as well).
  stringBuf = charSeqToStringBuffer buf
  srcLoc = (mkRealSrcLoc (mkFastString fileName) line col)
  -- Dummy values for constructing the srcLoc
  fileName = "mem"
  line = 0
  col = 0

-- TODO: Should find a faster way to convert CharSequence to StringBuffer
-- instead of going CharSequence to JString to [Char] to StringBuffer...
charSeqToStringBuffer :: CharSequence -> StringBuffer
charSeqToStringBuffer = stringToStringBuffer . fromJString . toStringJava

foreign export java advance :: Java EtaLexer ()
advance = do
  done <- getDone
  if done then
    setMyTokenType unsafeJNull
  else do
    nextTokenTypeOrNull <- getMyNextTokenType
    if not (isJNull nextTokenTypeOrNull) then do
      setMyTokenType nextTokenTypeOrNull
      setMyTokenStart =<< getMyNextTokenStart
      setMyTokenEnd =<< getMyNextTokenEnd
      setMyNextTokenType unsafeJNull
      setMyNextTokenStart (-1)
      setMyNextTokenEnd (-1)
      debugLexer ()
    else do
      pStatePtr <- getMyPStatePtr
      pStateRef <- io $ deRefStablePtr pStatePtr
      pState <- io $ readIORef pStateRef
      case L.unP (L.lexer False return) pState of
        L.POk pState' ltok -> do
          io $ writeIORef pStateRef pState'
          case ltok of
            L _ L.ITeof -> do
              debugLexer ()
              setDone True
              myTokenEnd <- getMyTokenEnd
              myBufferEnd <- getMyBufferEnd
              -- In the case that we have remaining characters after our last emitted
              -- token, we may have just omitted virtual tokens. It's simple enough to
              -- just emit T.badCharacter for the remaining input, which is likely to be
              -- whitespace.
              if myTokenEnd < myBufferEnd then do
                setMyTokenType T.whiteSpace
                setMyTokenStart myTokenEnd
                setMyTokenEnd myBufferEnd
              else
                setMyTokenType unsafeJNull
            L srcSpan token -> do
              -- If myTokenType is null, we're starting fresh.
              oldTokenType <- getMyTokenType
              myTokenStart <- if isJNull oldTokenType then return 0 else getMyTokenEnd
              setMyTokenStart myTokenStart
              myBuffer <- getMyBuffer
              myBufferEnd <- getMyBufferEnd

              -- TODO: This isn't efficient, but the only way we can get the offsets, for now.
              -- Also, for some reason column offsets are 0-based on line 0 but 1-based afterwards.
              let computeOffset line col =
                    if line == 0 then lineColToOffset myBuffer line col
                    else lineColToOffset myBuffer line (col - 1)

                  (startOffset, endOffset, iElementType) =
                    case srcSpan of
                      RealSrcSpan s ->
                        ( computeOffset (srcSpanStartLine s) (srcSpanStartCol s)
                        , computeOffset (srcSpanEndLine s) (srcSpanEndCol s)
                        , tokenToIElementType token
                        )

                      -- TODO: Should probably log that we weren't able to retrieve position info.
                      _ -> (myTokenStart, myBufferEnd, T.badCharacter)
              if startOffset == myTokenStart then do
                setMyTokenType iElementType
                setMyTokenEnd endOffset
                debugLexer (startOffset, endOffset, token, srcSpan)
              -- Found a gap, inject a whitespace token, prepare the next token.
              else if startOffset > myTokenStart then do
                setMyTokenType T.whiteSpace
                setMyTokenEnd startOffset
                setMyNextTokenType iElementType
                setMyNextTokenStart startOffset
                setMyNextTokenEnd endOffset
                debugLexer (startOffset, endOffset, token, srcSpan)
              else do
                debugLexer (startOffset, endOffset, token, srcSpan)
                -- TODO: Log error, yield T.badCharacter for the rest of the stream.
                error $
                  "Unexpected case, startOffset was " ++ show startOffset
                  ++ " and myTokenStart was " ++ show myTokenStart

        L.PFailed srcSpan msgDoc -> do
          startOffset <- getMyTokenEnd
          endOffset <- getMyBufferEnd
          let iElementType = T.badCharacter
          setMyTokenType iElementType
          setMyTokenStart startOffset
          setMyTokenEnd endOffset
          debugLexer (startOffset, endOffset, iElementType)
          setDone True

-- | If the DEBUG_LEXER env var is set, log lexer debug info to stdout.
{-# NOINLINE doDebugLexer #-}
doDebugLexer :: Bool
doDebugLexer = Unsafe.unsafePerformIO $ isJust <$> lookupEnv "DEBUG_LEXER"

debugLexer :: Show a => a -> Java EtaLexer ()
debugLexer info = when doDebugLexer $ do
  myState <- getMyState
  text <- getTokenText
  myTokenStart <- getMyTokenStart
  myTokenEnd <- getMyTokenEnd
  myTokenType <- getMyTokenType
  myNextTokenType <- getMyNextTokenType
  myNextTokenStart <- getMyNextTokenStart
  myNextTokenEnd <- getMyNextTokenEnd
  io $ putStrLn $ intercalate ", " $ map (\(k, v) -> k ++ ":" ++ v) $
    [ ("start", show myTokenStart)
    , ("end", show myTokenEnd)
    , ("type", if isJNull myTokenType then "null" else show myTokenType)
    , ("text", "'" ++ fromJString (jStringReplace text (toJString "\n") (toJString "\\n")) ++ "'")
    , ("nextType", if isJNull myNextTokenType then "null" else show myNextTokenType)
    , ("nextStart", show myNextTokenStart)
    , ("nextEnd", show myNextTokenEnd)
    , ("info", show info)
    ]

debugTokenStream :: StringBuffer -> RealSrcLoc -> DynFlags -> Java EtaLexer ()
debugTokenStream buf loc flags = when doDebugLexer $ io $
  case L.lexTokenStream buf loc flags of
    L.POk _ tokens -> do
      putStrLn "DEBUG TOKEN STREAM: POk"
      mapM_ (\(L srcSpan token) -> putStrLn $ show srcSpan ++ ": " ++ show token) tokens
      putStrLn "----------------------------------"

    _ -> putStrLn "DEBUG TOKEN STREAM: FAILED"
