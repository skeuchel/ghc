{-# OPTIONS -fno-implicit-prelude -#include "HsBase.h" #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Foreign.C.Error
-- Copyright   :  (c) The FFI task force 2001
-- License     :  BSD-style (see the file libraries/base/LICENSE)
-- 
-- Maintainer  :  ffi@haskell.org
-- Stability   :  provisional
-- Portability :  portable
--
-- C-specific Marshalling support: Handling of C \"errno\" error codes.
--
-----------------------------------------------------------------------------

module Foreign.C.Error (

  -- * Haskell representations of @errno@ values

  Errno(..),		-- instance: Eq

  -- ** Common @errno@ symbols
  -- | Different operating systems and\/or C libraries often support
  -- different values of @errno@.  This module defines the common values,
  -- but due to the open definition of 'Errno' users may add definitions
  -- which are not predefined.
  eOK, e2BIG, eACCES, eADDRINUSE, eADDRNOTAVAIL, eADV, eAFNOSUPPORT, eAGAIN, 
  eALREADY, eBADF, eBADMSG, eBADRPC, eBUSY, eCHILD, eCOMM, eCONNABORTED, 
  eCONNREFUSED, eCONNRESET, eDEADLK, eDESTADDRREQ, eDIRTY, eDOM, eDQUOT, 
  eEXIST, eFAULT, eFBIG, eFTYPE, eHOSTDOWN, eHOSTUNREACH, eIDRM, eILSEQ, 
  eINPROGRESS, eINTR, eINVAL, eIO, eISCONN, eISDIR, eLOOP, eMFILE, eMLINK, 
  eMSGSIZE, eMULTIHOP, eNAMETOOLONG, eNETDOWN, eNETRESET, eNETUNREACH, 
  eNFILE, eNOBUFS, eNODATA, eNODEV, eNOENT, eNOEXEC, eNOLCK, eNOLINK, 
  eNOMEM, eNOMSG, eNONET, eNOPROTOOPT, eNOSPC, eNOSR, eNOSTR, eNOSYS, 
  eNOTBLK, eNOTCONN, eNOTDIR, eNOTEMPTY, eNOTSOCK, eNOTTY, eNXIO, 
  eOPNOTSUPP, ePERM, ePFNOSUPPORT, ePIPE, ePROCLIM, ePROCUNAVAIL, 
  ePROGMISMATCH, ePROGUNAVAIL, ePROTO, ePROTONOSUPPORT, ePROTOTYPE, 
  eRANGE, eREMCHG, eREMOTE, eROFS, eRPCMISMATCH, eRREMOTE, eSHUTDOWN, 
  eSOCKTNOSUPPORT, eSPIPE, eSRCH, eSRMNT, eSTALE, eTIME, eTIMEDOUT, 
  eTOOMANYREFS, eTXTBSY, eUSERS, eWOULDBLOCK, eXDEV,

  -- ** 'Errno' functions
                        -- :: Errno
  isValidErrno,		-- :: Errno -> Bool

  -- access to the current thread's "errno" value
  --
  getErrno,             -- :: IO Errno
  resetErrno,           -- :: IO ()

  -- conversion of an "errno" value into IO error
  --
  errnoToIOError,       -- :: String       -- location
                        -- -> Errno        -- errno
                        -- -> Maybe Handle -- handle
                        -- -> Maybe String -- filename
                        -- -> IOError

  -- throw current "errno" value
  --
  throwErrno,           -- ::                String               -> IO a

  -- ** Guards for IO operations that may fail

  throwErrnoIf,         -- :: (a -> Bool) -> String -> IO a       -> IO a
  throwErrnoIf_,        -- :: (a -> Bool) -> String -> IO a       -> IO ()
  throwErrnoIfRetry,    -- :: (a -> Bool) -> String -> IO a       -> IO a
  throwErrnoIfRetry_,   -- :: (a -> Bool) -> String -> IO a       -> IO ()
  throwErrnoIfMinus1,   -- :: Num a 
			-- =>                String -> IO a       -> IO a
  throwErrnoIfMinus1_,  -- :: Num a 
			-- =>                String -> IO a       -> IO ()
  throwErrnoIfMinus1Retry,  
			-- :: Num a 
			-- =>                String -> IO a       -> IO a
  throwErrnoIfMinus1Retry_,  
			-- :: Num a 
			-- =>                String -> IO a       -> IO ()
  throwErrnoIfNull,	-- ::                String -> IO (Ptr a) -> IO (Ptr a)
  throwErrnoIfNullRetry,-- ::                String -> IO (Ptr a) -> IO (Ptr a)

  throwErrnoIfRetryMayBlock, 
  throwErrnoIfRetryMayBlock_,
  throwErrnoIfMinus1RetryMayBlock,
  throwErrnoIfMinus1RetryMayBlock_,  
  throwErrnoIfNullRetryMayBlock
) where


-- this is were we get the CONST_XXX definitions from that configure
-- calculated for us
--
#ifndef __NHC__
#include "config.h"
#endif

-- system dependent imports
-- ------------------------

-- GHC allows us to get at the guts inside IO errors/exceptions
--
#if __GLASGOW_HASKELL__
import GHC.IOBase (IOException(..), IOErrorType(..))
#endif /* __GLASGOW_HASKELL__ */


-- regular imports
-- ---------------

import Foreign.Storable
import Foreign.Ptr
import Foreign.C.Types
import Foreign.C.String
import Foreign.Marshal.Error 	( void )
import Data.Maybe

#if __GLASGOW_HASKELL__
import GHC.IOBase
import GHC.Num
import GHC.Base
#else
import System.IO		( IOError, Handle, ioError )
import System.IO.Unsafe		( unsafePerformIO )
#endif

#ifdef __HUGS__
{-# CBITS PrelIOUtils.c #-}
#endif


-- "errno" type
-- ------------

-- | Haskell representation for @errno@ values.
-- The implementation is deliberately exposed, to allow users to add
-- their own definitions of 'Errno' values.

newtype Errno = Errno CInt

instance Eq Errno where
  errno1@(Errno no1) == errno2@(Errno no2) 
    | isValidErrno errno1 && isValidErrno errno2 = no1 == no2
    | otherwise					 = False

-- common "errno" symbols
--
eOK, e2BIG, eACCES, eADDRINUSE, eADDRNOTAVAIL, eADV, eAFNOSUPPORT, eAGAIN, 
  eALREADY, eBADF, eBADMSG, eBADRPC, eBUSY, eCHILD, eCOMM, eCONNABORTED, 
  eCONNREFUSED, eCONNRESET, eDEADLK, eDESTADDRREQ, eDIRTY, eDOM, eDQUOT, 
  eEXIST, eFAULT, eFBIG, eFTYPE, eHOSTDOWN, eHOSTUNREACH, eIDRM, eILSEQ, 
  eINPROGRESS, eINTR, eINVAL, eIO, eISCONN, eISDIR, eLOOP, eMFILE, eMLINK, 
  eMSGSIZE, eMULTIHOP, eNAMETOOLONG, eNETDOWN, eNETRESET, eNETUNREACH, 
  eNFILE, eNOBUFS, eNODATA, eNODEV, eNOENT, eNOEXEC, eNOLCK, eNOLINK, 
  eNOMEM, eNOMSG, eNONET, eNOPROTOOPT, eNOSPC, eNOSR, eNOSTR, eNOSYS, 
  eNOTBLK, eNOTCONN, eNOTDIR, eNOTEMPTY, eNOTSOCK, eNOTTY, eNXIO, 
  eOPNOTSUPP, ePERM, ePFNOSUPPORT, ePIPE, ePROCLIM, ePROCUNAVAIL, 
  ePROGMISMATCH, ePROGUNAVAIL, ePROTO, ePROTONOSUPPORT, ePROTOTYPE, 
  eRANGE, eREMCHG, eREMOTE, eROFS, eRPCMISMATCH, eRREMOTE, eSHUTDOWN, 
  eSOCKTNOSUPPORT, eSPIPE, eSRCH, eSRMNT, eSTALE, eTIME, eTIMEDOUT, 
  eTOOMANYREFS, eTXTBSY, eUSERS, eWOULDBLOCK, eXDEV		       :: Errno
--
-- the cCONST_XXX identifiers are cpp symbols whose value is computed by
-- configure 
--
eOK             = Errno 0
#ifdef __NHC__
#include "Errno.hs"
#else
e2BIG           = Errno (CONST_E2BIG)
eACCES		= Errno (CONST_EACCES)
eADDRINUSE	= Errno (CONST_EADDRINUSE)
eADDRNOTAVAIL	= Errno (CONST_EADDRNOTAVAIL)
eADV		= Errno (CONST_EADV)
eAFNOSUPPORT	= Errno (CONST_EAFNOSUPPORT)
eAGAIN		= Errno (CONST_EAGAIN)
eALREADY	= Errno (CONST_EALREADY)
eBADF		= Errno (CONST_EBADF)
eBADMSG		= Errno (CONST_EBADMSG)
eBADRPC		= Errno (CONST_EBADRPC)
eBUSY		= Errno (CONST_EBUSY)
eCHILD		= Errno (CONST_ECHILD)
eCOMM		= Errno (CONST_ECOMM)
eCONNABORTED	= Errno (CONST_ECONNABORTED)
eCONNREFUSED	= Errno (CONST_ECONNREFUSED)
eCONNRESET	= Errno (CONST_ECONNRESET)
eDEADLK		= Errno (CONST_EDEADLK)
eDESTADDRREQ	= Errno (CONST_EDESTADDRREQ)
eDIRTY		= Errno (CONST_EDIRTY)
eDOM		= Errno (CONST_EDOM)
eDQUOT		= Errno (CONST_EDQUOT)
eEXIST		= Errno (CONST_EEXIST)
eFAULT		= Errno (CONST_EFAULT)
eFBIG		= Errno (CONST_EFBIG)
eFTYPE		= Errno (CONST_EFTYPE)
eHOSTDOWN	= Errno (CONST_EHOSTDOWN)
eHOSTUNREACH	= Errno (CONST_EHOSTUNREACH)
eIDRM		= Errno (CONST_EIDRM)
eILSEQ		= Errno (CONST_EILSEQ)
eINPROGRESS	= Errno (CONST_EINPROGRESS)
eINTR		= Errno (CONST_EINTR)
eINVAL		= Errno (CONST_EINVAL)
eIO		= Errno (CONST_EIO)
eISCONN		= Errno (CONST_EISCONN)
eISDIR		= Errno (CONST_EISDIR)
eLOOP		= Errno (CONST_ELOOP)
eMFILE		= Errno (CONST_EMFILE)
eMLINK		= Errno (CONST_EMLINK)
eMSGSIZE	= Errno (CONST_EMSGSIZE)
eMULTIHOP	= Errno (CONST_EMULTIHOP)
eNAMETOOLONG	= Errno (CONST_ENAMETOOLONG)
eNETDOWN	= Errno (CONST_ENETDOWN)
eNETRESET	= Errno (CONST_ENETRESET)
eNETUNREACH	= Errno (CONST_ENETUNREACH)
eNFILE		= Errno (CONST_ENFILE)
eNOBUFS		= Errno (CONST_ENOBUFS)
eNODATA		= Errno (CONST_ENODATA)
eNODEV		= Errno (CONST_ENODEV)
eNOENT		= Errno (CONST_ENOENT)
eNOEXEC		= Errno (CONST_ENOEXEC)
eNOLCK		= Errno (CONST_ENOLCK)
eNOLINK		= Errno (CONST_ENOLINK)
eNOMEM		= Errno (CONST_ENOMEM)
eNOMSG		= Errno (CONST_ENOMSG)
eNONET		= Errno (CONST_ENONET)
eNOPROTOOPT	= Errno (CONST_ENOPROTOOPT)
eNOSPC		= Errno (CONST_ENOSPC)
eNOSR		= Errno (CONST_ENOSR)
eNOSTR		= Errno (CONST_ENOSTR)
eNOSYS		= Errno (CONST_ENOSYS)
eNOTBLK		= Errno (CONST_ENOTBLK)
eNOTCONN	= Errno (CONST_ENOTCONN)
eNOTDIR		= Errno (CONST_ENOTDIR)
eNOTEMPTY	= Errno (CONST_ENOTEMPTY)
eNOTSOCK	= Errno (CONST_ENOTSOCK)
eNOTTY		= Errno (CONST_ENOTTY)
eNXIO		= Errno (CONST_ENXIO)
eOPNOTSUPP	= Errno (CONST_EOPNOTSUPP)
ePERM		= Errno (CONST_EPERM)
ePFNOSUPPORT	= Errno (CONST_EPFNOSUPPORT)
ePIPE		= Errno (CONST_EPIPE)
ePROCLIM	= Errno (CONST_EPROCLIM)
ePROCUNAVAIL	= Errno (CONST_EPROCUNAVAIL)
ePROGMISMATCH	= Errno (CONST_EPROGMISMATCH)
ePROGUNAVAIL	= Errno (CONST_EPROGUNAVAIL)
ePROTO		= Errno (CONST_EPROTO)
ePROTONOSUPPORT = Errno (CONST_EPROTONOSUPPORT)
ePROTOTYPE	= Errno (CONST_EPROTOTYPE)
eRANGE		= Errno (CONST_ERANGE)
eREMCHG		= Errno (CONST_EREMCHG)
eREMOTE		= Errno (CONST_EREMOTE)
eROFS		= Errno (CONST_EROFS)
eRPCMISMATCH	= Errno (CONST_ERPCMISMATCH)
eRREMOTE	= Errno (CONST_ERREMOTE)
eSHUTDOWN	= Errno (CONST_ESHUTDOWN)
eSOCKTNOSUPPORT = Errno (CONST_ESOCKTNOSUPPORT)
eSPIPE		= Errno (CONST_ESPIPE)
eSRCH		= Errno (CONST_ESRCH)
eSRMNT		= Errno (CONST_ESRMNT)
eSTALE		= Errno (CONST_ESTALE)
eTIME		= Errno (CONST_ETIME)
eTIMEDOUT	= Errno (CONST_ETIMEDOUT)
eTOOMANYREFS	= Errno (CONST_ETOOMANYREFS)
eTXTBSY		= Errno (CONST_ETXTBSY)
eUSERS		= Errno (CONST_EUSERS)
eWOULDBLOCK	= Errno (CONST_EWOULDBLOCK)
eXDEV		= Errno (CONST_EXDEV)
#endif

-- | Yield 'True' if the given 'Errno' value is valid on the system.
-- This implies that the 'Eq' instance of 'Errno' is also system dependent
-- as it is only defined for valid values of 'Errno'.
--
isValidErrno               :: Errno -> Bool
--
-- the configure script sets all invalid "errno"s to -1
--
isValidErrno (Errno errno)  = errno /= -1


-- access to the current thread's "errno" value
-- --------------------------------------------

-- | Get the current value of @errno@ in the current thread.
--
getErrno :: IO Errno

-- We must call a C function to get the value of errno in general.  On
-- threaded systems, errno is hidden behind a C macro so that each OS
-- thread gets its own copy.
#ifdef __NHC__
getErrno = do e <- peek _errno; return (Errno e)
foreign import ccall unsafe "errno.h &errno" _errno :: Ptr CInt
#else
getErrno = do e <- get_errno; return (Errno e)
foreign import ccall unsafe "HsBase.h __hscore_get_errno" get_errno :: IO CInt
#endif

-- | Reset the current thread\'s @errno@ value to 'eOK'.
--
resetErrno :: IO ()

-- Again, setting errno has to be done via a C function.
#ifdef __NHC__
resetErrno = poke _errno 0
#else
resetErrno = set_errno 0
foreign import ccall unsafe "HsBase.h __hscore_set_errno" set_errno :: CInt -> IO ()
#endif

-- throw current "errno" value
-- ---------------------------

-- | Throw an 'IOError' corresponding to the current value of 'getErrno'.
--
throwErrno     :: String	-- ^ textual description of the error location
	       -> IO a
throwErrno loc  =
  do
    errno <- getErrno
    ioError (errnoToIOError loc errno Nothing Nothing)


-- guards for IO operations that may fail
-- --------------------------------------

-- | Throw an 'IOError' corresponding to the current value of 'getErrno'
-- if the result value of the 'IO' action meets the given predicate.
--
throwErrnoIf    :: (a -> Bool)	-- ^ predicate to apply to the result value
				-- of the 'IO' operation
		-> String	-- ^ textual description of the location
		-> IO a		-- ^ the 'IO' operation to be executed
		-> IO a
throwErrnoIf pred loc f  = 
  do
    res <- f
    if pred res then throwErrno loc else return res

-- | as 'throwErrnoIf', but discards the result of the 'IO' action after
-- error handling.
--
throwErrnoIf_   :: (a -> Bool) -> String -> IO a -> IO ()
throwErrnoIf_ pred loc f  = void $ throwErrnoIf pred loc f

-- | as 'throwErrnoIf', but retry the 'IO' action when it yields the
-- error code 'eINTR' - this amounts to the standard retry loop for
-- interrupted POSIX system calls.
--
throwErrnoIfRetry            :: (a -> Bool) -> String -> IO a -> IO a
throwErrnoIfRetry pred loc f  = 
  do
    res <- f
    if pred res
      then do
	err <- getErrno
	if err == eINTR
	  then throwErrnoIfRetry pred loc f
	  else throwErrno loc
      else return res

-- | as 'throwErrnoIfRetry', but checks for operations that would block and
-- executes an alternative action before retrying in that case.
--
throwErrnoIfRetryMayBlock
		:: (a -> Bool)	-- ^ predicate to apply to the result value
				-- of the 'IO' operation
		-> String	-- ^ textual description of the location
		-> IO a		-- ^ the 'IO' operation to be executed
		-> IO b		-- ^ action to execute before retrying if
				-- an immediate retry would block
		-> IO a
throwErrnoIfRetryMayBlock pred loc f on_block  = 
  do
    res <- f
    if pred res
      then do
	err <- getErrno
	if err == eINTR
	  then throwErrnoIfRetryMayBlock pred loc f on_block
          else if err == eWOULDBLOCK || err == eAGAIN
	         then do on_block; throwErrnoIfRetryMayBlock pred loc f on_block
                 else throwErrno loc
      else return res

-- | as 'throwErrnoIfRetry', but discards the result.
--
throwErrnoIfRetry_            :: (a -> Bool) -> String -> IO a -> IO ()
throwErrnoIfRetry_ pred loc f  = void $ throwErrnoIfRetry pred loc f

-- | as 'throwErrnoIfRetryMayBlock', but discards the result.
--
throwErrnoIfRetryMayBlock_ :: (a -> Bool) -> String -> IO a -> IO b -> IO ()
throwErrnoIfRetryMayBlock_ pred loc f on_block 
  = void $ throwErrnoIfRetryMayBlock pred loc f on_block

-- | Throw an 'IOError' corresponding to the current value of 'getErrno'
-- if the 'IO' action returns a result of @-1@.
--
throwErrnoIfMinus1 :: Num a => String -> IO a -> IO a
throwErrnoIfMinus1  = throwErrnoIf (== -1)

-- | as 'throwErrnoIfMinus1', but discards the result.
--
throwErrnoIfMinus1_ :: Num a => String -> IO a -> IO ()
throwErrnoIfMinus1_  = throwErrnoIf_ (== -1)

-- | Throw an 'IOError' corresponding to the current value of 'getErrno'
-- if the 'IO' action returns a result of @-1@, but retries in case of
-- an interrupted operation.
--
throwErrnoIfMinus1Retry :: Num a => String -> IO a -> IO a
throwErrnoIfMinus1Retry  = throwErrnoIfRetry (== -1)

-- | as 'throwErrnoIfMinus1', but discards the result.
--
throwErrnoIfMinus1Retry_ :: Num a => String -> IO a -> IO ()
throwErrnoIfMinus1Retry_  = throwErrnoIfRetry_ (== -1)

-- | as 'throwErrnoIfMinus1Retry', but checks for operations that would block.
--
throwErrnoIfMinus1RetryMayBlock :: Num a => String -> IO a -> IO b -> IO a
throwErrnoIfMinus1RetryMayBlock  = throwErrnoIfRetryMayBlock (== -1)

-- | as 'throwErrnoIfMinus1RetryMayBlock', but discards the result.
--
throwErrnoIfMinus1RetryMayBlock_ :: Num a => String -> IO a -> IO b -> IO ()
throwErrnoIfMinus1RetryMayBlock_  = throwErrnoIfRetryMayBlock_ (== -1)

-- | Throw an 'IOError' corresponding to the current value of 'getErrno'
-- if the 'IO' action returns 'nullPtr'.
--
throwErrnoIfNull :: String -> IO (Ptr a) -> IO (Ptr a)
throwErrnoIfNull  = throwErrnoIf (== nullPtr)

-- | Throw an 'IOError' corresponding to the current value of 'getErrno'
-- if the 'IO' action returns 'nullPtr',
-- but retry in case of an interrupted operation.
--
throwErrnoIfNullRetry :: String -> IO (Ptr a) -> IO (Ptr a)
throwErrnoIfNullRetry  = throwErrnoIfRetry (== nullPtr)

-- | as 'throwErrnoIfNullRetry', but checks for operations that would block.
--
throwErrnoIfNullRetryMayBlock :: String -> IO (Ptr a) -> IO b -> IO (Ptr a)
throwErrnoIfNullRetryMayBlock  = throwErrnoIfRetryMayBlock (== nullPtr)

-- conversion of an "errno" value into IO error
-- --------------------------------------------

-- | Construct a Haskell 98 I\/O error based on the given 'Errno' value.
-- The optional information can be used to improve the accuracy of
-- error messages.
--
errnoToIOError	:: String	-- ^ the location where the error occurred
		-> Errno	-- ^ the error number
		-> Maybe Handle	-- ^ optional handle associated with the error
		-> Maybe String	-- ^ optional filename associated with the error
		-> IOError
errnoToIOError loc errno maybeHdl maybeName = unsafePerformIO $ do
    str <- strerror errno >>= peekCString
#if __GLASGOW_HASKELL__
    return (IOError maybeHdl errType loc str maybeName)
    where
    errType
        | errno == eOK             = OtherError
        | errno == e2BIG           = ResourceExhausted
        | errno == eACCES          = PermissionDenied
        | errno == eADDRINUSE      = ResourceBusy
        | errno == eADDRNOTAVAIL   = UnsupportedOperation
        | errno == eADV            = OtherError
        | errno == eAFNOSUPPORT    = UnsupportedOperation
        | errno == eAGAIN          = ResourceExhausted
        | errno == eALREADY        = AlreadyExists
        | errno == eBADF           = OtherError
        | errno == eBADMSG         = InappropriateType
        | errno == eBADRPC         = OtherError
        | errno == eBUSY           = ResourceBusy
        | errno == eCHILD          = NoSuchThing
        | errno == eCOMM           = ResourceVanished
        | errno == eCONNABORTED    = OtherError
        | errno == eCONNREFUSED    = NoSuchThing
        | errno == eCONNRESET      = ResourceVanished
        | errno == eDEADLK         = ResourceBusy
        | errno == eDESTADDRREQ    = InvalidArgument
        | errno == eDIRTY          = UnsatisfiedConstraints
        | errno == eDOM            = InvalidArgument
        | errno == eDQUOT          = PermissionDenied
        | errno == eEXIST          = AlreadyExists
        | errno == eFAULT          = OtherError
        | errno == eFBIG           = PermissionDenied
        | errno == eFTYPE          = InappropriateType
        | errno == eHOSTDOWN       = NoSuchThing
        | errno == eHOSTUNREACH    = NoSuchThing
        | errno == eIDRM           = ResourceVanished
        | errno == eILSEQ          = InvalidArgument
        | errno == eINPROGRESS     = AlreadyExists
        | errno == eINTR           = Interrupted
        | errno == eINVAL          = InvalidArgument
        | errno == eIO             = HardwareFault
        | errno == eISCONN         = AlreadyExists
        | errno == eISDIR          = InappropriateType
        | errno == eLOOP           = InvalidArgument
        | errno == eMFILE          = ResourceExhausted
        | errno == eMLINK          = ResourceExhausted
        | errno == eMSGSIZE        = ResourceExhausted
        | errno == eMULTIHOP       = UnsupportedOperation
        | errno == eNAMETOOLONG    = InvalidArgument
        | errno == eNETDOWN        = ResourceVanished
        | errno == eNETRESET       = ResourceVanished
        | errno == eNETUNREACH     = NoSuchThing
        | errno == eNFILE          = ResourceExhausted
        | errno == eNOBUFS         = ResourceExhausted
        | errno == eNODATA         = NoSuchThing
        | errno == eNODEV          = UnsupportedOperation
        | errno == eNOENT          = NoSuchThing
        | errno == eNOEXEC         = InvalidArgument
        | errno == eNOLCK          = ResourceExhausted
        | errno == eNOLINK         = ResourceVanished
        | errno == eNOMEM          = ResourceExhausted
        | errno == eNOMSG          = NoSuchThing
        | errno == eNONET          = NoSuchThing
        | errno == eNOPROTOOPT     = UnsupportedOperation
        | errno == eNOSPC          = ResourceExhausted
        | errno == eNOSR           = ResourceExhausted
        | errno == eNOSTR          = InvalidArgument
        | errno == eNOSYS          = UnsupportedOperation
        | errno == eNOTBLK         = InvalidArgument
        | errno == eNOTCONN        = InvalidArgument
        | errno == eNOTDIR         = InappropriateType
        | errno == eNOTEMPTY       = UnsatisfiedConstraints
        | errno == eNOTSOCK        = InvalidArgument
        | errno == eNOTTY          = IllegalOperation
        | errno == eNXIO           = NoSuchThing
        | errno == eOPNOTSUPP      = UnsupportedOperation
        | errno == ePERM           = PermissionDenied
        | errno == ePFNOSUPPORT    = UnsupportedOperation
        | errno == ePIPE           = ResourceVanished
        | errno == ePROCLIM        = PermissionDenied
        | errno == ePROCUNAVAIL    = UnsupportedOperation
        | errno == ePROGMISMATCH   = ProtocolError
        | errno == ePROGUNAVAIL    = UnsupportedOperation
        | errno == ePROTO          = ProtocolError
        | errno == ePROTONOSUPPORT = ProtocolError
        | errno == ePROTOTYPE      = ProtocolError
        | errno == eRANGE          = UnsupportedOperation
        | errno == eREMCHG         = ResourceVanished
        | errno == eREMOTE         = IllegalOperation
        | errno == eROFS           = PermissionDenied
        | errno == eRPCMISMATCH    = ProtocolError
        | errno == eRREMOTE        = IllegalOperation
        | errno == eSHUTDOWN       = IllegalOperation
        | errno == eSOCKTNOSUPPORT = UnsupportedOperation
        | errno == eSPIPE          = UnsupportedOperation
        | errno == eSRCH           = NoSuchThing
        | errno == eSRMNT          = UnsatisfiedConstraints
        | errno == eSTALE          = ResourceVanished
        | errno == eTIME           = TimeExpired
        | errno == eTIMEDOUT       = TimeExpired
        | errno == eTOOMANYREFS    = ResourceExhausted
        | errno == eTXTBSY         = ResourceBusy
        | errno == eUSERS          = ResourceExhausted
        | errno == eWOULDBLOCK     = OtherError
        | errno == eXDEV           = UnsupportedOperation
        | otherwise                = OtherError
#else
    return (userError (loc ++ ": " ++ str ++ maybe "" (": "++) maybeName))
#endif

foreign import ccall unsafe "string.h" strerror :: Errno -> IO (Ptr CChar)
