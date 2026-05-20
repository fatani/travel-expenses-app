import '../../domain/sms_parser_contract.dart';

class SmsBankDetector {
  const SmsBankDetector();

  // Barq date formats
  static final RegExp _barqDateWithPrefixPattern = RegExp(
    r'\u0641\u064A\s*:\s*\d{4}[-/]\d{1,2}[-/]\d{1,2}\s+\d{1,2}:\d{2}',
  );

  static final RegExp _barqBareDatePattern = RegExp(
    r'^\s*\d{4}[-/]\d{1,2}[-/]\d{1,2}\s+\d{1,2}:\d{2}\s*$',
    multiLine: true,
  );

  static const List<String> _barqCoreMarkers = <String>['\u0628\u0637\u0627\u0642\u0629', '\u0644\u062F\u0649'];

  static final RegExp _d360TimeFirstIsoDatePattern = RegExp(
    r'\u0641\u064A\s*:\s*\d{1,2}:\d{2}\s+\d{4}[-/]\d{1,2}[-/]\d{1,2}',
  );

  static final RegExp _d360DateFirstPattern = RegExp(
    r'\u0641\u064A\s*:\s*\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\s+\d{1,2}:\d{2}',
  );

  static final RegExp _d360TimeFirstLegacyPattern = RegExp(
    r'\u0641\u064A\s*:\s*\d{1,2}:\d{2}\s+\d{1,2}/\d{1,2}/\d{2,4}',
  );

  static final RegExp _d360AmountPattern = RegExp(
    r'\u0645\u0628\u0644\u063A\s*:\s*(?:[A-Z]{3})\s*\d',
    caseSensitive: false,
  );

  static const List<String> _d360Markers = <String>[
    '\u0628\u0637\u0627\u0642\u0629:',
    '\u0645\u0628\u0644\u063A:',
    '\u0644\u062F\u0649:',
    '\u0641\u064A:',
  ];

  static const List<String> _snbMarkers = <String>[
    '\u0628\u0637\u0627\u0642\u0629 \u0627\u0626\u062A\u0645\u0627\u0646\u064A\u0629',
    '\u0627\u0644\u062A\u0627\u0631\u064A\u062E',
    '\u0627\u0644\u0635\u0631\u0641 \u0627\u0644\u0645\u062A\u0628\u0642\u064A',
  ];

  static const List<String> _alRajhiMarkers = <String>[
    '\u0634\u0631\u0627\u0621 \u0639\u0628\u0631 \u0646\u0642\u0627\u0637 \u0627\u0644\u0628\u064A\u0639',
    '\u0634\u0631\u0627\u0621 \u0625\u0646\u062A\u0631\u0646\u062A',
    '\u0634\u0631\u0627\u0621 \u0627\u0646\u062A\u0631\u0646\u062A',
    '\u0628\u0637\u0627\u0642\u0629:',
    '\u0639\u0628\u0631',
    '\u0644\u062F\u0649:',
    '\u0644\u0640',
    '\u0631\u0635\u064A\u062F:',
  ];

  SmsBankDetection detect(String normalizedText) {
    final lower = normalizedText.toLowerCase();

    // Barq: require core markers and Barq-compatible date while excluding known bank markers.
    final barqMatched = _barqCoreMarkers
        .where((marker) => lower.contains(marker.toLowerCase()))
        .toList();
    final hasWalletBalance = lower.contains('\u0631\u0635\u064A\u062F \u0627\u0644\u0645\u062D\u0641\u0638\u0629');
    final hasBarqAmountKeyword = lower.contains('\u0645\u0628\u0644\u063A');
    final hasKnownBankNames =
        lower.contains('alrajhi') ||
        lower.contains('\u0627\u0644\u0631\u0627\u062C\u062D\u064A') ||
        lower.contains('snb') ||
        lower.contains('sab') ||
        lower.contains('\u0627\u0644\u0623\u0647\u0644\u064A') ||
        lower.contains('d360');
    if (barqMatched.length == _barqCoreMarkers.length &&
        _matchesBarqStructure(normalizedText) &&
        (!hasKnownBankNames || hasWalletBalance)) {
      final matchedMarkers = <String>[...barqMatched];
      if (hasWalletBalance) {
        matchedMarkers.add('\u0631\u0635\u064A\u062F \u0627\u0644\u0645\u062D\u0641\u0638\u0629');
      }
      if (hasBarqAmountKeyword) {
        matchedMarkers.add('\u0645\u0628\u0644\u063A');
      }
      return SmsBankDetection(bank: SmsBank.barq, matchedMarkers: matchedMarkers);
    }

    final d360Matched = _d360Markers
        .where((marker) => lower.contains(marker.toLowerCase()))
        .toList();
    if (d360Matched.length == _d360Markers.length &&
        _matchesD360Structure(normalizedText)) {
      return SmsBankDetection(bank: SmsBank.d360, matchedMarkers: d360Matched);
    }

    final sabMatched = <String>[];
    if (lower.contains('sab')) {
      sabMatched.add('sab');
    }
    if (lower.contains('was used at')) {
      sabMatched.add('was used at');
    }
    if (sabMatched.length == 2) {
      return SmsBankDetection(bank: SmsBank.sab, matchedMarkers: sabMatched);
    }

    final rajhiMatched = _alRajhiMarkers
        .where((marker) => lower.contains(marker.toLowerCase()))
        .toList();
    final hasRajhiTransaction =
        lower.contains('\u0634\u0631\u0627\u0621 \u0639\u0628\u0631 \u0646\u0642\u0627\u0637 \u0627\u0644\u0628\u064A\u0639') ||
        lower.contains('\u0634\u0631\u0627\u0621 \u0625\u0646\u062A\u0631\u0646\u062A') ||
        lower.contains('\u0634\u0631\u0627\u0621 \u0627\u0646\u062A\u0631\u0646\u062A');
    if (hasRajhiTransaction && rajhiMatched.length >= 3) {
      return SmsBankDetection(
        bank: SmsBank.alRajhi,
        matchedMarkers: rajhiMatched,
      );
    }

    final snbMatched =
        _snbMarkers
            .where((marker) => lower.contains(marker.toLowerCase()))
            .toList();
    if (snbMatched.isNotEmpty) {
      return SmsBankDetection(bank: SmsBank.snb, matchedMarkers: snbMatched);
    }

    return const SmsBankDetection(bank: SmsBank.unknown, matchedMarkers: []);
  }

  bool _matchesD360Structure(String normalizedText) {
    return _d360AmountPattern.hasMatch(normalizedText) &&
        (_d360TimeFirstIsoDatePattern.hasMatch(normalizedText) ||
            _d360DateFirstPattern.hasMatch(normalizedText) ||
            _d360TimeFirstLegacyPattern.hasMatch(normalizedText));
  }

  bool _matchesBarqStructure(String normalizedText) {
    return _barqDateWithPrefixPattern.hasMatch(normalizedText) ||
        _barqBareDatePattern.hasMatch(normalizedText);
  }
}
