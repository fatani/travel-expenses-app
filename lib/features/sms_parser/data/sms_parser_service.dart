import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sms_parse_result.dart';

final smsParserServiceProvider = Provider<SmsParserService>((ref) {
  return const SmsParserService();
});

class SmsParserService {
  const SmsParserService({List<SmsMessageParser>? parsers})
      : _parsers = parsers ?? const <SmsMessageParser>[
          SaudiBankSmsParser(),
          AlRajhiSmsParser(),
          GenericSmsParser(),
        ];

  final List<SmsMessageParser> _parsers;

  static const Map<String, String> _digitNormalization = <String, String>{
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  static final RegExp _directionalMarksPattern = RegExp(
    r'[\u200E\u200F\u202A-\u202E\u2066-\u2069\u061C]',
  );

  static String normalizeIncomingText(String input) {
    if (input.isEmpty) {
      return input;
    }

    var normalized = input
        .replaceAll(_directionalMarksPattern, '')
        .replaceAll('\u00A0', ' ')
        .replaceAll('٫', '.')
        .replaceAll('٬', ',');

    for (final entry in _digitNormalization.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }

    return normalized;
  }

  SmsParseResult parse(String rawText) {
    final normalizedText = normalizeIncomingText(rawText).trim();
    if (normalizedText.isEmpty) {
      return const SmsParseResult(rawText: '');
    }

    final selectedParsers = _parsers
        .where((parser) => parser.canParse(normalizedText))
        .toList();

    for (final parser in selectedParsers) {
      final result = parser.parse(normalizedText);
      if (result.hasAnyValue) {
        return result;
      }
    }

    return SmsParseResult(rawText: normalizedText);
  }
}

abstract class SmsMessageParser {
  const SmsMessageParser();

  bool canParse(String rawText);
  SmsParseResult parse(String rawText);
}

class SaudiBankSmsParser extends _BaseSmsMessageParser {
  const SaudiBankSmsParser();

  static const List<String> _snbIndicators = <String>[
    'بطاقة ائتمانية',
    'التاريخ',
    'الصرف المتبقي',
  ];

  static const List<String> _snbTransactionKeywords = <String>[
    'شراء',
    'purchase',
  ];

  static const List<String> _balanceLineKeywords = <String>[
    'المتبقي',
    'الرصيد',
    'remaining balance',
    'available balance',
    'balance',
  ];

  @override
  bool canParse(String rawText) {
    final lower = rawText.toLowerCase();
    final matched = _snbIndicators.where(lower.contains).toList();
    return matched.isNotEmpty;
  }

  @override
  SmsParseResult parse(String rawText) {
    final normalizedText = rawText.trim();
    final lines = normalizedText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final compact = normalizedText.replaceAll(RegExp(r'\s+'), ' ');

    final transactionIndex = lines.indexWhere(_isSnbTransactionLine);

    final amountResult = _extractAmountFromLines(lines, transactionIndex);
    final merchant = _extractMerchantFromLines(lines);
    final spentAt = _extractDateFromLines(lines);

    return SmsParseResult(
      rawText: normalizedText,
      amount: amountResult?.amount,
      currencyCode: amountResult?.currencyCode,
      merchant: merchant,
      spentAt: spentAt,
      suggestedCategory: _suggestSnbCategory('$compact ${merchant ?? ''}'),
    );
  }

  _AmountMatch? _extractAmountFromLines(List<String> lines, int transactionIndex) {
    if (transactionIndex == -1) {
      return null;
    }

    final candidates = <_AmountCandidate>[];
    // Fix: \b does not work for Arabic chars (they are \W in Dart regex).
    // Use containsAny approach instead of regex for more reliable matching.

    // Pass 1: prioritize explicitly labeled transaction amount lines.
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      if (_isSnbBalanceLine(lower)) {
        continue;
      }

      // Check if line contains "amount" or "مبلغ" (label keywords)
      final hasAmountLabel = lower.contains('amount') || line.contains('مبلغ');
      if (!hasAmountLabel) {
        continue;
      }

      final candidate = _extractAmountCandidateFromLine(
        line: line,
        lineIndex: i,
        transactionIndex: transactionIndex,
      );
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    // Pass 2: fallback to plain amount lines if no labeled line was found.
    if (candidates.isEmpty) {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lower = line.toLowerCase();
        if (_isSnbBalanceLine(lower)) {
          continue;
        }

        final candidate = _extractAmountCandidateFromLine(
          line: line,
          lineIndex: i,
          transactionIndex: transactionIndex,
        );
        if (candidate != null) {
          candidates.add(candidate);
        }
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) {
        return score;
      }
      return a.lineIndex.compareTo(b.lineIndex);
    });

    final topScore = candidates.first.score;
    final topCandidates = candidates.where((c) => c.score == topScore).toList();
    final distinct = topCandidates
        .map((c) => '${c.amount}|${c.currencyCode ?? ''}')
        .toSet();
    if (distinct.length > 1) {
      return null;
    }

    final selected = topCandidates.first;
    return _AmountMatch(
      amount: selected.amount,
      currencyCode: selected.currencyCode,
    );
  }

  _AmountCandidate? _extractAmountCandidateFromLine({
    required String line,
    required int lineIndex,
    required int transactionIndex,
  }) {
    const currencyPattern =
        '(USD|EUR|GBP|AED|SAR|QAR|KWD|BHD|OMR|EGP|TRY|JOD|MAD|INR|PKR|US\\\$|\\\$|€|£|TL)';
    final amountFirstPattern = RegExp(
      r'(?<!\d)(\d{1,3}(?:[,.]\d{3})*(?:[,.]\d{1,2})|\d+(?:[,.]\d{1,2})?)\s*'
      '$currencyPattern(?!\\w)',
      caseSensitive: false,
    );
    final currencyFirstPattern = RegExp(
      '$currencyPattern\\s*'
      r'(\d{1,3}(?:[,.]\d{3})*(?:[,.]\d{1,2})|\d+(?:[,.]\d{1,2})?)(?!\d)',
      caseSensitive: false,
    );

    final amountFirst = amountFirstPattern.firstMatch(line);
    if (amountFirst != null) {
      final amount = _parseSnbAmount(amountFirst.group(1));
      if (amount != null && amount > 0) {
        final score = lineIndex == transactionIndex + 1
            ? 3
            : lineIndex == transactionIndex
                ? 2
                : 1;
        return _AmountCandidate(
          amount: amount,
          currencyCode: _normalizeSnbCurrency(amountFirst.group(2)),
          score: score,
          lineIndex: lineIndex,
        );
      }
    }

    final currencyFirst = currencyFirstPattern.firstMatch(line);
    if (currencyFirst != null) {
      final amount = _parseSnbAmount(currencyFirst.group(2));
      if (amount != null && amount > 0) {
        final score = lineIndex == transactionIndex + 1
            ? 3
            : lineIndex == transactionIndex
                ? 2
                : 1;
        return _AmountCandidate(
          amount: amount,
          currencyCode: _normalizeSnbCurrency(currencyFirst.group(1)),
          score: score,
          lineIndex: lineIndex,
        );
      }
    }

    return null;
  }

  String? _extractMerchantFromLines(List<String> lines) {
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_isSnbBalanceLine(lower)) {
        continue;
      }

      final arabicMatch = RegExp(r'^من\s+(.+)$').firstMatch(line);
      if (arabicMatch != null) {
        final merchant = _cleanSnbMerchant(arabicMatch.group(1)!.trim());
        if (merchant.length >= 2) {
          return merchant;
        }
      }

      final englishMatch = RegExp(r'^(?:from)\s+(.+)$', caseSensitive: false)
          .firstMatch(line);
      if (englishMatch != null) {
        final merchant = _cleanSnbMerchant(englishMatch.group(1)!.trim());
        if (merchant.length >= 2) {
          return merchant;
        }
      }
    }

    return null;
  }

  DateTime? _extractDateFromLines(List<String> lines) {
    for (final line in lines) {
      if (!line.contains('التاريخ')) {
        continue;
      }

      final slash = RegExp(
        r'(?<!\d)(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?:\s+(\d{1,2}):(\d{2}))?(?!\d)',
      ).firstMatch(line);
      if (slash != null) {
        final day = int.parse(slash.group(1)!);
        final month = int.parse(slash.group(2)!);
        final year = _normalizeSnbYear(int.parse(slash.group(3)!));
        final hour = int.tryParse(slash.group(4) ?? '') ?? 0;
        final minute = int.tryParse(slash.group(5) ?? '') ?? 0;
        final parsed = _safeSnbDate(year, month, day, hour, minute);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    for (final line in lines) {
      final iso = RegExp(
        r'(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?(?!\d)',
      ).firstMatch(line);
      if (iso == null) {
        continue;
      }

      final year = int.parse(iso.group(1)!);
      final month = int.parse(iso.group(2)!);
      final day = int.parse(iso.group(3)!);
      final hour = int.tryParse(iso.group(4) ?? '') ?? 0;
      final minute = int.tryParse(iso.group(5) ?? '') ?? 0;
      final parsed = _safeSnbDate(year, month, day, hour, minute);
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  bool _isSnbTransactionLine(String line) {
    final lower = line.toLowerCase();
    return _snbTransactionKeywords.any(lower.contains);
  }

  bool _isSnbBalanceLine(String line) {
    final lowerLine = line.toLowerCase();
    return _balanceLineKeywords.any(lowerLine.contains);
  }

  String? _normalizeSnbCurrency(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return value.trim().toUpperCase().replaceAll('.', '');
  }

  double? _parseSnbAmount(String? value) {
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

  String _cleanSnbMerchant(String value) {
    var cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.split(RegExp(r'\s+التاريخ\b')).first;
    cleaned = cleaned.split(RegExp(r'\s+on\s+', caseSensitive: false)).first;
    return cleaned.trim();
  }

  int _normalizeSnbYear(int value) {
    if (value >= 100) {
      return value;
    }

    return value >= 70 ? 1900 + value : 2000 + value;
  }

  DateTime? _safeSnbDate(int year, int month, int day, int hour, int minute) {
    try {
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  String? _suggestSnbCategory(String text) {
    return const GenericSmsParser().parse(text).suggestedCategory;
  }

  @override
  List<String> get transactionKeywords => const <String>[
        'purchase',
        'payment',
        'transaction',
        'pos',
        'apple pay',
        'card used',
        'شراء',
        'مدى',
        'سداد',
      ];

  @override
  List<String> get balanceKeywords => const <String>[
        'remaining balance',
        'available balance',
        'balance',
        'الصرف المتبقي',
        'الرصيد المتبقي',
        'الرصيد الحالي',
      ];
}

class AlRajhiSmsParser extends _BaseSmsMessageParser {
  const AlRajhiSmsParser();

  static const List<String> _markers = <String>[
    'شراء عبر نقاط البيع',
    'شراء إنترنت',
    'شراء انترنت',
    'بطاقة:',
    'عبر',
    'لدى:',
    'لـ',
    'رصيد:',
  ];

  static const List<String> _transactionMarkers = <String>[
    'شراء عبر نقاط البيع',
    'شراء إنترنت',
    'شراء انترنت',
  ];

  static const List<String> _amountIgnoredKeywords = <String>[
    'رصيد',
    'رسوم وضريبة',
    'اجمالي المبلغ المستحق',
    'إجمالي المبلغ المستحق',
    'سعر الصرف',
    'دولة',
  ];

  @override
  bool canParse(String rawText) {
    final lower = rawText.toLowerCase();
    final markerHits = _markers.where((marker) => lower.contains(marker)).length;
    final hasTransactionMarker =
        _transactionMarkers.any((marker) => lower.contains(marker));
    return hasTransactionMarker && markerHits >= 3;
  }

  @override
  SmsParseResult parse(String rawText) {
    final normalizedText = rawText.trim();
    final lines = normalizedText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final amount = _extractAlRajhiAmount(lines);
    final merchant = _extractAlRajhiMerchant(lines);
    final spentAt = _extractAlRajhiDateTime(lines);
    final paymentDetails = _extractAlRajhiPaymentDetails(lines);
    final compact = normalizedText.replaceAll(RegExp(r'\s+'), ' ');

    return SmsParseResult(
      rawText: normalizedText,
      amount: amount?.amount,
      currencyCode: amount?.currencyCode,
      merchant: merchant,
      spentAt: spentAt,
      suggestedCategory: _suggestCategory('$compact ${merchant ?? ''}'),
      suggestedPaymentMethod: _resolvePaymentMethodCompatibility(
        paymentDetails.network,
        paymentDetails.channel,
      ),
      suggestedPaymentNetwork: paymentDetails.network,
      suggestedPaymentChannel: paymentDetails.channel,
    );
  }

  _PaymentDetails _extractAlRajhiPaymentDetails(List<String> lines) {
    String? network;
    String? channel;
    String? executionMethod;

    for (final line in lines) {
      if (!line.contains(';')) {
        continue;
      }
      final afterSemicolon = line.split(';').last.trim().toLowerCase();
      if (afterSemicolon.contains('فيزا') || afterSemicolon.contains('visa')) {
        network = 'Visa';
      } else if (afterSemicolon.contains('مدى') ||
          afterSemicolon.contains('mada')) {
        network = 'Mada';
      } else if (afterSemicolon.contains('mastercard')) {
        network = 'Mastercard';
      }

      if (afterSemicolon.contains('ابل باي') ||
          afterSemicolon.contains('apple pay')) {
        executionMethod = 'Apple Pay';
      } else if (afterSemicolon.contains('google pay')) {
        executionMethod = 'Google Pay';
      }

      if (network != null || executionMethod != null) {
        break;
      }
    }

    final compact = lines.join(' ').toLowerCase();
    if (compact.contains('شراء إنترنت') ||
        compact.contains('شراء انترنت') ||
        compact.contains('internet') ||
        compact.contains('online')) {
      channel = 'Online Purchase';
    } else if (compact.contains('شراء عبر نقاط البيع') ||
        compact.contains('pos')) {
      channel = 'POS Purchase';
    }

    return _PaymentDetails(
      network: network,
      channel: channel,
      executionMethod: executionMethod,
    );
  }

  String? _resolvePaymentMethodCompatibility(
    String? network,
    String? channel,
  ) {
    if (channel == 'POS Purchase' || channel == 'Online Purchase') {
      if (network == 'Mada') {
        return 'Debit Card';
      }
      if (network == 'Visa' || network == 'Mastercard') {
        return 'Credit Card';
      }
    }
    if (channel == 'Apple Pay' || channel == 'Google Pay') {
      return 'Mobile Wallet';
    }
    if (network == 'Mada') {
      return 'Debit Card';
    }
    if (network == 'Visa' || network == 'Mastercard') {
      return 'Credit Card';
    }
    if (channel == 'Online Purchase' || channel == 'POS Purchase') {
      return 'Other';
    }
    return null;
  }

  _AmountMatch? _extractAlRajhiAmount(List<String> lines) {
    // Pass 1: explicit مبلغ line is the highest-confidence transaction amount.
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (!lower.startsWith('مبلغ')) {
        continue;
      }
      final labeled = _extractAmountFromLabeledLine(line);
      if (labeled != null) {
        return labeled;
      }
    }

    // Pass 2: internet purchase line with currency prefix like: بـSR 6.97.
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_isIgnoredAmountLine(lower)) {
        continue;
      }
      if (!lower.contains('شراء إنترنت') && !lower.contains('شراء انترنت')) {
        continue;
      }

      final internetAmount = RegExp(
        r'بـ?\s*(SR|SAR|USD|EUR|GBP|AED|QAR|KWD|BHD|OMR)\s*(\d+(?:[.,]\d{1,2})?)',
        caseSensitive: false,
      ).firstMatch(line);
      if (internetAmount != null) {
        final amount = _parseAmount(internetAmount.group(2));
        if (amount != null && amount > 0) {
          return _AmountMatch(
            amount: amount,
            currencyCode: _normalizeAlRajhiCurrency(internetAmount.group(1)),
          );
        }
      }
    }

    // Pass 3: fallback to any non-ignored amount/currency candidate.
    final candidates = <_AmountMatch>[];
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_isIgnoredAmountLine(lower)) {
        continue;
      }

      final amountFirst = RegExp(
        r'(?<!\d)(\d+(?:[.,]\d{1,2})?)\s*(USD|EUR|GBP|AED|QAR|KWD|BHD|OMR|SAR|SR)(?!\w)',
        caseSensitive: false,
      ).firstMatch(line);
      if (amountFirst != null) {
        final amount = _parseAmount(amountFirst.group(1));
        if (amount != null && amount > 0) {
          candidates.add(
            _AmountMatch(
              amount: amount,
              currencyCode: _normalizeAlRajhiCurrency(amountFirst.group(2)),
            ),
          );
        }
      }

      final currencyFirst = RegExp(
        r'(?<!\w)(USD|EUR|GBP|AED|QAR|KWD|BHD|OMR|SAR|SR)\s*(\d+(?:[.,]\d{1,2})?)(?!\d)',
        caseSensitive: false,
      ).firstMatch(line);
      if (currencyFirst != null) {
        final amount = _parseAmount(currencyFirst.group(2));
        if (amount != null && amount > 0) {
          candidates.add(
            _AmountMatch(
              amount: amount,
              currencyCode: _normalizeAlRajhiCurrency(currencyFirst.group(1)),
            ),
          );
        }
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    final distinct = candidates
        .map((candidate) => '${candidate.amount}|${candidate.currencyCode ?? ''}')
        .toSet();
    if (distinct.length > 1) {
      return null;
    }

    return candidates.first;
  }

  _AmountMatch? _extractAmountFromLabeledLine(String line) {
    final amountFirst = RegExp(
      r'مبلغ\s*:\s*(\d+(?:[.,]\d{1,2})?)\s*(USD|EUR|GBP|AED|QAR|KWD|BHD|OMR|SAR|SR)',
      caseSensitive: false,
    ).firstMatch(line);
    if (amountFirst != null) {
      final amount = _parseAmount(amountFirst.group(1));
      if (amount != null && amount > 0) {
        return _AmountMatch(
          amount: amount,
          currencyCode: _normalizeAlRajhiCurrency(amountFirst.group(2)),
        );
      }
    }

    final currencyFirst = RegExp(
      r'مبلغ\s*:\s*(USD|EUR|GBP|AED|QAR|KWD|BHD|OMR|SAR|SR)\s*(\d+(?:[.,]\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(line);
    if (currencyFirst != null) {
      final amount = _parseAmount(currencyFirst.group(2));
      if (amount != null && amount > 0) {
        return _AmountMatch(
          amount: amount,
          currencyCode: _normalizeAlRajhiCurrency(currencyFirst.group(1)),
        );
      }
    }

    return null;
  }

  String? _extractAlRajhiMerchant(List<String> lines) {
    for (final line in lines) {
      final match = RegExp(r'^لدى\s*:\s*(.+)$').firstMatch(line);
      if (match != null) {
        final merchant = _cleanMerchant(match.group(1)!);
        if (merchant.length >= 2) {
          return merchant;
        }
      }
    }

    for (final line in lines) {
      final match = RegExp(r'^لـ\s*:?(.*)$').firstMatch(line);
      if (match != null) {
        final merchant = _cleanMerchant(match.group(1) ?? '');
        if (merchant.length >= 2) {
          return merchant;
        }
      }
    }

    return null;
  }

  DateTime? _extractAlRajhiDateTime(List<String> lines) {
    final pattern = RegExp(
      r'(?:في\s*:?)?\s*(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\s+(\d{1,2}):(\d{2})',
      caseSensitive: false,
    );

    for (final line in lines.reversed) {
      final match = pattern.firstMatch(line);
      if (match == null) {
        continue;
      }

      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = _normalizeYear(int.parse(match.group(3)!));
      final hour = int.parse(match.group(4)!);
      final minute = int.parse(match.group(5)!);
      final parsed = _safeDate(year, month, day, hour, minute);
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  bool _isIgnoredAmountLine(String lowerLine) {
    return _amountIgnoredKeywords.any((keyword) => lowerLine.contains(keyword));
  }

  String? _normalizeAlRajhiCurrency(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final upper = value.trim().toUpperCase();
    if (upper == 'SR') {
      return 'SAR';
    }
    return upper;
  }

  @override
  String _cleanMerchant(String value) {
    var cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.split(RegExp(r'\s+رصيد\s*:', caseSensitive: false)).first;
    cleaned = cleaned.split(RegExp(r'\s+في\s*:', caseSensitive: false)).first;
    return cleaned.trim();
  }

  @override
  List<String> get transactionKeywords => const <String>[
        'شراء',
        'شراء عبر نقاط البيع',
        'شراء إنترنت',
        'شراء انترنت',
      ];

  @override
  List<String> get balanceKeywords => const <String>[
        'رصيد',
      ];
}

class GenericSmsParser extends _BaseSmsMessageParser {
  const GenericSmsParser();

  @override
  bool canParse(String rawText) => true;

  @override
  List<String> get transactionKeywords => const <String>[
        'purchase',
        'payment',
        'transaction',
        'pos',
        'card used',
        'spent',
        'debit',
        'شراء',
      ];

  @override
  List<String> get balanceKeywords => const <String>[
        'remaining balance',
        'available balance',
        'balance',
        'outstanding',
        'الصرف المتبقي',
        'الرصيد المتبقي',
      ];
}

abstract class _BaseSmsMessageParser implements SmsMessageParser {
  const _BaseSmsMessageParser();

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

  List<String> get transactionKeywords;
  List<String> get balanceKeywords;

  @override
  SmsParseResult parse(String rawText) {
    final normalizedText = rawText.trim();
    final lines = normalizedText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final scoredLines = _buildScoredLines(lines);

    final amount = _extractAmount(scoredLines);
    final merchant = _extractMerchant(scoredLines);
    final spentAt = _extractDateTime(scoredLines);
    final compact = normalizedText.replaceAll(RegExp(r'\s+'), ' ');

    return SmsParseResult(
      rawText: normalizedText,
      amount: amount?.amount,
      currencyCode: amount?.currencyCode,
      spentAt: spentAt,
      merchant: merchant,
      suggestedCategory: _suggestCategory('$compact ${merchant ?? ''}'),
    );
  }

  List<_ScoredLine> _buildScoredLines(List<String> lines) {
    final scored = <_ScoredLine>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      var score = 0;
      if (_isTransactionLine(line)) {
        score += 100;
      }
      if (_containsMerchantHint(line)) {
        score += 35;
      }
      if (_isBalanceLine(line)) {
        score -= 200;
      }

      scored.add(_ScoredLine(text: line, index: i, score: score));
    }

    return scored;
  }

  _AmountMatch? _extractAmount(List<_ScoredLine> scoredLines) {
    if (scoredLines.isEmpty) {
      return null;
    }

    const currencyPattern =
        r'(USD|EUR|GBP|AED|SAR|QAR|KWD|BHD|OMR|EGP|TRY|JOD|MAD|INR|PKR|US\$|\$|€|£|TL)';
    final currencyFirst = RegExp(
      '$currencyPattern\\s*(\\d{1,3}(?:[,.]\\d{3})*(?:[,.]\\d{1,2})|\\d+(?:[,.]\\d{1,2})?)',
      caseSensitive: false,
    );
    final amountFirst = RegExp(
      '(\\d{1,3}(?:[,.]\\d{3})*(?:[,.]\\d{1,2})|\\d+(?:[,.]\\d{1,2})?)\\s*$currencyPattern',
      caseSensitive: false,
    );

    final candidates = <_AmountCandidate>[];
    for (final line in scoredLines) {
      if (_isBalanceLine(line.text)) {
        continue;
      }

      for (final match in currencyFirst.allMatches(line.text)) {
        final amount = _parseAmount(match.group(2));
        if (amount == null || amount <= 0) {
          continue;
        }

        candidates.add(
          _AmountCandidate(
            amount: amount,
            currencyCode: _normalizeCurrency(match.group(1)),
            score: line.score,
            lineIndex: line.index,
          ),
        );
      }

      for (final match in amountFirst.allMatches(line.text)) {
        final amount = _parseAmount(match.group(1));
        if (amount == null || amount <= 0) {
          continue;
        }

        candidates.add(
          _AmountCandidate(
            amount: amount,
            currencyCode: _normalizeCurrency(match.group(2)),
            score: line.score,
            lineIndex: line.index,
          ),
        );
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      return a.lineIndex.compareTo(b.lineIndex);
    });

    final topScore = candidates.first.score;
    final topCandidates = candidates.where((c) => c.score == topScore).toList();
    final distinctTop = topCandidates
        .map((c) => '${c.amount}|${c.currencyCode ?? ''}')
        .toSet();

    if (distinctTop.length > 1) {
      return null;
    }

    final selected = topCandidates.first;
    return _AmountMatch(
      amount: selected.amount,
      currencyCode: selected.currencyCode,
    );
  }

  DateTime? _extractDateTime(List<_ScoredLine> scoredLines) {
    final candidates = <_DateCandidate>[];

    for (final line in scoredLines) {
      if (_isBalanceLine(line.text)) {
        continue;
      }

      final slashMatches = RegExp(
        r'(?<!\d)(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?:\s+(\d{1,2}):(\d{2}))?(?!\d)',
      ).allMatches(line.text);
      for (final match in slashMatches) {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final year = _normalizeYear(int.parse(match.group(3)!));
        final hour = int.tryParse(match.group(4) ?? '') ?? 0;
        final minute = int.tryParse(match.group(5) ?? '') ?? 0;
        final parsed = _safeDate(year, month, day, hour, minute);
        if (parsed != null) {
          candidates.add(_DateCandidate(value: parsed, score: line.score));
        }
      }

      final isoMatches = RegExp(
        r'(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?(?!\d)',
      ).allMatches(line.text);
      for (final match in isoMatches) {
        final year = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final day = int.parse(match.group(3)!);
        final hour = int.tryParse(match.group(4) ?? '') ?? 0;
        final minute = int.tryParse(match.group(5) ?? '') ?? 0;
        final parsed = _safeDate(year, month, day, hour, minute);
        if (parsed != null) {
          candidates.add(_DateCandidate(value: parsed, score: line.score));
        }
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    final topScore = candidates.first.score;
    final topDates = candidates
        .where((d) => d.score == topScore)
        .map((d) => d.value)
        .toSet();

    if (topDates.length > 1) {
      return null;
    }

    return candidates.first.value;
  }

  String? _extractMerchant(List<_ScoredLine> scoredLines) {
    final patterns = <RegExp>[
      RegExp(r'(?:from|at|merchant[:\s]+)\s*([^,.\n]+)', caseSensitive: false),
      RegExp(r'(?:من|التاجر[:\s]+)\s*([^,.\n]+)', caseSensitive: false),
      RegExp(r'(?:desc(?:ription)?[:\s]+)\s*([^,.\n]+)', caseSensitive: false),
    ];

    final explicitCandidates = <_TextCandidate>[];
    for (final line in scoredLines) {
      if (_isBalanceLine(line.text)) {
        continue;
      }

      for (final pattern in patterns) {
        final match = pattern.firstMatch(line.text);
        final value = match?.group(1)?.trim();
        if (value == null || value.isEmpty) {
          continue;
        }

        final cleaned = _cleanMerchant(value);
        if (cleaned.length < 2) {
          continue;
        }

        explicitCandidates.add(_TextCandidate(value: cleaned, score: line.score));
      }
    }

    if (explicitCandidates.isEmpty) {
      return null;
    }

    explicitCandidates.sort((a, b) => b.score.compareTo(a.score));
    final topScore = explicitCandidates.first.score;
    final distinct = explicitCandidates
        .where((c) => c.score == topScore)
        .map((c) => c.value)
        .toSet();
    if (distinct.length > 1) {
      return null;
    }

    return explicitCandidates.first.value;
  }

  bool _isTransactionLine(String line) {
    final lower = line.toLowerCase();
    return transactionKeywords.any(lower.contains);
  }

  bool _isBalanceLine(String line) {
    final lower = line.toLowerCase();
    return balanceKeywords.any(lower.contains);
  }

  bool _containsMerchantHint(String line) {
    final lower = line.toLowerCase();
    return lower.contains('from ') ||
        lower.contains('merchant') ||
        lower.contains(' at ') ||
        lower.contains('من ') ||
        lower.contains('التاجر');
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

  String _cleanMerchant(String value) {
    var cleaned = value.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.split(RegExp(r'\s+on\s+', caseSensitive: false)).first;
    cleaned = cleaned.split(RegExp(r'\s+\d{1,2}[/-]\d{1,2}[/-]\d{2,4}')).first;
    cleaned = cleaned.split(RegExp(r'\s+balance', caseSensitive: false)).first;
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

class _ScoredLine {
  const _ScoredLine({
    required this.text,
    required this.index,
    required this.score,
  });

  final String text;
  final int index;
  final int score;
}

class _AmountCandidate {
  const _AmountCandidate({
    required this.amount,
    required this.currencyCode,
    required this.score,
    required this.lineIndex,
  });

  final double amount;
  final String? currencyCode;
  final int score;
  final int lineIndex;
}

class _DateCandidate {
  const _DateCandidate({required this.value, required this.score});

  final DateTime value;
  final int score;
}

class _TextCandidate {
  const _TextCandidate({required this.value, required this.score});

  final String value;
  final int score;
}

class _AmountMatch {
  const _AmountMatch({required this.amount, this.currencyCode});

  final double amount;
  final String? currencyCode;
}

class _PaymentDetails {
  const _PaymentDetails({this.network, this.channel, this.executionMethod});

  final String? network;
  final String? channel;
  final String? executionMethod;
}
