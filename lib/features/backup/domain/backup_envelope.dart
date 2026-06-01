import 'backup_manifest.dart';

/// Full CalmLedger JSON backup document (domain shape only; no file I/O in Stage 1.9.10.2).
///
/// Row lists use SQLite column maps (`snake_case` keys) so export can reuse existing
/// `toMap()` serializers and restore can feed repositories later.
///
/// [tripCashBalances] are intentionally omitted — balances are derived from
/// [cashTransactions] and recomputed on restore.
class BackupEnvelope {
  const BackupEnvelope({
    required this.manifest,
    this.userFinancialProfile = const [],
    this.settings = const [],
    this.cards = const [],
    this.trips = const [],
    this.manualExchangeRates = const [],
    this.expenses = const [],
    this.cashTransactions = const [],
  });

  static const String userFinancialProfileKey = 'user_financial_profile';
  static const String settingsKey = 'settings';
  static const String cardsKey = 'cards';
  static const String tripsKey = 'trips';
  static const String manualExchangeRatesKey = 'manual_exchange_rates';
  static const String expensesKey = 'expenses';
  static const String cashTransactionsKey = 'cash_transactions';

  /// Table name excluded from backup payloads (derived state).
  static const String excludedTripCashBalancesKey = 'trip_cash_balances';

  final BackupManifest manifest;
  final List<Map<String, dynamic>> userFinancialProfile;
  final List<Map<String, dynamic>> settings;
  final List<Map<String, dynamic>> cards;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> manualExchangeRates;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> cashTransactions;

  Map<String, dynamic> toJson() {
    return {
      'manifest': manifest.toJson(),
      userFinancialProfileKey: userFinancialProfile,
      settingsKey: settings,
      cardsKey: cards,
      tripsKey: trips,
      manualExchangeRatesKey: manualExchangeRates,
      expensesKey: expenses,
      cashTransactionsKey: cashTransactions,
    };
  }

  factory BackupEnvelope.fromJson(Map<String, dynamic> json) {
    return BackupEnvelope(
      manifest: BackupManifest.fromJson(
        Map<String, dynamic>.from(json['manifest']! as Map),
      ),
      userFinancialProfile: _readRowList(json, userFinancialProfileKey),
      settings: _readRowList(json, settingsKey),
      cards: _readRowList(json, cardsKey),
      trips: _readRowList(json, tripsKey),
      manualExchangeRates: _readRowList(json, manualExchangeRatesKey),
      expenses: _readRowList(json, expensesKey),
      cashTransactions: _readRowList(json, cashTransactionsKey),
    );
  }

  static List<Map<String, dynamic>> _readRowList(
    Map<String, dynamic> json,
    String key,
  ) {
    final raw = json[key];
    if (raw == null) {
      return const [];
    }
    if (raw is! List) {
      throw FormatException('Expected list for $key');
    }

    return [
      for (final row in raw)
        Map<String, dynamic>.from(row! as Map<Object?, Object?>),
    ];
  }

  /// Converts domain `toMap()` output into JSON-safe row maps.
  static List<Map<String, dynamic>> rowsFromMaps(
    Iterable<Map<String, Object?>> maps,
  ) {
    return [for (final map in maps) Map<String, dynamic>.from(map)];
  }
}
