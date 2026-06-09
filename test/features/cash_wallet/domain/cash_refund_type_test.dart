import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/backup/domain/backup_persisted_enums.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';

void main() {
  group('CashTransactionType.cashRefund', () {
    test('signedDelta returns positive amount', () {
      expect(CashTransactionType.cashRefund.signedDelta(100.0), 100.0);
      expect(CashTransactionType.cashRefund.signedDelta(0.5), 0.5);
    });

    test('value codec encodes to cash_refund', () {
      expect(CashTransactionType.cashRefund.value, 'cash_refund');
    });

    test('fromValue decodes cash_refund correctly', () {
      expect(
        CashTransactionTypeCodec.fromValue('cash_refund'),
        CashTransactionType.cashRefund,
      );
    });

    test('BackupPersistedEnums accepts cash_refund', () {
      expect(
        BackupPersistedEnums.isKnownCashTransactionType('cash_refund'),
        isTrue,
      );
    });

    test('BackupPersistedEnums rejects unknown type', () {
      expect(
        BackupPersistedEnums.isKnownCashTransactionType('unknown_type'),
        isFalse,
      );
    });

    test('BackupPersistedEnums.refundDestinations contains cash and card', () {
      expect(BackupPersistedEnums.isKnownRefundDestination('cash'), isTrue);
      expect(BackupPersistedEnums.isKnownRefundDestination('card'), isTrue);
      expect(BackupPersistedEnums.isKnownRefundDestination('wallet'), isFalse);
      expect(BackupPersistedEnums.isKnownRefundDestination(null), isFalse);
    });
  });
}
