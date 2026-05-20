import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sms_parse_result.dart';
import 'engine/sms_parser_engine.dart';
import 'engine/sms_text_normalizer.dart';

final smsParserServiceProvider = Provider<SmsParserService>((ref) {
  return SmsParserService();
});

class SmsParserService {
  SmsParserService({SmsParserEngine? engine}) : _engine = engine ?? SmsParserEngine();

  final SmsParserEngine _engine;

  static String normalizeIncomingText(String input) {
    return SmsTextNormalizer.normalize(input);
  }

  SmsParseResult parse(String rawText) {
    return _engine.parse(rawText);
  }
}
