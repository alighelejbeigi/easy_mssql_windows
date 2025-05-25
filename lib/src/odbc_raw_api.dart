// This file is part of the ODBC connector library.
// It defines the _OdbcRawApi class, which is responsible for loading the
// native ODBC library and resolving pointers to the ODBC functions.
part of 'odbc_connector.dart'; // Indicates this file is a part of the 'odbc_connector.dart' library,
// allowing access to other parts of the library, including typedefs
// from 'odbc_bindings.dart' without direct import if they are also parts.

/// A private helper class responsible for loading the specified ODBC dynamic library
/// and looking up the FFI (Foreign Function Interface) function pointers for various
/// ODBC API calls.
///
/// This class encapsulates the direct interaction with the native library, providing
/// type-safe Dart functions that correspond to the native ODBC functions.
/// The leading underscore indicates that this class is intended for internal use
/// within the 'odbc_connector.dart' library.
class _OdbcRawApi {
  /// Holds the instance of the loaded native ODBC dynamic library.
  /// All ODBC function calls will be made through this library instance.
  final DynamicLibrary _odbc;

  // --- Dart representations of ODBC function pointers ---
  // These are late-initialized final fields that will hold the Dart functions
  // corresponding to the native ODBC C functions after they are looked up.

  /// Dart FFI binding for the `SQLAllocHandle` ODBC function.
  /// Used to allocate ODBC handles (environment, connection, statement, descriptor).
  late final SQLAllocHandleDart sqlAllocHandle;

  /// Dart FFI binding for the `SQLSetEnvAttr` ODBC function.
  /// Used to set environment attributes, such as the ODBC version.
  late final SQLSetEnvAttrDart sqlSetEnvAttr;

  /// Dart FFI binding for the `SQLDriverConnectW` ODBC function (Unicode version).
  /// Used to establish a connection to a data source using a connection string.
  late final SQLDriverConnectWDart sqlDriverConnectW;

  /// Dart FFI binding for the `SQLExecDirectW` ODBC function (Unicode version).
  /// Used to execute an SQL statement directly.
  late final SQLExecDirectWDart sqlExecDirectW;

  /// Dart FFI binding for the `SQLFetch` ODBC function.
  /// Used to fetch the next row of data from a result set.
  late final SQLFetchDart sqlFetch;

  /// Dart FFI binding for the `SQLGetData` ODBC function.
  /// Used to retrieve data for a single column from the current row of a result set.
  late final SQLGetDataDart sqlGetData;

  /// Dart FFI binding for the `SQLFreeHandle` ODBC function.
  /// Used to free an ODBC handle and release its associated resources.
  late final SQLFreeHandleDart sqlFreeHandle;

  /// Dart FFI binding for the `SQLNumResultCols` ODBC function.
  /// Used to get the number of columns in a result set.
  late final SQLNumResultColsDart sqlNumResultCols;

  /// Dart FFI binding for the `SQLDescribeColW` ODBC function (Unicode version).
  /// Used to get metadata (name, type, size, etc.) for a specific column in a result set.
  late final SQLDescribeColWDart sqlDescribeColW;

  /// Dart FFI binding for the `SQLFreeStmt` ODBC function.
  /// Used to stop processing on a statement, close cursors, or reset parameters.
  late final SQLFreeStmtDart sqlFreeStmt;

  /// Dart FFI binding for the `SQLDisconnect` ODBC function.
  /// Used to close a connection to a data source.
  late final SQLDisconnectDart sqlDisconnect;

  /// Constructor for `_OdbcRawApi`.
  ///
  /// Attempts to open the specified ODBC dynamic library and then looks up
  /// pointers to the required ODBC functions within that library.
  ///
  /// [odbcLibName]: The name or path of the ODBC driver manager library
  ///                (e.g., 'odbc32.dll' on Windows, 'libodbc.so' on Linux).
  /// Throws an [Exception] if the library cannot be opened or if any of the
  /// required ODBC functions cannot be found within the library.
  _OdbcRawApi({required String odbcLibName})
    : _odbc = DynamicLibrary.open(odbcLibName) {
    // Attempt to open the native ODBC library.
    try {
      // Look up each required ODBC function by its name in the loaded library.
      // The `lookupFunction` method takes the native signature (e.g., SQLAllocHandleNative)
      // and the Dart signature (e.g., SQLAllocHandleDart) to create a type-safe Dart callable.

      sqlAllocHandle = _odbc
          .lookupFunction<SQLAllocHandleNative, SQLAllocHandleDart>(
            'SQLAllocHandle', // Name of the function in the C library.
          );

      sqlSetEnvAttr = _odbc
          .lookupFunction<SQLSetEnvAttrNative, SQLSetEnvAttrDart>(
            'SQLSetEnvAttr',
          );

      sqlDriverConnectW = _odbc
          .lookupFunction<SQLDriverConnectWNative, SQLDriverConnectWDart>(
            'SQLDriverConnectW', // Using the Unicode version.
          );

      sqlExecDirectW = _odbc
          .lookupFunction<SQLExecDirectWNative, SQLExecDirectWDart>(
            'SQLExecDirectW', // Using the Unicode version.
          );

      sqlFetch = _odbc.lookupFunction<SQLFetchNative, SQLFetchDart>('SQLFetch');

      sqlGetData = _odbc.lookupFunction<SQLGetDataNative, SQLGetDataDart>(
        'SQLGetData',
      );

      sqlFreeHandle = _odbc
          .lookupFunction<SQLFreeHandleNative, SQLFreeHandleDart>(
            'SQLFreeHandle',
          );

      sqlNumResultCols = _odbc
          .lookupFunction<SQLNumResultColsNative, SQLNumResultColsDart>(
            'SQLNumResultCols',
          );

      sqlDescribeColW = _odbc
          .lookupFunction<SQLDescribeColWNative, SQLDescribeColWDart>(
            'SQLDescribeColW', // Using the Unicode version.
          );

      sqlFreeStmt = _odbc.lookupFunction<SQLFreeStmtNative, SQLFreeStmtDart>(
        'SQLFreeStmt',
      );

      sqlDisconnect = _odbc
          .lookupFunction<SQLDisconnectNative, SQLDisconnectDart>(
            'SQLDisconnect',
          );
    } catch (e) {
      // If DynamicLibrary.open or any lookupFunction fails, an exception is caught.
      // Consider how to handle library/function loading errors more gracefully
      // or provide more specific error types for consumers of the OdbcConnector.
      // For now, re-throw a generic exception with details.
      throw Exception(
        'Failed to lookup one or more ODBC functions in library "$odbcLibName". Ensure the library is correct and contains all required ODBC V3 functions. Original error: $e',
      );
    }
  }
}
