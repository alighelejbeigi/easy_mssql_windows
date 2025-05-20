import 'dart:ffi';

import 'package:ffi/ffi.dart';

// ODBC result-column count
typedef SQLNumResultColsNative = SQLRETURN Function(
    SQLHANDLE stmtHandle,
    Pointer<Int16> columnCountPtr,
    );
typedef SQLNumResultColsDart = int Function(
    SQLHANDLE stmtHandle,
    Pointer<Int16> columnCountPtr,
    );

// ODBC describe-col (wide)
typedef SQLDescribeColWNative = SQLRETURN Function(
    SQLHANDLE stmtHandle,
    Uint16 columnNumber,
    Pointer<Utf16> columnNamePtr,
    Int16 nameBufferLength,
    Pointer<Int16> nameLengthPtr,
    Pointer<Int16> dataTypePtr,
    Pointer<Int32> columnSizePtr,
    Pointer<Int16> decimalDigitsPtr,
    Pointer<Int16> nullablePtr,
    );
typedef SQLDescribeColWDart = int Function(
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


/// Native typedefs
typedef SQLRETURN = Int16;
typedef SQLHANDLE = Pointer<Void>;
typedef SQLPOINTER = Pointer<Void>;

// ODBC C data types
const int SQL_C_SLONG = 4; // 32-bit signed integer
const int SQL_C_DOUBLE = 8; // 64-bit floating point
const int SQL_C_BIT = (-7); // BIT

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

typedef SQLExecDirectWNative =
    SQLRETURN Function(SQLHANDLE stmt, Pointer<Utf16> sqlStr, Int32 textLength);
typedef SQLExecDirectWDart =
    int Function(SQLHANDLE stmt, Pointer<Utf16> sqlStr, int textLength);

typedef SQLFetchNative = SQLRETURN Function(SQLHANDLE stmt);
typedef SQLFetchDart = int Function(SQLHANDLE stmt);

typedef SQLGetDataNative =
    SQLRETURN Function(
      SQLHANDLE stmt,
      Uint16 colNumber,
      Uint16 targetType,
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

typedef SQLFreeHandleNative =
    SQLRETURN Function(Int16 handleType, SQLHANDLE handle);
typedef SQLFreeHandleDart = int Function(int handleType, SQLHANDLE handle);

/// ODBC handle types
const int SQL_HANDLE_ENV = 1;
const int SQL_HANDLE_DBC = 2;
const int SQL_HANDLE_STMT = 3;

/// ODBC attributes
const int SQL_ATTR_ODBC_VERSION = 200;
const int SQL_OV_ODBC3 = 3;

/// Driver completion options
const int SQL_DRIVER_COMPLETE = 1;

/// C data types for SQLGetData
const int SQL_C_CHAR = 1; // ANSI char
const int SQL_C_WCHAR = -8; // wide char (Unicode)

class OdbcConnector {
  late final DynamicLibrary _odbc;
  late final SQLAllocHandleDart _SQLAllocHandle;
  late final SQLSetEnvAttrDart _SQLSetEnvAttr;
  late final SQLDriverConnectWDart _SQLDriverConnectW;
  late final SQLExecDirectWDart _SQLExecDirectW;
  late final SQLFetchDart _SQLFetch;
  late final SQLGetDataDart _SQLGetData;
  late final SQLFreeHandleDart _SQLFreeHandle;
  late final SQLNumResultColsDart _SQLNumResultCols;
  late final SQLDescribeColWDart _SQLDescribeColW;

  SQLHANDLE? _env;
  SQLHANDLE? _dbc;
  SQLHANDLE? _stmt;

  OdbcConnector() {
    _odbc = DynamicLibrary.open('odbc32.dll');

    _SQLAllocHandle = _odbc
        .lookupFunction<SQLAllocHandleNative, SQLAllocHandleDart>(
          'SQLAllocHandle',
        );
    _SQLSetEnvAttr = _odbc
        .lookupFunction<SQLSetEnvAttrNative, SQLSetEnvAttrDart>(
          'SQLSetEnvAttr',
        );
    _SQLDriverConnectW = _odbc
        .lookupFunction<SQLDriverConnectWNative, SQLDriverConnectWDart>(
          'SQLDriverConnectW',
        );
    _SQLExecDirectW = _odbc
        .lookupFunction<SQLExecDirectWNative, SQLExecDirectWDart>(
          'SQLExecDirectW',
        );
    _SQLFetch = _odbc.lookupFunction<SQLFetchNative, SQLFetchDart>('SQLFetch');
    _SQLGetData = _odbc.lookupFunction<SQLGetDataNative, SQLGetDataDart>(
      'SQLGetData',
    );
    _SQLFreeHandle = _odbc
        .lookupFunction<SQLFreeHandleNative, SQLFreeHandleDart>(
          'SQLFreeHandle',
        );
    _SQLNumResultCols = _odbc.lookupFunction<
        SQLNumResultColsNative,
        SQLNumResultColsDart>(
      'SQLNumResultCols',
    );

    _SQLDescribeColW = _odbc.lookupFunction<
        SQLDescribeColWNative,
        SQLDescribeColWDart>(
      'SQLDescribeColW',
    );
  }

  /// ایجاد و مقداردهی اولیه محیط و اتصال
  Future<String?> connect(String connectionString) async {
    final envOut = calloc<SQLHANDLE>();
    if (_SQLAllocHandle(SQL_HANDLE_ENV, nullptr, envOut) != 0) {
      calloc.free(envOut);
      throw Exception('❌ SQLAllocHandle ENV failed');
    }
    _env = envOut.value;
    calloc.free(envOut);

    if (_SQLSetEnvAttr(
          _env!,
          SQL_ATTR_ODBC_VERSION,
          Pointer.fromAddress(SQL_OV_ODBC3),
          0,
        ) !=
        0) {
      throw Exception('❌ SQLSetEnvAttr failed');
    }

    final dbcOut = calloc<SQLHANDLE>();
    if (_SQLAllocHandle(SQL_HANDLE_DBC, _env!, dbcOut) != 0) {
      calloc.free(dbcOut);
      throw Exception('❌ SQLAllocHandle DBC failed');
    }
    _dbc = dbcOut.value;
    calloc.free(dbcOut);

    // ===== داخل متد connect =====
    final connPtr = connectionString.toNativeUtf16();

    // الف) بافر خروجی
    final outBuf = calloc<Uint16>(512);
    final Pointer<Utf16> outStr = outBuf.cast<Utf16>();

    // ب) طول رشته خروجی
    final outLen = calloc<Int16>();

    // ج) فراخوانی ODBC
    final ret = _SQLDriverConnectW(
      _dbc!,
      0,
      connPtr,
      -3,
      outStr,
      512,
      outLen,
      SQL_DRIVER_COMPLETE,
    );

    calloc.free(connPtr); // بعد از استفاده از connPtr

    if (ret != 0 && ret != 1) {
      // قبل از پرتاب Exception، بافرها رو آزاد کن
      calloc.free(outBuf);
      calloc.free(outLen);
      return ('❌ SQLDriverConnectW failed: return code $ret');
    }

    // د) حالا که کارتان با outStr تمام شد، بافرها را آزاد کنید
    calloc.free(outBuf);
    calloc.free(outLen);

    // ادامه: تخصیص STMT و ...

    if (ret != 0 && ret != 1 /* SQL_SUCCESS_WITH_INFO */ ) {
      return ('❌ SQLDriverConnectW failed: return code $ret');
    }

    final stmtOut = calloc<SQLHANDLE>();
    if (_SQLAllocHandle(SQL_HANDLE_STMT, _dbc!, stmtOut) != 0) {
      calloc.free(stmtOut);

      return ('❌ SQLAllocHandle STMT failed');

    }
    _stmt = stmtOut.value;
    calloc.free(stmtOut);
    return 'success';
  }

/*
  Future<List<ProductNew>> queryGet(String sql) async {
    // 1) ارسال کوئری
    final sqlPtr = sql.toNativeUtf16();
    final execRet = _SQLExecDirectW(_stmt!, sqlPtr, -3);
    calloc.free(sqlPtr);
    if (execRet != 0 && execRet != 1) {
      throw Exception('ExecDirect failed: code $execRet');
    }

    final products = <ProductNew>[];

    // خواندن رشته (WCHAR)
    String readString(int col) {
      final buf = calloc<Uint16>(512);
      final lenPtr = calloc<Int64>();
      final ret = _SQLGetData(
        _stmt!,
        col,
        SQL_C_WCHAR,
        buf.cast<Void>(),
        sizeOf<Uint16>() * 512,
        lenPtr,
      );
      if (ret != 0) {
        calloc.free(buf);
        calloc.free(lenPtr);
        throw Exception('SQLGetData failed at col=$col, code $ret');
      }
      final s = buf.cast<Utf16>().toDartString().trim();
      calloc.free(buf);
      calloc.free(lenPtr);
      return s;
    }

    // خواندن double باینری
    double readDouble(int col) {
      final buf = calloc<Double>();
      final lenPtr = calloc<Int64>();
      final ret = _SQLGetData(
        _stmt!,
        col,
        SQL_C_DOUBLE,
        buf.cast<Void>(),
        sizeOf<Double>(),
        lenPtr,
      );
      if (ret != 0) {
        calloc.free(buf);
        calloc.free(lenPtr);
        throw Exception('SQLGetData(double) failed at col=$col, code $ret');
      }
      final v = buf.value;
      calloc.free(buf);
      calloc.free(lenPtr);
      return v;
    }

    // خواندن int32 باینری
    int readInt(int col) {
      final buf = calloc<Int32>();
      final lenPtr = calloc<Int64>();
      final ret = _SQLGetData(
        _stmt!,
        col,
        SQL_C_SLONG,
        buf.cast<Void>(),
        sizeOf<Int32>(),
        lenPtr,
      );
      if (ret != 0) {
        calloc.free(buf);
        calloc.free(lenPtr);
        throw Exception('SQLGetData(int) failed at col=$col, code $ret');
      }
      final v = buf.value;
      calloc.free(buf);
      calloc.free(lenPtr);
      return v;
    }

    // خواندن BIT
    bool readBool(int col) {
      final buf = calloc<Uint8>();
      final lenPtr = calloc<Int64>();
      final ret = _SQLGetData(
        _stmt!,
        col,
        SQL_C_BIT,
        buf.cast<Void>(),
        sizeOf<Uint8>(),
        lenPtr,
      );
      if (ret != 0) {
        calloc.free(buf);
        calloc.free(lenPtr);
        throw Exception('SQLGetData(bool) failed at col=$col, code $ret');
      }
      final v = buf.value;
      calloc.free(buf);
      calloc.free(lenPtr);
      return v != 0;
    }

    // 2) پیمایش ردیف‌ها
    while (true) {
      final fetchRet = _SQLFetch(_stmt!);
      if (fetchRet != 0) break;

      products.add(
        ProductNew(
          aCode: readString(1),
          aCodeC: readString(2),
          aName: readString(3),
          aCountry: readString(4),
          attribute: readString(5),
          picturePath: readString(6),
          model: readString(7),
          buyPrice: readDouble(8),
          firstBuyPrice: readDouble(9),
          endBuyPrice: readDouble(10),
          sellPrice1: readDouble(11),
          sellPrice2: readDouble(12),
          sellPrice3: readDouble(13),
          sellPrice4: readDouble(14),
          sellPrice5: readDouble(15),
          sellPrice6: readDouble(16),
          sellPrice7: readDouble(17),
          sellPrice8: readDouble(18),
          sellPrice9: readDouble(19),
          sellPrice10: readDouble(20),
          darsadForush: readDouble(21),
          toolArz: readDouble(22),
          moddat: readDouble(23),
          weight2: readDouble(24),
          incField: readString(25),
          exist: readInt(26),
          exist2: readInt(27),
          finishDate: readString(28),
          place: readString(29),
          aMin: readInt(30),
          aMax: readInt(31),
          firstExist: readDouble(32),
          firstExist2: readDouble(33),
          existMandeh: readInt(34),
          buyDollar: readDouble(35),
          sellDollar: readDouble(36),
          deleted: readBool(37),
          typeAnbarC: readString(38),
          fewTakhfif: readDouble(39),
          darsadTakhfif: readDouble(40),
          vahedCode: readString(41),
          hlpFieldL: readString(42),
          karton: readInt(43),
          basteh: readInt(44),
          myBuyPrice: readDouble(45),
          maxPrice: readDouble(46),
          minPrice: readDouble(47),
          darsadPorsant: readDouble(48),
          weight: readDouble(49),
          hajm: readDouble(50),
          userPrice: readDouble(51),
          other1: readString(52),
          other2: readString(53),
          other3: readString(54),
          other4: readString(55),
          other5: readString(56),
          other6: readString(57),
        ),
      );
    }

    return products;
  }
*/

  void disconnect() {
    if (_stmt != null) {
      _SQLFreeHandle(SQL_HANDLE_STMT, _stmt!);
    }
    if (_dbc != null) {
      _SQLFreeHandle(SQL_HANDLE_DBC, _dbc!);
    }
    if (_env != null) {
      _SQLFreeHandle(SQL_HANDLE_ENV, _env!);
    }
  }
}

extension EasyQuery on OdbcConnector {
  /// اجراکنندهٔ داینامیک SELECT روی جدول محلی
  ///
  /// [table]     : نام جدول (بدون براکت)
  /// [columns]   : لیست نام ستون‌ها (بدون براکت)
  /// اگر خالی باشد، همهٔ ستون‌ها (*) خوانده می‌شوند.
  Future<List<Map<String, dynamic>>> query(
      String table, {
        List<String>? columns,
      }) async {
    // 1. ساخت رشتهٔ SELECT
    final colsPart = (columns == null || columns.isEmpty)
        ? '*'
        : columns.map((c) => '[$c]').join(', ');
    final sql = 'SELECT $colsPart FROM [$table]';

    // 2. اجرای کوئری
    final sqlPtr = sql.toNativeUtf16();
    final execRet = _SQLExecDirectW(_stmt!, sqlPtr, -3);
    calloc.free(sqlPtr);
    if (execRet != 0 && execRet != 1) {
      throw Exception('ExecDirect failed: code $execRet');
    }

    // 3. تعداد ستون‌ها
    final colCountPtr = calloc<Int16>();
    final retCols = _SQLNumResultCols(_stmt!, colCountPtr);
    if (retCols != 0) {
      calloc.free(colCountPtr);
      throw Exception('SQLNumResultCols failed: $retCols');
    }
    final colCount = colCountPtr.value;
    calloc.free(colCountPtr);

    // 4. متادیتای ستون‌ها
    final meta = <_ColMeta>[];
    for (var i = 1; i <= colCount; i++) {
      final nameBuf = calloc<Uint16>(128).cast<Utf16>();
      final nameLenPtr = calloc<Int16>();
      final typePtr = calloc<Int16>();
      final sizePtr = calloc<Int32>();
      final decPtr = calloc<Int16>();
      final nulPtr = calloc<Int16>();

      final descRet = _SQLDescribeColW(
        _stmt!,
        i,
        nameBuf,
        128,
        nameLenPtr,
        typePtr,
        sizePtr,
        decPtr,
        nulPtr,
      );
      if (descRet != 0) {
        throw Exception('DescribeColW failed at col $i');
      }

      final name = nameBuf.toDartString(length: nameLenPtr.value);
      meta.add(_ColMeta(name: name, sqlType: typePtr.value));
      calloc.free(nameBuf);
      calloc.free(nameLenPtr);
      calloc.free(typePtr);
      calloc.free(sizePtr);
      calloc.free(decPtr);
      calloc.free(nulPtr);
    }
    // خواندن رشته (WCHAR)
    String readString(int col) {
      final buf = calloc<Uint16>(512);
      final lenPtr = calloc<Int64>();
      final ret = _SQLGetData(
        _stmt!,
        col,
        SQL_C_WCHAR,
        buf.cast<Void>(),
        sizeOf<Uint16>() * 512,
        lenPtr,
      );
      if (ret != 0) {
        calloc.free(buf);
        calloc.free(lenPtr);
        throw Exception('SQLGetData failed at col=$col, code $ret');
      }
      final s = buf.cast<Utf16>().toDartString().trim();
      calloc.free(buf);
      calloc.free(lenPtr);
      return s;
    }

    // خواندن double باینری
    double readDouble(int col) {
      final buf = calloc<Double>();
      final lenPtr = calloc<Int64>();
      final ret = _SQLGetData(
        _stmt!,
        col,
        SQL_C_DOUBLE,
        buf.cast<Void>(),
        sizeOf<Double>(),
        lenPtr,
      );
      if (ret != 0) {
        calloc.free(buf);
        calloc.free(lenPtr);
        throw Exception('SQLGetData(double) failed at col=$col, code $ret');
      }
      final v = buf.value;
      calloc.free(buf);
      calloc.free(lenPtr);
      return v;
    }

    // خواندن int32 باینری
    int readInt(int col) {
      final buf = calloc<Int32>();
      final lenPtr = calloc<Int64>();
      final ret = _SQLGetData(
        _stmt!,
        col,
        SQL_C_SLONG,
        buf.cast<Void>(),
        sizeOf<Int32>(),
        lenPtr,
      );
      if (ret != 0) {
        calloc.free(buf);
        calloc.free(lenPtr);
        throw Exception('SQLGetData(int) failed at col=$col, code $ret');
      }
      final v = buf.value;
      calloc.free(buf);
      calloc.free(lenPtr);
      return v;
    }

    // خواندن BIT
    bool readBool(int col) {
      final buf = calloc<Uint8>();
      final lenPtr = calloc<Int64>();
      final ret = _SQLGetData(
        _stmt!,
        col,
        SQL_C_BIT,
        buf.cast<Void>(),
        sizeOf<Uint8>(),
        lenPtr,
      );
      if (ret != 0) {
        calloc.free(buf);
        calloc.free(lenPtr);
        throw Exception('SQLGetData(bool) failed at col=$col, code $ret');
      }
      final v = buf.value;
      calloc.free(buf);
      calloc.free(lenPtr);
      return v != 0;
    }

    // 5. خواندن ردیف‌ها
    final rows = <Map<String, dynamic>>[];
    while (_SQLFetch(_stmt!) == 0) {
      final row = <String, dynamic>{};
      for (var i = 0; i < meta.length; i++) {
        final colIndex = i + 1;
        final m = meta[i];
        dynamic val;
        switch (m.sqlType) {
          case SQL_C_SLONG:
            val = readInt(colIndex);
            break;
          case SQL_C_DOUBLE:
            val = readDouble(colIndex);
            break;
          case SQL_C_BIT:
            val = readBool(colIndex);
            break;
          default:
            val = readString(colIndex);
        }
        row[m.name] = val;
      }
      rows.add(row);
    }

    return rows;
  }
}

class _ColMeta {
  final String name;
  final int sqlType;
  _ColMeta({required this.name, required this.sqlType});
}

