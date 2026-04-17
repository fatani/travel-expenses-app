class SmsTextNormalizer {
  const SmsTextNormalizer._();

  static const Map<String, String> _digitNormalization = <String, String>{
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  static final RegExp _directionalMarksPattern = RegExp(
    r'[\u200E\u200F\u202A-\u202E\u2066-\u2069\u061C]',
  );

  static String normalize(String input) {
    if (input.isEmpty) {
      return input;
    }

    var normalized = input
        .replaceAll(_directionalMarksPattern, '')
        .replaceAll('\u00A0', ' ')
        .replaceAll('٫', '.')
        .replaceAll('٬', ',');

    for (final entry in _digitNormalization.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }

    return normalized;
  }
}
