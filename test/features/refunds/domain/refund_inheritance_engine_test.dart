import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/refunds/domain/over_refund_exception.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/refunds/domain/refund_inheritance_engine.dart';

void main() {
  late RefundInheritanceEngine engine;

  setUp(() {
    engine = const RefundInheritanceEngine();
  });

  // ---------------------------------------------------------------------------
  // 1. Linked cash refund creates a cash-lot plan
  // ---------------------------------------------------------------------------

  group('1 — linked cash refund creates cash-lot plan', () {
    test('shouldCreateCashLot is true and fields are populated', () {
      final plan = engine.planCashRefund(
        expenseId: 'exp-001',
        refundAmount: 1200,
        refundCurrency: 'JPY',
        homeAmount: 30.0,
        homeCurrency: 'SAR',
      );

      expect(plan.shouldCreateCashLot, isTrue);
      expect(plan.destination, RefundDestination.cash);
      expect(plan.cashLotAmount, closeTo(1200, 1e-6));
      expect(plan.cashLotCurrency, 'JPY');
      expect(plan.inheritedHomeAmount, closeTo(30.0, 1e-6));
      expect(plan.inheritedHomeCurrency, 'SAR');
      expect(plan.linkedExpenseId, 'exp-001');
      expect(plan.isUnlinked, isFalse);
    });

    test('currency is normalised to upper-case', () {
      final plan = engine.planCashRefund(
        expenseId: 'exp-x',
        refundAmount: 100,
        refundCurrency: 'jpy',
        homeAmount: 2.5,
        homeCurrency: 'sar',
      );

      expect(plan.refundCurrency, 'JPY');
      expect(plan.cashLotCurrency, 'JPY');
      expect(plan.inheritedHomeCurrency, 'SAR');
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Linked cash refund effectiveRate calculation
  // ---------------------------------------------------------------------------

  group('2 — effectiveRate calculation', () {
    test('effectiveRate == homeAmount / refundAmount', () {
      final plan = engine.planCashRefund(
        expenseId: 'exp-002',
        refundAmount: 4000,
        refundCurrency: 'JPY',
        homeAmount: 100.0,
        homeCurrency: 'SAR',
      );

      // 100 SAR / 4000 JPY = 0.025 SAR/JPY
      expect(plan.effectiveRate, closeTo(0.025, 1e-9));
    });

    test('effectiveRate is null when homeAmount is null (linked, no snapshot)', () {
      final plan = engine.planCashRefund(
        expenseId: 'exp-003',
        refundAmount: 2000,
        refundCurrency: 'JPY',
        // no homeAmount provided — linked expense might not have one
      );

      expect(plan.effectiveRate, isNull);
      expect(plan.inheritedHomeAmount, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Partial refund allowed
  // ---------------------------------------------------------------------------

  group('3 — partial refund allowed', () {
    test('refundAmount less than expense amount is accepted', () {
      // Expense original home amount = 100 SAR; refunding 60 SAR worth
      final plan = engine.planCashRefund(
        expenseId: 'exp-004',
        refundAmount: 2400,
        refundCurrency: 'JPY',
        homeAmount: 60.0,
        homeCurrency: 'SAR',
        linkedExpenseHomeAmount: 100.0,
        linkedExpenseHomeCurrency: 'SAR',
        existingRefundsHomeTotal: 0.0,
      );

      expect(plan.inheritedHomeAmount, closeTo(60.0, 1e-6));
    });

    test('second partial refund allowed when cumulative stays within limit', () {
      // Already refunded 40 SAR; now refunding another 50 SAR; limit = 100 SAR
      final plan = engine.planCashRefund(
        expenseId: 'exp-005',
        refundAmount: 2000,
        refundCurrency: 'JPY',
        homeAmount: 50.0,
        homeCurrency: 'SAR',
        linkedExpenseHomeAmount: 100.0,
        linkedExpenseHomeCurrency: 'SAR',
        existingRefundsHomeTotal: 40.0,
      );

      expect(plan.inheritedHomeAmount, closeTo(50.0, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Over-refund rejected
  // ---------------------------------------------------------------------------

  group('4 — over-refund rejected', () {
    test('throws OverRefundException when new + existing > limit', () {
      expect(
        () => engine.planCashRefund(
          expenseId: 'exp-006',
          refundAmount: 5000,
          refundCurrency: 'JPY',
          homeAmount: 80.0,
          homeCurrency: 'SAR',
          linkedExpenseHomeAmount: 100.0,
          linkedExpenseHomeCurrency: 'SAR',
          existingRefundsHomeTotal: 50.0, // 50 + 80 = 130 > 100
        ),
        throwsA(
          isA<OverRefundException>()
              .having((e) => e.requested, 'requested', closeTo(80.0, 1e-6))
              .having((e) => e.existing, 'existing', closeTo(50.0, 1e-6))
              .having((e) => e.limit, 'limit', closeTo(100.0, 1e-6)),
        ),
      );
    });

    test('over-refund check also applies to card refunds', () {
      expect(
        () => engine.planCardRefund(
          expenseId: 'exp-007',
          refundAmount: 3000,
          refundCurrency: 'JPY',
          homeAmount: 90.0,
          homeCurrency: 'SAR',
          linkedExpenseHomeAmount: 100.0,
          linkedExpenseHomeCurrency: 'SAR',
          existingRefundsHomeTotal: 20.0, // 20 + 90 = 110 > 100
        ),
        throwsA(isA<OverRefundException>()),
      );
    });

    test('exactly at the limit is accepted (epsilon boundary)', () {
      // existing 40 + new 60 = 100 exactly == limit 100 → ok
      final plan = engine.planCashRefund(
        expenseId: 'exp-008',
        refundAmount: 2400,
        refundCurrency: 'JPY',
        homeAmount: 60.0,
        homeCurrency: 'SAR',
        linkedExpenseHomeAmount: 100.0,
        linkedExpenseHomeCurrency: 'SAR',
        existingRefundsHomeTotal: 40.0,
      );
      expect(plan.inheritedHomeAmount, closeTo(60.0, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Cash refund without home amount rejected when unlinked
  // ---------------------------------------------------------------------------

  group('5 — unlinked cash refund without home amount rejected', () {
    test('throws ArgumentError when expenseId is null and homeAmount is null', () {
      expect(
        () => engine.planCashRefund(
          expenseId: null,
          refundAmount: 1000,
          refundCurrency: 'JPY',
          // no homeAmount
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Unlinked cash refund with home amount accepted
  // ---------------------------------------------------------------------------

  group('6 — unlinked cash refund with home amount accepted', () {
    test('isUnlinked is true and lot is created with caller-supplied basis', () {
      final plan = engine.planCashRefund(
        expenseId: null,
        refundAmount: 5000,
        refundCurrency: 'JPY',
        homeAmount: 125.0,
        homeCurrency: 'SAR',
      );

      expect(plan.isUnlinked, isTrue);
      expect(plan.linkedExpenseId, isNull);
      expect(plan.shouldCreateCashLot, isTrue);
      expect(plan.inheritedHomeAmount, closeTo(125.0, 1e-6));
      expect(plan.inheritedHomeCurrency, 'SAR');
      expect(plan.effectiveRate, closeTo(0.025, 1e-9)); // 125/5000
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Card refund creates no cash lot
  // ---------------------------------------------------------------------------

  group('7 — card refund creates no cash lot', () {
    test('shouldCreateCashLot is false for card refund', () {
      final plan = engine.planCardRefund(
        expenseId: 'exp-card-1',
        refundAmount: 3000,
        refundCurrency: 'JPY',
        homeAmount: 75.0,
        homeCurrency: 'SAR',
      );

      expect(plan.shouldCreateCashLot, isFalse);
      expect(plan.destination, RefundDestination.card);
      expect(plan.cashLotAmount, isNull);
      expect(plan.cashLotCurrency, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Linked card refund accepts home amount
  // ---------------------------------------------------------------------------

  group('8 — linked card refund accepts home amount', () {
    test('plan has inherited home amount and is not unlinked', () {
      final plan = engine.planCardRefund(
        expenseId: 'exp-card-2',
        refundAmount: 2000,
        refundCurrency: 'JPY',
        homeAmount: 50.0,
        homeCurrency: 'SAR',
      );

      expect(plan.inheritedHomeAmount, closeTo(50.0, 1e-6));
      expect(plan.inheritedHomeCurrency, 'SAR');
      expect(plan.isUnlinked, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Unlinked card refund accepts null home amount
  // ---------------------------------------------------------------------------

  group('9 — unlinked card refund accepts null home amount', () {
    test('no error when expenseId is null and homeAmount is null for card refund', () {
      final plan = engine.planCardRefund(
        expenseId: null,
        refundAmount: 1500,
        refundCurrency: 'JPY',
        // no homeAmount — allowed for card
      );

      expect(plan.inheritedHomeAmount, isNull);
      expect(plan.inheritedHomeCurrency, isNull);
      expect(plan.isUnlinked, isTrue);
      expect(plan.shouldCreateCashLot, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 10. isUnlinked flag
  // ---------------------------------------------------------------------------

  group('10 — isUnlinked flag', () {
    test('isUnlinked is true when expenseId is null (cash)', () {
      final plan = engine.planCashRefund(
        expenseId: null,
        refundAmount: 1000,
        refundCurrency: 'JPY',
        homeAmount: 25.0,
        homeCurrency: 'SAR',
      );
      expect(plan.isUnlinked, isTrue);
    });

    test('isUnlinked is false when expenseId is provided (cash)', () {
      final plan = engine.planCashRefund(
        expenseId: 'exp-linked',
        refundAmount: 1000,
        refundCurrency: 'JPY',
      );
      expect(plan.isUnlinked, isFalse);
    });

    test('isUnlinked is true when expenseId is null (card)', () {
      final plan = engine.planCardRefund(
        expenseId: null,
        refundAmount: 500,
        refundCurrency: 'JPY',
      );
      expect(plan.isUnlinked, isTrue);
    });

    test('isUnlinked is false when expenseId is provided (card)', () {
      final plan = engine.planCardRefund(
        expenseId: 'exp-linked-card',
        refundAmount: 500,
        refundCurrency: 'JPY',
      );
      expect(plan.isUnlinked, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 11. Destination cash vs card
  // ---------------------------------------------------------------------------

  group('11 — destination field', () {
    test('planCashRefund returns destination == cash', () {
      final plan = engine.planCashRefund(
        expenseId: 'exp-d',
        refundAmount: 1000,
        refundCurrency: 'JPY',
      );
      expect(plan.destination, RefundDestination.cash);
    });

    test('planCardRefund returns destination == card', () {
      final plan = engine.planCardRefund(
        expenseId: 'exp-d',
        refundAmount: 1000,
        refundCurrency: 'JPY',
      );
      expect(plan.destination, RefundDestination.card);
    });
  });

  // ---------------------------------------------------------------------------
  // 12. Decimal precision
  // ---------------------------------------------------------------------------

  group('12 — decimal precision', () {
    test('effectiveRate for repeating decimal amount', () {
      // 1/3 SAR per 1/3 JPY → effectiveRate should be exactly 1.0
      final third = 1.0 / 3.0;
      final plan = engine.planCashRefund(
        expenseId: 'exp-frac',
        refundAmount: third,
        refundCurrency: 'JPY',
        homeAmount: third,
        homeCurrency: 'SAR',
      );
      expect(plan.effectiveRate, closeTo(1.0, 1e-9));
    });

    test('effectiveRate for sub-unit amounts', () {
      final plan = engine.planCashRefund(
        expenseId: 'exp-sub',
        refundAmount: 0.01,
        refundCurrency: 'JPY',
        homeAmount: 0.00025,
        homeCurrency: 'SAR',
      );
      // 0.00025 / 0.01 = 0.025
      expect(plan.effectiveRate, closeTo(0.025, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // 13. refundAmount <= 0 rejected
  // ---------------------------------------------------------------------------

  group('13 — refundAmount <= 0 rejected', () {
    test('throws ArgumentError when refundAmount == 0 (cash)', () {
      expect(
        () => engine.planCashRefund(
          expenseId: 'exp-z',
          refundAmount: 0,
          refundCurrency: 'JPY',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when refundAmount < 0 (cash)', () {
      expect(
        () => engine.planCashRefund(
          expenseId: 'exp-neg',
          refundAmount: -100,
          refundCurrency: 'JPY',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when refundAmount == 0 (card)', () {
      expect(
        () => engine.planCardRefund(
          expenseId: 'exp-zc',
          refundAmount: 0,
          refundCurrency: 'JPY',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 14. Home snapshot incoherence rejected
  // ---------------------------------------------------------------------------

  group('14 — home snapshot incoherence rejected', () {
    test('homeAmount provided without homeCurrency throws ArgumentError (cash)', () {
      expect(
        () => engine.planCashRefund(
          expenseId: 'exp-incoherent-1',
          refundAmount: 1000,
          refundCurrency: 'JPY',
          homeAmount: 25.0,
          homeCurrency: null, // missing
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('homeCurrency provided without homeAmount throws ArgumentError (cash)', () {
      expect(
        () => engine.planCashRefund(
          expenseId: 'exp-incoherent-2',
          refundAmount: 1000,
          refundCurrency: 'JPY',
          homeAmount: null, // missing
          homeCurrency: 'SAR',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('homeAmount provided without homeCurrency throws ArgumentError (card)', () {
      expect(
        () => engine.planCardRefund(
          expenseId: 'exp-incoherent-3',
          refundAmount: 1000,
          refundCurrency: 'JPY',
          homeAmount: 25.0,
          homeCurrency: null,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('homeCurrency provided without homeAmount throws ArgumentError (card)', () {
      expect(
        () => engine.planCardRefund(
          expenseId: 'exp-incoherent-4',
          refundAmount: 1000,
          refundCurrency: 'JPY',
          homeAmount: null,
          homeCurrency: 'SAR',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty-string homeCurrency treated as absent — incoherent with homeAmount', () {
      expect(
        () => engine.planCashRefund(
          expenseId: 'exp-incoherent-5',
          refundAmount: 1000,
          refundCurrency: 'JPY',
          homeAmount: 25.0,
          homeCurrency: '   ', // blank
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
