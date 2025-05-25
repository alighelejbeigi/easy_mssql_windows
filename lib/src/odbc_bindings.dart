// This file is part of the ODBC connector library.
// It contains FFI (Foreign Function Interface) type definitions for interacting
// with native ODBC functions, as well as ODBC-specific constants and helper data structures.
part of 'odbc_connector.dart'; // Indicates this file is a part of the 'odbc_connector.dart' library.
// Alternatively, if this were a standalone file, you'd use import/export.

//##############################################################################
//##
//## ODBC FFI Type Definitions and Constants
//##
//##############################################################################

//----------------------------------------------------------------------------
// Core ODBC Types
// These typedefs map fundamental ODBC C types to Dart FFI types.
//----------------------------------------------------------------------------

/// Represents the return code from an ODBC function.
/// Typically, SQL_SUCCESS (0) or SQL_SUCCESS_WITH_INFO (1) indicate success.
typedef SQLRETURN = Int16;

/// A generic ODBC handle (e.g., for environment, connection, statement, or descriptor).
/// In C, this is usually a `void*` or a specific struct pointer.
typedef SQLHANDLE = Pointer<Void>;

/// A generic pointer type used in ODBC, often for output parameters or data buffers.
typedef SQLPOINTER = Pointer<Void>;

/// Native signature for the SQLDisconnect ODBC function.
/// This function closes the connection associated with a specific connection handle.
typedef SQLDisconnectNative = SQLRETURN Function(SQLHANDLE connectionHandle);

/// Dart signature for the SQLDisconnect ODBC function.
typedef SQLDisconnectDart = int Function(SQLHANDLE connectionHandle);

//----------------------------------------------------------------------------
// ODBC Function Signatures (Native & Dart)
// Each pair defines the C function signature (Native) and its Dart equivalent (Dart)
// for use with FFI's `lookupFunction`.
//----------------------------------------------------------------------------

// ---- Handle Management Functions ----

/// Native signature for SQLAllocHandle.
/// Allocates an environment, connection, statement, or descriptor handle.
typedef SQLAllocHandleNative =
    SQLRETURN Function(
      Int16
      handleType, // The type of handle to be allocated (e.g., SQL_HANDLE_ENV).
      SQLHANDLE
      inputHandle, // An existing handle on which the new handle is allocated (context).
      Pointer<SQLHANDLE>
      outputHandle, // Pointer to a buffer in which to return the new handle.
    );

/// Dart signature for SQLAllocHandle.
typedef SQLAllocHandleDart =
    int Function(
      int handleType,
      SQLHANDLE inputHandle,
      Pointer<SQLHANDLE> outputHandle,
    );

/// Native signature for SQLFreeHandle.
/// Frees resources associated with a specific environment, connection, statement, or descriptor handle.
typedef SQLFreeHandleNative =
    SQLRETURN Function(
      Int16 handleType, // The type of handle to be freed.
      SQLHANDLE handle, // The handle to be freed.
    );

/// Dart signature for SQLFreeHandle.
typedef SQLFreeHandleDart = int Function(int handleType, SQLHANDLE handle);

/// Native signature for SQLFreeStmt.
/// Stops processing associated with a specific statement, closes any open cursors,
/// discards pending results, or optionally frees the statement handle.
typedef SQLFreeStmtNative =
    SQLRETURN Function(
      SQLHANDLE statementHandle, // The statement handle.
      Uint16
      option, // Option for the operation (e.g., SQL_CLOSE, SQL_RESET_PARAMS).
    );

/// Dart signature for SQLFreeStmt.
typedef SQLFreeStmtDart = int Function(SQLHANDLE statementHandle, int option);

// ---- Environment Attribute Functions ----

/// Native signature for SQLSetEnvAttr.
/// Sets attributes that govern aspects of environments.
typedef SQLSetEnvAttrNative =
    SQLRETURN Function(
      SQLHANDLE envHandle, // Environment handle.
      Int32 attribute, // Attribute to set (e.g., SQL_ATTR_ODBC_VERSION).
      SQLPOINTER
      valuePtr, // Value for the attribute. Can be an integer or a pointer to a string.
      Int32
      stringLength, // Length of the value if it's a string; SQL_IS_INTEGER for integer values.
    );

/// Dart signature for SQLSetEnvAttr.
typedef SQLSetEnvAttrDart =
    int Function(
      SQLHANDLE envHandle,
      int attribute,
      SQLPOINTER valuePtr,
      int stringLength,
    );

// ---- Connection Management Functions ----

/// Native signature for SQLDriverConnectW (Unicode version).
/// Establishes a connection to a driver and a data source. More flexible than SQLConnect.
typedef SQLDriverConnectWNative =
    SQLRETURN Function(
      SQLHANDLE dbc, // Connection handle.
      IntPtr hwnd, // Window handle (for dialogs if needed, often NULL).
      Pointer<Utf16> inConnStr, // A full connection string.
      Int16
      inConnStrLen, // Length of inConnStr (or SQL_NTS for null-terminated).
      Pointer<Utf16> outConnStr, // Buffer for the completed connection string.
      Int16 outConnStrMax, // Length of outConnStr buffer.
      Pointer<Int16>
      outConnStrLen, // Pointer to return the actual length of outConnStr.
      Int16 completion, // Driver completion option (e.g., SQL_DRIVER_NOPROMPT).
    );

/// Dart signature for SQLDriverConnectW.
typedef SQLDriverConnectWDart =
    int Function(
      SQLHANDLE dbc,
      int hwnd, // Dart representation of HWND, usually 0.
      Pointer<Utf16> inConnStr,
      int inConnStrLen,
      Pointer<Utf16> outConnStr,
      int outConnStrMax,
      Pointer<Int16> outConnStrLen,
      int completion,
    );

// ---- Statement Execution Functions ----

/// Native signature for SQLExecDirectW (Unicode version).
/// Executes a preparable statement, using the current values of the parameter marker variables if any exist.
typedef SQLExecDirectWNative =
    SQLRETURN Function(
      SQLHANDLE stmt, // Statement handle.
      Pointer<Utf16> sqlStr, // SQL statement string.
      Int32 textLength, // Length of sqlStr (or SQL_NTS for null-terminated).
    );

/// Dart signature for SQLExecDirectW.
typedef SQLExecDirectWDart =
    int Function(SQLHANDLE stmt, Pointer<Utf16> sqlStr, int textLength);

// ---- Result Set Processing Functions ----

/// Native signature for SQLFetch.
/// Fetches the next rowset of data from the result set and returns data for all bound columns.
typedef SQLFetchNative =
    SQLRETURN Function(SQLHANDLE stmt); // Statement handle.
/// Dart signature for SQLFetch.
typedef SQLFetchDart = int Function(SQLHANDLE stmt);

/// Native signature for SQLNumResultCols.
/// Returns the number of columns in a result set.
typedef SQLNumResultColsNative =
    SQLRETURN Function(
      SQLHANDLE stmtHandle, // Statement handle.
      Pointer<Int16> columnCountPtr, // Pointer to store the number of columns.
    );

/// Dart signature for SQLNumResultCols.
typedef SQLNumResultColsDart =
    int Function(SQLHANDLE stmtHandle, Pointer<Int16> columnCountPtr);

/// Native signature for SQLDescribeColW (Unicode version).
/// Returns the result descriptor—column name, type, size, etc.—for one column in the result set.
typedef SQLDescribeColWNative =
    SQLRETURN Function(
      SQLHANDLE stmtHandle, // Statement handle.
      Uint16 columnNumber, // Column number to describe (1-based).
      Pointer<Utf16> columnNamePtr, // Buffer for the column name.
      Int16 nameBufferLength, // Length of columnNamePtr buffer.
      Pointer<Int16>
      nameLengthPtr, // Pointer to return the actual length of the column name.
      Pointer<Int16>
      dataTypePtr, // Pointer to store the SQL data type of the column (e.g., SQL_VARCHAR).
      Pointer<Int32>
      columnSizePtr, // Pointer to store the size (precision) of the column.
      Pointer<Int16>
      decimalDigitsPtr, // Pointer to store the scale of the column (digits after decimal).
      Pointer<Int16>
      nullablePtr, // Pointer to store nullability (e.g., SQL_NO_NULLS, SQL_NULLABLE).
    );

/// Dart signature for SQLDescribeColW.
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

/// Native signature for SQLGetData.
/// Retrieves data for a single column in the current row of the result set.
/// Typically called after SQLFetch.
typedef SQLGetDataNative =
    SQLRETURN Function(
      SQLHANDLE stmt, // Statement handle.
      Uint16 colNumber, // Column number to retrieve data from (1-based).
      Uint16
      targetType, // The C data type to convert the column data to (e.g., SQL_C_CHAR, SQL_C_SLONG).
      Pointer<Void>
      targetValue, // Pointer to the buffer to store the retrieved data.
      Int64 bufferLength, // Length of the targetValue buffer in bytes.
      Pointer<Int64>
      strLenOrIndPtr, // Pointer to store the length of the data or an indicator (e.g., SQL_NULL_DATA).
    );

/// Dart signature for SQLGetData.
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
// ODBC Constants (lowerCamelCase for Dart style)
// These constants are defined by the ODBC specification.
//----------------------------------------------------------------------------

// ---- General Return Codes ----
const int sqlSuccess = 0; // Function completed successfully.
const int sqlSuccessWithInfo =
    1; // Function completed successfully, but with non-fatal information.
const int sqlNoData = 100; // No more data was available (e.g., after SQLFetch).
const int sqlError = -1; // Function failed. Call SQLGetDiagRec for more info.
const int sqlInvalidHandle = -2; // Handle passed to the function was invalid.

// ---- Handle Types for SQLAllocHandle and SQLFreeHandle ----
const int sqlHandleTypeEnv = 1; // Environment handle type.
const int sqlHandleTypeDbc = 2; // Connection handle type.
const int sqlHandleTypeStmt = 3; // Statement handle type.
// const int SQL_HANDLE_DESC = 4;     // Descriptor handle type (not used in this example).

// ---- Environment Attributes for SQLSetEnvAttr ----
const int sqlAttrOdbcVersion =
    200; // Attribute to set the ODBC behavior version.
const int sqlOdbcVersion3 =
    3; // Value for sqlAttrOdbcVersion to indicate ODBC 3.x behavior.

// ---- Options for SQLFreeStmt ----
const int sqlFreeStmtClose =
    0; // Closes the cursor associated with the statement handle.
// Other options include SQL_DROP (1), SQL_UNBIND (2), SQL_RESET_PARAMS (3).

// ---- Driver Completion Options for SQLDriverConnect ----
const int sqlDriverNoprompt =
    0; // Driver should not prompt the user for connection info.
const int sqlDriverComplete =
    1; // Driver may prompt if not enough info; completes if possible.

// ---- Special Length/Indicator Values ----
const int sqlNts =
    -3; // Indicates a Null-Terminated String for input string length parameters.
const int sqlNullData =
    -1; // Value for strLenOrIndPtr (SQLGetData) indicating the data is NULL.
const int sqlDataAtExec = -2; // For SQLParamData/SQLPutData operations.
const int sqlNoTotal =
    -4; // For SQLGetData when retrieving LOBs, indicates total length is unknown.

// ---- C Data Types for SQLGetData (targetType parameter) - sql*C*DataType ----
// These specify the desired C data type for the retrieved data.
const int sqlcDataTypeChar = 1; // ANSI character string (char*).
const int sqlcDataTypeWchar =
    -8; // Unicode character string (wchar_t* / UTF-16).
const int sqlcDataTypeSlong = 4; // Signed long integer (32-bit).
const int sqlcDataTypeDouble = 8; // Double-precision floating-point number.
const int sqlcDataTypeBit = -7; // Single bit value (typically 0 or 1).
const int sqlcDataTypeDefault =
    99; // Driver uses default C type for the SQL type.
const int sqlcDataTypeNumeric =
    2; // For SQL_NUMERIC/SQL_DECIMAL (maps to SQL_NUMERIC_STRUCT).
const int sqlcDataTypeDate =
    9; // Date struct (SQL_DATE_STRUCT or tagDATE_STRUCT).
const int sqlcDataTypeTime =
    10; // Time struct (SQL_TIME_STRUCT or tagTIME_STRUCT).
const int sqlcDataTypeTimestamp =
    11; // Timestamp struct (SQL_TIMESTAMP_STRUCT or tagTIMESTAMP_STRUCT).

// ---- ODBC SQL Data Type Indicators (returned by SQLDescribeCol's dataTypePtr) - sqlDataType ----
// These specify the SQL data type of a column in the database.
const int sqlDataTypeChar = 1; // Fixed-length character string.
const int sqlDataTypeVarchar = 12; // Variable-length character string.
const int sqlDataTypeLongvarchar =
    -1; // Variable-length character string (long).
const int sqlDataTypeWchar =
    -8; // Fixed-length Unicode character string (UTF-16).
const int sqlDataTypeWvarchar =
    -9; // Variable-length Unicode character string (UTF-16).
const int sqlDataTypeWlongvarchar =
    -10; // Variable-length Unicode character string (long, UTF-16).
const int sqlDataTypeDecimal =
    3; // Signed, exact numeric value with a fixed precision and scale.
const int sqlDataTypeNumeric = 2; // Signed, exact numeric value.
const int sqlDataTypeSmallint =
    5; // Exact numeric value with precision 5 and scale 0 (signed 16-bit).
const int sqlDataTypeInteger =
    4; // Exact numeric value with precision 10 and scale 0 (signed 32-bit).
const int sqlDataTypeReal =
    7; // Signed, approximate numeric value with a binary precision of 24 (float).
const int sqlDataTypeFloat =
    6; // Signed, approximate numeric value with a binary precision of 53 (double).
const int sqlDataTypeDouble =
    8; // Signed, approximate numeric value (double precision).
const int sqlDataTypeBit = -7; // Single bit binary data.
const int sqlDataTypeDate =
    91; // Date (year, month, day). (SQL_TYPE_DATE in ODBC 3.x)
const int sqlDataTypeTime =
    92; // Time (hour, minute, second). (SQL_TYPE_TIME in ODBC 3.x)
const int sqlDataTypeTimestamp =
    93; // Timestamp (year, month, day, hour, minute, second, fraction). (SQL_TYPE_TIMESTAMP in ODBC 3.x)

/// Represents metadata for a single column in a result set.
/// This class is used to store information about a column, such as its name
/// and SQL data type, typically obtained from `SQLDescribeColW`.
class OdbcColumnMeta {
  /// The name of the column as returned by the database.
  final String name;

  /// The SQL data type of the column (e.g., `sqlDataTypeInteger`, `sqlDataTypeVarchar`).
  /// This value corresponds to one of the `sqlDataType*` constants.
  final int sqlDataType;

  /// Creates an instance of [OdbcColumnMeta].
  ///
  /// [name] is the column's name.
  /// [sqlDataType] is the ODBC SQL data type code for the column.
  OdbcColumnMeta({required this.name, required this.sqlDataType});
}
