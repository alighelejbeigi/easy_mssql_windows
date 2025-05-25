import 'package:flutter/material.dart';

// 1. Import your package
// Ensure 'easy_mssql_windows' matches the name in your pubspec.yaml
import 'package:easy_mssql_windows/easy_mssql_windows.dart';

void main() {
  // Standard Flutter application entry point.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easy MSSQL Windows Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true, // Using Material 3 design
        elevatedButtonTheme: ElevatedButtonThemeData(
          // Consistent button styling
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ),
      // Set MyHomePage as the home screen of the application.
      home: const MyHomePage(title: 'Flutter ODBC SQL Server Demo'),
    );
  }
}

// MyHomePage is a StatefulWidget because its content (database results, connection status)
// will change based on user interactions and asynchronous operations.
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// This is the private State class for MyHomePage.
// All mutable state and logic related to database interaction will reside here.
class _MyHomePageState extends State<MyHomePage> {
  // 2. Instantiate OdbcConnector
  // It's declared as 'late final' because it's initialized in initState.
  // This object will manage our connection to the SQL Server database.
  late final OdbcConnector _odbcConnector;

  // --- State Variables for UI Feedback and Data Storage ---
  String _connectionStatusMessage =
      "Not Connected"; // Displays the current connection status.
  bool _isLoading =
      false; // Controls visibility of a loading indicator during async operations.
  List<Map<String, dynamic>> _queryResults =
      []; // Stores results fetched from the database.
  String _dataDisplayMessage =
      "No data queried yet."; // User-friendly message about query results.
  String _lastError =
      ""; // Stores the last error message for display to the user.
  int _currentArticleIndex =
      0; // Used to cycle through articles in this example.

  // 3. Define Your Connection String
  // IMPORTANT: THIS IS A CRITICAL STEP!
  // You MUST replace the placeholder values below (SERVER, DATABASE, UID, PWD)
  // with your actual SQL Server instance details, database name, and credentials.
  // Also, ensure the 'DRIVER' matches an ODBC driver installed on your Windows machine.
  // Common drivers: {ODBC Driver 17 for SQL Server}, {ODBC Driver 18 for SQL Server}, {SQL Server Native Client 11.0}
  final String _connectionString =
      'DRIVER={ODBC Driver 17 for SQL Server};SERVER=192.168.2.110,1433;DATABASE=Holoo5;UID=sa;PWD=@Aa123456;';

  // Example for Windows Authentication (Trusted Connection) if your server is configured for it:
  // final String _connectionString =
  //    'DRIVER={ODBC Driver 17 for SQL Server};SERVER=YOUR_SERVER_NAME\\YOUR_INSTANCE_NAME;DATABASE=YOUR_DATABASE_NAME;Trusted_Connection=yes;';

  @override
  void initState() {
    super.initState();
    // Initialize the OdbcConnector when the widget's state is first created.
    _odbcConnector = OdbcConnector();
    // We are not connecting automatically on init in this example.
    // Connection will be triggered by a user action (button press).
  }

  /// Helper method to update the loading state and trigger a UI rebuild.
  void _setLoading(bool loading) {
    if (mounted) {
      // Check if the widget is still part of the widget tree.
      setState(() {
        _isLoading = loading;
      });
    }
  }

  /// Clears previous error messages from the UI.
  void _clearError() {
    if (mounted && _lastError.isNotEmpty) {
      setState(() {
        _lastError = "";
      });
    }
  }

  /// Attempts to connect to the SQL Server database using the defined connection string.
  Future<void> _connectToDb() async {
    _clearError();
    _setLoading(true);
    try {
      // 4. Connect to the Database
      // The connect() method is asynchronous.
      final String connectMessage = await _odbcConnector.connect(
        _connectionString,
      );

      if (mounted) {
        setState(() {
          // The interpretation of 'connectMessage' depends on your package's OdbcConnector.connect() implementation.
          // Assuming a non-null string containing "success" (case-insensitive) indicates success.
          if (connectMessage.toLowerCase().contains('success')) {
            _connectionStatusMessage = "Connected: $connectMessage";
          } else {
            _connectionStatusMessage =
                "Connection Attempt Info: $connectMessage (Verify success manually)";
          }
        });
      }
    } catch (e) {
      // Handle any exceptions thrown during the connection process.
      if (mounted) {
        setState(() {
          _connectionStatusMessage = "Connection Failed";
          _lastError = "Connection Error: ${e.toString()}";
        });
        debugPrint(
          "ODBC Connection Error: $e",
        ); // Log to console for debugging.
      }
    } finally {
      _setLoading(false); // Ensure loading indicator is turned off.
    }
  }

  /// Fetches data from the 'ARTICLE' table.
  /// This example fetches all specified columns and stores them.
  /// The UI will then display one article name at a time, cycling with each button press.
  Future<void> _fetchArticleData() async {
    // Prevent query attempt if not connected.
    if (!_connectionStatusMessage.toLowerCase().contains("connected")) {
      if (mounted) {
        setState(() {
          _dataDisplayMessage =
              "Cannot fetch data: Not connected to the database.";
          _lastError = "Please connect to the database first.";
        });
      }
      return;
    }

    _clearError();
    _setLoading(true);
    try {
      // 5. Execute a Query
      // Using the customQuery extension method for simplicity.
      // Replace 'ARTICLE' and column names with your actual table and desired columns.
      final List<Map<String, dynamic>> results = await _odbcConnector
          .customQuery(
            table: 'ARTICLE', // The name of the table to query.
            columns: [
              'A_Code',
              'A_Name',
              'Sel_Price',
            ], // A list of columns to select.
          );

      if (mounted) {
        setState(() {
          _queryResults = results; // Store all fetched results.
          if (results.isEmpty) {
            _dataDisplayMessage =
                "Query executed, but no articles were found in the 'ARTICLE' table.";
            _currentArticleIndex = 0;
          } else {
            _dataDisplayMessage =
                "Fetched ${results.length} articles. Click 'Next Article' to view.";
            _currentArticleIndex = 0; // Reset index to show the first article.
            // Display the first article immediately after fetching.
            _displayCurrentArticle();
          }
        });
      }
    } catch (e) {
      // Handle any exceptions during query execution.
      if (mounted) {
        setState(() {
          _dataDisplayMessage = "Failed to fetch article data.";
          _lastError = "Query Error: ${e.toString()}";
        });
        debugPrint("ODBC Query Error: $e");
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Updates the UI to display the current article based on _currentArticleIndex.
  void _displayCurrentArticle() {
    if (_queryResults.isEmpty) {
      if (mounted) {
        setState(() {
          _dataDisplayMessage = "No articles to display. Fetch data first.";
        });
      }
      return;
    }
    if (_currentArticleIndex >= _queryResults.length) {
      _currentArticleIndex = 0; // Wrap around to the first article.
    }
    if (mounted) {
      setState(() {
        final article = _queryResults[_currentArticleIndex];
        // Assuming 'A_Name' is a column in your 'ARTICLE' table.
        _dataDisplayMessage =
            "Article (${_currentArticleIndex + 1}/${_queryResults.length}): ${article['A_Name'] ?? 'N/A'} (Code: ${article['A_Code'] ?? 'N/A'}, Price: ${article['Sel_Price'] ?? 'N/A'})";
      });
    }
  }

  /// Cycles to the next article in the fetched results.
  void _nextArticle() {
    if (_queryResults.isEmpty) {
      if (mounted) {
        setState(() {
          _dataDisplayMessage = "No articles loaded. Please fetch data first.";
          _lastError = "Fetch data before trying to view next article.";
        });
      }
      return;
    }
    _clearError();
    _currentArticleIndex++;
    _displayCurrentArticle(); // Update UI with the new current article.
  }

  /// Disconnects from the SQL Server database.
  Future<void> _disconnectFromDb() async {
    _clearError();
    _setLoading(true);
    try {
      // 6. Disconnect from the Database
      // The disconnect() method in your package is synchronous and returns a bool.
      final bool wasDisconnected = _odbcConnector.disconnect();

      if (mounted) {
        setState(() {
          if (wasDisconnected) {
            _connectionStatusMessage = "Disconnected Successfully";
          } else {
            _connectionStatusMessage =
                "Disconnection attempt finished, but some cleanup might have failed.";
            _lastError =
                "Disconnect warning: Check application logs if issues persist.";
          }
          // Reset data-related state upon disconnection.
          _queryResults = [];
          _dataDisplayMessage = "No data queried yet.";
          _currentArticleIndex = 0;
        });
      }
    } catch (e) {
      // Although disconnect() is synchronous, include a catch block for any unexpected errors.
      if (mounted) {
        setState(() {
          _connectionStatusMessage =
              "Error occurred during disconnection process.";
          _lastError = "Disconnection Error: ${e.toString()}";
        });
        debugPrint("ODBC Disconnection Error: $e");
      }
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    // CRITICAL: This method is called when the widget's State object is removed from the tree permanently.
    // It's essential to disconnect from the database here to free up native ODBC resources
    // and database server connections, preventing potential memory leaks or resource exhaustion.
    debugPrint(
      "MyHomePage disposing. Attempting to disconnect from ODBC source.",
    );
    _odbcConnector.disconnect(); // Ensure disconnection on dispose.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        // Allows content to scroll if it overflows the screen.
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // Make buttons take full width.
            children: <Widget>[
              // Section: Connection Status Display
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Status: $_connectionStatusMessage',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color:
                          _connectionStatusMessage.toLowerCase().contains(
                                "connected",
                              )
                              ? Colors.green.shade700
                              : (_connectionStatusMessage
                                      .toLowerCase()
                                      .contains("fail")
                                  ? Colors.red.shade700
                                  : Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.color),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Section: Error Message Display (if any)
              if (_lastError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _lastError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),

              // Section: Action Buttons (Connect, Fetch Data, Disconnect)
              // A loading indicator is shown if an async operation is in progress.
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // Use spread operator to include multiple widgets if not loading.
                ElevatedButton(
                  onPressed: _connectToDb,
                  child: const Text('Connect to Database'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _fetchArticleData,
                  child: const Text('Fetch Articles'),
                ),
                const SizedBox(height: 12),
                if (_queryResults.isNotEmpty) ...[
                  // Show "Next Article" only if data is loaded
                  ElevatedButton(
                    onPressed: _nextArticle,
                    child: const Text('Next Article'),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton(
                  onPressed: _disconnectFromDb,
                  child: const Text('Disconnect'),
                ),
              ],
              const SizedBox(height: 30),

              // Section: Display Queried Data
              Text(
                _dataDisplayMessage,
                // Shows current article name or status messages.
                style: Theme.of(context).textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Optionally, display the raw list of fetched results for debugging/demonstration
              if (_queryResults.isNotEmpty &&
                  !_isLoading) // Show only if results exist and not loading
                Container(
                  height: 200,
                  // Constrain height to make it scrollable if many items.
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _queryResults.length,
                    itemBuilder: (context, index) {
                      final row = _queryResults[index];
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(
                            // Displaying multiple fields from the row. Adjust as per your columns.
                            "Code: ${row['A_Code'] ?? 'N/A'}\nName: ${row['A_Name'] ?? 'N/A'}\nPrice: ${row['Sel_Price'] ?? 'N/A'}",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
