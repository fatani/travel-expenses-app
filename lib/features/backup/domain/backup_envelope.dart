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
    this.expenseRefunds = const [],
  });

  static const String userFinancialProfileKey = 'user_financial_profile';
  static const String settingsKey = 'settings';
  static const String cardsKey = 'cards';
  static const String tripsKey = 'trips';
  static const String manualExchangeRatesKey = 'manual_exchange_rates';
  static const String expensesKey = 'expenses';
  static const String cashTransactionsKey = 'cash_transactions';
  static const String expenseRefundsKey = 'expense_refunds';

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
  final List<Map<String, dynamic>> expenseRefunds;

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
      expenseRefundsKey: expenseRefunds,
    };
  }

  factory BackupEnvelope.fromJson(Map<String, dynamic> json) {
    return BackupEnvelope(
      manifest: BackupManifest.fromJson(
        Map<String, dynamic>.from(json['manifest']! as Map),
      ),
      userFinancialProfile: _readRowListLenient(json, userFinancialProfileKey),
      settings: _readRowListLenient(json, settingsKey),
      cards: _readRowListLenient(json, cardsKey),
      trips: _readRowListLenient(json, tripsKey),
      manualExchangeRates: _readRowListLenient(json, manualExchangeRatesKey),
      expenses: _readRowListLenient(json, expensesKey),
      cashTransactions: _readRowListLenient(json, cashTransactionsKey),
      expenseRefunds: _readRowListLenient(json, expenseRefundsKey),
    );
  }

  /// Restore-only parser: every payload array must be present and typed as a list.
  /// [expenseRefunds] is read leniently — old backups without this key restore
  /// successfully with an empty refund list.
  factory BackupEnvelope.fromJsonStrict(Map<String, dynamic> json) {
    return BackupEnvelope(
      manifest: BackupManifest.fromJson(
        Map<String, dynamic>.from(json['manifest']! as Map),
      ),
      userFinancialProfile: _readRowListStrict(
        json,
        userFinancialProfileKey,
      ),
      settings: _readRowListStrict(json, settingsKey),
      cards: _readRowListStrict(json, cardsKey),
      trips: _readRowListStrict(json, tripsKey),
      manualExchangeRates: _readRowListStrict(
        json,
        manualExchangeRatesKey,
      ),
      expenses: _readRowListStrict(json, expensesKey),
      cashTransactions: _readRowListStrict(json, cashTransactionsKey),
      expenseRefunds: _readRowListLenient(json, expenseRefundsKey),
    );
  }

  static const List<String> requiredPayloadKeys = [
    userFinancialProfileKey,
    settingsKey,
    cardsKey,
    tripsKey,
    manualExchangeRatesKey,
    expensesKey,
    cashTransactionsKey,
  ];

  static List<Map<String, dynamic>> _readRowListLenient(
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

    return _rowListFromRaw(raw, key);
  }

  static List<Map<String, dynamic>> _readRowListStrict(
    Map<String, dynamic> json,
    String key,
  ) {
    if (!json.containsKey(key)) {
      throw FormatException('Missing required key: $key');
    }
    final raw = json[key];
    if (raw == null) {
      throw FormatException('Expected non-null list for $key');
    }
    if (raw is! List) {
      throw FormatException('Expected list for $key');
    }

    return _rowListFromRaw(raw, key);
  }

  static List<Map<String, dynamic>> _rowListFromRaw(List<dynamic> raw, String key) {
    return [
      for (var i = 0; i < raw.length; i++)
        _rowFromElement(raw[i], key: key, index: i),
    ];
  }

  static Map<String, dynamic> _rowFromElement(
    Object? element, {
    required String key,
    required int index,
  }) {
    if (element == null) {
      throw FormatException('Null row at $key[$index]');
    }
    if (element is! Map) {
      throw FormatException('Expected map row at $key[$index]');
    }
    return Map<String, dynamic>.from(element);
  }

  /// Converts domain `toMap()` output into JSON-safe row maps.
  static List<Map<String, dynamic>> rowsFromMaps(
    Iterable<Map<String, Object?>> maps,
  ) {
    return [for (final map in maps) Map<String, dynamic>.from(map)];
  }
}
