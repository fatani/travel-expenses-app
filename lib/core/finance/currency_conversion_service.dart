import 'currency_conversion.dart';

abstract class CurrencyConversionService {
  Future<CurrencyConversion?> getLatestConversion({
    required String fromCurrency,
    required String toCurrency,
  });

  Future<void> saveManualConversion(CurrencyConversion conversion);
}
