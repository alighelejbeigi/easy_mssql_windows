# Easy MSSQL Windows

[![pub package](https://img.shields.io/pub/v/easy_mssql_windows.svg)](https://pub.dev/packages/easy_mssql_windows) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) A Flutter package designed to simplify connecting a **Flutter desktop application on Windows** to a Microsoft SQL Server database using ODBC. It provides straightforward methods for establishing a connection, executing queries, and managing the disconnection process.

---

## 📋 Overview

`easy_mssql_windows` abstracts the complexities of FFI (Foreign Function Interface) calls to the Windows ODBC (Open Database Connectivity) API, allowing developers to interact with MS SQL Server databases with minimal setup. This package is specifically tailored for **Windows desktop applications**.

**Key Features:**
* Easy-to-use API for connecting to MS SQL Server.
* Simple methods for executing SQL queries.
* Proper management of ODBC handles and disconnection.
* Designed for Flutter applications running on the Windows platform.

---

## ⚠️ Prerequisites

Before using this package, please ensure the following prerequisites are met on the target Windows system:

1.  **Windows Operating System:** This package is specifically designed for and tested on Windows.
2.  **ODBC Driver for SQL Server:** **ODBC Driver 17 for SQL Server** (or a compatible newer version like ODBC Driver 18) **must be installed** on the system. You can download the official Microsoft ODBC drivers from their website.
3.  **Network Access:** The Windows machine running the application must have network access to the target MS SQL Server instance.

---

## 💻 Installation

1.  Add `easy_mssql_windows` to your `pubspec.yaml` file:

    ```yaml
    dependencies:
      flutter:
        sdk: flutter
      easy_mssql_windows: ^[your_package_version] # Replace with the latest version
    ```
    If you are using a local path during development:
    ```yaml
    dependencies:
      flutter:
        sdk: flutter
      easy_mssql_windows:
        path: ../path_to_your_package
    ```

2.  Run `flutter pub get` in your terminal from your project's root directory.

3.  Import the package in your Dart code:

    ```dart
    import 'package:easy_mssql_windows/easy_mssql_windows.dart';
    ```

---

## 🚀 Usage

Here's a basic guide on how to use the `easy_mssql_windows` package:

### 1. Initialize the Connector

First, create an instance of `OdbcConnector`. It's recommended to manage its lifecycle within a `StatefulWidget` if your connection is tied to a specific screen or part of your application.

```dart
final OdbcConnector odbcConnector = OdbcConnector();

// Optional: If your odbc32.dll is not in a standard system path,
// or if you are using a different ODBC driver manager DLL, you can specify its name:
// final OdbcConnector odbcConnector = OdbcConnector(odbcLibName: 'custom_odbc_driver_manager.dll');