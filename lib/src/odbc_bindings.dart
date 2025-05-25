part of 'odbc_connector.dart'; // Or remove if you prefer explicit imports

//##############################################################################
//##
//## ODBC FFI Type Definitions and Constants
//##
//##############################################################################

//----------------------------------------------------------------------------
// Core ODBC Types
//----------------------------------------------------------------------------

typedef SQLRETURN = Int16;
typedef SQLHANDLE = Pointer<Void>;
typedef SQLPOINTER = Pointer<Void>;
typedef SQLDisconnectNative = SQLRETURN Function(SQLHANDLE connectionHandle);
typedef SQLDisconnectDart = int Function(SQLHANDLE connectionHandle);

//----------------------------------------------------------------------------
// ODBC Function Signatures (Native & Dart)
//----------------------------------------------------------------------------

// Handle Management
typedef SQLAllocHandleNative =
    SQLRETURN Function(
      Int16 handleType,
      SQLHANDLE inputHandle,
      Pointer<SQLHANDLE> outputHandle,
    );
typedef SQLAllocHandleDart =
    int Function(
      int handleType,
      SQLHANDLE inputHandle,
      Pointer<SQLHANDLE> outputHandle,
    );

typedef SQLFreeHandleNative =
    SQLRETURN Function(Int16 handleType, SQLHANDLE handle);
typedef SQLFreeHandleDart = int Function(int handleType, SQLHANDLE handle);

typedef SQLFreeStmtNative =
    SQLRETURN Function(SQLHANDLE statementHandle, Uint16 option);
typedef SQLFreeStmtDart = int Function(SQLHANDLE statementHandle, int option);

// Environment Attributes
typedef SQLSetEnvAttrNative =
    SQLRETURN Function(
      SQLHANDLE envHandle,
      Int32 attribute,
      SQLPOINTER valuePtr,
      Int32 stringLength,
    );
typedef SQLSetEnvAttrDart =
    int Function(
      SQLHANDLE envHandle,
      int attribute,
      SQLPOINTER valuePtr,
      int stringLength,
    );

// Connection Management
typedef SQLDriverConnectWNative =
    SQLRETURN Function(
      SQLHANDLE dbc,
      IntPtr hwnd,
      Pointer<Utf16> inConnStr,
      Int16 inConnStrLen,
      Pointer<Utf16> outConnStr,
      Int16 outConnStrMax,
      Pointer<Int16> outConnStrLen,
      Int16 completion,
    );
typedef SQLDriverConnectWDart =
    int Function(
      SQLHANDLE dbc,
      int hwnd,
      Pointer<Utf16> inConnStr,
      int inConnStrLen,
      Pointer<Utf16> outConnStr,
      int outConnStrMax,
      Pointer<Int16> outConnStrLen,
      int completion,
    );

// Statement Execution
typedef SQLExecDirectWNative =
    SQLRETURN Function(SQLHANDLE stmt, Pointer<Utf16> sqlStr, Int32 textLength);
typedef SQLExecDirectWDart =
    int Function(SQLHANDLE stmt, Pointer<Utf16> sqlStr, int textLength);

// Result Set Processing
typedef SQLFetchNative = SQLRETURN Function(SQLHANDLE stmt);
typedef SQLFetchDart = int Function(SQLHANDLE stmt);

typedef SQLNumResultColsNative =
    SQLRETURN Function(SQLHANDLE stmtHandle, Pointer<Int16> columnCountPtr);
typedef SQLNumResultColsDart =
    int Function(SQLHANDLE stmtHandle, Pointer<Int16> columnCountPtr);

typedef SQLDescribeColWNative =
    SQLRETURN Function(
      SQLHANDLE stmtHandle,
      Uint16 columnNumber,
      Pointer<Utf16> columnNamePtr,
      Int16 nameBufferLength,
      Pointer<Int16> nameLengthPtr,
      Pointer<Int16> dataTypePtr, // This is SQL_XXX type
      Pointer<Int32> columnSizePtr,
      Pointer<Int16> decimalDigitsPtr,
      Pointer<Int16> nullablePtr,
    );
typedef SQLDescribeColWDart =
    int Function(
      SQLHANDLE stmtHandle,
      int columnNumber,
      Pointer<Utf16> columnNamePtr,
      int nameBufferLength,
      Pointer<Int16> nameLengthPtr,
      Pointer<Int16> dataTypePtr,
      Pointer<Int32> columnSizePtr,
      Pointer<Int16> decimalDigitsPtr,
      Pointer<Int16> nullablePtr,
    );

typedef SQLGetDataNative =
    SQLRETURN Function(
      SQLHANDLE stmt,
      Uint16 colNumber,
      Uint16 targetType, // This is SQL_C_XXX type
      Pointer<Void> targetValue,
      Int64 bufferLength,
      Pointer<Int64> strLenOrIndPtr,
    );
typedef SQLGetDataDart =
    int Function(
      SQLHANDLE stmt,
      int colNumber,
      int targetType,
      Pointer<Void> targetValue,
      int bufferLength,
      Pointer<Int64> strLenOrIndPtr,
    );

//----------------------------------------------------------------------------
// ODBC Constants (lowerCamelCase)
//----------------------------------------------------------------------------
const int sqlSuccess = 0;
const int sqlSuccessWithInfo = 1;
const int sqlNoData = 100;
const int sqlError = -1;
const int sqlInvalidHandle = -2;

const int sqlHandleTypeEnv = 1;
const int sqlHandleTypeDbc = 2;
const int sqlHandleTypeStmt = 3;

const int sqlAttrOdbcVersion = 200;
const int sqlOdbcVersion3 = 3;

const int sqlFreeStmtClose = 0;

const int sqlDriverNoprompt = 0;
const int sqlDriverComplete = 1;

const int sqlNts = -3;
const int sqlNullData = -1;
const int sqlDataAtExec = -2;
const int sqlNoTotal = -4;

const int sqlcDataTypeChar = 1;
const int sqlcDataTypeWchar = -8;
const int sqlcDataTypeSlong = 4;
const int sqlcDataTypeDouble = 8;
const int sqlcDataTypeBit = -7;
const int sqlcDataTypeDefault = 99;
const int sqlcDataTypeNumeric = 2;
const int sqlcDataTypeDate = 9;
const int sqlcDataTypeTime = 10;
const int sqlcDataTypeTimestamp = 11;

const int sqlDataTypeChar = 1;
const int sqlDataTypeVarchar = 12;
const int sqlDataTypeLongvarchar = -1;
const int sqlDataTypeWchar = -8;
const int sqlDataTypeWvarchar = -9;
const int sqlDataTypeWlongvarchar = -10;
const int sqlDataTypeDecimal = 3;
const int sqlDataTypeNumeric = 2;
const int sqlDataTypeSmallint = 5;
const int sqlDataTypeInteger = 4;
const int sqlDataTypeReal = 7;
const int sqlDataTypeFloat = 6;
const int sqlDataTypeDouble = 8;
const int sqlDataTypeBit = -7;
const int sqlDataTypeDate = 91;
const int sqlDataTypeTime = 92;
const int sqlDataTypeTimestamp = 93;

/// Represents metadata for a result column.
class OdbcColumnMeta {
  // Made public and renamed
  final String name;
  final int sqlDataType; // sqlDataTypeXxx from SQLDescribeCol

  OdbcColumnMeta({required this.name, required this.sqlDataType});
}
