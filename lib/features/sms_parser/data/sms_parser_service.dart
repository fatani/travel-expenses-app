import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sms_parse_result.dart';

final smsParserServiceProvider = Provider<SmsParserService>((ref) {
  return const SmsParserService();
});

class SmsParserService {
  const SmsParserService();

  static const Map<String, String> _currencyTokens = <String, String>{
    'USD': 'USD',
    'EUR': 'EUR',
    'GBP': 'GBP',
    'AED': 'AED',
    'SAR': 'SAR',
    'QAR': 'QAR',
    'KWD': 'KWD',
    'OMR': 'OMR',
    'JOD': 'JOD',
    'EGP': 'EGP',
    'TRY': 'TRY',
    'INR': 'INR',
    'PKR': 'PKR',
    r'$': 'USD',
    'US\$': 'USD',
    '€': 'EUR',
    '£': 'GBP',
    'TL': 'TRY',
  };

  static const Map<String, String> _categoryKeywords = <String, String>{
    'uber': 'Transport',
    'taxi': 'Transport',
    'airline': 'Transport',
    'hotel': 'Accommodation',
    'inn': 'Accommodation',
    'restaurant': 'Food',
    'cafe': 'Food',
    'coffee': 'Food',
    'starbucks': 'Food',
    'visa': 'Visa',
    'embassy': 'Visa',
    'mall': 'Shopping',
    'store': 'Shopping',
    'market': 'Shopping',
    'cinema': 'Entertainment',
    'museum': 'Entertainment',
  };

  SmsParseResult parse(String rawText) {
    final compact = rawText.trim().replaceAll(RegExp(r'\s+'), ' ');
    final amountMatch = _extractAmount(compact);
    final merchant = _extractMerchant(compact);

    return SmsParseResult(
      rawText: rawText.trim(),
      amount: amountMatch?.amount,
      currencyCode: amountMatch?.currency,
      spentAt: _extractDateTime(compact),
      merchant: merchant,
      suggestedCategory: _suggestCategory('$compact ${merchant ?? ''}'),
    );
  }

  _AmountMatch? _extractAmount(String input) {
    final patterns = <RegExp>[
      RegExp(
        r'(USD|EUR|GBP|AED|SAR|QAR|KWD|OMR|JOD|EGP|TRY|INR|PKR|US\$|\$|€|£|TL)\s*(\d{1,3}(?:[,.]\d{3})*(?:[,.]\d{1,2})|\d+(?:[,.]\d{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d{1,3}(?:[,.]\d{3})*(?:[,.]\d{1,2})|\d+(?:[,.]\d{1,2})?)\s*(USD|EUR|GBP|AED|SAR|QAR|KWD|OMR|JOD|EGP|TRY|INR|PKR|US\$|\$|€|£|TL)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:spent|purchase|paid|payment|transaction)[^\d]{0,20}(\d{1,3}(?:[,.]\d{3})*(?:[,.]\d{1,2})|\d+(?:[,.]\d{1,2})?)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match == null) {
        continue;
      }

      final first = match.group(1);
      final second = match.group(2);
      final currency = _normalizeCurrency(first) ?? _normalizeCurrency(second);
      final amount = _parseAmount(
        currency == null
            ? first
            : (currency == _normalizeCurrency(first) ? second : first),
      );

      if (amount != null) {
        return _AmountMatch(amount: amount, currency: currency);
      }
    }

    return null;
  }

  String? _normalizeCurrency(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final token = value.trim().toUpperCase();
    return _currencyTokens[token] ?? _currencyTokens[value.trim()];
  }

  double? _parseAmount(String? rawAmount) {
    if (rawAmount == null || rawAmount.trim().isEmpty) {
      return null;
    }

    var amount = rawAmount.replaceAll(' ', '');
    if (amount.contains(',') && amount.contains('.')) {
      amount = amount.replaceAll(',', '');
    } else if (amount.contains(',')) {
      final commaIndex = amount.lastIndexOf(',');
      final decimals = amount.length - commaIndex - 1;
      amount = decimals == 2
          ? amount.replaceAll(',', '.')
          : amount.replaceAll(',', '');
    }

    return double.tryParse(amount);
  }

  DateTime? _extractDateTime(String input) {
    final dmy = RegExp(
      r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?:\s+(\d{1,2}):(\d{2}))?',
    ).firstMatch(input);
    if (dmy != null) {
      final day = int.parse(dmy.group(1)!);
      final month = int.parse(dmy.group(2)!);
      final year = _normalizeYear(int.parse(dmy.group(3)!));
      final hour = int.tryParse(dmy.group(4) ?? '') ?? 0;
      final minute = int.tryParse(dmy.group(5) ?? '') ?? 0;
      return _safeDate(year, month, day, hour, minute);
    }

    final iso = RegExp(
      r'(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?',
    ).firstMatch(input);
    if (iso != null) {
      final year = int.parse(iso.group(1)!);
      final month = int.parse(iso.group(2)!);
      final day = int.parse(iso.group(3)!);
      final hour = int.tryParse(iso.group(4) ?? '') ?? 0;
      final minute = int.tryParse(iso.group(5) ?? '') ?? 0;
      return _safeDate(year, month, day, hour, minute);
    }

    return null;
  }

  int _normalizeYear(int year) {
    if (year >= 100) {
      return year;
    }

    return year >= 70 ? 1900 + year : 2000 + year;
  }

  DateTime? _safeDate(int year, int month, int day, int hour, int minute) {
    try {
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  String? _extractMerchant(String input) {
    final patterns = <RegExp>[
      RegExp(r'(?:at|from|merchant[:\s]+)([^,.\n]+)', caseSensitive: false),
      RegExp(r'(?:desc(?:ription)?[:\s]+)([^,.\n]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match == null) {
        continue;
      }

      final merchant = match.group(1)?.trim();
      if (merchant == null || merchant.isEmpty) {
        continue;
      }

      return _cleanMerchant(merchant);
    }

    return null;
  }

  String _cleanMerchant(String input) {
    var output = input.replaceAll(RegExp(r'\s+'), ' ');
    output = output.split(RegExp(r'\s+on\s+', caseSensitive: false)).first;
    output = output.split(RegExp(r'\s+\d{1,2}[/-]\d{1,2}[/-]\d{2,4}')).first;
    return output.trim();
  }

  String? _suggestCategory(String text) {
    final lower = text.toLowerCase();

    for (final entry in _categoryKeywords.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }
}

class _AmountMatch {
  const _AmountMatch({required this.amount, required this.currency});

  final double amount;
  final String? currency;
}
