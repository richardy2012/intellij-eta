module IntelliJ.Plugin.Eta.Lang.Lexer.EtaLexer where

import P
import FFI.Com.IntelliJ.Psi.Tree (IElementType)

data {-# CLASS "com.typelead.intellij.plugin.eta.lang.lexer.EtaLexer extends com.intellij.lexer.LexerBase" #-}
  EtaLexer = EtaLexer (Object# EtaLexer)
  deriving Class

foreign import java unsafe "@new" newEtaLexer :: Java a EtaLexer

start :: CharSequence -> Int -> Int -> Int -> Java EtaLexer ()
start buffer startOffset endOffset initialState = undefined

foreign export java "start" start :: CharSequence -> Int -> Int -> Int -> Java EtaLexer ()

getState :: Java EtaLexer Int
getState = return 0

foreign export java "getState" getState :: Java EtaLexer Int

getTokenType :: Java EtaLexer (Maybe IElementType)
getTokenType = undefined

getTokenTypeJava :: Java EtaLexer IElementType
getTokenTypeJava = maybeToJava <$> getTokenType

foreign export java "getTokenType" getTokenTypeJava :: Java EtaLexer IElementType

getTokenStart :: Java EtaLexer Int
getTokenStart = undefined

foreign export java "getTokenStart" getTokenStart :: Java EtaLexer Int

getTokenEnd :: Java EtaLexer Int
getTokenEnd = undefined

foreign export java "getTokenEnd" getTokenEnd :: Java EtaLexer Int

advance :: Java EtaLexer ()
advance = undefined

foreign export java "advance" advance :: Java EtaLexer ()

getBufferSequence :: Java EtaLexer CharSequence
getBufferSequence = undefined

foreign export java "getBufferSequence" getBufferSequence :: Java EtaLexer CharSequence

getBufferEnd :: Java EtaLexer Int
getBufferEnd = undefined

foreign export java "getBufferEnd" getBufferEnd :: Java EtaLexer Int
