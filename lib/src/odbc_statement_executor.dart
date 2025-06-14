// This file is part of the ODBC connector library.
// It defines the _OdbcStatementExecutor class, which is responsible for
// executing SQL statements and processing their results.
part of 'odbc_connector.dart'; // Indicates this file is part of the 'odbc_connector.dart' library.
// This allows it to access other library-private members if needed,
// and shares the same library namespace.

// Or, if using direct imports (less common for tightly coupled private classes):
// import 'dart:ffi';
// import 'package:ffi/ffi.dart';
// import 'package:flutter/foundation.dart'; // For kDebugMode, if used directly here.
// import 'odbc_bindings.dart'; // For SQLHANDLE, OdbcColumnMeta, constants, etc.
// import 'odbc_raw_api.dart';   // For _OdbcRawApi.

/// A private helper class responsible for executing SQL statements on a given ODBC statement handle (`HSTMT`)
/// and processing the results.
///
/// This class encapsulates the logic for:
/// - Executing SQL queries using `SQLExecDirectW`.
/// - Determining the structure of the result set (number of columns, metadata)
///   using `SQLNumResultCols` and `SQLDescribeColW`.
/// - Fetching rows from the result set using `SQLFetch`.
/// - Retrieving data for individual columns and converting it to appropriate Dart types
///   using `SQLGetData`.
///
/// The leading underscore indicates that this class is intended for internal use
/// within the 'odbc_connector.dart' library.
class _OdbcStatementExecutor {
  /// Provides access to the loaded ODBC functions (e.g., SQLExecDirectW, SQLGetData).
  /// This is typically injected from the main OdbcConnector.
  final _OdbcRawApi _api;

  /// Creates an instance of [_OdbcStatementExecutor].
  ///
  /// [_api]: An instance of [_OdbcRawApi] that provides the FFI function bindings
  ///         to the native ODBC library.
  _OdbcStatementExecutor(this._api);

  /// Executes a SELECT SQL query on the given statement handle and returns the
  /// results as a list of maps. Each map represents a row, with column names
  /// as keys and cell values as values.
  ///
  /// [stmtHandle]: The active ODBC Statement Handle (HSTMT) to use for execution.
  ///               It's assumed this handle has been properly allocated and is valid.
  /// [sqlQuery]: The SQL query string to execute.
  /// [checkReturnCode]: A callback function (usually from `OdbcConnector`) used to
  ///                    verify the return status of ODBC API calls and throw an
  ///                    exception on failure.
  ///
  /// Returns a [Future] that completes with a list of `Map<String, dynamic>` representing the query results.
  /// Throws an [Exception] if any ODBC error occurs during query execution or data fetching.
  Future<List<Map<String, dynamic>>> executeQuery(
    SQLHANDLE stmtHandle,
    String sqlQuery,
    void Function(int, String, {List<int> successCodes}) checkReturnCode,
  ) async {
    // Assumption: stmtHandle is valid and allocated by the caller (OdbcConnector).
    // The OdbcConnector should ensure stmtHandle is not null before calling this method.

    // Convert the Dart SQL query string to a native UTF-16 string for ODBC W-functions.
    final sqlPtr = sqlQuery.toNativeUtf16();
    try {
      // --- 1. Execute the SQL Query ---
      // SQLExecDirectW executes a preparable statement.
      checkReturnCode(
        _api.sqlExecDirectW(stmtHandle, sqlPtr, sqlNts),
        // sqlNts indicates a null-terminated string.
        'SQLExecDirectW for query: "$sqlQuery"',
      );

      // --- 2. Get the Number of Result Columns ---
      // This determines how many columns are in the result set generated by the query.
      final colCountPtr =
          calloc<Int16>(); // Allocate memory for the column count output.
      try {
        checkReturnCode(
          _api.sqlNumResultCols(stmtHandle, colCountPtr),
          'SQLNumResultCols',
        );
        final numCols = colCountPtr.value; // Get the actual number of columns.

        // If there are no columns, it might be a non-SELECT statement (e.g., UPDATE, INSERT)
        // that doesn't produce a result set, or a SELECT query that genuinely has no columns (rare).
        // For DML statements, SQLExecDirectW might return SQL_NO_DATA, which should be handled by checkReturnCode if not expected.
        if (numCols <= 0) {
          return []; // Return an empty list if no result columns.
        }

        // --- 3. Get Column Metadata ---
        // For each column in the result set, retrieve its name, data type, and other attributes.
        final colMetadata =
            <OdbcColumnMeta>[]; // List to store metadata for each column.
        for (var i = 1; i <= numCols; i++) {
          // ODBC column numbers are 1-based.
          // Allocate memory for output parameters of SQLDescribeColW.
          final nameBuf =
              calloc<Uint16>(
                256,
              ).cast<Utf16>(); // Buffer for column name (WCHARs).
          final nameLenPtr =
              calloc<Int16>(); // Pointer for actual length of column name.
          final typePtr =
              calloc<Int16>(); // Pointer for SQL data type of the column.
          final sizePtr = calloc<Int32>(); // Pointer for column size/precision.
          final decDigitsPtr =
              calloc<Int16>(); // Pointer for decimal digits (scale).
          final nullablePtr =
              calloc<Int16>(); // Pointer for nullability status.

          try {
            // SQLDescribeColW provides information about a single column in the result set.
            checkReturnCode(
              _api.sqlDescribeColW(
                stmtHandle,
                i,
                // Column number (1-based).
                nameBuf,
                // Buffer to receive column name.
                256,
                // Length of nameBuf in characters.
                nameLenPtr,
                // Output: actual length of column name.
                typePtr,
                // Output: SQL data type (e.g., SQL_VARCHAR).
                sizePtr,
                // Output: column size.
                decDigitsPtr,
                // Output: decimal digits.
                nullablePtr, // Output: nullability.
              ),
              'SQLDescribeColW for column $i',
            );

            // Convert the native column name to a Dart string.
            final colName = nameBuf.toDartString(length: nameLenPtr.value);
            // Store the retrieved metadata.
            colMetadata.add(
              OdbcColumnMeta(name: colName, sqlDataType: typePtr.value),
            );
          } finally {
            // Free all allocated memory for this iteration.
            calloc.free(nameBuf);
            calloc.free(nameLenPtr);
            calloc.free(typePtr);
            calloc.free(sizePtr);
            calloc.free(decDigitsPtr);
            calloc.free(nullablePtr);
          }
        }

        // --- 4. Fetch Rows and Data ---
        // Iterate through the result set row by row.
        final results =
            <Map<String, dynamic>>[]; // List to store all fetched rows.
        int fetchRet;
        while (true) {
          // SQLFetch advances the cursor to the next row and retrieves data for any bound columns.
          // Since we are using SQLGetData, data is retrieved explicitly after fetching.
          fetchRet = _api.sqlFetch(stmtHandle);

          if (fetchRet == sqlNoData) break; // No more rows to fetch.
          checkReturnCode(
            fetchRet,
            'SQLFetch',
          ); // Check for errors during fetch.

          final row =
              <String, dynamic>{}; // Map to store data for the current row.
          // For each column in the current row, get its data.
          for (var i = 0; i < numCols; i++) {
            final meta = colMetadata[i]; // Get metadata for the current column.
            final colIndex = i + 1; // ODBC column index is 1-based.
            // Retrieve and convert data for the current column.
            row[meta.name] = _getDataForColumn(
              stmtHandle,
              colIndex,
              meta.sqlDataType,
              checkReturnCode,
            );
          }
          results.add(row); // Add the populated row to the results list.
        }
        return results; // Return all fetched rows.
      } finally {
        calloc.free(colCountPtr); // Free memory for column count pointer.
      }
    } finally {
      calloc.free(sqlPtr); // Free memory for the native SQL string.

      // --- Reset Statement Handle State ---
      // After processing a query, it's crucial to reset the statement handle's state,
      // especially if the handle is to be reused for another query or properly freed.
      // SQLFreeStmt with SQL_CLOSE closes any open cursor and discards pending results,
      // making the statement handle available for re-execution or freeing.
      final closeRet = _api.sqlFreeStmt(stmtHandle, sqlFreeStmtClose);
      if (closeRet != sqlSuccess && closeRet != sqlSuccessWithInfo) {
        // This warning indicates a potential issue with resetting the statement,
        // which might affect subsequent operations or cleanup.
        if (kDebugMode) {
          // Only print warnings in debug mode.
          print(
            'ODBC Warning: SQLFreeStmt(sqlFreeStmtClose) failed after query with code $closeRet on statement handle.',
          );
        }
      }
    }
  }

  /// Internal helper method to retrieve and convert data for a single column
  /// from the current row of the result set.
  ///
  /// This method is called after `SQLFetch` has successfully positioned the cursor on a row.
  /// It uses `SQLGetData` to fetch the column's data and then converts it to an
  /// appropriate Dart type based on the column's SQL data type.
  ///
  /// [stmtHandle]: The active ODBC Statement Handle (HSTMT).
  /// [columnIndex]: The 1-based index of the column to retrieve data for.
  /// [columnSqlDataType]: The SQL data type of the column (e.g., `sqlDataTypeInteger`),
  ///                      obtained from `SQLDescribeColW`.
  /// [checkReturnCode]: A callback function to verify ODBC API call status.
  ///
  /// Returns the data for the specified column, converted to a Dart type, or `null` if the data is SQL NULL.
  dynamic _getDataForColumn(
    SQLHANDLE stmtHandle,
    int columnIndex,
    int columnSqlDataType,
    void Function(int, String, {List<int> successCodes}) checkReturnCode,
  ) {
    // Pointer to store the length of the retrieved data in bytes, or an indicator
    // value such as SQL_NULL_DATA if the column value is NULL.
    Pointer<Int64> strLenOrIndPtr = calloc<Int64>();
    try {
      // --- Local Helper Function: readData ---
      // This closure simplifies calling SQLGetData and handling its common logic.
      dynamic readData(
        int cDataType,
        // The target C data type (e.g., SQL_C_WCHAR, SQL_C_SLONG) to convert to.
        int bufferSizeInBytes, // The size of the `buffer` in bytes.
        Pointer<Void> buffer, // The memory buffer to receive the data.
        // A converter function that takes the native buffer and its actual length/indicator,
        // and returns the Dart representation of the data.
        Function(Pointer<Void> buf, int lengthOrIndicator) converter,
      ) {
        // SQLGetData retrieves data for a single column.
        final ret = _api.sqlGetData(
          stmtHandle,
          columnIndex,
          cDataType,
          buffer,
          bufferSizeInBytes,
          strLenOrIndPtr,
        );

        // SQL_NO_DATA can be a valid return if, for example, SQLGetData is called multiple times
        // for a large LOB value and all data has been retrieved. For simple types, if data fits,
        // it usually returns SQL_SUCCESS or SQL_SUCCESS_WITH_INFO.
        checkReturnCode(
          ret,
          'SQLGetData for column $columnIndex (C Type: $cDataType)',
          successCodes: [sqlSuccess, sqlSuccessWithInfo, sqlNoData],
        );

        // Check if the data value is SQL NULL.
        if (strLenOrIndPtr.value == sqlNullData) return null;

        // If SQLGetData returned SQL_NO_DATA but the indicator isn't SQL_NULL_DATA,
        // and length is 0, it might be an empty value (e.g., empty string).
        if (ret == sqlNoData && strLenOrIndPtr.value == 0) {
          return converter(buffer, 0); // Convert based on zero length.
        }

        // Convert the data using the provided converter function.
        return converter(buffer, strLenOrIndPtr.value);
      }

      // --- Type-Specific Data Retrieval ---
      // Determine how to fetch and convert data based on its SQL data type.
      switch (columnSqlDataType) {
        // Cases for various string types (ANSI and Unicode) and date/time types often fetched as strings.
        case sqlDataTypeChar:
        case sqlDataTypeVarchar:
        case sqlDataTypeLongvarchar:
        case sqlDataTypeWchar: // Typically UTF-16 on Windows.
        case sqlDataTypeWvarchar:
        case sqlDataTypeWlongvarchar:
        case sqlDataTypeDate: // Dates are often best fetched as strings for simplicity.
        case sqlDataTypeTime: // Times too.
        case sqlDataTypeTimestamp: // Timestamps too.
          final bufferCharLength =
              1024; // Max characters to fetch (can be adjusted).
          final bufferByteLength =
              sizeOf<Uint16>() * bufferCharLength; // Size in bytes for UTF-16.
          final buffer = calloc<Uint16>(
            bufferCharLength,
          ); // Allocate buffer for UTF-16 string.
          try {
            return readData(
              sqlcDataTypeWchar, // Target C type: wide character (UTF-16).
              bufferByteLength,
              buffer.cast<Void>(),
              (buf, lenInBytes) {
                // Converter function.
                if (lenInBytes < 0) {
                  return null; // Should be caught by sqlNullData check earlier.
                }
                // lenInBytes from SQLGetData for SQL_C_WCHAR is in bytes.
                // Divide by sizeOf<Uint16>() to get length in characters for toDartString.
                return buf
                    .cast<Utf16>()
                    .toDartString(length: lenInBytes ~/ sizeOf<Uint16>())
                    .trim(); // Trim whitespace.
              },
            );
          } finally {
            calloc.free(buffer); // Always free the allocated buffer.
          }

        case sqlDataTypeBit: // Boolean type.
          final buffer =
              calloc<Uint8>(); // Typically represented as a single byte.
          try {
            return readData(
              sqlcDataTypeBit, // Target C type: bit.
              sizeOf<Uint8>(),
              buffer.cast<Void>(),
              (buf, len) =>
                  buf.cast<Uint8>().value !=
                  0, // Convert 0 to false, non-zero to true.
            );
          } finally {
            calloc.free(buffer);
          }

        case sqlDataTypeSmallint: // 16-bit integer.
        case sqlDataTypeInteger: // 32-bit integer.
          final buffer =
              calloc<
                Int32
              >(); // Fetch as a 32-bit signed integer (SQL_C_SLONG).
          try {
            return readData(
              sqlcDataTypeSlong, // Target C type: signed long.
              sizeOf<Int32>(),
              buffer.cast<Void>(),
              (buf, len) => buf.cast<Int32>().value, // Get the int value.
            );
          } finally {
            calloc.free(buffer);
          }

        case sqlDataTypeReal: // Single-precision float.
        case sqlDataTypeFloat: // Double-precision float (can vary by driver).
        case sqlDataTypeDouble: // Double-precision float.
        case sqlDataTypeNumeric: // Exact numeric types.
        case sqlDataTypeDecimal:
          // Fetching NUMERIC/DECIMAL as double might lead to precision loss.
          // For exact precision, fetch as string (SQL_C_WCHAR) and parse with a decimal library.
          final buffer = calloc<Double>(); // Fetch as a double.
          try {
            return readData(
              sqlcDataTypeDouble, // Target C type: double.
              sizeOf<Double>(),
              buffer.cast<Void>(),
              (buf, len) => buf.cast<Double>().value, // Get the double value.
            );
          } finally {
            calloc.free(buffer);
          }

        // Example for handling native DATE structs (if needed):
        // case sqlDataTypeDate:
        //   final buffer = calloc<TagDateStruct>(); // Assuming TagDateStruct is defined via FFI
        //   try {
        //     return readData(sqlcDataTypeDate, sizeOf<TagDateStruct>(), buffer.cast<Void>(),
        //       (buf, len) {
        //         final dateStruct = buf.cast<TagDateStruct>().ref;
        //         return DateTime(dateStruct.year, dateStruct.month, dateStruct.day);
        //       });
        //   } finally { calloc.free(buffer); }
        // Similar logic would apply for SQL_TIME_STRUCT and SQL_TIMESTAMP_STRUCT.

        default:
          // Fallback for unhandled or unknown SQL data types.
          if (kDebugMode) {
            // Log a warning in debug mode.
            print(
              'ODBC Warning: Unhandled SQL data type $columnSqlDataType for column $columnIndex. Attempting to read as string.',
            );
          }
          // Attempt to read as a Unicode string.
          final bufferCharLength = 256; // Smaller buffer for unknown types.
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
      calloc.free(strLenOrIndPtr); // Always free the indicator pointer.
    }
  }
}
