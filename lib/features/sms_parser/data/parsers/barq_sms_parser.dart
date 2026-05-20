import '../../domain/sms_parse_result.dart';
import '../../domain/sms_parser_contract.dart';
import 'base_sms_parser.dart';

class BarqSmsParser extends BaseSmsParser implements SmsBankParser {
  const BarqSmsParser();

  // "10 USD (37.53 SAR)" — international
  static final RegExp _amountWithBillingPattern = RegExp(
    r'([\d,]+(?:\.\d{1,2})?)\s+([A-Z]{3})\s*\(\s*([\d,]+(?:\.\d{1,2})?)\s+SAR\s*\)',
    caseSensitive: false,
  );

  // "USD (37.53 SAR) 10" — international reversed order
  static final RegExp _amountWithBillingReversedPattern = RegExp(
    r'([A-Z]{3})\s*\(\s*([\d,]+(?:\.\d{1,2})?)\s+SAR\s*\)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // "17.92 SAR" — domestic
  static final RegExp _amountBasicPattern = RegExp(
    r'([\d,]+(?:\.\d{1,2})?)\s+([A-Z]{3})\b',
    caseSensitive: false,
  );

  // "في:2026-01-14 06:38"
  static final RegExp _dateWithPrefixPattern = RegExp(
    r'\u0641\u064A\s*:\s*(\d{4})[-/](\d{1,2})[-/](\d{1,2})\s+(\d{1,2}):(\d{2})',
  );

  // Bare ISO date: "2026-03-17 11:38"
  static final RegExp _bareDatePattern = RegExp(
    r'^\s*(\d{4})[-/](\d{1,2})[-/](\d{1,2})\s+(\d{1,2}):(\d{2})\s*$',
  );

  static final RegExp _merchantPattern = RegExp(r'\u0644\u062F\u0649\s*:?\s*(.+)$');

  @override
  String get parserName => 'barq';

  @override
  bool supports(SmsBank bank) => bank == SmsBank.barq;

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
      labels: const <String>['fees', 'fee', '\u0631\u0633\u0648\u0645', '\u0631\u0633\u0648\u0645 \u0648\u0636\u0631\u064a\u0628\u0629'],
    );
    final totalCharged = extractLabeledAmount(
      lines,
      labels: const <String>['total charged', 'total amount', '\u0627\u062c\u0645\u0627\u0644\u064a', '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0645\u0628\u0644\u063a \u0627\u0644\u0645\u0633\u062a\u062d\u0642'],
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
      suggestedCategory: suggestCategory('$compact ${merchant ?? \'\'}'),
      suggestedPaymentMethod: _resolvePaymentMethod(payment.network),
      suggestedPaymentNetwork: payment.network,
      suggestedPaymentChannel: payment.channel,
      suggestedPaymentDetail: _buildPaymentDetail(payment),
    );
  }

  _BarqAmountData _extractAmountData(List<String> lines) {
    for (final line in lines) {
      // Skip balance line
      if (line.contains('\u0631\u0635\u064a\u062f \u0627\u0644\u0645\u062d\u0641\u0638\u0629') || line.contains('\u0631\u0635\u064a\u062f')) continue;

      final withBilling = _amountWithBillingPattern.firstMatch(line);
      if (withBilling != null) {
        final transactionAmount = parseAmount(withBilling.group(1));
        final transactionCurrency = withBilling.group(2)!.toUpperCase();
        final billedAmount = parseAmount(withBilling.group(3));

        return _BarqAmountData(
          transactionAmount: transactionAmount,
          transactionCurrency: transactionCurrency,
          billedAmount: billedAmount,
          billedCurrency: billedAmount == null ? null : 'SAR',
          isInternational:
              transactionCurrency != 'SAR' && billedAmount != null,
        );
      }

      final withBillingReversed = _amountWithBillingReversedPattern.firstMatch(
        line,
      );
      if (withBillingReversed != null) {
        final transactionCurrency = withBillingReversed.group(1)!.toUpperCase();
        final billedAmount = parseAmount(withBillingReversed.group(2));
        final transactionAmount = parseAmount(withBillingReversed.group(3));

        return _BarqAmountData(
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
      if (line.contains('\u0631\u0635\u064a\u062f \u0627\u0644\u0645\u062d\u0641\u0638\u0629') || line.contains('\u0631\u0635\u064a\u062f')) continue;

      final basic = _amountBasicPattern.firstMatch(line);
      if (basic != null) {
        final amount = parseAmount(basic.group(1));
        final currency = basic.group(2)!.toUpperCase();

        return _BarqAmountData(
          transactionAmount: amount,
          transactionCurrency: currency,
          billedAmount: null,
          billedCurrency: null,
          isInternational: false,
        );
      }
    }

    return const _BarqAmountData();
  }

  String? _extractMerchant(List<String> lines) {
    for (final line in lines) {
      final match = _merchantPattern.firstMatch(line);
      if (match == null) continue;
      final merchant = cleanMerchant(match.group(1) ?? '').trim();
      if (merchant.length >= 2) return merchant;
    }
    return null;
  }

  DateTime? _extractDateTime(List<String> lines) {
    for (final line in lines) {
      final prefixed = _dateWithPrefixPattern.firstMatch(line);
      if (prefixed != null) {
        return safeDate(
          int.parse(prefixed.group(1)!),
          int.parse(prefixed.group(2)!),
          int.parse(prefixed.group(3)!),
          int.parse(prefixed.group(4)!),
          int.parse(prefixed.group(5)!),
        );
      }

      final bare = _bareDatePattern.firstMatch(line);
      if (bare != null) {
        return safeDate(
          int.parse(bare.group(1)!),
          int.parse(bare.group(2)!),
          int.parse(bare.group(3)!),
          int.parse(bare.group(4)!),
          int.parse(bare.group(5)!),
        );
      }
    }
    return null;
  }

  _BarqPaymentData _extractPaymentData(List<String> lines) {
    for (final line in lines) {
      if (!line.contains('\u0628\u0637\u0627\u0642\u0629')) continue;

      final lower = line.toLowerCase();
      final last4Match = RegExp(r'\*+(\d{4})').firstMatch(line);
      final last4 = last4Match?.group(1);

      String? network;
      if (lower.contains('mada') ||
          lower.contains('\u0645\u062f\u0649') ||
          lower.contains('\u0645\u062f\u064a')) {
        network = 'Mada';
      } else if (lower.contains('visa') || line.contains('\u0641\u064a\u0632\u0627')) {
        network = 'Visa';
      } else if (lower.contains('mastercard') ||
          lower.contains('\u0645\u0627\u0633\u062a\u0631\u0643\u0627\u0631\u062f')) {
        network = 'Mastercard';
      }

      String channel;
      String? channelType;
      if (lower.contains('apple pay') || line.contains('\u0627\u0628\u0644 \u0628\u0627\u064a')) {
        channel = 'Apple Pay';
        channelType = 'Apple Pay';
      } else if (lower.contains('\u0639\u0628\u0631 \u0627\u0644\u0627\u0646\u062a\u0631\u0646\u062a') ||
          lower.contains('\u0639\u0628\u0631 \u0627\u0644\u0625\u0646\u062a\u0631\u0646\u062a') ||
          lower.contains('\u0625\u0646\u062a\u0631\u0646\u062a') ||
          lower.contains('\u0627\u0646\u062a\u0631\u0646\u062a')) {
        channel = '\u0634\u0631\u0627\u0621 \u0639\u0628\u0631 \u0627\u0644\u0625\u0646\u062a\u0631\u0646\u062a';
        channelType = 'Ecommerce';
      } else if (lower.contains('\u0646\u0642\u0627\u0637 \u0627\u0644\u0628\u064a\u0639')) {
        channel = '\u0634\u0631\u0627\u0621 \u0639\u0628\u0631 \u0646\u0642\u0627\u0637 \u0627\u0644\u0628\u064a\u0639';
      } else {
        channel = '\u0634\u0631\u0627\u0621 \u0639\u0628\u0631 \u0646\u0642\u0627\u0637 \u0627\u0644\u0628\u064a\u0639';
      }

      return _BarqPaymentData(
        network: network,
        channel: channel,
        channelType: channelType,
        last4Digits: last4,
      );
    }
    return const _BarqPaymentData();
  }

  String? _resolvePaymentMethod(String? network) {
    if (network == 'Mada') return 'Debit Card';
    if (network == 'Visa' || network == 'Mastercard') return 'Credit Card';
    return null;
  }

  String? _buildPaymentDetail(_BarqPaymentData payment) {
    if (payment.channelType == null && payment.last4Digits == null) return null;
    if (payment.channelType != null && payment.last4Digits != null) {
      return '${payment.channelType} \u2022 ${payment.last4Digits}';
    }
    return payment.channelType ?? payment.last4Digits;
  }

  @override
  List<String> get transactionKeywords => const <String>['\u0644\u062f\u0649', '\u0628\u0637\u0627\u0642\u0629'];

  @override
  List<String> get balanceKeywords => const <String>[
    '\u0631\u0635\u064a\u062f \u0627\u0644\u0645\u062d\u0641\u0638\u0629',
    '\u0631\u0635\u064a\u062f',
    'balance',
  ];
}

class _BarqAmountData {
  const _BarqAmountData({
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

class _BarqPaymentData {
  const _BarqPaymentData({
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
