import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/finance/manual_currency_conversion_service.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate_repository.dart';

class _FakeManualExchangeRateRepository implements ManualExchangeRateRepository {
  _FakeManualExchangeRateRepository(this._latestRate);

  ManualExchangeRate? _latestRate;

  @override
  Future<ManualExchangeRate?> getLatestRate({
    String? tripId,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    if (_latestRate == null) {
      return null;
    }

    if (_latestRate!.fromCurrency == fromCurrency &&
        _latestRate!.toCurrency == toCurrency) {
      return _latestRate;
    }

    return null;
  }

  @override
  Future<void> saveRate(ManualExchangeRate rate) async {
    _latestRate = rate;
  }

  @override
  Future<List<ManualExchangeRate>> listLatestTripRates(String tripId) async {
    if (_latestRate == null) {
      return const [];
    }

    if (_latestRate!.tripId == tripId) {
      return [_latestRate!];
    }

    return const [];
  }
}

void main() {
  test('returns converted amount when manual rate exists', () async {
    final repo = _FakeManualExchangeRateRepository(
      ManualExchangeRate.create(
        fromCurrency: 'THB',
        toCurrency: 'SAR',
        rate: 0.103,
      ),
    );
    final service = ManualCurrencyConversionService(repo);

    final result = await service.convert(
      amount: 300,
      fromCurrency: 'THB',
      toCurrency: 'SAR',
    );

    expect(result, isNotNull);
    expect(result!.rate, 0.103);
    expect(result.convertedAmount, closeTo(30.9, 0.0001));
  });

  test('returns null when no manual rate exists', () async {
    final repo = _FakeManualExchangeRateRepository(null);
    final service = ManualCurrencyConversionService(repo);

    final result = await service.convert(
      amount: 300,
      fromCurrency: 'THB',
      toCurrency: 'SAR',
    );

    expect(result, isNull);
  });
}
