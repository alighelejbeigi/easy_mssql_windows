import 'package:easy_mssql_windows/easy_mssql_windows.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key, required this.title});

  final test = OdbcConnector();
  String? resultConnection;
  String? resultValue;
  String? resultDic;
  int value = 0;

  Future<void> test2() async {
    resultConnection = await test.connect(
      'DRIVER={ODBC Driver 17 for SQL Server};SERVER=192.168.2.110,1433;DATABASE=Holoo5;UID=sa;PWD=@Aa123456;',
    );
  }

  Future<void> test3() async {
    final result = await test.customQuery(table: 'ARTICLE', columns: ['A_Name']);
    resultValue = result[value]['A_Name'];
    value++;
  }

  Future<void> test4() async {
    final result = test.disconnect();
    if (result) {
      resultDic = 'disconnected';
    }
  }

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            InkWell(
              onTap:
                  () => setState(() {
                    widget.test2();
                  }),
              child: Text('connect'),
            ),
            widget.resultConnection != null
                ? Text(widget.resultConnection!)
                : SizedBox(),
            InkWell(
              onTap:
                  () => setState(() {
                    widget.test3();
                  }),
              child: Text('get data'),
            ),
            widget.resultValue != null ? Text(widget.resultValue!) : SizedBox(),
            InkWell(
              onTap:
                  () => setState(() {
                    widget.test4();
                  }),
              child: Text('diconeccted'),
            ),
            widget.resultDic != null ? Text(widget.resultDic!) : SizedBox(),
          ],
        ),
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
