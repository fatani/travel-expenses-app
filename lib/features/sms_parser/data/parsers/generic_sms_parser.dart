import '../../domain/sms_parse_result.dart';
import '../../domain/sms_parser_contract.dart';
import 'base_sms_parser.dart';

class GenericSmsParser extends BaseSmsParser implements SmsBankParser {
  const GenericSmsParser();

  @override
  String get parserName => 'generic';

  @override
  bool supports(SmsBank bank) => bank == SmsBank.unknown;

  @override
  SmsParseResult parse(String normalizedText) {
    return parseGeneric(normalizedText);
  }

  @override
  List<String> get transactionKeywords => const <String>[
    'purchase',
    'payment',
    'transaction',
    'pos',
    'card used',
    'spent',
    'debit',
    '\u0634\u0631\u0627\u0621',
  ];

  @override
  List<String> get balanceKeywords => const <String>[
    'remaining balance',
    'available balance',
    'balance',
    'outstanding',
    '\u0627\u0644\u0635\u0631\u0641 \u0627\u0644\u0645\u062A\u0628\u0642\u064A',
    '\u0627\u0644\u0631\u0635\u064A\u062F \u0627\u0644\u0645\u062A\u0628\u0642\u064A',
  ];
}
