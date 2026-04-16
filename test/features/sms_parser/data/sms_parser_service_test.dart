import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_option_labels.dart';
import 'package:travel_expenses/features/sms_parser/data/sms_parser_service.dart';

void main() {
  final parser = SmsParserService();

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

  test('Al Rajhi: POS purchase with labeled amount and merchant لدى', () {
    final result = parser.parse('''
شراء عبر نقاط البيع
بطاقة:8664 ;فيزا-ابل باي
لدى:NAFTHAT A
مبلغ:15 SAR
رصيد:1780.92 SAR
12/4/26 13:24
''');

    expect(result.amount, 15);
    expect(result.currencyCode, 'SAR');
    expect(result.merchant, 'NAFTHAT A');
    expect(result.spentAt, DateTime(2026, 4, 12, 13, 24));
    expect(result.suggestedPaymentNetwork, 'Visa');
    expect(result.suggestedPaymentChannel, 'POS Purchase');
    expect(result.suggestedPaymentMethod, 'Credit Card');
  });

  test('Al Rajhi: internet purchase fallback amount from بـSR line', () {
    final result = parser.parse('''
شراء إنترنت بـSR 6.97
عبر 8664 ;فيزا-ابل باي
لـCAREEM RI
رصيد:1795.92 SR
11/4/26 20:53
''');

    expect(result.amount, 6.97);
    expect(result.currencyCode, 'SAR');
    expect(result.merchant, 'CAREEM RI');
    expect(result.spentAt, DateTime(2026, 4, 11, 20, 53));
    expect(result.suggestedPaymentNetwork, 'Visa');
    expect(result.suggestedPaymentChannel, 'Online Purchase');
    expect(result.suggestedPaymentMethod, 'Credit Card');
  });

  test('Al Rajhi: POS purchase with large labeled amount', () {
    final result = parser.parse('''
شراء عبر نقاط البيع
بطاقة:1331 ;فيزا
لدى:ALJAZIRA T
مبلغ:500 SAR
رصيد:14304.82 SAR
10/4/26 00:49
''');

    expect(result.amount, 500);
    expect(result.currencyCode, 'SAR');
    expect(result.merchant, 'ALJAZIRA T');
    expect(result.spentAt, DateTime(2026, 4, 10, 0, 49));
    expect(result.suggestedPaymentNetwork, 'Visa');
    expect(result.suggestedPaymentChannel, 'POS Purchase');
    expect(result.suggestedPaymentMethod, 'Credit Card');
    expect(result.isInternational, isFalse);
    expect(result.feesAmount, isNull);
    expect(result.totalChargedAmount, isNull);
  });

  test('Al Rajhi: keeps primary amount and ignores fees and total due', () {
    final result = parser.parse('''
شراء انترنت
بطاقة:8664 ;فيزا-ابل باي
مبلغ: 11.91 SAR
لدى:UBR* PEND
رسوم وضريبة: 0.24 SAR
اجمالي المبلغ المستحق: 12.15 SAR
دولة:Netherlands
رصيد:1902.19 SAR
في:7/4/26 18:46
''');

    expect(result.amount, 11.91);
    expect(result.currencyCode, 'SAR');
    expect(result.merchant, 'UBR* PEND');
    expect(result.spentAt, DateTime(2026, 4, 7, 18, 46));
    expect(result.suggestedPaymentNetwork, 'Visa');
    expect(result.suggestedPaymentChannel, 'Online Purchase');
    expect(result.suggestedPaymentMethod, 'Credit Card');
  });

  test('Al Rajhi: foreign currency uses USD amount and not total due SAR', () {
    final result = parser.parse('''
شراء انترنت
بطاقة: 1331 ;فيزا
مبلغ: 100 USD (375.45 ريال)
لدى: GITHUB, I
رسوم وضريبة: 7.51 SAR
سعر الصرف~ 3.7545
إجمالي المبلغ المستحق: 382.96 SAR
دولة: USA
رصيد: 13015.49 SAR
13/3/26 20:29
''');

    expect(result.amount, 100);
    expect(result.currencyCode, 'USD');
    expect(result.merchant, 'GITHUB, I');
    expect(result.spentAt, DateTime(2026, 3, 13, 20, 29));
    expect(result.suggestedPaymentNetwork, 'Visa');
    expect(result.suggestedPaymentChannel, 'Online Purchase');
    expect(result.suggestedPaymentMethod, 'Credit Card');
    expect(result.transactionAmount, 100);
    expect(result.transactionCurrency, 'USD');
    expect(result.billedAmount, 375.45);
    expect(result.billedCurrency, 'SAR');
    expect(result.feesAmount, 7.51);
    expect(result.feesCurrency, 'SAR');
    expect(result.totalChargedAmount, 382.96);
    expect(result.totalChargedCurrency, 'SAR');
    expect(result.isInternational, isTrue);
  });

  test('Al Rajhi: merchant falls back to لـ and keeps datetime with time', () {
    final result = parser.parse('''
شراء انترنت بـSR 5
عبر:9565;مدى-ابل باي
من:7329
لـbarq
13/4/26 08:05
''');

    expect(result.amount, 5);
    expect(result.currencyCode, 'SAR');
    expect(result.merchant, 'barq');
    expect(result.spentAt, DateTime(2026, 4, 13, 8, 5));
    expect(result.suggestedPaymentNetwork, 'Mada');
    expect(result.suggestedPaymentChannel, 'Online Purchase');
    expect(result.suggestedPaymentMethod, 'Debit Card');
  });

  group('SAB', () {
    test('SAB example 1: Online Purchase with foreign currency (THB)', () {
      final result = parser.parse('''
Online Purchase
SAB Mastercard Alfursan Credit Card (8263) was used at AMP*AIS SERVICES for THB 10.00 in THAILAND
Exchange rate: 0.11800
Amount in SAR: 1.18
International Fees in SAR: 0.02
Total amount in SAR: 1.20
Date: 2026-04-10 11:42:33
Balance: SAR 1141.56
''');

      expect(result.amount, 10.00);
      expect(result.currencyCode, 'THB');
      expect(result.merchant, 'AMP*AIS SERVICES');
      expect(result.spentAt, DateTime(2026, 4, 10, 11, 42));
      expect(result.suggestedPaymentNetwork, 'Mastercard');
      expect(result.suggestedPaymentChannel, 'Online Purchase');
      expect(result.suggestedPaymentMethod, 'Credit Card');
      expect(result.billedAmount, 1.18);
      expect(result.billedCurrency, 'SAR');
      expect(result.feesAmount, 0.02);
      expect(result.feesCurrency, 'SAR');
      expect(result.totalChargedAmount, 1.20);
      expect(result.totalChargedCurrency, 'SAR');
      expect(result.isInternational, isTrue);
      // Must NOT use any of the secondary amounts
      expect(result.amount, isNot(1.18));
      expect(result.amount, isNot(1.20));
    });

    test('SAB parses billed/fees/total with label variations', () {
      final result = parser.parse('''
Online Purchase
SAB Mastercard Alfursan Credit Card (8263) was used at AMP*AIS SERVICES for THB 10.00 in THAILAND
Amount in SAR 1.18
International Fees 0.02
Total amount 1.20
Date: 2026-04-10 11:42:33
Balance: SAR 1141.56
''');

      expect(result.transactionAmount, 10.00);
      expect(result.transactionCurrency, 'THB');
      expect(result.billedAmount, 1.18);
      expect(result.billedCurrency, 'SAR');
      expect(result.feesAmount, 0.02);
      expect(result.feesCurrency, 'SAR');
      expect(result.totalChargedAmount, 1.20);
      expect(result.totalChargedCurrency, 'SAR');
      expect(result.isInternational, isTrue);
    });

    test('SAB example 2: POS Purchase with inline datetime', () {
      final result = parser.parse('''
POS Purchase
SAB Mastercard Alfursan Credit Card (8263) was used at ALJAZIRA TAKAFUL TAAWU for SAR 500.00 on 2026-04-10 00:49:35
Balance: SAR 1145.10
''');

      expect(result.amount, 500.00);
      expect(result.currencyCode, 'SAR');
      expect(result.merchant, 'ALJAZIRA TAKAFUL TAAWU');
      expect(result.spentAt, DateTime(2026, 4, 10, 0, 49));
      expect(result.suggestedPaymentNetwork, 'Mastercard');
      expect(result.suggestedPaymentChannel, 'POS Purchase');
      expect(result.suggestedPaymentMethod, 'Credit Card');
      expect(result.amount, isNot(1145.10));
    });

    test('SAB example 3: POS Purchase via Apple Pay — Apple Pay is detail not channel', () {
      final result = parser.parse('''
POS Purchase
SAB Mastercard Alfursan Credit Card (8263) was used at AJLAN BROS for SAR 720.00 via Apple Pay
Date: 2026-03-18 09:45:13
Balance: SAR 1112.77
''');

      expect(result.amount, 720.00);
      expect(result.currencyCode, 'SAR');
      expect(result.merchant, 'AJLAN BROS');
      expect(result.spentAt, DateTime(2026, 3, 18, 9, 45));
      expect(result.suggestedPaymentNetwork, 'Mastercard');
      expect(result.suggestedPaymentChannel, 'POS Purchase');
      expect(result.suggestedPaymentMethod, 'Credit Card');
    });

    test('SAB example 4: PoS International Purchase — channel normalized safely', () {
      final result = parser.parse('''
PoS International Purchase
SAB Mastercard Alfursan Credit Card (8263) was used at www.shein.com for SAR 909.97 in UNITED ARAB EMIRATES
Exchange rate: 1.00000
Amount in SAR: 909.97
International Fees: 20.92
Total amount: 930.89
Date: 2026-02-22 14:34:20
Balance: SAR 2354.38
''');

      expect(result.amount, 909.97);
      expect(result.currencyCode, 'SAR');
      expect(result.merchant, 'www.shein.com');
      expect(result.spentAt, DateTime(2026, 2, 22, 14, 34));
      expect(result.suggestedPaymentNetwork, 'Mastercard');
      expect(result.suggestedPaymentChannel, 'POS Purchase');
      expect(result.suggestedPaymentMethod, 'Credit Card');
      // Fees and total must not be used as amount
      expect(result.amount, isNot(930.89));
      expect(result.amount, isNot(20.92));
    });

    test('SAB parsed channel is always valid for dropdown', () {
      final result = parser.parse('''
PoS International Purchase
SAB Mastercard Alfursan Credit Card (8263) was used at www.shein.com for SAR 909.97 in UNITED ARAB EMIRATES
Exchange rate: 1.00000
Amount in SAR: 909.97
International Fees: 20.92
Total amount: 930.89
Date: 2026-02-22 14:34:20
Balance: SAR 2354.38
''');

      expect(
        ExpenseOptionLabels.paymentChannels.contains(
          result.suggestedPaymentChannel,
        ),
        isTrue,
      );
    });

    test('SAB example 5: POS Purchase with inline datetime — Amazon SA', () {
      final result = parser.parse('''
POS Purchase
SAB Mastercard Alfursan Credit Card (9519) was used at Amazon SA for SAR 73.74 on 2026-02-16 20:48:47
Balance: SAR 2956.62
''');

      expect(result.amount, 73.74);
      expect(result.currencyCode, 'SAR');
      expect(result.merchant, 'Amazon SA');
      expect(result.spentAt, DateTime(2026, 2, 16, 20, 48));
      expect(result.suggestedPaymentNetwork, 'Mastercard');
      expect(result.suggestedPaymentChannel, 'POS Purchase');
      expect(result.suggestedPaymentMethod, 'Credit Card');
      expect(result.amount, isNot(2956.62));
    });
  });

  test('payment channel dropdown values are unique', () {
    expect(
      ExpenseOptionLabels.paymentChannels.toSet().length,
      ExpenseOptionLabels.paymentChannels.length,
      reason: 'Duplicate payment channel values can trigger DropdownButton assertion.',
    );
  });
}
