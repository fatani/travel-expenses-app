import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../global_reports/data/global_report_provider.dart';
import '../domain/expense.dart';
import '../domain/money_model.dart';

final expenseControllerProvider =
    AsyncNotifierProvider.family<ExpenseController, List<Expense>, String>(
      ExpenseController.new,
    );

class ExpenseController extends FamilyAsyncNotifier<List<Expense>, String> {
  late final String _tripId;

  @override
  Future<List<Expense>> build(String tripId) {
    _tripId = tripId;
    return _loadExpenses();
  }

  Future<void> reload() async {
    state = const AsyncLoading();

    try {
      state = AsyncData(await _loadExpenses());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> createExpense({
    required String title,
    required double amount,
    required String currencyCode,
    MoneyModel? moneyModel,
    double? transactionAmount,
    String? transactionCurrency,
    double? billedAmount,
    String? billedCurrency,
    double? feesAmount,
    String? feesCurrency,
    double? totalChargedAmount,
    String? totalChargedCurrency,
    bool? isInternational,
    required String category,
    required DateTime spentAt,
    required String paymentMethod,
    String? paymentNetwork,
    String? paymentChannel,
    String source = 'manual',
    String? note,
    String? rawSmsText,
  }) async {
    final normalizedMoney = moneyModel ??
        MoneyModel(
          transactionAmount: transactionAmount ?? amount,
          transactionCurrency: transactionCurrency ?? currencyCode,
          billedAmount: billedAmount,
          billedCurrency: billedCurrency,
          feesAmount: feesAmount,
          feesCurrency: feesCurrency,
          totalChargedAmount: totalChargedAmount,
          totalChargedCurrency: totalChargedCurrency,
          isInternational: isInternational ?? false,
        );

    final expense = Expense.create(
      tripId: _tripId,
      title: title,
      amount: amount,
      currencyCode: currencyCode,
      transactionAmount: normalizedMoney.transactionAmount ?? amount,
      transactionCurrency: normalizedMoney.transactionCurrency ?? currencyCode,
      billedAmount: normalizedMoney.billedAmount,
      billedCurrency: normalizedMoney.billedCurrency,
      feesAmount: normalizedMoney.feesAmount,
      feesCurrency: normalizedMoney.feesCurrency,
      totalChargedAmount: normalizedMoney.totalChargedAmount,
      totalChargedCurrency: normalizedMoney.totalChargedCurrency,
      isInternational: moneyModel?.isInternational ?? isInternational,
      spentAt: spentAt,
      paymentMethod: paymentMethod,
      paymentNetwork: paymentNetwork,
      paymentChannel: paymentChannel,
      source: source,
      category: category,
      note: _normalizeText(note),
      rawSmsText: _normalizeText(rawSmsText),
    );

    await _runMutation(
      () => ref.read(expenseRepositoryProvider).createExpense(expense),
    );
  }

  Future<void> updateExpense({
    required Expense expense,
    required String title,
    required double amount,
    required String currencyCode,
    MoneyModel? moneyModel,
    double? transactionAmount,
    String? transactionCurrency,
    double? billedAmount,
    String? billedCurrency,
    double? feesAmount,
    String? feesCurrency,
    double? totalChargedAmount,
    String? totalChargedCurrency,
    bool? isInternational,
    required String category,
    required DateTime spentAt,
    required String paymentMethod,
    String? paymentNetwork,
    String? paymentChannel,
    String source = 'manual',
    String? note,
    String? rawSmsText,
  }) async {
    final normalizedMoney = moneyModel ??
        MoneyModel(
          transactionAmount: transactionAmount ?? amount,
          transactionCurrency: transactionCurrency ?? currencyCode,
          billedAmount: billedAmount,
          billedCurrency: billedCurrency,
          feesAmount: feesAmount,
          feesCurrency: feesCurrency,
          totalChargedAmount: totalChargedAmount,
          totalChargedCurrency: totalChargedCurrency,
          isInternational: isInternational ?? expense.isInternational,
        );

    final updatedExpense = expense.copyWith(
      title: title,
      amount: amount,
      currencyCode: currencyCode,
      transactionAmount: normalizedMoney.transactionAmount ?? amount,
      transactionCurrency: normalizedMoney.transactionCurrency ?? currencyCode,
      billedAmount: normalizedMoney.billedAmount,
      billedCurrency: normalizedMoney.billedCurrency,
      feesAmount: normalizedMoney.feesAmount,
      feesCurrency: normalizedMoney.feesCurrency,
      totalChargedAmount: normalizedMoney.totalChargedAmount,
      totalChargedCurrency: normalizedMoney.totalChargedCurrency,
      isInternational: moneyModel?.isInternational ?? isInternational,
      spentAt: spentAt,
      paymentMethod: paymentMethod,
      paymentNetwork: paymentNetwork,
      paymentChannel: paymentChannel,
      source: source,
      category: category,
      note: _normalizeText(note),
      rawSmsText: _normalizeText(rawSmsText),
    );

    await _runMutation(
      () => ref.read(expenseRepositoryProvider).updateExpense(updatedExpense),
    );
  }

  Future<void> deleteExpense(String expenseId) async {
    await _runMutation(
      () => ref.read(expenseRepositoryProvider).deleteExpense(expenseId),
    );
  }

  Future<List<Expense>> _loadExpenses() {
    return ref.read(expenseRepositoryProvider).getExpensesByTrip(_tripId);
  }

  Future<void> _runMutation(Future<void> Function() mutation) async {
    state = const AsyncLoading();

    try {
      await mutation();
      ref.invalidate(globalReportProvider);
      state = AsyncData(await _loadExpenses());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
