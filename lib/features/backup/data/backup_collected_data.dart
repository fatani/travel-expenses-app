import '../../../core/database/app_database.dart';

/// Raw SQLite rows collected for a CalmLedger backup export.
class BackupCollectedData {
  const BackupCollectedData({
    this.userFinancialProfile = const [],
    this.settings = const [],
    this.cards = const [],
    this.trips = const [],
    this.manualExchangeRates = const [],
    this.expenses = const [],
    this.cashTransactions = const [],
    this.expenseRefunds = const [],
  });

  static const List<String> exportedTableNames = [
    AppDatabase.userFinancialProfileTable,
    AppDatabase.settingsTable,
    AppDatabase.cardsTable,
    AppDatabase.tripsTable,
    AppDatabase.manualExchangeRatesTable,
    AppDatabase.expensesTable,
    AppDatabase.cashTransactionsTable,
    AppDatabase.expenseRefundsTable,
  ];

  static const String excludedTableName = AppDatabase.tripCashBalancesTable;

  final List<Map<String, dynamic>> userFinancialProfile;
  final List<Map<String, dynamic>> settings;
  final List<Map<String, dynamic>> cards;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> manualExchangeRates;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> cashTransactions;
  final List<Map<String, dynamic>> expenseRefunds;
}
