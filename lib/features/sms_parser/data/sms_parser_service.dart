import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sms_parse_result.dart';

final smsParserServiceProvider = Provider<SmsParserService>((ref) {
  return const SmsParserService();
});

class SmsParserService {
  const SmsParserService();

  static const Map<String, String> _currencyAliases = <String, String>{
    'USD': 'USD',
    'EUR': 'EUR',
    'GBP': 'GBP',
    'AED': 'AED',
    'SAR': 'SAR',
    'QAR': 'QAR',
    'KWD': 'KWD',
    'BHD': 'BHD',
    'OMR': 'OMR',
    'EGP': 'EGP',
    'TRY': 'TRY',
    'JOD': 'JOD',
    'MAD': 'MAD',
    'INR': 'INR',
    'PKR': 'PKR',
    r'$': 'USD',
    'US\$': 'USD',
    '€': 'EUR',
    '£': 'GBP',
    'TL': 'TRY',
    'AED.': 'AED',
    'SAR.': 'SAR',
  };

  static const Map<String, String> _categoryKeywords = <String, String>{
    'uber': 'Transport',
    'taxi': 'Transport',
    'metro': 'Transport',
    'airline': 'Transport',
    'hotel': 'Accommodation',
    'inn': 'Accommodation',
    'restaurant': 'Food',
    'cafe': 'Food',
    'coffee': 'Food',
    'starbucks': 'Food',
    'burger': 'Food',
    'visa': 'Visa',
    'embassy': 'Visa',
    'mall': 'Shopping',
    'store': 'Shopping',
    'market': 'Shopping',
    'cinema': 'Entertainment',
    'museum': 'Entertainment',
  };

  SmsParseResult parse(String rawText) {
    final normalizedText = rawText.trim();
    final compact = normalizedText.replaceAll(RegExp(r'\s+'), ' ');
    final amountMatch = _findAmountMatch(compact);
    final merchant = _extractMerchant(compact);

    return SmsParseResult(
      rawText: normalizedText,
      amount: amountMatch?.amount,
      currencyCode: amountMatch?.currencyCode,
      spentAt: _extractDateTime(compact),
      merchant: merchant,
      suggestedCategory: _suggestCategory(compact, merchant),
    );
  }

  _AmountMatch? _findAmountMatch(String input) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:(USD|EUR|GBP|AED|SAR|QAR|KWD|BHD|OMR|EGP|TRY|JOD|MAD|INR|PKR|US\$|\$|€|£|TL)\s*)(\d{1,3}(?:[,.]\d{3})*(?:[,.]\d{2})|\d+(?:[,.]\d{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d{1,3}(?:[,.]\d{3})*(?:[,.]\d{2})|\d+(?:[,.]\d{1,2})?)\s*(USD|EUR|GBP|AED|SAR|QAR|KWD|BHD|OMR|EGP|TRY|JOD|MAD|INR|PKR|US\$|\$|€|£|TL)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:spent|purchase|payment|paid|trx|transaction)[^\d]{0,20}(\d{1,3}(?:[,.]\d{3})*(?:[,.]\d{2})|\d+(?:[,.]\d{1,2})?)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match == null) {
        continue;
      }

      final groups = match.groups(<int>[1, 2]);
      final first = groups[0];
      final second = groups[1];
      final currencyToken =
          _currencyAliases.containsKey((first ?? '').toUpperCase()) ||
              _currencyAliases.containsKey(first ?? '')
          ? first
          : second;
      final amountToken = currencyToken == first ? second : first;
      final parsedAmount = _parseAmount(amountToken);
      if (parsedAmount == null) {
        continue;
      }

      return _AmountMatch(
        amount: parsedAmount,
        currencyCode: _normalizeCurrency(currencyToken),
      );
    }

    return null;
  }

  double? _parseAmount(String? value) {
    if (value == null) {
      return null;
    }

    var normalized = value.replaceAll(' ', '');
    if (normalized.contains(',') && normalized.contains('.')) {
      normalized = normalized.replaceAll(',', '');
    } else if (normalized.contains(',')) {
      final lastComma = normalized.lastIndexOf(',');
      final digitsAfter = normalized.length - lastComma - 1;
      normalized = digitsAfter == 2
          ? normalized.replaceAll(',', '.')
          : normalized.replaceAll(',', '');
    }

    return double.tryParse(normalized);
  }

  String? _normalizeCurrency(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final upper = value.trim().toUpperCase();
    return _currencyAliases[upper] ?? _currencyAliases[value.trim()] ?? upper;
  }

  DateTime? _extractDateTime(String input) {
    final slashMatch = RegExp(
      r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?:\s+(\d{1,2}):(\d{2}))?',
    ).firstMatch(input);
    if (slashMatch != null) {
      final day = int.parse(slashMatch.group(1)!);
      final month = int.parse(slashMatch.group(2)!);
      final year = _normalizeYear(int.parse(slashMatch.group(3)!));
      final hour = int.tryParse(slashMatch.group(4) ?? '') ?? 0;
      final minute = int.tryParse(slashMatch.group(5) ?? '') ?? 0;
      return _safeDate(year, month, day, hour, minute);
    }

    final isoMatch = RegExp(
      r'(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?',
    ).firstMatch(input);
    if (isoMatch != null) {
      final year = int.parse(isoMatch.group(1)!);
      final month = int.parse(isoMatch.group(2)!);
      final day = int.parse(isoMatch.group(3)!);
      final hour = int.tryParse(isoMatch.group(4) ?? '') ?? 0;
      final minute = int.tryParse(isoMatch.group(5) ?? '') ?? 0;
      return _safeDate(year, month, day, hour, minute);
    }

    return null;
  }

  int _normalizeYear(int value) {
    if (value >= 100) {
      return value;
    }

    return value >= 70 ? 1900 + value : 2000 + value;
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
      RegExp(
        r'(?:purchase|payment|transaction)[^a-zA-Z0-9]{0,8}at\s+([^,.\n]+)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match == null) {
        continue;
      }

      final value = match.group(1)?.trim();
      if (value == null || value.isEmpty) {
        continue;
      }

      return _cleanMerchant(value);
    }

    return null;
  }

  String _cleanMerchant(String value) {
    var cleaned = value.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.split(RegExp(r'\s+on\s+', caseSensitive: false)).first;
    cleaned = cleaned.split(RegExp(r'\s+at\s+\d{1,2}:\d{2}')).first;
    cleaned = cleaned.split(RegExp(r'\s+\d{1,2}[/-]\d{1,2}[/-]\d{2,4}')).first;
    return cleaned.trim();
  }

  String? _suggestCategory(String input, String? merchant) {
    final haystack = '${merchant ?? ''} $input'.toLowerCase();
    for (final entry in _categoryKeywords.entries) {
      if (haystack.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }
}

class _AmountMatch {
  const _AmountMatch({required this.amount, this.currencyCode});

  final double amount;
  final String? currencyCode;
}
