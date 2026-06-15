import '../../expenses/domain/expense.dart';
import '../../../core/integrity/data_integrity.dart';

/// Derives refund home-currency snapshot per refund model spec §1.4.
({double? homeAmount, String? homeCurrency}) deriveRefundHomeAmount({
  required double? callerHomeAmount,
  required String? callerHomeCurrency,
  required double refundAmount,
  required Expense? linkedExpense,
}) {
  if (callerHomeAmount != null) {
    if (callerHomeCurrency == null || callerHomeCurrency.trim().isEmpty) {
      throw const DataIntegrityException(
        'missingHomeCurrency',
        details: 'homeAmount requires homeCurrency',
      );
    }
    return (
      homeAmount: callerHomeAmount,
      homeCurrency: DataIntegrity.normalizeCurrencyCode(callerHomeCurrency),
    );
  }

  if (linkedExpense == null) {
    return (homeAmount: null, homeCurrency: null);
  }

  final expense = linkedExpense;
  final homeCurrency = expense.homeCurrency?.trim().toUpperCase();
  if (homeCurrency == null || homeCurrency.isEmpty) {
    return (homeAmount: null, homeCurrency: null);
  }

  final rate = expense.conversionRate;
  if (rate != null && rate > 0) {
    return (homeAmount: refundAmount * rate, homeCurrency: homeCurrency);
  }

  final convertedHome = expense.convertedHomeAmount;
  final txAmount = expense.transactionAmount;
  if (convertedHome != null && convertedHome > 0 && txAmount > 0) {
    return (
      homeAmount: (refundAmount / txAmount) * convertedHome,
      homeCurrency: homeCurrency,
    );
  }

  return (homeAmount: null, homeCurrency: null);
}
