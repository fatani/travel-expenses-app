import 'package:travel_expenses/l10n/app_localizations.dart';

import '../domain/expense_payment.dart';

class ExpenseOptionLabels {
  const ExpenseOptionLabels._();

  static const List<String> categories = <String>[
    'Transport',
    'Accommodation',
    'Food',
    'Visa',
    'Shopping',
    'Entertainment',
    'Other',
  ];

  static const List<String> paymentMethods = <String>[
    'Cash',
    'Credit Card',
    'Debit Card',
    'Bank Transfer',
    'Other',
  ];

  static const List<String> paymentNetworks = <String>[
    'Visa',
    'Mastercard',
    'Mada',
    'Other',
  ];

  static const List<String> paymentChannels = <String>[
    'POS Purchase',
    'Online Purchase',
    'Cash',
    'Other',
  ];

  /// Primary expense-entry payment choices (method, not purchase channel).
  static const List<String> primaryPaymentMethods = <String>[
    'Cash',
    'Card',
    'Other',
  ];

  /// Purchase channels shown only when [primaryPaymentMethods] Card is selected.
  static const List<String> cardPurchaseChannels = <String>[
    'POS Purchase',
    'Online Purchase',
  ];

  static String category(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Transport':
        return l10n.expenseCategoryTransport;
      case 'Accommodation':
        return l10n.expenseCategoryAccommodation;
      case 'Food':
        return l10n.expenseCategoryFood;
      case 'Visa':
        return l10n.expenseCategoryVisa;
      case 'Shopping':
        return l10n.expenseCategoryShopping;
      case 'Entertainment':
        return l10n.expenseCategoryEntertainment;
      default:
        return l10n.expenseCategoryOther;
    }
  }

  static String paymentMethod(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Cash':
        return l10n.paymentMethodCash;
      case 'Credit Card':
        return l10n.paymentMethodCreditCard;
      case 'Debit Card':
        return l10n.paymentMethodDebitCard;
      case 'Bank Transfer':
        return l10n.paymentMethodBankTransfer;
      case 'Other':
        return l10n.paymentMethodOther;
      default:
        return value;
    }
  }

  static String paymentNetwork(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Visa':
        return l10n.paymentNetworkVisa;
      case 'Mastercard':
        return l10n.paymentNetworkMastercard;
      case 'Mada':
        return l10n.paymentNetworkMada;
      default:
        return l10n.paymentNetworkOther;
    }
  }

  static String paymentChannel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'POS Purchase':
      case 'Card Present':
        return l10n.paymentChannelCardPresent;
      case 'Online Purchase':
      case 'Online':
        return l10n.paymentChannelOnline;
      case 'Cash':
        return l10n.paymentMethodCash;
      default:
        return l10n.paymentChannelOther;
    }
  }

  static String primaryPaymentMethod(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Cash':
        return l10n.paymentMethodCash;
      case 'Card':
        return l10n.tripDetailsQuickAddPaymentCard;
      case 'Other':
        return l10n.paymentMethodOther;
      default:
        return value;
    }
  }

  /// Shorter purchase-channel labels for the card secondary selector.
  static String cardPurchaseChannel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'POS Purchase':
      case 'Card Present':
        return l10n.paymentChannelCardPresentShort;
      case 'Online Purchase':
      case 'Online':
        return l10n.paymentChannelOnlineShort;
      default:
        return paymentChannel(l10n, value);
    }
  }

  /// Maps stored payment metadata to the primary form payment choice.
  static String derivePrimaryPaymentMethod({
    required String paymentMethod,
    String? paymentChannel,
  }) {
    if (isCashExpensePayment(
      paymentMethod: paymentMethod,
      paymentChannel: paymentChannel,
    )) {
      return 'Cash';
    }
    if (isCardExpenseChannel(paymentChannel) ||
        _isStoredCardPaymentMethod(paymentMethod)) {
      return 'Card';
    }
    return 'Other';
  }

  static bool _isStoredCardPaymentMethod(String paymentMethod) {
    final lower = paymentMethod.trim().toLowerCase();
    return lower == 'credit card' ||
        lower == 'debit card' ||
        lower == 'card';
  }

  static String paymentSummary(
    AppLocalizations l10n, {
    String? paymentMethodValue,
    String? paymentNetworkValue,
    String? paymentChannelValue,
  }) {
    if (isCashExpensePayment(
      paymentMethod: paymentMethodValue ?? '',
      paymentChannel: paymentChannelValue,
    )) {
      return l10n.paymentMethodCash;
    }

    final parts = <String>[];
    if (paymentNetworkValue != null && paymentNetworkValue.isNotEmpty) {
      parts.add(paymentNetwork(l10n, paymentNetworkValue));
    }
    if (paymentChannelValue != null && paymentChannelValue.isNotEmpty) {
      parts.add(paymentChannel(l10n, paymentChannelValue));
    }
    if (parts.isNotEmpty) {
      return parts.join(' | ');
    }
    return paymentMethod(l10n, paymentMethodValue ?? 'Other');
  }
}
