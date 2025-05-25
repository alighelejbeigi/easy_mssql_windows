import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart'; // If kDebugMode is still used

// Use 'part' and 'part of' for tight coupling if these files are conceptually one library unit
// Or use direct imports if they are more independent.
part 'odbc_bindings.dart';

part 'odbc_raw_api.dart';

// If odbc_extensions.dart also uses 'part of', include it:
// part 'odbc_extensions.dart';

// Or, if using separate files with imports:
// import 'odbc_bindings.dart';
// import 'odbc_raw_api.dart';

/// Manages ODBC connections and operations.
class OdbcConnector {
  final _OdbcRawApi _api;

  // ODBC Handles
  SQLHANDLE? _envHandle;
  SQLHANDLE? _dbcHandle;
  SQLHANDLE? _stmtHandle;

  /// Creates an OdbcConnector.
  ///
  /// [odbcLibName]: The name or path of the ODBC driver manager library
  /// (e.g., 'odbc32.dll' on Windows).
  OdbcConnector({String odbcLibName = 'odbc32.dll'})
    : _api = _OdbcRawApi(odbcLibName: odbcLibName);

  void _checkReturnCode(
    int code,
    String functionName, {
    List<int> successCodes = const [sqlSuccess, sqlSuccessWithInfo],
  }) {
    if (!successCodes.contains(code)) {
      throw Exception('❌ ODBC Error: $functionName failed with code $code.');
    }
  }

  /// Establishes a connection to an ODBC data source.
  Future<String> connect(String connectionString) async {
    // 1. Allocate Environment Handle
    final envOut = calloc<SQLHANDLE>();
    try {
      _checkReturnCode(
        _api.sqlAllocHandle(sqlHandleTypeEnv, nullptr, envOut),
        'SQLAllocHandle (ENV)',
      );
      _envHandle = envOut.value;
    } finally {
      calloc.free(envOut);
    }

    // 2. Set ODBC Version
    try {
      _checkReturnCode(
        _api.sqlSetEnvAttr(
          _envHandle!,
          sqlAttrOdbcVersion,
          Pointer.fromAddress(sqlOdbcVersion3),
          // Value passed directly as a pointer-sized integer
          0, // For integer attributes like SQL_ATTR_ODBC_VERSION with SQL_OV_ODBC3, this is SQL_IS_INTEGER or 0
        ),
        'SQLSetEnvAttr (ODBC_VERSION)',
      );
    } catch (e) {
      disconnect(); // Clean up if this step fails
      rethrow;
    }

    // 3. Allocate Connection Handle
    final dbcOut = calloc<SQLHANDLE>();
    try {
      _checkReturnCode(
        _api.sqlAllocHandle(sqlHandleTypeDbc, _envHandle!, dbcOut),
        'SQLAllocHandle (DBC)',
      );
      _dbcHandle = dbcOut.value;
    } catch (e) {
      disconnect();
      rethrow;
    } finally {
      calloc.free(dbcOut);
    }

    // 4. Connect to the Driver
    final connPtr = connectionString.toNativeUtf16();
    final outBuf =
        calloc<Uint16>(
          512,
        ).cast<Utf16>(); // Buffer for output connection string
    final outLenPtr = calloc<Int16>(); // Pointer for length of output string

    try {
      final ret = _api.sqlDriverConnectW(
        _dbcHandle!,
        0,
        // Window handle (hWnd = 0 for no dialog)
        connPtr,
        sqlNts,
        // Input connection string is null-terminated
        outBuf,
        512,
        // Max length of output buffer in characters
        outLenPtr,
        sqlDriverComplete, // Driver completion option
      );
      _checkReturnCode(ret, 'SQLDriverConnectW');
      // Optionally, you can read the completed connection string:
      // String completedConnectionString = outBuf.toDartString(length: outLenPtr.value);
      // print("Completed connection string: $completedConnectionString");
    } catch (e) {
      disconnect();
      rethrow;
    } finally {
      calloc.free(connPtr);
      calloc.free(outBuf);
      calloc.free(outLenPtr);
    }

    // 5. Allocate Statement Handle
    final stmtOut = calloc<SQLHANDLE>();
    try {
      _checkReturnCode(
        _api.sqlAllocHandle(sqlHandleTypeStmt, _dbcHandle!, stmtOut),
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

  /// Disconnects from the data source and frees all allocated handles.
  /// Disconnects from the data source and frees all allocated handles.
  ///
  /// Returns `true` if all deallocation operations for existing handles
  /// completed successfully, `false` otherwise.
  bool disconnect() {
    bool allOperationsSuccessful = true;
    final bool inDebugMode = kDebugMode; // Check once

    // 1. Free Statement Handle
    if (_stmtHandle != null) {
      int freeStmtRet = _api.sqlFreeStmt(_stmtHandle!, sqlFreeStmtClose);
      if (freeStmtRet != sqlSuccess && freeStmtRet != sqlSuccessWithInfo) {
        allOperationsSuccessful = false;
        if (inDebugMode) {
          if (kDebugMode) {
            print(
              'ODBC Warning: SQLFreeStmt (SQL_CLOSE) failed with code $freeStmtRet for STMT handle.',
            );
          }
        }
      }

      int freeStmtHandleRet = _api.sqlFreeHandle(
        sqlHandleTypeStmt,
        _stmtHandle!,
      );
      if (freeStmtHandleRet != sqlSuccess &&
          freeStmtHandleRet != sqlSuccessWithInfo) {
        allOperationsSuccessful = false;
        if (inDebugMode) {
          if (kDebugMode) {
            print(
              'ODBC Warning: SQLFreeHandle for STMT handle failed with code $freeStmtHandleRet.',
            );
          }
        }
      }
      _stmtHandle = null;
    }

    // 2. Disconnect and Free Connection Handle (DBC)
    if (_dbcHandle != null) {
      // Call SQLDisconnect first
      int disconnectRet = _api.sqlDisconnect(_dbcHandle!);
      if (disconnectRet != sqlSuccess && disconnectRet != sqlSuccessWithInfo) {
        allOperationsSuccessful = false;
        if (inDebugMode) {
          if (kDebugMode) {
            print(
              'ODBC Warning: SQLDisconnect failed with code $disconnectRet.',
            );
          }
        }
        // Even if SQLDisconnect fails, we still attempt to free the handle
        // as per general cleanup best practices, though it might also fail.
      }

      int freeDbcHandleRet = _api.sqlFreeHandle(sqlHandleTypeDbc, _dbcHandle!);
      if (freeDbcHandleRet != sqlSuccess &&
          freeDbcHandleRet != sqlSuccessWithInfo) {
        allOperationsSuccessful = false;
        if (inDebugMode) {
          // This is the error you are currently seeing for DBC
          if (kDebugMode) {
            print(
              'ODBC Warning: SQLFreeHandle for DBC handle failed with code $freeDbcHandleRet.',
            );
          }
        }
      }
      _dbcHandle = null;
    }

    // 3. Free Environment Handle
    if (_envHandle != null) {
      int freeEnvHandleRet = _api.sqlFreeHandle(sqlHandleTypeEnv, _envHandle!);
      if (freeEnvHandleRet != sqlSuccess &&
          freeEnvHandleRet != sqlSuccessWithInfo) {
        allOperationsSuccessful = false;
        if (inDebugMode) {
          // This is the error you are currently seeing for ENV
          if (kDebugMode) {
            print(
              'ODBC Warning: SQLFreeHandle for ENV handle failed with code $freeEnvHandleRet.',
            );
          }
        }
      }
      _envHandle = null;
    }

    return allOperationsSuccessful;
  }

  /// Executes a SELECT query and returns the results as a list of maps.
  Future<List<Map<String, dynamic>>> executeQuery(String sqlQuery) async {
    if (_stmtHandle == null) {
      throw Exception(
        'Cannot execute query: Statement handle is not allocated. Ensure connect() was called successfully.',
      );
    }

    final sqlPtr = sqlQuery.toNativeUtf16();
    try {
      // 1. Execute the query
      _checkReturnCode(
        _api.sqlExecDirectW(_stmtHandle!, sqlPtr, sqlNts),
        // sqlNts indicates null-terminated string
        'SQLExecDirectW for query: "$sqlQuery"',
      );

      // 2. Get number of result columns
      final colCountPtr = calloc<Int16>();
      try {
        _checkReturnCode(
          _api.sqlNumResultCols(_stmtHandle!, colCountPtr),
          'SQLNumResultCols',
        );
        final numCols = colCountPtr.value;

        // If numCols is 0, it might be a non-SELECT statement or an empty result set metadata
        if (numCols <= 0) {
          // It's also possible for SQLExecDirectW to return SQL_NO_DATA for updates/deletes.
          // For SELECTs, SQL_NO_DATA from SQLFetch indicates an empty result set.
          // Here, numCols <= 0 means no columns were described by the query.
          return [];
        }

        // 3. Get column metadata
        final colMetadata =
            <OdbcColumnMeta>[]; // Using the renamed public class
        for (var i = 1; i <= numCols; i++) {
          // ODBC columns are 1-based
          final nameBuf =
              calloc<Uint16>(256).cast<Utf16>(); // Buffer for column name
          final nameLenPtr = calloc<Int16>();
          final typePtr = calloc<Int16>(); // SQL_XXX type
          final sizePtr = calloc<Int32>(); // Column size
          final decDigitsPtr = calloc<Int16>(); // Decimal digits
          final nullablePtr = calloc<Int16>(); // Nullability

          try {
            _checkReturnCode(
              _api.sqlDescribeColW(
                _stmtHandle!,
                i,
                // Column number (1-based)
                nameBuf,
                256,
                // Buffer length for name in characters
                nameLenPtr,
                typePtr,
                sizePtr,
                decDigitsPtr,
                nullablePtr,
              ),
              'SQLDescribeColW for column $i',
            );

            final colName = nameBuf.toDartString(length: nameLenPtr.value);
            colMetadata.add(
              OdbcColumnMeta(name: colName, sqlDataType: typePtr.value),
            );
          } finally {
            calloc.free(nameBuf);
            calloc.free(nameLenPtr);
            calloc.free(typePtr);
            calloc.free(sizePtr);
            calloc.free(decDigitsPtr);
            calloc.free(nullablePtr);
          }
        }

        // 4. Fetch rows and data
        final results = <Map<String, dynamic>>[];
        int fetchRet;
        while (true) {
          fetchRet = _api.sqlFetch(_stmtHandle!);
          if (fetchRet == sqlNoData) break; // No more rows
          _checkReturnCode(fetchRet, 'SQLFetch'); // Check for other errors

          final row = <String, dynamic>{};
          for (var i = 0; i < numCols; i++) {
            final meta = colMetadata[i];
            final colIndex = i + 1; // ODBC columns are 1-based
            row[meta.name] = _getDataForColumn(colIndex, meta.sqlDataType);
          }
          results.add(row);
        }
        return results;
      } finally {
        calloc.free(colCountPtr);
      }
    } finally {
      calloc.free(sqlPtr);
      // Close the cursor to allow the statement handle to be reused or freed properly.
      final closeRet = _api.sqlFreeStmt(_stmtHandle!, sqlFreeStmtClose);
      if (closeRet != sqlSuccess && closeRet != sqlSuccessWithInfo) {
        // This is usually not critical for the query result itself but indicates a cleanup issue.
        if (kDebugMode) {
          // Only print in debug mode
          print(
            'Warning: SQLFreeStmt(sqlFreeStmtClose) failed after query with code $closeRet.',
          );
        }
      }
    }
  }

  /// Internal helper to get data for a specific column based on its SQL type.
  dynamic _getDataForColumn(int columnIndex, int columnSqlDataType) {
    Pointer<Int64> strLenOrIndPtr = calloc<Int64>(); // For length or indicator
    try {
      // Helper closure to reduce boilerplate for SQLGetData calls
      dynamic readData(
        int cDataType, // SQL_C_XXX type
        int bufferSizeInBytes,
        Pointer<Void> buffer,
        // Converter function: takes buffer and actual length/indicator
        Function(Pointer<Void> buf, int lengthOrIndicator) converter,
      ) {
        final ret = _api.sqlGetData(
          _stmtHandle!,
          columnIndex,
          cDataType,
          buffer,
          bufferSizeInBytes,
          strLenOrIndPtr,
        );
        // SQL_NO_DATA is a valid success code here if all data was already fetched or for zero-length data.
        _checkReturnCode(
          ret,
          'SQLGetData for column $columnIndex (C Type: $cDataType)',
          successCodes: [sqlSuccess, sqlSuccessWithInfo, sqlNoData],
        );

        if (strLenOrIndPtr.value == sqlNullData) return null; // SQL_NULL_DATA

        // If SQLGetData returns SQL_NO_DATA, it means no more data for *this specific call*.
        // For fixed-size types, this shouldn't usually happen if strLenOrIndPtr isn't SQL_NULL_DATA.
        // For variable types, strLenOrIndPtr will contain the total length.
        // If strLenOrIndPtr.value is 0, it's an empty string/value.
        if (ret == sqlNoData && strLenOrIndPtr.value == 0) {
          return converter(buffer, 0); // e.g. empty string
        }

        return converter(buffer, strLenOrIndPtr.value);
      }

      switch (columnSqlDataType) {
        case sqlDataTypeChar:
        case sqlDataTypeVarchar:
        case sqlDataTypeLongvarchar:
        case sqlDataTypeWchar:
        case sqlDataTypeWvarchar:
        case sqlDataTypeWlongvarchar:
        // Dates/Times/Timestamps are often best fetched as strings for simplicity
        // unless you need to parse their native struct representations.
        case sqlDataTypeDate:
        case sqlDataTypeTime:
        case sqlDataTypeTimestamp:
          final bufferCharLength =
              1024; // Max characters to fetch for a string column
          final bufferByteLength = sizeOf<Uint16>() * bufferCharLength;
          final buffer = calloc<Uint16>(
            bufferCharLength,
          ); // Using Utf16 for WCHAR
          try {
            return readData(
              sqlcDataTypeWchar, // Target C type
              bufferByteLength,
              buffer.cast<Void>(),
              (buf, lenInBytes) {
                if (lenInBytes < 0) {
                  return null; // Should be caught by sqlNullData
                }
                // lenInBytes from SQLGetData for SQL_C_WCHAR is in bytes.
                return buf
                    .cast<Utf16>()
                    .toDartString(length: lenInBytes ~/ sizeOf<Uint16>())
                    .trim();
              },
            );
          } finally {
            calloc.free(buffer);
          }

        case sqlDataTypeBit:
          final buffer = calloc<Uint8>();
          try {
            return readData(
              sqlcDataTypeBit,
              sizeOf<Uint8>(),
              buffer.cast<Void>(),
              (buf, len) =>
                  buf.cast<Uint8>().value != 0, // Convert 0/1 to false/true
            );
          } finally {
            calloc.free(buffer);
          }

        case sqlDataTypeSmallint:
        case sqlDataTypeInteger:
          final buffer = calloc<Int32>(); // SQL_C_SLONG corresponds to Int32
          try {
            return readData(
              sqlcDataTypeSlong,
              sizeOf<Int32>(),
              buffer.cast<Void>(),
              (buf, len) => buf.cast<Int32>().value,
            );
          } finally {
            calloc.free(buffer);
          }

        case sqlDataTypeReal: // Typically a 32-bit float
        case sqlDataTypeFloat: // Can be 32-bit or 64-bit depending on driver/DB
        case sqlDataTypeDouble: // Typically a 64-bit float
        // NUMERIC and DECIMAL might lose precision if fetched as double.
        // Fetching as string (SQL_C_WCHAR) and then parsing with `decimal` package is safer for exact values.
        case sqlDataTypeNumeric:
        case sqlDataTypeDecimal:
          final buffer = calloc<Double>();
          try {
            return readData(
              sqlcDataTypeDouble,
              sizeOf<Double>(),
              buffer.cast<Void>(),
              (buf, len) => buf.cast<Double>().value,
            );
          } finally {
            calloc.free(buffer);
          }

        // To handle native DATE, TIME, TIMESTAMP structs:
        // case sqlDataTypeDate:
        //   final buffer = calloc<TagDateStruct>(); // Assuming you define TagDateStruct FFI mapping
        //   try {
        //     return readData(sqlcDataTypeDate, sizeOf<TagDateStruct>(), buffer.cast<Void>(),
        //       (buf, len) {
        //         final dateStruct = buf.cast<TagDateStruct>().ref;
        //         return DateTime(dateStruct.year, dateStruct.month, dateStruct.day);
        //       });
        //   } finally { calloc.free(buffer); }
        // Similar for TIME and TIMESTAMP using their respective C structs and SQL_C_TIME/SQL_C_TIMESTAMP.

        default:
          // Fallback for unknown or unhandled SQL types: attempt to read as string.
          if (kDebugMode) {
            print(
              'Warning: Unhandled SQL data type $columnSqlDataType for column $columnIndex. Attempting to read as string.',
            );
          }
          final bufferCharLength = 256; // Smaller buffer for unknown types
          final bufferByteLength = sizeOf<Uint16>() * bufferCharLength;
          final buffer = calloc<Uint16>(bufferCharLength);
          try {
            return readData(
              sqlcDataTypeWchar,
              bufferByteLength,
              buffer.cast<Void>(),
              (buf, lenInBytes) {
                if (lenInBytes < 0) return null;
                return buf
                    .cast<Utf16>()
                    .toDartString(length: lenInBytes ~/ sizeOf<Uint16>())
                    .trim();
              },
            );
          } finally {
            calloc.free(buffer);
          }
      }
    } finally {
      calloc.free(strLenOrIndPtr);
    }
  }
}
