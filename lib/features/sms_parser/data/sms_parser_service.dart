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

  static const List<String> _balanceKeywords = <String>[
    'remaining balance',
    'available balance',
    'balance',
    'الصرف المتبقي',
    'الرصيد المتبقي',
  ];

  static const List<String> _transactionKeywords = <String>[
    'purchase',
    'payment',
    'transaction',
    'pos',
    'apple pay',
    'card used',
    'شراء',
  ];

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
    final amountMatch = _findAmountMatch(normalizedText);
    final merchant = _extractMerchant(normalizedText);

    return SmsParseResult(
      rawText: normalizedText,
      amount: amountMatch?.amount,
      currencyCode: amountMatch?.currencyCode,
      spentAt: _extractDateTime(compact),
      merchant: merchant,
      suggestedCategory: _suggestCategory('$compact ${merchant ?? ''}'),
    );
  }

  _AmountMatch? _findAmountMatch(String input) {
    final lines = input
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return null;
    }

    final prioritizedLines = _prioritizedTransactionLines(lines);
    final fromPriority = _extractAmountFromLines(prioritizedLines);
    if (fromPriority != null) {
      return fromPriority;
    }

    final filteredLines = lines.where((line) => !_isBalanceLine(line)).toList();
    return _extractAmountFromLines(filteredLines);
  }

  List<String> _prioritizedTransactionLines(List<String> lines) {
    final prioritized = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!_isTransactionLine(line)) {
        continue;
      }

      prioritized.add(line);
      if (i + 1 < lines.length) {
        prioritized.add(lines[i + 1]);
      }
      if (i > 0) {
        prioritized.add(lines[i - 1]);
      }
    }

    return prioritized;
  }

  _AmountMatch? _extractAmountFromLines(List<String> lines) {
    const pattern =
        r'(USD|EUR|GBP|AED|SAR|QAR|KWD|BHD|OMR|EGP|TRY|JOD|MAD|INR|PKR|US\$|\$|€|£|TL)';
    final currencyFirst = RegExp(
      '$pattern\\s*(\\d{1,3}(?:[,.]\\d{3})*(?:[,.]\\d{1,2})|\\d+(?:[,.]\\d{1,2})?)',
      caseSensitive: false,
    );
    final amountFirst = RegExp(
      '(\\d{1,3}(?:[,.]\\d{3})*(?:[,.]\\d{1,2})|\\d+(?:[,.]\\d{1,2})?)\\s*$pattern',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (_isBalanceLine(line)) {
        continue;
      }

      final firstMatch = currencyFirst.firstMatch(line);
      if (firstMatch != null) {
        final amount = _parseAmount(firstMatch.group(2));
        final currency = _normalizeCurrency(firstMatch.group(1));
        if (amount != null) {
          return _AmountMatch(amount: amount, currencyCode: currency);
        }
      }

      final secondMatch = amountFirst.firstMatch(line);
      if (secondMatch != null) {
        final amount = _parseAmount(secondMatch.group(1));
        final currency = _normalizeCurrency(secondMatch.group(2));
        if (amount != null) {
          return _AmountMatch(amount: amount, currencyCode: currency);
        }
      }
    }

    return null;
  }

  bool _isTransactionLine(String line) {
    final lower = line.toLowerCase();
    return _transactionKeywords.any(lower.contains);
  }

  bool _isBalanceLine(String line) {
    final lower = line.toLowerCase();
    return _balanceKeywords.any(lower.contains);
  }

  String? _normalizeCurrency(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final key = value.trim().toUpperCase();
    return _currencyAliases[key] ?? _currencyAliases[value.trim()] ?? key;
  }

  double? _parseAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
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
    final lines = input
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final patterns = <RegExp>[
      RegExp(r'(?:from|at|merchant[:\s]+)([^,.\n]+)', caseSensitive: false),
      RegExp(r'(?:من|التاجر[:\s]+)([^,.\n]+)', caseSensitive: false),
      RegExp(r'(?:desc(?:ription)?[:\s]+)([^,.\n]+)', caseSensitive: false),
    ];

    for (final line in lines) {
      if (_isBalanceLine(line)) {
        continue;
      }

      for (final pattern in patterns) {
        final match = pattern.firstMatch(line);
        final value = match?.group(1)?.trim();
        if (value != null && value.isNotEmpty) {
          return _cleanMerchant(value);
        }
      }
    }

    for (final line in lines) {
      if (_isBalanceLine(line)) {
        continue;
      }
      if (_isTransactionLine(line) && !_hasAmountToken(line)) {
        return _cleanMerchant(line);
      }
    }

    return null;
  }

  bool _hasAmountToken(String line) {
    return RegExp(r'\d+(?:[,.]\d{1,2})').hasMatch(line);
  }

  String _cleanMerchant(String value) {
    var cleaned = value.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.split(RegExp(r'\s+on\s+', caseSensitive: false)).first;
    cleaned = cleaned.split(RegExp(r'\s+\d{1,2}[/-]\d{1,2}[/-]\d{2,4}')).first;
    return cleaned.trim();
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
  const _AmountMatch({required this.amount, this.currencyCode});

  final double amount;
  final String? currencyCode;
}
