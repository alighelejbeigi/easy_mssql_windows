// This file defines extension methods on the OdbcConnector class.
// Extension methods allow adding new functionality to existing classes without modifying them directly.
// In this case, it provides more convenient, higher-level ways to execute common queries.

// If 'odbc_connector.dart' (the file defining OdbcConnector) uses a 'library' directive
// and this file is meant to be part of that same library, 'part of' is appropriate.
// part of 'odbc_connector.dart';

// Alternatively, if this extension is in a separate file that consumes the OdbcConnector
// class (which is more common for extensions if they aren't tightly coupled or needing
// access to private library members), a direct import is used.
import 'odbc_connector.dart'; // Assuming OdbcConnector class is defined in odbc_connector.dart

/// Provides convenience extension methods for the [OdbcConnector] class,
/// simplifying common database query operations.
extension EasyQuery on OdbcConnector {
  /// Executes a simple SELECT query on a specified table for a list of columns.
  ///
  /// This method constructs a standard SQL SELECT statement and then calls
  /// the underlying `executeQuery` method of the `OdbcConnector` instance.
  ///
  /// Parameters:
  ///   [table]: The name of the database table to query. This name will be
  ///            automatically enclosed in square brackets (e.g., `[TableName]`)
  ///            in the generated SQL.
  ///   [columns]: An optional list of column names to select. Each column name
  ///              will also be enclosed in square brackets (e.g., `[ColumnName]`).
  ///              If `columns` is null or empty, all columns (`*`) will be selected.
  ///
  /// Returns:
  ///   A `Future` that completes with a list of `Map<String, dynamic>`, where
  ///   each map represents a row from the result set. The map keys are the
  ///   column names, and the values are the corresponding cell data.
  ///
  /// Throws:
  ///   This method may throw exceptions if the underlying `executeQuery` method
  ///   encounters an error (e.g., connection issues, SQL syntax errors,
  ///   ODBC driver errors).
  Future<List<Map<String, dynamic>>> customQuery({
    required String table,
    List<String>? columns,
  }) async {
    // The following commented-out check demonstrates a consideration for extension methods.
    // Extensions don't have access to private members (like _stmtHandle) of the class they extend.
    // The responsibility for such checks (e.g., if the connection is active or handles are valid)
    // lies within the OdbcConnector class itself, specifically within its executeQuery method.
    // if (this._stmtHandle == null) { // 'this' refers to the OdbcConnector instance. This won't compile due to _stmtHandle being private.
    //   throw Exception(
    //     'Cannot execute query: Statement handle is not allocated. Did you connect?',
    //   );
    // }

    // Construct the column selection part of the SQL query.
    // If 'columns' is null or empty, select all columns using '*'.
    // Otherwise, join the column names, enclosing each in square brackets.
    final String colsPart =
        (columns == null || columns.isEmpty)
            ? '*' // Select all columns.
            : columns
                .map((c) => '[$c]')
                .join(', '); // e.g., "[Column1], [Column2]"

    // Construct the final SQL query string.
    // The table name is also enclosed in square brackets.
    // Note: Using square brackets for identifiers is common in SQL Server and MS Access.
    // For other databases (e.g., PostgreSQL, MySQL), standard SQL quoting uses double quotes ("Identifier")
    // or backticks (`Identifier`). This bracketing might need to be adjusted or made
    // configurable if broader database compatibility is required beyond what the ODBC driver handles.
    final String sql = 'SELECT $colsPart FROM [$table]';

    // Delegate the execution of the constructed SQL query to the `executeQuery` method
    // of the `OdbcConnector` instance on which this extension method is called.
    // 'this.executeQuery(sql)' could also be written, but 'this' is implicit.
    return executeQuery(sql);
  }
}
