import 'currency_conversion.dart';
import 'currency_conversion_service.dart';
import 'manual_exchange_rate.dart';
import 'manual_exchange_rate_repository.dart';

class ManualConversionResult {
  const ManualConversionResult({
    required this.rate,
    required this.convertedAmount,
  });

  final double rate;
  final double convertedAmount;
}

class ManualCurrencyConversionService implements CurrencyConversionService {
  const ManualCurrencyConversionService(this._repository);

  final ManualExchangeRateRepository _repository;

  Future<ManualConversionResult?> convert({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final normalizedFrom = fromCurrency.trim().toUpperCase();
    final normalizedTo = toCurrency.trim().toUpperCase();

    if (normalizedFrom == normalizedTo) {
      return ManualConversionResult(rate: 1, convertedAmount: amount);
    }

    final latestRate = await _repository.getLatestRate(
      fromCurrency: normalizedFrom,
      toCurrency: normalizedTo,
    );

    if (latestRate == null) {
      return null;
    }

    return ManualConversionResult(
      rate: latestRate.rate,
      convertedAmount: amount * latestRate.rate,
    );
  }

  Future<void> saveRate(ManualExchangeRate rate) {
    return _repository.saveRate(rate);
  }

  @override
  Future<CurrencyConversion?> getLatestConversion({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final rate = await _repository.getLatestRate(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
    );
    if (rate == null) {
      return null;
    }

    return CurrencyConversion(
      fromCurrency: rate.fromCurrency,
      toCurrency: rate.toCurrency,
      rate: rate.rate,
      createdAt: rate.createdAt,
      isManual: true,
    );
  }

  @override
  Future<void> saveManualConversion(CurrencyConversion conversion) {
    return saveRate(
      ManualExchangeRate.create(
        fromCurrency: conversion.fromCurrency,
        toCurrency: conversion.toCurrency,
        rate: conversion.rate,
        createdAt: conversion.createdAt,
      ),
    );
  }
}
