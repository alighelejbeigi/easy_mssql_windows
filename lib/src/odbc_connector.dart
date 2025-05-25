import 'dart:ffi'; // Provides FFI (Foreign Function Interface) capabilities.
import 'package:ffi/ffi.dart'; // Provides FFI utility functions like calloc and Utf16 extensions.
import 'package:flutter/foundation.dart'; // Used for kDebugMode to conditionally print warnings.

// 'part' directives are used to include other Dart files as part of this library.
// This allows splitting a single library across multiple files.
part 'odbc_bindings.dart'; // Contains FFI typedefs, ODBC constants, and OdbcColumnMeta.
part 'odbc_raw_api.dart'; // Contains the _OdbcRawApi class for loading ODBC functions.
part 'odbc_statement_executor.dart'; // Contains _OdbcStatementExecutor for query execution logic.

/// Manages the lifecycle of an ODBC connection and facilitates query execution.
///
/// This class is the primary entry point for interacting with an ODBC data source.
/// It handles:
/// - Establishing and terminating connections.
/// - Allocating and freeing necessary ODBC handles (Environment, Connection, Statement).
/// - Delegating query execution and result fetching to a statement executor.
class OdbcConnector {
  /// Provides access to the loaded ODBC functions (e.g., SQLAllocHandle, SQLExecDirectW).
  final _OdbcRawApi _api;

  /// Helper class responsible for executing SQL queries and processing results.
  late final _OdbcStatementExecutor _statementExecutor;

  // --- ODBC Handles ---
  // These handles are pointers to internal ODBC structures managed by the driver.
  // They must be allocated and freed in a specific order.

  /// The ODBC Environment Handle (HENV).
  /// This is the top-level handle and must be allocated first.
  SQLHANDLE? _envHandle;

  /// The ODBC Connection Handle (HDBC).
  /// Represents a connection to a specific data source. Allocated on an environment handle.
  SQLHANDLE? _dbcHandle;

  /// The ODBC Statement Handle (HSTMT).
  /// Used to execute SQL statements and process results. Allocated on a connection handle.
  SQLHANDLE? _stmtHandle;

  /// Creates an instance of [OdbcConnector].
  ///
  /// Initializes the raw ODBC API by loading functions from the specified ODBC driver manager library.
  /// It also initializes the statement executor.
  ///
  /// [odbcLibName]: The name or path of the ODBC driver manager library.
  ///                Defaults to 'odbc32.dll' for Windows. For other platforms (Linux/macOS),
  ///                this would typically be 'libodbc.so' or 'libiodbc.dylib', respectively,
  ///                or a specific driver manager library path.
  OdbcConnector({String odbcLibName = 'odbc32.dll'})
    : _api = _OdbcRawApi(odbcLibName: odbcLibName) {
    // Initialize the raw API loader.
    _statementExecutor = _OdbcStatementExecutor(
      _api,
    ); // Initialize the statement executor, passing the API.
  }

  /// Checks the return code from an ODBC function call.
  ///
  /// Throws an [Exception] if the `code` is not among the `successCodes`.
  /// This is a common utility to reduce boilerplate error checking after FFI calls.
  ///
  /// [code]: The return code from the ODBC function.
  /// [functionName]: The name of the ODBC function called, used for error messages.
  /// [successCodes]: A list of codes considered successful (defaults to `sqlSuccess` and `sqlSuccessWithInfo`).
  void _checkReturnCode(
    int code,
    String functionName, {
    List<int> successCodes = const [sqlSuccess, sqlSuccessWithInfo],
  }) {
    if (!successCodes.contains(code)) {
      // In a production library, you might want to call SQLGetDiagRec here
      // to get more detailed error information from the ODBC driver.
      throw Exception('❌ ODBC Error: $functionName failed with code $code.');
    }
  }

  /// Establishes a connection to an ODBC data source.
  ///
  /// This method performs the standard ODBC connection sequence:
  /// 1. Allocates an environment handle.
  /// 2. Sets the ODBC version for the environment.
  /// 3. Allocates a connection handle.
  /// 4. Connects to the data source using `SQLDriverConnectW`.
  /// 5. Allocates a statement handle for future queries.
  ///
  /// [connectionString]: The ODBC connection string (e.g., "DRIVER={SQL Server};SERVER=...").
  /// Returns a [Future] that completes with a success message string.
  /// Throws an [Exception] if any step in the connection process fails.
  Future<String> connect(String connectionString) async {
    // --- 1. Allocate Environment Handle (HENV) ---
    // The environment handle is the parent handle for all other ODBC operations.
    final envOut =
        calloc<SQLHANDLE>(); // Allocate memory for the output handle pointer.
    try {
      _checkReturnCode(
        _api.sqlAllocHandle(sqlHandleTypeEnv, nullptr, envOut),
        // `nullptr` as input handle for ENV.
        'SQLAllocHandle (ENV)',
      );
      _envHandle = envOut.value; // Retrieve the actual handle value.
    } finally {
      calloc.free(
        envOut,
      ); // Free the memory allocated for the pointer, not the handle itself.
    }

    // --- 2. Set ODBC API Version for the Environment ---
    // This tells the driver manager which version of ODBC behavior to expect.
    // SQL_OV_ODBC3 specifies ODBC 3.x behavior.
    try {
      _checkReturnCode(
        _api.sqlSetEnvAttr(
          _envHandle!, // The environment handle to configure.
          sqlAttrOdbcVersion, // The attribute to set: ODBC version.
          Pointer.fromAddress(sqlOdbcVersion3),
          // The value for the attribute (SQL_OV_ODBC3).
          // Passed as a pointer-sized integer.
          0, // For integer attributes like this, the stringLength is 0 or SQL_IS_INTEGER.
        ),
        'SQLSetEnvAttr (ODBC_VERSION)',
      );
    } catch (e) {
      disconnect(); // Attempt to clean up any allocated handles if this step fails.
      rethrow; // Re-throw the exception to the caller.
    }

    // --- 3. Allocate Connection Handle (HDBC) ---
    // The connection handle is allocated on the environment handle.
    final dbcOut = calloc<SQLHANDLE>();
    try {
      _checkReturnCode(
        _api.sqlAllocHandle(sqlHandleTypeDbc, _envHandle!, dbcOut),
        // ENV handle is the input context.
        'SQLAllocHandle (DBC)',
      );
      _dbcHandle = dbcOut.value;
    } catch (e) {
      disconnect();
      rethrow;
    } finally {
      calloc.free(dbcOut);
    }

    // --- 4. Connect to the Data Source using SQLDriverConnectW ---
    // SQLDriverConnectW allows connecting with a connection string and can optionally prompt the user.
    final connPtr =
        connectionString
            .toNativeUtf16(); // Convert Dart string to a native UTF-16 string.
    final outBuf =
        calloc<Uint16>(512)
            .cast<
              Utf16
            >(); // Buffer for the driver to return the completed connection string.
    final outLenPtr =
        calloc<
          Int16
        >(); // Pointer to store the length of the completed connection string.

    try {
      final ret = _api.sqlDriverConnectW(
        _dbcHandle!,
        0,
        // Window handle (hWnd): 0 for no driver-specific dialog.
        connPtr,
        // Input connection string.
        sqlNts,
        // Indicates connPtr is a Null-Terminated String.
        outBuf,
        // Output buffer for the completed connection string.
        512,
        // Size of outBuf in characters.
        outLenPtr,
        // Pointer to return the length of the string in outBuf.
        sqlDriverComplete, // Driver completion option: complete if possible, may prompt if needed (if hWnd provided).
      );
      _checkReturnCode(ret, 'SQLDriverConnectW');
    } catch (e) {
      disconnect();
      rethrow;
    } finally {
      calloc.free(connPtr); // Free the native UTF-16 string.
      calloc.free(outBuf); // Free the output buffer.
      calloc.free(outLenPtr); // Free the pointer for the output length.
    }

    // --- 5. Allocate Statement Handle (HSTMT) ---
    // The statement handle is allocated on the connection handle and used for executing SQL statements.
    final stmtOut = calloc<SQLHANDLE>();
    try {
      _checkReturnCode(
        _api.sqlAllocHandle(sqlHandleTypeStmt, _dbcHandle!, stmtOut),
        // DBC handle is the input context.
        'SQLAllocHandle (STMT)',
      );
      _stmtHandle = stmtOut.value;
    } catch (e) {
      disconnect();
      rethrow;
    } finally {
      calloc.free(stmtOut);
    }

    return 'Successfully connected to ODBC data source.';
  }

  /// Disconnects from the data source and frees all allocated ODBC handles.
  ///
  /// This method attempts to:
  /// 1. Close any open cursor and free the statement handle.
  /// 2. Disconnect from the data source using `SQLDisconnect`.
  /// 3. Free the connection handle.
  /// 4. Free the environment handle.
  ///
  /// Returns `true` if all deallocation operations for existing handles
  /// that were attempted completed with `sqlSuccess` or `sqlSuccessWithInfo`.
  /// Returns `false` if any of these operations failed.
  /// It attempts all cleanup steps even if one fails.
  bool disconnect() {
    bool allOperationsSuccessful = true;
    final bool inDebugMode =
        kDebugMode; // Cache kDebugMode check for minor efficiency.

    // --- 1. Free Statement Handle ---
    if (_stmtHandle != null) {
      // Close any open cursor on the statement handle before freeing it.
      int freeStmtRet = _api.sqlFreeStmt(_stmtHandle!, sqlFreeStmtClose);
      if (freeStmtRet != sqlSuccess && freeStmtRet != sqlSuccessWithInfo) {
        allOperationsSuccessful = false;
        if (kDebugMode) {
          print(
            'ODBC Warning: SQLFreeStmt (SQL_CLOSE) failed with code $freeStmtRet for STMT handle.',
          );
        }
      }

      // Free the statement handle itself.
      int freeStmtHandleRet = _api.sqlFreeHandle(
        sqlHandleTypeStmt,
        _stmtHandle!,
      );
      if (freeStmtHandleRet != sqlSuccess &&
          freeStmtHandleRet != sqlSuccessWithInfo) {
        allOperationsSuccessful = false;
        if (kDebugMode) {
          print(
            'ODBC Warning: SQLFreeHandle for STMT handle failed with code $freeStmtHandleRet.',
          );
        }
      }
      _stmtHandle = null; // Mark as freed.
    }

    // --- 2. Disconnect and Free Connection Handle (DBC) ---
    if (_dbcHandle != null) {
      // Terminate the connection to the data source.
      int disconnectRet = _api.sqlDisconnect(
        _dbcHandle!,
      ); // Assumes sqlDisconnect is available in _api.
      if (disconnectRet != sqlSuccess && disconnectRet != sqlSuccessWithInfo) {
        allOperationsSuccessful = false;
        if (kDebugMode) {
          print('ODBC Warning: SQLDisconnect failed with code $disconnectRet.');
        }
        // Even if SQLDisconnect fails, an attempt is still made to free the handle.
      }

      // Free the connection handle.
      int freeDbcHandleRet = _api.sqlFreeHandle(sqlHandleTypeDbc, _dbcHandle!);
      if (freeDbcHandleRet != sqlSuccess &&
          freeDbcHandleRet != sqlSuccessWithInfo) {
        allOperationsSuccessful = false;
        if (kDebugMode) {
          print(
            'ODBC Warning: SQLFreeHandle for DBC handle failed with code $freeDbcHandleRet.',
          );
        }
      }
      _dbcHandle = null; // Mark as freed.
    }

    // --- 3. Free Environment Handle ---
    if (_envHandle != null) {
      // Free the environment handle. This should be the last handle freed.
      int freeEnvHandleRet = _api.sqlFreeHandle(sqlHandleTypeEnv, _envHandle!);
      if (freeEnvHandleRet != sqlSuccess &&
          freeEnvHandleRet != sqlSuccessWithInfo) {
        allOperationsSuccessful = false;
        if (kDebugMode) {
          print(
            'ODBC Warning: SQLFreeHandle for ENV handle failed with code $freeEnvHandleRet.',
          );
        }
      }
      _envHandle = null; // Mark as freed.
    }

    return allOperationsSuccessful;
  }

  /// Executes a SELECT SQL query and returns the results as a list of maps.
  /// Each map represents a row, with column names as keys and cell values as values.
  ///
  /// [sqlQuery]: The SQL query string to execute.
  /// Returns a [Future] that completes with a list of `Map<String, dynamic>`.
  /// Throws an [Exception] if the statement handle is not allocated (i.e., not connected)
  /// or if any ODBC error occurs during query execution or data fetching.
  Future<List<Map<String, dynamic>>> executeQuery(String sqlQuery) async {
    // Ensure there's an allocated statement handle to use.
    if (_stmtHandle == null) {
      throw Exception(
        'Cannot execute query: Statement handle is not allocated. Ensure connect() was called successfully.',
      );
    }

    // Delegate the actual query execution and result processing to the _statementExecutor.
    // This keeps OdbcConnector focused on connection management and handle lifecycle.
    return _statementExecutor.executeQuery(
      _stmtHandle!, // Pass the active statement handle.
      sqlQuery, // The SQL query to execute.
      _checkReturnCode, // Pass the utility method for checking ODBC return codes.
    );
  }
}
