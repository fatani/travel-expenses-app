import '../../domain/sms_parse_result.dart';

abstract class BaseSmsParser {
  const BaseSmsParser();

  static const Map<String, String> currencyAliases = <String, String>{
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

  static const Map<String, String> categoryKeywords = <String, String>{
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

  SmsParseResult parseGeneric(String rawText) {
    final normalizedText = rawText.trim();
    final lines = normalizedText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final scoredLines = buildScoredLines(lines);

    final amount = extractAmount(scoredLines);
    final merchant = extractMerchant(scoredLines);
    final spentAt = extractDateTime(scoredLines);
    final compact = normalizedText.replaceAll(RegExp(r'\s+'), ' ');
    final transactionCurrency = amount?.currencyCode;

    return SmsParseResult(
      rawText: normalizedText,
      transactionAmount: amount?.amount,
      transactionCurrency: transactionCurrency,
      isInternational: isInternationalTransaction(transactionCurrency, null),
      spentAt: spentAt,
      merchant: merchant,
      suggestedCategory: suggestCategory('$compact ${merchant ?? ''}'),
    );
  }

  List<ScoredLine> buildScoredLines(List<String> lines) {
    final scored = <ScoredLine>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      var score = 0;
      if (isTransactionLine(line)) {
        score += 100;
      }
      if (containsMerchantHint(line)) {
        score += 35;
      }
      if (isBalanceLine(line)) {
        score -= 200;
      }

      scored.add(ScoredLine(text: line, index: i, score: score));
    }

    return scored;
  }

  AmountMatch? extractAmount(List<ScoredLine> scoredLines) {
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

    final candidates = <AmountCandidate>[];
    for (final line in scoredLines) {
      if (isBalanceLine(line.text)) {
        continue;
      }

      for (final match in currencyFirst.allMatches(line.text)) {
        final amount = parseAmount(match.group(2));
        if (amount == null || amount <= 0) {
          continue;
        }

        candidates.add(
          AmountCandidate(
            amount: amount,
            currencyCode: normalizeCurrency(match.group(1)),
            score: line.score,
            lineIndex: line.index,
          ),
        );
      }

      for (final match in amountFirst.allMatches(line.text)) {
        final amount = parseAmount(match.group(1));
        if (amount == null || amount <= 0) {
          continue;
        }

        candidates.add(
          AmountCandidate(
            amount: amount,
            currencyCode: normalizeCurrency(match.group(2)),
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
    final distinctTop =
        topCandidates.map((c) => '${c.amount}|${c.currencyCode ?? ''}').toSet();

    if (distinctTop.length > 1) {
      return null;
    }

    final selected = topCandidates.first;
    return AmountMatch(
      amount: selected.amount,
      currencyCode: selected.currencyCode,
    );
  }

  DateTime? extractDateTime(List<ScoredLine> scoredLines) {
    final candidates = <DateCandidate>[];

    for (final line in scoredLines) {
      if (isBalanceLine(line.text)) {
        continue;
      }

      final slashMatches = RegExp(
        r'(?<!\d)(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?:\s+(\d{1,2}):(\d{2}))?(?!\d)',
      ).allMatches(line.text);
      for (final match in slashMatches) {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final year = normalizeYear(int.parse(match.group(3)!));
        final hour = int.tryParse(match.group(4) ?? '') ?? 0;
        final minute = int.tryParse(match.group(5) ?? '') ?? 0;
        final parsed = safeDate(year, month, day, hour, minute);
        if (parsed != null) {
          candidates.add(DateCandidate(value: parsed, score: line.score));
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
        final parsed = safeDate(year, month, day, hour, minute);
        if (parsed != null) {
          candidates.add(DateCandidate(value: parsed, score: line.score));
        }
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    final topScore = candidates.first.score;
    final topDates =
        candidates.where((d) => d.score == topScore).map((d) => d.value).toSet();

    if (topDates.length > 1) {
      return null;
    }

    return candidates.first.value;
  }

  String? extractMerchant(List<ScoredLine> scoredLines) {
    final patterns = <RegExp>[
      RegExp(r'(?:from|at|merchant[:\s]+)\s*([^,.\n]+)', caseSensitive: false),
      RegExp(r'(?:من|التاجر[:\s]+)\s*([^,.\n]+)', caseSensitive: false),
      RegExp(r'(?:desc(?:ription)?[:\s]+)\s*([^,.\n]+)', caseSensitive: false),
    ];

    final explicitCandidates = <TextCandidate>[];
    for (final line in scoredLines) {
      if (isBalanceLine(line.text)) {
        continue;
      }

      for (final pattern in patterns) {
        final match = pattern.firstMatch(line.text);
        final value = match?.group(1)?.trim();
        if (value == null || value.isEmpty) {
          continue;
        }

        final cleaned = cleanMerchant(value);
        if (cleaned.length < 2) {
          continue;
        }

        explicitCandidates.add(TextCandidate(value: cleaned, score: line.score));
      }
    }

    if (explicitCandidates.isEmpty) {
      return null;
    }

    explicitCandidates.sort((a, b) => b.score.compareTo(a.score));
    final topScore = explicitCandidates.first.score;
    final distinct =
        explicitCandidates.where((c) => c.score == topScore).map((c) => c.value).toSet();
    if (distinct.length > 1) {
      return null;
    }

    return explicitCandidates.first.value;
  }

  bool isTransactionLine(String line) {
    final lower = line.toLowerCase();
    return transactionKeywords.any(lower.contains);
  }

  bool isBalanceLine(String line) {
    final lower = line.toLowerCase();
    return balanceKeywords.any(lower.contains);
  }

  bool containsMerchantHint(String line) {
    final lower = line.toLowerCase();
    return lower.contains('from ') ||
        lower.contains('merchant') ||
        lower.contains(' at ') ||
        lower.contains('من ') ||
        lower.contains('التاجر');
  }

  String? normalizeCurrency(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final key = value.trim().toUpperCase();
    return currencyAliases[key] ?? currencyAliases[value.trim()] ?? key;
  }

  double? parseAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    var normalized = value.replaceAll(' ', '');
    if (normalized.contains(',') && normalized.contains('.')) {
      normalized = normalized.replaceAll(',', '');
    } else if (normalized.contains(',')) {
      final lastComma = normalized.lastIndexOf(',');
      final digitsAfter = normalized.length - lastComma - 1;
      normalized =
          digitsAfter == 2
              ? normalized.replaceAll(',', '.')
              : normalized.replaceAll(',', '');
    }

    return double.tryParse(normalized);
  }

  int normalizeYear(int value) {
    if (value >= 100) {
      return value;
    }

    return value >= 70 ? 1900 + value : 2000 + value;
  }

  DateTime? safeDate(int year, int month, int day, int hour, int minute) {
    try {
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  String cleanMerchant(String value) {
    var cleaned = value.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.split(RegExp(r'\s+on\s+', caseSensitive: false)).first;
    cleaned = cleaned.split(RegExp(r'\s+\d{1,2}[/-]\d{1,2}[/-]\d{2,4}')).first;
    cleaned = cleaned.split(RegExp(r'\s+balance', caseSensitive: false)).first;
    return cleaned.trim();
  }

  String? suggestCategory(String text) {
    final lower = text.toLowerCase();
    for (final entry in categoryKeywords.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  AmountMatch? extractLabeledAmount(
    List<String> lines, {
    required List<String> labels,
    String? defaultCurrency,
  }) {
    final normalizedLabels = labels.map((label) => label.toLowerCase()).toList();
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (!normalizedLabels.any(lower.contains)) {
        continue;
      }

      final amountFirst = RegExp(
        r'(\d+(?:[.,]\d{1,2})?)\s*(USD|EUR|GBP|AED|QAR|KWD|BHD|OMR|SAR|SR|THB)',
        caseSensitive: false,
      ).firstMatch(line);
      if (amountFirst != null) {
        final amount = parseAmount(amountFirst.group(1));
        if (amount != null && amount > 0) {
          return AmountMatch(
            amount: amount,
            currencyCode: normalizeCurrency(amountFirst.group(2)),
          );
        }
      }

      final currencyFirst = RegExp(
        r'(USD|EUR|GBP|AED|QAR|KWD|BHD|OMR|SAR|SR|THB)\s*(\d+(?:[.,]\d{1,2})?)',
        caseSensitive: false,
      ).firstMatch(line);
      if (currencyFirst != null) {
        final amount = parseAmount(currencyFirst.group(2));
        if (amount != null && amount > 0) {
          return AmountMatch(
            amount: amount,
            currencyCode: normalizeCurrency(currencyFirst.group(1)),
          );
        }
      }

      if (defaultCurrency != null) {
        final numberOnly = RegExp(
          r'(\d+(?:[.,]\d{1,2})?)',
          caseSensitive: false,
        ).firstMatch(line);
        if (numberOnly != null) {
          final amount = parseAmount(numberOnly.group(1));
          if (amount != null && amount > 0) {
            return AmountMatch(amount: amount, currencyCode: defaultCurrency);
          }
        }
      }
    }

    return null;
  }

  bool isInternationalTransaction(String? currency, double? feesAmount) {
    if (currency == null || currency.isEmpty) {
      return (feesAmount ?? 0) > 0;
    }

    return currency.trim().toUpperCase() != 'SAR' || (feesAmount ?? 0) > 0;
  }
}

class ScoredLine {
  const ScoredLine({required this.text, required this.index, required this.score});

  final String text;
  final int index;
  final int score;
}

class AmountCandidate {
  const AmountCandidate({
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

class DateCandidate {
  const DateCandidate({required this.value, required this.score});

  final DateTime value;
  final int score;
}

class TextCandidate {
  const TextCandidate({required this.value, required this.score});

  final String value;
  final int score;
}

class AmountMatch {
  const AmountMatch({required this.amount, this.currencyCode});

  final double amount;
  final String? currencyCode;

  AmountMatch copyWith({double? amount, String? currencyCode}) {
    return AmountMatch(
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}

class PaymentDetails {
  const PaymentDetails({this.network, this.channel, this.executionMethod});

  final String? network;
  final String? channel;
  final String? executionMethod;
}
