import '../../domain/sms_parse_result.dart';
import '../../domain/sms_parser_contract.dart';
import 'base_sms_parser.dart';

class D360SmsParser extends BaseSmsParser implements SmsBankParser {
  const D360SmsParser();

  static final RegExp _amountWithBillingPattern = RegExp(
    r'مبلغ\s*:\s*([A-Z]{3})\s*([\d,]+(?:\.\d{1,2})?)\s*\(\s*SAR\s*([\d,]+(?:\.\d{1,2})?)\s*\)',
    caseSensitive: false,
  );

  static final RegExp _amountPattern = RegExp(
    r'مبلغ\s*:\s*([A-Z]{3})\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _merchantPattern = RegExp(r'لدى\s*:\s*(.+)$');

  static final RegExp _timeFirstIsoDatePattern = RegExp(
    r'في\s*:\s*(\d{1,2}):(\d{2})\s+(\d{4})[-/](\d{1,2})[-/](\d{1,2})',
    caseSensitive: false,
  );

  static final RegExp _dateFirstPattern = RegExp(
    r'في\s*:\s*(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\s+(\d{1,2}):(\d{2})',
    caseSensitive: false,
  );

  static final RegExp _timeFirstLegacyPattern = RegExp(
    r'في\s*:\s*(\d{1,2}):(\d{2})\s+(\d{1,2})/(\d{1,2})/(\d{2,4})',
    caseSensitive: false,
  );

  @override
  String get parserName => 'd360';

  @override
  bool supports(SmsBank bank) => bank == SmsBank.d360;

  @override
  SmsParseResult parse(String rawText) {
    final normalizedText = rawText.trim();
    final lines = normalizedText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final amountData = _extractAmountData(lines);
    final fees = extractLabeledAmount(
      lines,
      labels: const <String>['fees', 'fee', 'رسوم', 'رسوم وضريبة'],
    );
    final totalCharged = extractLabeledAmount(
      lines,
      labels: const <String>['total charged', 'total amount', 'اجمالي', 'إجمالي المبلغ المستحق'],
    );
    final merchant = _extractMerchant(lines);
    final spentAt = _extractDateTime(lines);
    final payment = _extractPaymentData(lines);
    final compact = normalizedText.replaceAll(RegExp(r'\s+'), ' ');
    final transactionCurrency = amountData.transactionCurrency;
    final inferredInternational =
        amountData.isInternational ??
        isInternationalTransaction(transactionCurrency, fees?.amount);

    return SmsParseResult(
      rawText: normalizedText,
      transactionAmount: amountData.transactionAmount,
      transactionCurrency: transactionCurrency,
      billedAmount: amountData.billedAmount,
      billedCurrency: amountData.billedCurrency,
      feesAmount: fees?.amount,
      feesCurrency: fees?.currencyCode,
      totalChargedAmount: totalCharged?.amount,
      totalChargedCurrency: totalCharged?.currencyCode,
      isInternational: inferredInternational,
      merchant: merchant,
      spentAt: spentAt,
      suggestedCategory: suggestCategory('$compact ${merchant ?? ''}'),
      suggestedPaymentMethod: _resolvePaymentMethod(payment.network),
      suggestedPaymentNetwork: payment.network,
      suggestedPaymentChannel: payment.channel,
      suggestedPaymentDetail: _buildPaymentDetail(payment),
    );
  }

  _D360AmountData _extractAmountData(List<String> lines) {
    for (final line in lines) {
      final withBilling = _amountWithBillingPattern.firstMatch(line);
      if (withBilling != null) {
        final transactionCurrency = withBilling.group(1)!.toUpperCase();
        final transactionAmount = parseAmount(withBilling.group(2));
        final billedAmount = parseAmount(withBilling.group(3));

        return _D360AmountData(
          transactionAmount: transactionAmount,
          transactionCurrency: transactionCurrency,
          billedAmount: billedAmount,
          billedCurrency: billedAmount == null ? null : 'SAR',
          isInternational:
              transactionCurrency != 'SAR' && billedAmount != null,
        );
      }
    }

    for (final line in lines) {
      final basic = _amountPattern.firstMatch(line);
      if (basic == null) {
        continue;
      }

      final currency = basic.group(1)!.toUpperCase();
      final amount = parseAmount(basic.group(2));

      return _D360AmountData(
        transactionAmount: amount,
        transactionCurrency: currency,
        billedAmount: null,
        billedCurrency: null,
        isInternational: false,
      );
    }

    return const _D360AmountData();
  }

  String? _extractMerchant(List<String> lines) {
    for (final line in lines) {
      final match = _merchantPattern.firstMatch(line);
      if (match == null) {
        continue;
      }

      final merchant = _cleanD360Merchant(match.group(1) ?? '');
      if (merchant.length >= 2) {
        return merchant;
      }
    }

    return null;
  }

  DateTime? _extractDateTime(List<String> lines) {
    for (final line in lines) {
      final timeFirstIso = _timeFirstIsoDatePattern.firstMatch(line);
      if (timeFirstIso != null) {
        final hour = int.parse(timeFirstIso.group(1)!);
        final minute = int.parse(timeFirstIso.group(2)!);
        final year = int.parse(timeFirstIso.group(3)!);
        final month = int.parse(timeFirstIso.group(4)!);
        final day = int.parse(timeFirstIso.group(5)!);
        final parsed = safeDate(year, month, day, hour, minute);
        if (parsed != null) {
          return parsed;
        }
      }

      final dateFirst = _dateFirstPattern.firstMatch(line);
      if (dateFirst != null) {
        final day = int.parse(dateFirst.group(1)!);
        final month = int.parse(dateFirst.group(2)!);
        final year = normalizeYear(int.parse(dateFirst.group(3)!));
        final hour = int.parse(dateFirst.group(4)!);
        final minute = int.parse(dateFirst.group(5)!);
        final parsed = safeDate(year, month, day, hour, minute);
        if (parsed != null) {
          return parsed;
        }
      }

      final timeFirstLegacy = _timeFirstLegacyPattern.firstMatch(line);
      if (timeFirstLegacy != null) {
        final hour = int.parse(timeFirstLegacy.group(1)!);
        final minute = int.parse(timeFirstLegacy.group(2)!);
        final day = int.parse(timeFirstLegacy.group(3)!);
        final month = int.parse(timeFirstLegacy.group(4)!);
        final year = normalizeYear(int.parse(timeFirstLegacy.group(5)!));
        final parsed = safeDate(year, month, day, hour, minute);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  _D360PaymentData _extractPaymentData(List<String> lines) {
    for (final line in lines) {
      if (!line.contains('بطاقة:')) {
        continue;
      }

      final lower = line.toLowerCase();
      final last4Match = RegExp(r'(\d{4})(?!.*\d)').firstMatch(line);
      final last4 = last4Match?.group(1);

      String? network;
      if (lower.contains('mada') || line.contains('مدى')) {
        network = 'Mada';
      } else if (lower.contains('visa') || line.contains('فيزا')) {
        network = 'Visa';
      }

      String? channelType;
      String? channel;
      if (lower.contains('apple pay') || line.contains('ابل باي')) {
        channelType = 'Apple Pay';
        channel = 'Apple Pay';
      } else if (lower.contains('google pay') || line.contains('جوجل باي')) {
        channelType = 'Google Pay';
        channel = 'Google Pay';
      } else if (lower.contains('ecommerce')) {
        channelType = 'Ecommerce';
        channel = 'شراء عبر الإنترنت';
      } else {
        channel = 'شراء عبر نقاط البيع';
      }

      return _D360PaymentData(
        network: network,
        channel: channel,
        channelType: channelType,
        last4Digits: last4,
      );
    }

    return const _D360PaymentData();
  }

  String? _resolvePaymentMethod(String? network) {
    if (network == 'Mada') {
      return 'Debit Card';
    }
    if (network == 'Visa') {
      return 'Credit Card';
    }
    return null;
  }

  String? _buildPaymentDetail(_D360PaymentData payment) {
    if (payment.channelType == null && payment.last4Digits == null) {
      return null;
    }

    if (payment.channelType != null && payment.last4Digits != null) {
      return '${payment.channelType} • ${payment.last4Digits}';
    }

    return payment.channelType ?? payment.last4Digits;
  }

  String _cleanD360Merchant(String value) {
    var cleaned = cleanMerchant(value).replaceAll(RegExp(r'\s+'), ' ').trim();

    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*[-–—]\s*(apple\s*pay|google\s*pay|ecommerce|ابل\s*باي|جوجل\s*باي|شراء\s+عبر\s+الإنترنت)\s*$',
        caseSensitive: false,
      ),
      '',
    );

    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*\(\s*(apple\s*pay|google\s*pay|ecommerce|ابل\s*باي|جوجل\s*باي|شراء\s+عبر\s+الإنترنت)\s*\)\s*$',
        caseSensitive: false,
      ),
      '',
    );

    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s+(apple\s*pay|google\s*pay|ecommerce|ابل\s*باي|جوجل\s*باي|شراء\s+عبر\s+الإنترنت)\s*$',
        caseSensitive: false,
      ),
      '',
    );

    return cleaned.trim();
  }

  @override
  List<String> get transactionKeywords => const <String>[
    'مبلغ:',
    'بطاقة:',
  ];

  @override
  List<String> get balanceKeywords => const <String>['رصيد', 'balance'];
}

class _D360AmountData {
  const _D360AmountData({
    this.transactionAmount,
    this.transactionCurrency,
    this.billedAmount,
    this.billedCurrency,
    this.isInternational,
  });

  final double? transactionAmount;
  final String? transactionCurrency;
  final double? billedAmount;
  final String? billedCurrency;
  final bool? isInternational;
}

class _D360PaymentData {
  const _D360PaymentData({
    this.network,
    this.channel,
    this.channelType,
    this.last4Digits,
  });

  final String? network;
  final String? channel;
  final String? channelType;
  final String? last4Digits;
}
