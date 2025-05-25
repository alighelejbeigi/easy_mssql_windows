// If odbc_connector.dart uses 'part of':
// part of 'odbc_connector.dart';

// Or, if using direct imports:
import 'odbc_connector.dart'; // Assuming OdbcConnector is in odbc_connector.dart

/// Convenience extension methods for OdbcConnector.
extension EasyQuery on OdbcConnector {
  /// Executes a simple SELECT query on a given table for specified columns.
  ///
  /// [table]: Name of the table (without brackets, will be bracketed automatically).
  /// [columns]: Optional list of column names (without brackets, will be bracketed automatically).
  /// If null or empty, selects all columns (`*`).
  Future<List<Map<String, dynamic>>> query({
    required String table,
    List<String>? columns,
  }) async {
    // Basic check to prevent direct _stmtHandle access from extension if it were public
    // However, executeQuery in OdbcConnector already checks _stmtHandle.
    // if (this._stmtHandle == null) { // This won't work as _stmtHandle is private
    //   throw Exception(
    //     'Cannot execute query: Statement handle is not allocated. Did you connect?',
    //   );
    // }

    final colsPart =
    (columns == null || columns.isEmpty)
        ? '*'
        : columns.map((c) => '[$c]').join(', '); // Bracketing column names
    // Bracketing table name, though some DBs/drivers might not need/want this.
    // Consider if this should be configurable or if the user should provide already-quoted names.
    final sql = 'SELECT $colsPart FROM [$table]';

    return executeQuery(sql); // Delegate to the main class's method
  }
}