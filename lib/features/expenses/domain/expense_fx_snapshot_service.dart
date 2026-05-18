import '../../cash_wallet/data/cash_wallet_repository.dart';
import '../domain/expense.dart';
import '../domain/money_model.dart';
import 'expense_payment_service.dart';

class ExpenseConversionSnapshot {
  // FX snapshots are immutable write-time facts used by reports later.
  // We resolve once at save/update and never mutate historical rows in place.
  const ExpenseConversionSnapshot({
    required this.originalAmount,
    required this.originalCurrency,
    required this.convertedHomeAmount,
    required this.homeCurrency,
    required this.conversionRate,
    required this.missingManualRate,
  });

  final double? originalAmount;
  final String? originalCurrency;
  final double? convertedHomeAmount;
  final String? homeCurrency;
  final double? conversionRate;
  final bool missingManualRate;
}

class ExpenseFxSnapshotService {
  const ExpenseFxSnapshotService({
    required CashWalletRepository cashWalletRepository,
  }) : _cashWalletRepository = cashWalletRepository;

  final CashWalletRepository _cashWalletRepository;

  Future<ExpenseConversionSnapshot> resolveCreateSnapshot({
    required String tripId,
    required double fallbackAmount,
    required String fallbackCurrencyCode,
    required MoneyModel normalizedMoney,
    double? originalAmount,
    String? originalCurrency,
    double? convertedHomeAmount,
    String? homeCurrency,
    double? conversionRate,
    String? tripHomeCurrency,
    required String paymentMethod,
    String? paymentChannel,
  }) {
    return _resolveSnapshot(
      tripId: tripId,
      fallbackAmount: fallbackAmount,
      fallbackCurrencyCode: fallbackCurrencyCode,
      normalizedMoney: normalizedMoney,
      originalAmount: originalAmount,
      originalCurrency: originalCurrency,
      convertedHomeAmount: convertedHomeAmount,
      homeCurrency: homeCurrency,
      conversionRate: conversionRate,
      tripHomeCurrency: tripHomeCurrency,
      paymentMethod: paymentMethod,
      paymentChannel: paymentChannel,
    );
  }

  Future<ExpenseConversionSnapshot> resolveUpdateSnapshot({
    required String tripId,
    required double fallbackAmount,
    required String fallbackCurrencyCode,
    required MoneyModel normalizedMoney,
    double? originalAmount,
    String? originalCurrency,
    double? convertedHomeAmount,
    String? homeCurrency,
    double? conversionRate,
    String? tripHomeCurrency,
    required Expense previousExpense,
    required String paymentMethod,
    String? paymentChannel,
    bool forceClearSnapshot = false,
  }) {
    return _resolveSnapshot(
      tripId: tripId,
      fallbackAmount: fallbackAmount,
      fallbackCurrencyCode: fallbackCurrencyCode,
      normalizedMoney: normalizedMoney,
      originalAmount: originalAmount,
      originalCurrency: originalCurrency,
      convertedHomeAmount: convertedHomeAmount,
      homeCurrency: homeCurrency,
      conversionRate: conversionRate,
      tripHomeCurrency: tripHomeCurrency,
      previousExpense: previousExpense,
      paymentMethod: paymentMethod,
      paymentChannel: paymentChannel,
      forceClearSnapshot: forceClearSnapshot,
    );
  }

  Future<ExpenseConversionSnapshot> _resolveSnapshot({
    required String tripId,
    required double fallbackAmount,
    required String fallbackCurrencyCode,
    required MoneyModel normalizedMoney,
    double? originalAmount,
    String? originalCurrency,
    double? convertedHomeAmount,
    String? homeCurrency,
    double? conversionRate,
    String? tripHomeCurrency,
    Expense? previousExpense,
    required String paymentMethod,
    String? paymentChannel,
    bool forceClearSnapshot = false,
  }) async {
    final normalizedTransactionAmount =
        normalizedMoney.transactionAmount ?? fallbackAmount;
    final normalizedTransactionCurrency =
        _normalizeCurrency(
          normalizedMoney.transactionCurrency ?? fallbackCurrencyCode,
        ) ??
        fallbackCurrencyCode.trim().toUpperCase();
    final normalizedOriginalAmount = originalAmount ?? normalizedTransactionAmount;
    final normalizedOriginalCurrency =
        _normalizeCurrency(originalCurrency) ?? normalizedTransactionCurrency;
    final normalizedHomeCurrency = _normalizeCurrency(
      homeCurrency ?? tripHomeCurrency ?? previousExpense?.homeCurrency,
    );

    final isCashPayment = isCashExpensePayment(
      paymentMethod: paymentMethod,
      paymentChannel: paymentChannel,
    );
    final wasCashPayment = previousExpense != null &&
        isCashExpensePayment(
          paymentMethod: previousExpense.paymentMethod,
          paymentChannel: previousExpense.paymentChannel,
        );

    if (normalizedHomeCurrency == null || normalizedHomeCurrency.isEmpty) {
      return ExpenseConversionSnapshot(
        originalAmount: null,
        originalCurrency: null,
        convertedHomeAmount: null,
        homeCurrency: null,
        conversionRate: null,
        missingManualRate: false,
      );
    }

    if (conversionRate != null) {
      return ExpenseConversionSnapshot(
        originalAmount: normalizedOriginalAmount,
        originalCurrency: normalizedOriginalCurrency,
        convertedHomeAmount: normalizedOriginalAmount * conversionRate,
        homeCurrency: normalizedHomeCurrency,
        conversionRate: conversionRate,
        missingManualRate: false,
      );
    }

    if (!isCashPayment) {
      final cardFx = _resolveCardProvidedFxSnapshot(
        normalizedMoney: normalizedMoney,
        normalizedHomeCurrency: normalizedHomeCurrency,
        normalizedTransactionAmount: normalizedTransactionAmount,
        normalizedTransactionCurrency: normalizedTransactionCurrency,
      );
      if (cardFx != null) {
        return cardFx;
      }

      if (forceClearSnapshot) {
        return const ExpenseConversionSnapshot(
          originalAmount: null,
          originalCurrency: null,
          convertedHomeAmount: null,
          homeCurrency: null,
          conversionRate: null,
          missingManualRate: false,
        );
      }

      if (previousExpense != null &&
          !wasCashPayment &&
          previousExpense.conversionRate != null &&
          _canInheritPreviousRate(
            previousExpense: previousExpense,
            currentOriginalCurrency: normalizedTransactionCurrency,
            currentHomeCurrency: normalizedHomeCurrency,
          )) {
        // Inherited rates are valid only within the same currency pair.
        final storedRate = previousExpense.conversionRate!;
        return ExpenseConversionSnapshot(
          originalAmount: normalizedTransactionAmount,
          originalCurrency: normalizedTransactionCurrency,
          convertedHomeAmount: normalizedTransactionAmount * storedRate,
          homeCurrency: normalizedHomeCurrency,
          conversionRate: storedRate,
          missingManualRate: false,
        );
      }

      return ExpenseConversionSnapshot(
        originalAmount: null,
        originalCurrency: null,
        convertedHomeAmount: null,
        homeCurrency: null,
        conversionRate: null,
        missingManualRate: normalizedTransactionCurrency != normalizedHomeCurrency,
      );
    }

    final shouldKeepCashRate =
        previousExpense != null &&
        wasCashPayment &&
        isCashPayment &&
        previousExpense.conversionRate != null &&
        _canInheritPreviousRate(
          previousExpense: previousExpense,
          currentOriginalCurrency: normalizedOriginalCurrency,
          currentHomeCurrency: normalizedHomeCurrency,
        );

    if (shouldKeepCashRate) {
      // Inherited rates are valid only within the same currency pair.
      final storedRate = previousExpense.conversionRate!;
      return ExpenseConversionSnapshot(
        originalAmount: normalizedOriginalAmount,
        originalCurrency: normalizedOriginalCurrency,
        convertedHomeAmount: normalizedOriginalAmount * storedRate,
        homeCurrency: normalizedHomeCurrency,
        conversionRate: storedRate,
        missingManualRate: false,
      );
    }

    if (normalizedTransactionCurrency == normalizedHomeCurrency) {
      return ExpenseConversionSnapshot(
        originalAmount: normalizedTransactionAmount,
        originalCurrency: normalizedTransactionCurrency,
        convertedHomeAmount: normalizedTransactionAmount,
        homeCurrency: normalizedHomeCurrency,
        conversionRate: 1,
        missingManualRate: false,
      );
    }

    try {
      final cashRate = await _cashWalletRepository.getEffectiveCashRate(
        tripId: tripId,
        transactionCurrencyCode: normalizedTransactionCurrency,
        homeCurrencyCode: normalizedHomeCurrency,
      );

      if (cashRate != null) {
        return ExpenseConversionSnapshot(
          originalAmount: normalizedTransactionAmount,
          originalCurrency: normalizedTransactionCurrency,
          convertedHomeAmount: normalizedTransactionAmount * cashRate,
          homeCurrency: normalizedHomeCurrency,
          conversionRate: cashRate,
          missingManualRate: false,
        );
      }
    } catch (_) {
      // Ignore and return empty conversion snapshot below.
    }

    return const ExpenseConversionSnapshot(
      originalAmount: null,
      originalCurrency: null,
      convertedHomeAmount: null,
      homeCurrency: null,
      conversionRate: null,
      missingManualRate: true,
    );
  }

  bool _canInheritPreviousRate({
    required Expense previousExpense,
    required String currentOriginalCurrency,
    required String currentHomeCurrency,
  }) {
    final previousOriginalCurrency = _normalizeCurrency(previousExpense.originalCurrency);
    final previousHomeCurrency = _normalizeCurrency(previousExpense.homeCurrency);
    // Cross-currency comparisons are dangerous; only match an exact pair.
    return previousOriginalCurrency == currentOriginalCurrency &&
        previousHomeCurrency == currentHomeCurrency;
  }

  String? _normalizeCurrency(String? value) {
    final trimmed = value?.trim().toUpperCase();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  ExpenseConversionSnapshot? _resolveCardProvidedFxSnapshot({
    required MoneyModel normalizedMoney,
    required String normalizedHomeCurrency,
    required double normalizedTransactionAmount,
    required String normalizedTransactionCurrency,
  }) {
    final chargedAmount = normalizedMoney.totalChargedAmount;
    final chargedCurrency = _normalizeCurrency(normalizedMoney.totalChargedCurrency);

    if (chargedAmount == null || chargedAmount <= 0 || chargedCurrency == null) {
      return null;
    }

    if (chargedCurrency == normalizedHomeCurrency) {
      return ExpenseConversionSnapshot(
        originalAmount: normalizedTransactionAmount,
        originalCurrency: normalizedTransactionCurrency,
        convertedHomeAmount: chargedAmount,
        homeCurrency: normalizedHomeCurrency,
        conversionRate: chargedAmount / normalizedTransactionAmount,
        missingManualRate: false,
      );
    }

    if (chargedCurrency == normalizedTransactionCurrency) {
      return ExpenseConversionSnapshot(
        originalAmount: normalizedTransactionAmount,
        originalCurrency: normalizedTransactionCurrency,
        convertedHomeAmount: chargedAmount,
        // Home currency must remain the trip/home snapshot, never charged FX currency.
        homeCurrency: normalizedHomeCurrency,
        conversionRate: chargedAmount / normalizedTransactionAmount,
        missingManualRate: false,
      );
    }

    return null;
  }
}