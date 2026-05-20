import '../../expenses/domain/money_model.dart';
import 'sms_parse_result.dart';

extension SmsParseResultMoneyMapper on SmsParseResult {
  MoneyModel toMoneyModel() {
    final transactionCurrencyNormalized = transactionCurrency?.trim().toUpperCase();
    final billedCurrencyNormalized = billedCurrency?.trim().toUpperCase();
    final totalCurrencyNormalized = totalChargedCurrency?.trim().toUpperCase();

    final billedDiffers = _moneyDiffers(
      primaryAmount: transactionAmount,
      primaryCurrency: transactionCurrencyNormalized,
      candidateAmount: billedAmount,
      candidateCurrency: billedCurrencyNormalized,
    );

    final totalDiffers = _moneyDiffers(
      primaryAmount: transactionAmount,
      primaryCurrency: transactionCurrencyNormalized,
      candidateAmount: totalChargedAmount,
      candidateCurrency: totalCurrencyNormalized,
    );

    final inferredInternational =
        (transactionCurrencyNormalized != null &&
            transactionCurrencyNormalized.isNotEmpty &&
            transactionCurrencyNormalized != 'SAR') ||
        feesAmount != null ||
        billedDiffers ||
        totalDiffers;

    return MoneyModel(
      transactionAmount: transactionAmount,
      transactionCurrency: transactionCurrencyNormalized,
      billedAmount: billedAmount,
      billedCurrency: billedCurrencyNormalized,
      totalChargedAmount: totalChargedAmount,
      totalChargedCurrency: totalCurrencyNormalized,
      feesAmount: feesAmount,
      feesCurrency: feesCurrency?.trim().toUpperCase(),
      isInternational: inferredInternational,
    );
  }

  bool _moneyDiffers({
    required double? primaryAmount,
    required String? primaryCurrency,
    required double? candidateAmount,
    required String? candidateCurrency,
  }) {
    if (candidateAmount == null && (candidateCurrency == null || candidateCurrency.isEmpty)) {
      return false;
    }

    final currencyDiffers =
        candidateCurrency != null &&
        candidateCurrency.isNotEmpty &&
        primaryCurrency != null &&
        primaryCurrency.isNotEmpty &&
        candidateCurrency != primaryCurrency;

    final amountDiffers =
        primaryAmount != null &&
        candidateAmount != null &&
        (candidateAmount - primaryAmount).abs() > 0.000001;

    return currencyDiffers || amountDiffers;
  }
}
