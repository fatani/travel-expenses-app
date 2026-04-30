import 'package:travel_expenses/l10n/app_localizations.dart';

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
    'Mobile Wallet',
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
    'Mobile Wallet',
    'Other',
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
      case 'Mobile Wallet':
        return l10n.paymentMethodMobileWallet;
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
      case 'Mobile Wallet':
      case 'Wallet':
        return l10n.paymentMethodMobileWallet;
      default:
        return l10n.paymentChannelOther;
    }
  }

  static String paymentSummary(
    AppLocalizations l10n, {
    String? paymentMethodValue,
    String? paymentNetworkValue,
    String? paymentChannelValue,
  }) {
    final parts = <String>[];
    if (paymentNetworkValue != null && paymentNetworkValue.isNotEmpty) {
      parts.add(paymentNetwork(l10n, paymentNetworkValue));
    }
    if (paymentChannelValue != null && paymentChannelValue.isNotEmpty) {
      parts.add(paymentChannel(l10n, paymentChannelValue));
    }
    if (parts.isNotEmpty) {
      return parts.join(' • ');
    }
    return paymentMethod(l10n, paymentMethodValue ?? 'Other');
  }
}
