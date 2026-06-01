import '../../cash_wallet/domain/cash_transaction.dart';
import '../../expenses/presentation/expense_option_labels.dart';
import '../../settings/domain/card_profile_enums.dart';

/// Known persisted enum / closed-set values for backup restore validation.
///
/// Restore must reject rows with values outside these sets rather than
/// coercing unknown values (e.g. [CashTransactionTypeCodec.fromValue] default).
abstract final class BackupPersistedEnums {
  static const Set<String> cashTransactionTypes = {
    'initial_cash',
    'atm_withdrawal',
    'currency_exchange_in',
    'currency_exchange_out',
    'manual_adjustment',
    'cash_expense_deduction',
  };

  static final Set<String> expensePaymentMethods =
      ExpenseOptionLabels.paymentMethods.toSet();

  static final Set<String> expensePaymentNetworks =
      ExpenseOptionLabels.paymentNetworks.toSet();

  /// Includes legacy channel strings still present in older rows.
  static final Set<String> expensePaymentChannels = {
    ...ExpenseOptionLabels.paymentChannels,
    'Card Present',
    'Online',
  };

  static final Set<String> expenseCategories =
      ExpenseOptionLabels.categories.toSet();

  static const Set<String> expenseSources = {'manual', 'sms'};

  static bool isKnownCashTransactionType(String? raw) {
    return raw != null && cashTransactionTypes.contains(raw);
  }

  static bool isKnownExpensePaymentMethod(String? raw) {
    return raw != null && expensePaymentMethods.contains(raw);
  }

  static bool isKnownExpensePaymentNetwork(String? raw) {
    if (raw == null || raw.isEmpty) {
      return true;
    }
    return expensePaymentNetworks.contains(raw);
  }

  static bool isKnownExpensePaymentChannel(String? raw) {
    if (raw == null || raw.isEmpty) {
      return true;
    }
    return expensePaymentChannels.contains(raw);
  }

  static bool isKnownExpenseCategory(String? raw) {
    if (raw == null || raw.isEmpty) {
      return true;
    }
    return expenseCategories.contains(raw);
  }

  static bool isKnownExpenseSource(String? raw) {
    return raw != null && expenseSources.contains(raw);
  }

  static bool isKnownCardBank(String? raw) {
    if (raw == null || raw.isEmpty) {
      return true;
    }
    return _cardBankStorageValues.contains(raw);
  }

  static bool isKnownCardNetwork(String? raw) {
    if (raw == null || raw.isEmpty) {
      return true;
    }
    return _cardNetworkStorageValues.contains(raw);
  }

  static bool isKnownCardTier(String? raw) {
    if (raw == null || raw.isEmpty) {
      return true;
    }
    return _cardTierStorageValues.contains(raw);
  }

  static final Set<String> _cardBankStorageValues = {
    for (final bank in CardBank.values) bank.storageValue,
  };

  static final Set<String> _cardNetworkStorageValues = {
    for (final network in CardNetwork.values) network.storageValue,
  };

  static final Set<String> _cardTierStorageValues = {
    for (final tier in CardTier.values) tier.storageValue,
  };
}
