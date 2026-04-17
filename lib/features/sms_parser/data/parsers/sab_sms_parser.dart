import '../../domain/sms_parse_result.dart';
import '../../domain/sms_parser_contract.dart';
import 'base_sms_parser.dart';

class SabSmsParser extends BaseSmsParser implements SmsBankParser {
  const SabSmsParser();

  @override
  String get parserName => 'sab';

  @override
  bool supports(SmsBank bank) => bank == SmsBank.sab;

  @override
  SmsParseResult parse(String rawText) {
    final normalizedText = rawText.trim();
    final lines = normalizedText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final amount = _extractSabAmount(lines);
    final billed =
        _extractSabBilledAmount(lines) ??
        extractLabeledAmount(
          lines,
          labels: const <String>['amount in sar'],
          defaultCurrency: 'SAR',
        );
    final fees =
        _extractSabFeesAmount(lines) ??
        extractLabeledAmount(
          lines,
          labels: const <String>['international fees'],
          defaultCurrency: 'SAR',
        );
    final totalCharged =
        _extractSabTotalAmount(lines) ??
        extractLabeledAmount(
          lines,
          labels: const <String>['total amount in sar', 'total amount'],
          defaultCurrency: 'SAR',
        );
    final merchant = _extractSabMerchant(lines);
    final spentAt = _extractSabDateTime(lines);
    final paymentDetails = _extractSabPaymentDetails(lines);
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
      suggestedPaymentMethod: _resolveSabPaymentMethod(
        paymentDetails.network,
        paymentDetails.channel,
      ),
      suggestedPaymentNetwork: paymentDetails.network,
      suggestedPaymentChannel: paymentDetails.channel,
      suggestedPaymentDetail: paymentDetails.executionMethod,
    );
  }

  AmountMatch? _extractSabAmount(List<String> lines) {
    for (final line in lines) {
      if (!line.toLowerCase().contains('was used at')) {
        continue;
      }

      final match = RegExp(
        r'\bfor\s+([A-Z]{3})\s+(\d+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ).firstMatch(line);

      if (match != null) {
        final currency = match.group(1)!.toUpperCase();
        final amount = parseAmount(match.group(2));
        if (amount != null && amount > 0) {
          return AmountMatch(amount: amount, currencyCode: currency);
        }
      }
    }
    return null;
  }

  AmountMatch? _extractSabBilledAmount(List<String> lines) {
    for (final line in lines) {
      final match = RegExp(
        r'\bamount\s+in\s+sar\s*:?\s*(\d+(?:[.,]\d{1,2})?)\b',
        caseSensitive: false,
      ).firstMatch(line);
      if (match == null) {
        continue;
      }

      final amount = parseAmount(match.group(1));
      if (amount != null) {
        return const AmountMatch(amount: 0, currencyCode: 'SAR').copyWith(
          amount: amount,
        );
      }
    }

    return null;
  }

  AmountMatch? _extractSabFeesAmount(List<String> lines) {
    for (final line in lines) {
      final match = RegExp(
        r'\binternational\s+fees(?:\s+in\s+sar)?\s*:?\s*(\d+(?:[.,]\d{1,2})?)\b',
        caseSensitive: false,
      ).firstMatch(line);
      if (match == null) {
        continue;
      }

      final amount = parseAmount(match.group(1));
      if (amount != null) {
        return const AmountMatch(amount: 0, currencyCode: 'SAR').copyWith(
          amount: amount,
        );
      }
    }

    return null;
  }

  AmountMatch? _extractSabTotalAmount(List<String> lines) {
    for (final line in lines) {
      final match = RegExp(
        r'\btotal\s+amount(?:\s+in\s+sar)?\s*:?\s*(\d+(?:[.,]\d{1,2})?)\b',
        caseSensitive: false,
      ).firstMatch(line);
      if (match == null) {
        continue;
      }

      final amount = parseAmount(match.group(1));
      if (amount != null) {
        return const AmountMatch(amount: 0, currencyCode: 'SAR').copyWith(
          amount: amount,
        );
      }
    }

    return null;
  }

  String? _extractSabMerchant(List<String> lines) {
    for (final line in lines) {
      if (!line.toLowerCase().contains('was used at')) {
        continue;
      }

      final match = RegExp(
        r'was used at\s+(.+?)\s+(?:for|via|on)\s',
        caseSensitive: false,
      ).firstMatch(line);

      if (match != null) {
        final merchant = match.group(1)!.trim();
        if (merchant.length >= 2) {
          return merchant;
        }
      }
    }
    return null;
  }

  DateTime? _extractSabDateTime(List<String> lines) {
    for (final line in lines) {
      if (!line.toLowerCase().startsWith('date:')) {
        continue;
      }
      final match = RegExp(
        r'(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})(?::(\d{2}))?',
      ).firstMatch(line);
      if (match != null) {
        final parsed = safeDate(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
          int.parse(match.group(4)!),
          int.parse(match.group(5)!),
        );
        if (parsed != null) {
          return parsed;
        }
      }
    }

    for (final line in lines) {
      if (!line.toLowerCase().contains('was used at')) {
        continue;
      }
      final match = RegExp(
        r'\bon\s+(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})(?::(\d{2}))?',
        caseSensitive: false,
      ).firstMatch(line);
      if (match != null) {
        final parsed = safeDate(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
          int.parse(match.group(4)!),
          int.parse(match.group(5)!),
        );
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  PaymentDetails _extractSabPaymentDetails(List<String> lines) {
    String? network;
    String? channel;
    String? executionMethod;

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('mastercard')) {
        network = 'Mastercard';
        break;
      } else if (lower.contains('visa')) {
        network = 'Visa';
        break;
      } else if (lower.contains('mada')) {
        network = 'Mada';
        break;
      }
    }

    if (lines.isNotEmpty) {
      switch (lines.first.trim().toLowerCase()) {
        case 'online purchase':
          channel = 'Online Purchase';
        case 'pos purchase':
          channel = 'POS Purchase';
        case 'pos international purchase':
          channel = 'POS Purchase';
      }
    }

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('via apple pay')) {
        executionMethod = 'Apple Pay';
        break;
      } else if (lower.contains('via google pay')) {
        executionMethod = 'Google Pay';
        break;
      }
    }

    return PaymentDetails(
      network: network,
      channel: channel,
      executionMethod: executionMethod,
    );
  }

  String? _resolveSabPaymentMethod(String? network, String? channel) {
    if (network == 'Mastercard' || network == 'Visa') {
      return 'Credit Card';
    }
    if (network == 'Mada') {
      return 'Debit Card';
    }
    return null;
  }

  @override
  List<String> get transactionKeywords => const <String>[
    'pos purchase',
    'online purchase',
    'was used at',
  ];

  @override
  List<String> get balanceKeywords => const <String>['balance:', 'balance'];
}
