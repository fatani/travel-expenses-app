import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_option_labels.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

/// The ATM withdrawal fee must read as a clear ATM card fee — never the generic
/// "Other / Other" it collapsed to before the fix.
void main() {
  group('ATM fee labels — English', () {
    late AppLocalizations en;

    setUp(() async {
      en = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test("category 'Fees' is not labelled Other", () {
      final label = ExpenseOptionLabels.category(en, 'Fees');
      expect(label, isNot(equals(en.expenseCategoryOther)));
      expect(label, en.cashWalletAtmFeeCategory);
    });

    test("channel 'ATM Withdrawal Fee' is not labelled Other", () {
      final label = ExpenseOptionLabels.paymentChannel(en, 'ATM Withdrawal Fee');
      expect(label, isNot(equals(en.paymentChannelOther)));
      expect(label, en.cashWalletAtmWithdrawalFeeChannel);
    });

    test('payment summary surfaces the ATM withdrawal fee channel', () {
      final summary = ExpenseOptionLabels.paymentSummary(
        en,
        paymentMethodValue: 'Credit Card',
        paymentChannelValue: 'ATM Withdrawal Fee',
      );
      expect(summary, contains(en.cashWalletAtmWithdrawalFeeChannel));
      expect(summary, isNot(equals(en.paymentChannelOther)));
    });
  });

  group('ATM fee labels — Arabic', () {
    late AppLocalizations ar;

    setUp(() async {
      ar = await AppLocalizations.delegate.load(const Locale('ar'));
    });

    test("category 'Fees' shows the Arabic ATM fee label", () {
      final label = ExpenseOptionLabels.category(ar, 'Fees');
      expect(label, isNot(equals(ar.expenseCategoryOther)));
      expect(label, 'رسوم الصراف');
    });

    test("channel 'ATM Withdrawal Fee' shows the Arabic fee label", () {
      final label = ExpenseOptionLabels.paymentChannel(ar, 'ATM Withdrawal Fee');
      expect(label, isNot(equals(ar.paymentChannelOther)));
      expect(label, 'رسوم سحب من الصراف');
    });
  });
}
