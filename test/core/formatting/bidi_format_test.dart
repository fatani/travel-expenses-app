import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/formatting/bidi_format.dart';

void main() {
  group('wrapLtrIsolate', () {
    test('wraps text with Unicode LRI and PDI', () {
      expect(
        wrapLtrIsolate('320 SAR'),
        '${ltrIsolateStart}320 SAR$ltrIsolateEnd',
      );
    });
  });

  group('BidiAmountFormat', () {
    test('formats numbers with grouping in English locale pattern', () {
      expect(BidiAmountFormat.formatNumber(1234.5), '1,234.5');
    });

    test('ltrIsolate keeps amount and currency together', () {
      expect(
        BidiAmountFormat.ltrIsolate(320, 'sar'),
        '${ltrIsolateStart}320 SAR$ltrIsolateEnd',
      );
    });

    test('formatApproximate prefixes with ≈', () {
      expect(
        BidiAmountFormat.formatApproximate(52.5, 'SAR'),
        '≈ ${ltrIsolateStart}52.5 SAR$ltrIsolateEnd',
      );
    });
  });

  group('embedLtrInRtl', () {
    test('embeds date segment after Arabic prefix', () {
      final result = embedLtrInRtl('ينتهي ', '25 May');
      expect(result, 'ينتهي ${wrapLtrIsolate('25 May')}');
    });
  });
}
