part of 'odbc_connector.dart'; // Or remove if you prefer explicit imports

/// Internal class to load and hold ODBC FFI function pointers.
class _OdbcRawApi {
  final DynamicLibrary _odbc;

  late final SQLAllocHandleDart sqlAllocHandle;
  late final SQLSetEnvAttrDart sqlSetEnvAttr;
  late final SQLDriverConnectWDart sqlDriverConnectW;
  late final SQLExecDirectWDart sqlExecDirectW;
  late final SQLFetchDart sqlFetch;
  late final SQLGetDataDart sqlGetData;
  late final SQLFreeHandleDart sqlFreeHandle;
  late final SQLNumResultColsDart sqlNumResultCols;
  late final SQLDescribeColWDart sqlDescribeColW;
  late final SQLFreeStmtDart sqlFreeStmt;
  late final SQLDisconnectDart sqlDisconnect;

  _OdbcRawApi({required String odbcLibName})
    : _odbc = DynamicLibrary.open(odbcLibName) {
    try {
      sqlAllocHandle = _odbc
          .lookupFunction<SQLAllocHandleNative, SQLAllocHandleDart>(
            'SQLAllocHandle',
          );
      sqlSetEnvAttr = _odbc
          .lookupFunction<SQLSetEnvAttrNative, SQLSetEnvAttrDart>(
            'SQLSetEnvAttr',
          );
      sqlDriverConnectW = _odbc
          .lookupFunction<SQLDriverConnectWNative, SQLDriverConnectWDart>(
            'SQLDriverConnectW',
          );
      sqlExecDirectW = _odbc
          .lookupFunction<SQLExecDirectWNative, SQLExecDirectWDart>(
            'SQLExecDirectW',
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
            'SQLDescribeColW',
          );
      sqlFreeStmt = _odbc.lookupFunction<SQLFreeStmtNative, SQLFreeStmtDart>(
        'SQLFreeStmt',
      );
      sqlDisconnect = _odbc
          .lookupFunction<SQLDisconnectNative, SQLDisconnectDart>(
            'SQLDisconnect',
          );
    } catch (e) {
      // Consider how to handle library/function loading errors.
      // This might involve re-throwing a more specific exception.
      throw Exception('Failed to lookup ODBC functions in "$odbcLibName": $e');
    }
  }
}
