import '../../domain/sms_parse_result.dart';
import '../../domain/sms_parser_contract.dart';
import 'base_sms_parser.dart';
import 'generic_sms_parser.dart';

class SnbSmsParser extends BaseSmsParser implements SmsBankParser {
  const SnbSmsParser();

  static const List<String> _transactionKeywords = <String>[
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
  String get parserName => 'snb';

  @override
  bool supports(SmsBank bank) => bank == SmsBank.snb;

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
    final billed = extractLabeledAmount(
      lines,
      labels: const <String>['amount in sar'],
      defaultCurrency: 'SAR',
    );
    final fees = extractLabeledAmount(
      lines,
      labels: const <String>['international fees', 'fees'],
      defaultCurrency: 'SAR',
    );
    final totalCharged = extractLabeledAmount(
      lines,
      labels: const <String>['total amount in sar', 'total amount'],
      defaultCurrency: 'SAR',
    );
    final merchant = _extractMerchantFromLines(lines);
    final spentAt = _extractDateFromLines(lines);
    final transactionCurrency = amountResult?.currencyCode;

    return SmsParseResult(
      rawText: normalizedText,
      transactionAmount: amountResult?.amount,
      transactionCurrency: transactionCurrency,
      billedAmount: billed?.amount,
      billedCurrency: billed?.currencyCode,
      feesAmount: fees?.amount,
      feesCurrency: fees?.currencyCode,
      totalChargedAmount: totalCharged?.amount,
      totalChargedCurrency: totalCharged?.currencyCode,
      isInternational: isInternationalTransaction(transactionCurrency, fees?.amount),
      merchant: merchant,
      spentAt: spentAt,
      suggestedCategory: _suggestSnbCategory('$compact ${merchant ?? ''}'),
    );
  }

  AmountMatch? _extractAmountFromLines(List<String> lines, int transactionIndex) {
    if (transactionIndex == -1) {
      return null;
    }

    final candidates = <AmountCandidate>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      if (_isSnbBalanceLine(lower)) {
        continue;
      }

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
    return AmountMatch(
      amount: selected.amount,
      currencyCode: selected.currencyCode,
    );
  }

  AmountCandidate? _extractAmountCandidateFromLine({
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
        final score =
            lineIndex == transactionIndex + 1
                ? 3
                : lineIndex == transactionIndex
                ? 2
                : 1;
        return AmountCandidate(
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
        final score =
            lineIndex == transactionIndex + 1
                ? 3
                : lineIndex == transactionIndex
                ? 2
                : 1;
        return AmountCandidate(
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

      final englishMatch = RegExp(
        r'^(?:from)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
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
    return _transactionKeywords.any(lower.contains);
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
    return parseAmount(value);
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
    return safeDate(year, month, day, hour, minute);
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
