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
