/// Shared validation for local-first financial data.
class DataIntegrityException implements Exception {
  const DataIntegrityException(this.code, {this.details});

  final String code;
  final String? details;

  @override
  String toString() => 'DataIntegrityException($code${details == null ? '' : ': $details'})';
}

abstract final class DataIntegrity {
  static final RegExp _currencyCodePattern = RegExp(r'^[A-Z]{3}$');

  static String normalizeCurrencyCode(String value) {
    return value.trim().toUpperCase();
  }

  static void requireNonEmptyId(String id, {String field = 'id'}) {
    if (id.trim().isEmpty) {
      throw DataIntegrityException('emptyId', details: field);
    }
  }

  static void requireNonEmptyTripId(String tripId) {
    requireNonEmptyId(tripId, field: 'tripId');
  }

  static void requireValidCurrencyCode(String currencyCode, {String field = 'currency'}) {
    final normalized = normalizeCurrencyCode(currencyCode);
    if (!_currencyCodePattern.hasMatch(normalized)) {
      throw DataIntegrityException('invalidCurrency', details: field);
    }
  }

  static void requirePositiveAmount(double amount, {String field = 'amount'}) {
    if (amount.isNaN || amount.isInfinite || amount <= 0) {
      throw DataIntegrityException('invalidAmount', details: field);
    }
  }

  static void requireNonNegativeAmount(double amount, {String field = 'amount'}) {
    if (amount.isNaN || amount.isInfinite || amount < 0) {
      throw DataIntegrityException('invalidAmount', details: field);
    }
  }

  static void requirePositiveExchangeRate(double rate) {
    if (rate.isNaN || rate.isInfinite || rate <= 0) {
      throw DataIntegrityException('invalidExchangeRate');
    }
  }

  static void requireDistinctCurrencies(String from, String to) {
    final normalizedFrom = normalizeCurrencyCode(from);
    final normalizedTo = normalizeCurrencyCode(to);
    if (normalizedFrom == normalizedTo) {
      throw DataIntegrityException('sameExchangeCurrencyPair');
    }
  }

  static void requireExpense(ExpenseLike expense) {
    requireNonEmptyTripId(expense.tripId);
    requireNonEmptyId(expense.id, field: 'expenseId');
    requireValidCurrencyCode(expense.transactionCurrency, field: 'transactionCurrency');
    requirePositiveAmount(expense.transactionAmount, field: 'transactionAmount');
    if (expense.title.trim().isEmpty) {
      throw const DataIntegrityException('emptyTitle');
    }
  }

  static void requireTripCurrencies({
    required String baseCurrency,
    String? destinationCurrency,
    String? homeCurrencySnapshot,
    String? budgetCurrency,
  }) {
    requireValidCurrencyCode(baseCurrency, field: 'baseCurrency');
    final destination = destinationCurrency?.trim();
    if (destination != null && destination.isNotEmpty) {
      requireValidCurrencyCode(destination, field: 'destinationCurrency');
    }
    final home = homeCurrencySnapshot?.trim();
    if (home != null && home.isNotEmpty) {
      requireValidCurrencyCode(home, field: 'homeCurrencySnapshot');
    }
    final budget = budgetCurrency?.trim();
    if (budget != null && budget.isNotEmpty) {
      requireValidCurrencyCode(budget, field: 'budgetCurrency');
    }
  }

  static void requireManualExchangeRate({
    required String fromCurrency,
    required String toCurrency,
    required double rate,
  }) {
    requireValidCurrencyCode(fromCurrency, field: 'fromCurrency');
    requireValidCurrencyCode(toCurrency, field: 'toCurrency');
    requireDistinctCurrencies(fromCurrency, toCurrency);
    requirePositiveExchangeRate(rate);
  }

  static void requireCashTransactionInput({
    required String tripId,
    required double amount,
    required String currencyCode,
    bool allowZeroAmount = false,
  }) {
    requireNonEmptyTripId(tripId);
    if (allowZeroAmount) {
      requireNonNegativeAmount(amount);
    } else {
      requirePositiveAmount(amount);
    }
    requireValidCurrencyCode(currencyCode);
  }
}

/// Minimal expense shape for repository validation without importing [Expense].
abstract class ExpenseLike {
  String get id;
  String get tripId;
  String get title;
  double get transactionAmount;
  String get transactionCurrency;
}
