class SmsTextNormalizer {
  const SmsTextNormalizer._();

  static const Map<String, String> _digitNormalization = <String, String>{
    '\u0660': '0',
    '\u0661': '1',
    '\u0662': '2',
    '\u0663': '3',
    '\u0664': '4',
    '\u0665': '5',
    '\u0666': '6',
    '\u0667': '7',
    '\u0668': '8',
    '\u0669': '9',
    '\u06F0': '0',
    '\u06F1': '1',
    '\u06F2': '2',
    '\u06F3': '3',
    '\u06F4': '4',
    '\u06F5': '5',
    '\u06F6': '6',
    '\u06F7': '7',
    '\u06F8': '8',
    '\u06F9': '9',
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
        .replaceAll('\u066B', '.')
        .replaceAll('\u066C', ',');

    for (final entry in _digitNormalization.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }

    return normalized;
  }
}
