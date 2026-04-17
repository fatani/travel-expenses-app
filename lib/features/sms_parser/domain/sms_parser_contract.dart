import 'sms_parse_result.dart';

enum SmsBank {
  barq,
  d360,
  snb,
  alRajhi,
  sab,
  unknown,
}

class SmsBankDetection {
  const SmsBankDetection({required this.bank, required this.matchedMarkers});

  final SmsBank bank;
  final List<String> matchedMarkers;
}

abstract class SmsBankParser {
  const SmsBankParser();

  String get parserName;
  bool supports(SmsBank bank);
  SmsParseResult parse(String normalizedText);
}
