import 'package:easy_mssql_windows/easy_mssql_windows.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart'; // If using Flutter integration_test

void main() {
  OdbcConnector? connector; // Nullable because setup/teardown might fail

  // IMPORTANT: Read connection details from environment variables
  // to avoid committing credentials to source control.
  final server = String.fromEnvironment(
    'DB_SERVER',
    defaultValue: 'localhost\\SQLEXPRESS',
  );
  final database = String.fromEnvironment(
    'DB_DATABASE',
    defaultValue: 'TestDB',
  );
  final uid = String.fromEnvironment('DB_UID', defaultValue: 'sa');
  final pwd = String.fromEnvironment(
    'DB_PWD',
    defaultValue: 'YourStrong(!)Password',
  );

  // Construct a DSN-less connection string
  final connectionString =
      'DRIVER={ODBC Driver 17 for SQL Server};SERVER=$server;DATABASE=$database;UID=$uid;PWD=$pwd;';
  // Or use a DSN: 'DSN=MyTestDSN;UID=$uid;PWD=$pwd;'

  setUpAll(() async {
    // This block runs once before all tests in this file.
    // You could create test tables or ensure the database state here.
    // For example, establish a temporary connection to setup schema.
    connector = OdbcConnector();
    try {
      if (kDebugMode) {
        print("Attempting to connect for setupAll: $connectionString");
      }
      await connector!.connect(connectionString);
      // Create a test table
      await connector!.executeQuery(
        'IF OBJECT_ID(\'dbo.TestItems\', \'U\') IS NOT NULL DROP TABLE dbo.TestItems;'
        'CREATE TABLE TestItems (ID INT PRIMARY KEY, Name NVARCHAR(100), Price DECIMAL(10,2));',
      );
      await connector!.executeQuery(
        "INSERT INTO TestItems (ID, Name, Price) VALUES (1, 'Test Product A', 10.99);",
      );
      await connector!.executeQuery(
        "INSERT INTO TestItems (ID, Name, Price) VALUES (2, 'Test Product B', 25.50);",
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error in setUpAll while preparing database: $e');
      }
      // If setup fails, connector might be null or not connected, tests will likely fail.
    } finally {
      connector?.disconnect(); // Disconnect after setup
    }
  });

  tearDownAll(() async {
    // This block runs once after all tests in this file.
    // Clean up test data or tables.
    connector = OdbcConnector();
    try {
      await connector!.connect(connectionString);
      await connector!.executeQuery(
        'IF OBJECT_ID(\'dbo.TestItems\', \'U\') IS NOT NULL DROP TABLE dbo.TestItems;',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error in tearDownAll while cleaning database: $e');
      }
    } finally {
      connector?.disconnect();
    }
  });

  setUp(() {
    // Runs before each individual test.
    connector = OdbcConnector(); // Fresh connector for each test
  });

  tearDown(() {
    // Runs after each individual test.
    connector?.disconnect();
    connector = null;
  });

  testWidgets('Connect to database, query data, and disconnect successfully', (
    WidgetTester tester,
  ) async {
    // This test uses testWidgets for Flutter integration_test, but the core logic is OdbcConnector.
    // For pure Dart integration tests, you'd use `test()` from `package:test`.

    expect(
      connector,
      isNotNull,
      reason: "Connector should be initialized in setUp",
    );

    // 1. Connect
    String? connectResult;
    List<Map<String, dynamic>>? queryResults;
    bool disconnectResult = false;

    try {
      connectResult = await connector!.connect(connectionString);
      expect(
        connectResult,
        isNotNull,
        reason: "Connection result string should not be null",
      );
      expect(
        connectResult.toLowerCase(),
        contains('success'),
        reason: "Connection should be successful",
      );

      // 2. Query Data
      queryResults = await connector!.customQuery(
        table: 'TestItems',
        columns: ['ID', 'Name', 'Price'],
      );
      expect(
        queryResults,
        isNotNull,
        reason: "Query results should not be null",
      );
      expect(
        queryResults.length,
        greaterThanOrEqualTo(2),
        reason: "Should fetch at least 2 items",
      );
      expect(
        queryResults.any((row) => row['Name'] == 'Test Product A'),
        isTrue,
      );
    } catch (e) {
      fail('Database operation failed during test: $e');
    } finally {
      // 3. Disconnect
      disconnectResult = connector!.disconnect();
    }
    expect(
      disconnectResult,
      isTrue,
      reason: "Disconnection should be successful",
    );
  });

  testWidgets('Handle query on non-existent table gracefully', (
    WidgetTester tester,
  ) async {
    expect(connector, isNotNull);
    await connector!.connect(
      connectionString,
    ); // Assume this succeeds based on other tests or setup

    try {
      await connector!.customQuery(table: 'NonExistentTable', columns: ['ID']);
      fail('Querying a non-existent table should have thrown an exception.');
    } catch (e) {
      expect(e, isA<Exception>());
      // You might want to check for specific ODBC error messages or SQLSTATEs if your
      // _checkReturnCode or package surfaces them.
      if (kDebugMode) {
        print('Caught expected error for non-existent table: $e');
      }
    } finally {
      connector!.disconnect();
    }
  });
}
