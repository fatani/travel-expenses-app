import '../../domain/sms_parse_result.dart';
import '../../domain/sms_parser_contract.dart';
import 'base_sms_parser.dart';

class AlRajhiSmsParser extends BaseSmsParser implements SmsBankParser {
  const AlRajhiSmsParser();

  static const List<String> _amountIgnoredKeywords = <String>[
    'رصيد',
    'رسوم وضريبة',
    'اجمالي المبلغ المستحق',
    'إجمالي المبلغ المستحق',
    'سعر الصرف',
    'دولة',
  ];

  @override
  String get parserName => 'al_rajhi';

  @override
  bool supports(SmsBank bank) => bank == SmsBank.alRajhi;

  @override
  SmsParseResult parse(String rawText) {
    final normalizedText = rawText.trim();
    final lines = normalizedText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final amount = _extractAlRajhiAmount(lines);
    final billed = _extractAlRajhiBilledAmount(lines);
    final fees = extractLabeledAmount(
      lines,
      labels: const <String>['رسوم وضريبة'],
      defaultCurrency: 'SAR',
    );
    final totalCharged = extractLabeledAmount(
      lines,
      labels: const <String>['اجمالي المبلغ المستحق', 'إجمالي المبلغ المستحق'],
      defaultCurrency: 'SAR',
    );
    final merchant = _extractAlRajhiMerchant(lines);
    final spentAt = _extractAlRajhiDateTime(lines);
    final paymentDetails = _extractAlRajhiPaymentDetails(lines);
    final compact = normalizedText.replaceAll(RegExp(r'\s+'), ' ');
    final transactionCurrency = amount?.currencyCode;

    return SmsParseResult(
      rawText: normalizedText,
      transactionAmount: amount?.amount,
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
      suggestedCategory: suggestCategory('$compact ${merchant ?? ''}'),
      suggestedPaymentMethod: _resolvePaymentMethodCompatibility(
        paymentDetails.network,
        paymentDetails.channel,
      ),
      suggestedPaymentNetwork: paymentDetails.network,
      suggestedPaymentChannel: paymentDetails.channel,
      suggestedPaymentDetail: paymentDetails.executionMethod,
    );
  }

  AmountMatch? _extractAlRajhiBilledAmount(List<String> lines) {
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (!lower.startsWith('مبلغ')) {
        continue;
      }

      final parentheticalSar = RegExp(
        r'\((\d+(?:[.,]\d{1,2})?)\s*(?:ريال|SAR|SR)\)',
        caseSensitive: false,
      ).firstMatch(line);
      if (parentheticalSar == null) {
        continue;
      }

      final amount = parseAmount(parentheticalSar.group(1));
      if (amount != null && amount > 0) {
        return AmountMatch(amount: amount, currencyCode: 'SAR');
      }
    }

    return null;
  }

  PaymentDetails _extractAlRajhiPaymentDetails(List<String> lines) {
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

    return PaymentDetails(
      network: network,
      channel: channel,
      executionMethod: executionMethod,
    );
  }

  String? _resolvePaymentMethodCompatibility(String? network, String? channel) {
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

  AmountMatch? _extractAlRajhiAmount(List<String> lines) {
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
        final amount = parseAmount(internetAmount.group(2));
        if (amount != null && amount > 0) {
          return AmountMatch(
            amount: amount,
            currencyCode: _normalizeAlRajhiCurrency(internetAmount.group(1)),
          );
        }
      }
    }

    final candidates = <AmountMatch>[];
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
        final amount = parseAmount(amountFirst.group(1));
        if (amount != null && amount > 0) {
          candidates.add(
            AmountMatch(
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
        final amount = parseAmount(currencyFirst.group(2));
        if (amount != null && amount > 0) {
          candidates.add(
            AmountMatch(
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

  AmountMatch? _extractAmountFromLabeledLine(String line) {
    final amountFirst = RegExp(
      r'مبلغ\s*:\s*(\d+(?:[.,]\d{1,2})?)\s*(USD|EUR|GBP|AED|QAR|KWD|BHD|OMR|SAR|SR)',
      caseSensitive: false,
    ).firstMatch(line);
    if (amountFirst != null) {
      final amount = parseAmount(amountFirst.group(1));
      if (amount != null && amount > 0) {
        return AmountMatch(
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
      final amount = parseAmount(currencyFirst.group(2));
      if (amount != null && amount > 0) {
        return AmountMatch(
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
        final merchant = cleanMerchant(match.group(1)!);
        if (merchant.length >= 2) {
          return merchant;
        }
      }
    }

    for (final line in lines) {
      final match = RegExp(r'^لـ\s*:?(.*)$').firstMatch(line);
      if (match != null) {
        final merchant = cleanMerchant(match.group(1) ?? '');
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
      final year = normalizeYear(int.parse(match.group(3)!));
      final hour = int.parse(match.group(4)!);
      final minute = int.parse(match.group(5)!);
      final parsed = safeDate(year, month, day, hour, minute);
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
  String cleanMerchant(String value) {
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
  List<String> get balanceKeywords => const <String>['رصيد'];
}
