import '../../domain/sms_parser_contract.dart';

class SmsBankDetector {
  const SmsBankDetector();

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
}
