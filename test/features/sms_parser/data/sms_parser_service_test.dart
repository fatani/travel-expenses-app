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
}
