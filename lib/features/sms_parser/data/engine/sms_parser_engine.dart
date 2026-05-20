import '../../domain/sms_parse_result.dart';
import '../../domain/sms_parser_contract.dart';
import '../parsers/al_rajhi_sms_parser.dart';
import '../parsers/barq_sms_parser.dart';
import '../parsers/d360_sms_parser.dart';
import '../parsers/generic_sms_parser.dart';
import '../parsers/sab_sms_parser.dart';
import '../parsers/snb_sms_parser.dart';
import 'sms_bank_detector.dart';
import 'sms_text_normalizer.dart';

class SmsParserEngine {
  SmsParserEngine({
    SmsBankDetector? detector,
    List<SmsBankParser>? bankParsers,
    SmsBankParser? fallbackParser,
  }) : _detector = detector ?? const SmsBankDetector(),
       _bankParsers =
           bankParsers ??
           const <SmsBankParser>[
             BarqSmsParser(),
             D360SmsParser(),
             SnbSmsParser(),
             AlRajhiSmsParser(),
             SabSmsParser(),
           ],
       _fallbackParser = fallbackParser ?? const GenericSmsParser();

  final SmsBankDetector _detector;
  final List<SmsBankParser> _bankParsers;
  final SmsBankParser _fallbackParser;

  SmsParseResult parse(String rawText) {
    final normalizedText = SmsTextNormalizer.normalize(rawText).trim();
    if (normalizedText.isEmpty) {
      return const SmsParseResult(rawText: '');
    }

    final detection = _detector.detect(normalizedText);
    final selected = _selectParser(detection.bank);

    if (selected != null) {
      final selectedResult = selected.parse(normalizedText);
      if (selectedResult.hasAnyValue) {
        return selectedResult.copyWith(
          parserName: selected.parserName,
          notes: detection.matchedMarkers.isEmpty
              ? null
              : 'markers=${detection.matchedMarkers.join(',')}',
        );
      }
    }

    final fallbackResult = _fallbackParser.parse(normalizedText);
    if (fallbackResult.hasAnyValue) {
      return fallbackResult.copyWith(
        parserName: _fallbackParser.parserName,
        notes: selected == null
            ? 'fallback:unknown-bank'
            : 'fallback:${selected.parserName}',
      );
    }

    return SmsParseResult(
      rawText: normalizedText,
      parserName: selected?.parserName ?? _fallbackParser.parserName,
      notes: 'no-reliable-fields',
    );
  }

  SmsBankParser? _selectParser(SmsBank bank) {
    for (final parser in _bankParsers) {
      if (parser.supports(bank)) {
        return parser;
      }
    }
    return null;
  }
}
