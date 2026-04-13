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

  test('parses SNB Arabic SMS line by line and ignores balance line amount', () {
    final result = parser.parse('''
شراء إنترنت (Apple Pay)
مبلغ 46.00 SAR
بطاقة ائتمانية ****4744
من Mobily
التاريخ 11/04/26 12:07
الصرف المتبقي 5859.81 SAR
''');

    expect(result.amount, 46.00);
    expect(result.currencyCode, 'SAR');
    expect(result.merchant, 'Mobily');
    expect(result.spentAt, DateTime(2026, 4, 11, 12, 7));
    expect(result.amount, isNot(5859.81));
  });

  test('parses SNB SMS with hidden bidi marks in amount and date lines', () {
    final result = parser.parse('''
شراء إنترنت \u202C\u202A(Apple Pay)
مبلغ \u202C\u202A46.00 \u202C\u202ASAR
بطاقة ائتمانية ***4744
من \u202C\u202AMobily
التاريخ \u202C\u202A11/04/26 \u202C\u202A12:07
الصرف المتبقي \u202C\u202A5859.81 \u202C\u202ASAR
''');

    expect(result.amount, 46.00);
    expect(result.currencyCode, 'SAR');
    expect(result.merchant, 'Mobily');
    expect(result.spentAt, DateTime(2026, 4, 11, 12, 7));
    expect(result.amount, isNot(5859.81));
  });

  test('supports amount format: amount then SAR', () {
    final result = parser.parse('''
Purchase approved
46.00 SAR
from STC Pay
12/04/2026 09:10
Available balance 1000.00 SAR
''');

    expect(result.amount, 46.00);
    expect(result.currencyCode, 'SAR');
    expect(result.merchant, 'STC Pay');
    expect(result.spentAt, DateTime(2026, 4, 12, 9, 10));
  });

  test('supports amount format: SAR then amount', () {
    final result = parser.parse('''
POS Purchase
SAR 87.25
at Jarir Bookstore
2026-04-12 18:45
Remaining balance SAR 2500.00
''');

    expect(result.amount, 87.25);
    expect(result.currencyCode, 'SAR');
    expect(result.merchant, 'Jarir Bookstore');
    expect(result.spentAt, DateTime(2026, 4, 12, 18, 45));
  });

  test('parses mixed Arabic and English SMS safely', () {
    final result = parser.parse('''
شراء باستخدام البطاقة
Amount: SAR 19.50
from Starbucks Riyadh
التاريخ 11/04/26 08:30
الرصيد المتبقي 1200.00 SAR
''');

    expect(result.amount, 19.50);
    expect(result.currencyCode, 'SAR');
    expect(result.merchant, 'Starbucks Riyadh');
    expect(result.suggestedCategory, 'Food');
    expect(result.spentAt, DateTime(2026, 4, 11, 8, 30));
  });

  test('leaves amount empty when multiple top transaction amounts are present', () {
    final result = parser.parse('''
Purchase details:
POS transaction
SAR 46.00 and fee SAR 1.00
from Test Merchant
12/04/2026 10:15
''');

    expect(result.amount, isNull);
    expect(result.currencyCode, isNull);
    expect(result.merchant, 'Test Merchant');
    expect(result.spentAt, DateTime(2026, 4, 12, 10, 15));
  });

  test('Hardened: Arabic SNB with balance line recognizes 46.00 as transaction not 5859.81 balance', () {
    final result = parser.parse('''
شراء إنترنت (Apple Pay)
مبلغ 46.00 SAR
بطاقة ائتمانية ****4744
من Mobily
التاريخ 11/04/26 12:07
الصرف المتبقي 5859.81 SAR
''');

    expect(result.amount, 46.00,
        reason: 'Must use 46.00 from مبلغ line, not 5859.81 from balance');
    expect(result.currencyCode, 'SAR');
    expect(result.merchant, 'Mobily');
    expect(result.spentAt, DateTime(2026, 4, 11, 12, 7));
    expect(result.hasAnyValue, true, reason: 'Parser found transaction data');
  });

  test('Hardened: English-like SMS with balance ignored', () {
    final result = parser.parse('''
Purchase at Starbucks
SAR 18.50
Card ending 1234
Date 2026-04-10 09:15
Remaining balance SAR 900.00
''');

    expect(result.amount, 18.50,
        reason: 'Must use 18.50 transaction, not 900.00 remaining balance');
    expect(result.currencyCode, 'SAR');
    expect(result.merchant, contains('Starbucks'));
    expect(result.spentAt, isNotNull);
  });

  test('Hardened: Generic mixed SMS with available balance avoided', () {
    final result = parser.parse('''
POS transaction
125.00 USD
at Booking.com
2026-04-11 20:30
Available balance 2000.00 USD
''');

    expect(result.amount, 125.00,
        reason: 'Must use 125.00 transaction, not 2000.00 available balance');
    expect(result.currencyCode, 'USD');
    expect(result.merchant, contains('Booking'));
    expect(result.spentAt, DateTime(2026, 4, 11, 20, 30));
  });

  test('Hardened: Low-confidence SMS keeps fields empty instead of guessing', () {
    final result = parser.parse('''
Your card activity notice
Ref 12345
''');

    expect(result.amount, isNull,
        reason: 'No clear amount should be null, not guessed');
    expect(result.merchant == null || result.merchant!.isEmpty, true,
        reason: 'No clear merchant should be null/empty, not guessed');
    expect(result.currencyCode, isNull, reason: 'No clear currency');
    expect(result.spentAt, isNull, reason: 'No clear date/time');
  });
}
