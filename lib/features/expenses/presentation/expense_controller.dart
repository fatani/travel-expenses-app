import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../domain/expense.dart';

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
    required String category,
    required DateTime spentAt,
    required String paymentMethod,
    String source = 'manual',
    String? note,
    String? rawSmsText,
  }) async {
    final expense = Expense.create(
      tripId: _tripId,
      title: title,
      amount: amount,
      currencyCode: currencyCode,
      spentAt: _normalizeDate(spentAt),
      paymentMethod: paymentMethod,
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
    required String category,
    required DateTime spentAt,
    required String paymentMethod,
    String source = 'manual',
    String? note,
    String? rawSmsText,
  }) async {
    final updatedExpense = expense.copyWith(
      title: title,
      amount: amount,
      currencyCode: currencyCode,
      spentAt: _normalizeDate(spentAt),
      paymentMethod: paymentMethod,
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
      state = AsyncData(await _loadExpenses());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
