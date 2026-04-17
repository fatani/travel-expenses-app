import '../../domain/sms_parser_contract.dart';

class SmsBankDetector {
  const SmsBankDetector();

  // Barq date formats
  static final RegExp _barqDateWithPrefixPattern = RegExp(
    r'في\s*:\s*\d{4}[-/]\d{1,2}[-/]\d{1,2}\s+\d{1,2}:\d{2}',
  );

  static final RegExp _barqBareDatePattern = RegExp(
    r'^\s*\d{4}[-/]\d{1,2}[-/]\d{1,2}\s+\d{1,2}:\d{2}\s*$',
    multiLine: true,
  );

  static const List<String> _barqCoreMarkers = <String>['بطاقة', 'لدى'];

  static final RegExp _d360TimeFirstIsoDatePattern = RegExp(
    r'في\s*:\s*\d{1,2}:\d{2}\s+\d{4}[-/]\d{1,2}[-/]\d{1,2}',
  );

  static final RegExp _d360DateFirstPattern = RegExp(
    r'في\s*:\s*\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\s+\d{1,2}:\d{2}',
  );

  static final RegExp _d360TimeFirstLegacyPattern = RegExp(
    r'في\s*:\s*\d{1,2}:\d{2}\s+\d{1,2}/\d{1,2}/\d{2,4}',
  );

  static final RegExp _d360AmountPattern = RegExp(
    r'مبلغ\s*:\s*(?:[A-Z]{3})\s*\d',
    caseSensitive: false,
  );

  static const List<String> _d360Markers = <String>[
    'بطاقة:',
    'مبلغ:',
    'لدى:',
    'في:',
  ];

  static const List<String> _snbMarkers = <String>[
    'بطاقة ائتمانية',
    'التاريخ',
    'الصرف المتبقي',
  ];

  static const List<String> _alRajhiMarkers = <String>[
    'شراء عبر نقاط البيع',
    'شراء إنترنت',
    'شراء انترنت',
    'بطاقة:',
    'عبر',
    'لدى:',
    'لـ',
    'رصيد:',
  ];

  SmsBankDetection detect(String normalizedText) {
    final lower = normalizedText.toLowerCase();

    // Barq: require core markers and Barq-compatible date while excluding known bank markers.
    final barqMatched = _barqCoreMarkers
        .where((marker) => lower.contains(marker.toLowerCase()))
        .toList();
    final hasWalletBalance = lower.contains('رصيد المحفظة');
    final hasBarqAmountKeyword = lower.contains('مبلغ');
    final hasKnownBankNames =
        lower.contains('alrajhi') ||
        lower.contains('الراجحي') ||
        lower.contains('snb') ||
        lower.contains('sab') ||
        lower.contains('الأهلي') ||
        lower.contains('d360');
    if (barqMatched.length == _barqCoreMarkers.length &&
        _matchesBarqStructure(normalizedText) &&
        (!hasKnownBankNames || hasWalletBalance)) {
      final matchedMarkers = <String>[...barqMatched];
      if (hasWalletBalance) {
        matchedMarkers.add('رصيد المحفظة');
      }
      if (hasBarqAmountKeyword) {
        matchedMarkers.add('مبلغ');
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
        lower.contains('شراء عبر نقاط البيع') ||
        lower.contains('شراء إنترنت') ||
        lower.contains('شراء انترنت');
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
