import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/sms_parser/data/sms_parser_service.dart';

void main() {
  const parser = SmsParserService();

  test('extracts common values from a card purchase SMS', () {
    final result = parser.parse(
      'Card purchase of USD 24.50 at Starbucks Airport on 09/04/2026 14:35',
    );

    expect(result.amount, 24.50);
    expect(result.currencyCode, 'USD');
    expect(result.merchant, 'Starbucks Airport');
    expect(result.suggestedCategory, 'Food');
    expect(result.spentAt, DateTime(2026, 4, 9, 14, 35));
  });

  test('prefers transaction amount and ignores remaining balance amount', () {
    final result = parser.parse('''
شراء انترنت (Apple Pay)
46.00 SAR
بطاقة ائتمانية ****4744
from Mobily
التاريخ 11/04/26 12:07
الصرف المتبقي 5859.81 SAR
''');

    expect(result.amount, 46.00);
    expect(result.currencyCode, 'SAR');
    expect(result.merchant, contains('Mobily'));
    expect(result.amount, isNot(5859.81));
  });
}
