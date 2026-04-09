import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/sms_parser/data/sms_parser_service.dart';

void main() {
  const service = SmsParserService();

  test('parses amount currency merchant and date from common bank SMS', () {
    final result = service.parse(
      'Card purchase of USD 24.50 at Starbucks Airport on 09/04/2026 14:35',
    );

    expect(result.amount, 24.50);
    expect(result.currencyCode, 'USD');
    expect(result.merchant, 'Starbucks Airport');
    expect(result.suggestedCategory, 'Food');
    expect(result.spentAt, DateTime(2026, 4, 9, 14, 35));
  });

  test('suggests category and keeps missing fields null when not found', () {
    final result = service.parse(
      'Transaction alert: payment completed at Grand Hotel Downtown',
    );

    expect(result.amount, isNull);
    expect(result.currencyCode, isNull);
    expect(result.suggestedCategory, 'Accommodation');
    expect(result.merchant, 'Grand Hotel Downtown');
  });
}
