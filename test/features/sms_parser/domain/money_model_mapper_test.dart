import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/sms_parser/data/sms_parser_service.dart';
import 'package:travel_expenses/features/sms_parser/domain/sms_parse_result_money_mapper.dart';

void main() {
  final parser = SmsParserService();

  group('MoneyModel mapper', () {
    test('SNB case maps primary transaction without inventing optional fields', () {
      final result = parser.parse('''
شراء إنترنت (Apple Pay)
مبلغ 46.00 SAR
بطاقة ائتمانية ****4744
من Mobily
التاريخ 11/04/26 12:07
الصرف المتبقي 5859.81 SAR
''');

      final money = result.toMoneyModel();

      expect(money.transactionAmount, 46.00);
      expect(money.transactionCurrency, 'SAR');
      expect(money.billedAmount, isNull);
      expect(money.totalChargedAmount, isNull);
      expect(money.feesAmount, isNull);
      expect(money.isInternational, isFalse);
    });

    test('Al Rajhi international case maps billed + fees + total', () {
      final result = parser.parse('''
شراء إنترنت
بطاقة: 1234; visa
لدى: AMAZON
مبلغ: USD 10.00 (37.53 SAR)
رسوم وضريبة: 0.24 SAR
اجمالي المبلغ المستحق: 37.77 SAR
13/04/26 08:05
''');

      final money = result.toMoneyModel();

      expect(money.transactionAmount, 10.00);
      expect(money.transactionCurrency, 'USD');
      expect(money.billedAmount, 37.53);
      expect(money.billedCurrency, 'SAR');
      expect(money.feesAmount, 0.24);
      expect(money.feesCurrency, 'SAR');
      expect(money.totalChargedAmount, 37.77);
      expect(money.totalChargedCurrency, 'SAR');
      expect(money.isInternational, isTrue);
    });

    test('SAB international case maps billed + fees + total charged', () {
      final result = parser.parse('''
Online Purchase
SAB Mastercard Alfursan Credit Card (8263) was used at AMP*AIS SERVICES for THB 10.00 in THAILAND
Amount in SAR: 1.18
International Fees in SAR: 0.02
Total amount in SAR: 1.20
Date: 2026-04-10 11:42:33
Balance: SAR 1141.56
''');

      final money = result.toMoneyModel();

      expect(money.transactionAmount, 10.00);
      expect(money.transactionCurrency, 'THB');
      expect(money.billedAmount, 1.18);
      expect(money.billedCurrency, 'SAR');
      expect(money.feesAmount, 0.02);
      expect(money.totalChargedAmount, 1.20);
      expect(money.totalChargedCurrency, 'SAR');
      expect(money.isInternational, isTrue);
    });

    test('D360 billed without fees keeps optional fees null', () {
      final result = parser.parse('''
بطاقة: 8263 VISA Ecommerce
مبلغ: THB 10.00 (SAR 1.18)
لدى: AMP*AIS SERVICES
في: 08:01 2026-04-16
''');

      final money = result.toMoneyModel();

      expect(money.transactionAmount, 10.00);
      expect(money.transactionCurrency, 'THB');
      expect(money.billedAmount, 1.18);
      expect(money.billedCurrency, 'SAR');
      expect(money.feesAmount, isNull);
      expect(money.totalChargedAmount, isNull);
      expect(money.isInternational, isTrue);
    });

    test('Barq billed without fees keeps optional fees null', () {
      final result = parser.parse('''
شراء إنترنت
بطاقة فيزا
مبلغ USD (37.53 SAR) 10
لدى WWW PERPLEXITY AI
2026-03-17 11:38
''');

      final money = result.toMoneyModel();

      expect(money.transactionAmount, 10.0);
      expect(money.transactionCurrency, 'USD');
      expect(money.billedAmount, 37.53);
      expect(money.billedCurrency, 'SAR');
      expect(money.feesAmount, isNull);
      expect(money.totalChargedAmount, isNull);
      expect(money.isInternational, isTrue);
    });

    test('Future-proof case: D360 captures fees when message includes them', () {
      final result = parser.parse('''
بطاقة: 8263 VISA Ecommerce
مبلغ: THB 10.00 (SAR 1.18)
رسوم: SAR 0.02
لدى: AMP*AIS SERVICES
في: 08:01 2026-04-16
''');

      final money = result.toMoneyModel();

      expect(money.transactionAmount, 10.00);
      expect(money.transactionCurrency, 'THB');
      expect(money.billedAmount, 1.18);
      expect(money.feesAmount, 0.02);
      expect(money.feesCurrency, 'SAR');
      expect(money.isInternational, isTrue);
    });
  });
}
