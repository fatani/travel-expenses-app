class NormalizedExpensePayment {
  const NormalizedExpensePayment({
    required this.paymentMethod,
    required this.paymentNetwork,
    required this.paymentChannel,
    required this.cardProfileId,
  });

  final String paymentMethod;
  final String? paymentNetwork;
  final String? paymentChannel;
  final int? cardProfileId;
}

class ExpensePaymentService {
  const ExpensePaymentService();

  NormalizedExpensePayment normalizeExpensePaymentMetadata({
    required String paymentMethod,
    String? paymentNetwork,
    String? paymentChannel,
    int? cardProfileId,
  }) {
    final trimmedMethod = paymentMethod.trim();
    final trimmedNetwork = _normalizeText(paymentNetwork);
    final trimmedChannel = _normalizeText(paymentChannel);

    if (isCashExpensePayment(
      paymentMethod: trimmedMethod,
      paymentChannel: trimmedChannel,
    )) {
      return const NormalizedExpensePayment(
        paymentMethod: 'Cash',
        paymentNetwork: null,
        paymentChannel: 'Cash',
        cardProfileId: null,
      );
    }

    if (_isMobileWalletPayment(trimmedMethod, trimmedChannel)) {
      return NormalizedExpensePayment(
        paymentMethod: 'Credit Card',
        paymentNetwork: trimmedNetwork ?? 'Other',
        paymentChannel: 'POS Purchase',
        cardProfileId: cardProfileId,
      );
    }

    if (isCardExpenseChannel(trimmedChannel) || _isCardMethod(trimmedMethod)) {
      final resolvedChannel = isCardExpenseChannel(trimmedChannel)
          ? _canonicalCardChannel(trimmedChannel!)
          : 'POS Purchase';
      return NormalizedExpensePayment(
        paymentMethod: _resolveCardMethod(trimmedMethod, trimmedNetwork),
        paymentNetwork: trimmedNetwork,
        paymentChannel: resolvedChannel,
        cardProfileId: cardProfileId,
      );
    }

    return NormalizedExpensePayment(
      paymentMethod: trimmedMethod.isEmpty ? 'Other' : trimmedMethod,
      paymentNetwork: null,
      paymentChannel: trimmedChannel,
      cardProfileId: null,
    );
  }

  bool isCashExpensePayment({
    required String paymentMethod,
    String? paymentChannel,
  }) {
    final normalizedPaymentMethod = paymentMethod.trim().toLowerCase();
    final normalizedPaymentChannel = paymentChannel?.trim().toLowerCase();
    return normalizedPaymentMethod == 'cash' || normalizedPaymentChannel == 'cash';
  }

  bool isCardExpenseChannel(String? paymentChannel) {
    final normalizedChannel = paymentChannel?.trim().toLowerCase();
    return normalizedChannel == 'pos purchase' ||
        normalizedChannel == 'online purchase';
  }

  /// Infers the canonical payment method string from the user-selected
  /// [network] and [channel]. Call this to produce the [paymentMethod] hint
  /// before passing it to [normalizeExpensePaymentMetadata].
  String resolvePaymentMethodHint(String? network, String channel) {
    if (channel == 'Cash') {
      return 'Cash';
    }
    if (channel == 'Mobile Wallet') {
      // Legacy: Mobile Wallet maps to Credit Card (the real financial source)
      return 'Credit Card';
    }
    if (network == null || network.isEmpty) {
      return 'Other';
    }
    if (network == 'Mada') {
      return 'Debit Card';
    }
    if (network == 'Visa' || network == 'Mastercard') {
      return 'Credit Card';
    }
    if (channel == 'POS Purchase' || channel == 'Online Purchase') {
      return 'Other';
    }
    return 'Other';
  }

  String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  bool _isCardMethod(String? paymentMethod) {
    final normalized = paymentMethod?.trim().toLowerCase() ?? '';
    return normalized == 'credit card' ||
        normalized == 'debit card' ||
        normalized == 'card';
  }

  bool _isMobileWalletPayment(String? paymentMethod, String? paymentChannel) {
    final normalizedMethod = paymentMethod?.trim().toLowerCase() ?? '';
    final normalizedChannel = paymentChannel?.trim().toLowerCase() ?? '';
    return normalizedMethod == 'mobile wallet' ||
        normalizedChannel == 'mobile wallet' ||
        normalizedChannel == 'wallet';
  }

  String _canonicalCardChannel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'online purchase') {
      return 'Online Purchase';
    }
    return 'POS Purchase';
  }

  String _resolveCardMethod(String paymentMethod, String? paymentNetwork) {
    final normalizedMethod = paymentMethod.trim().toLowerCase();
    if (normalizedMethod == 'credit card') {
      return 'Credit Card';
    }
    if (normalizedMethod == 'debit card') {
      return 'Debit Card';
    }

    final normalizedNetwork = paymentNetwork?.trim().toLowerCase();
    if (normalizedNetwork == 'mada') {
      return 'Debit Card';
    }
    if (normalizedNetwork == 'visa' || normalizedNetwork == 'mastercard') {
      return 'Credit Card';
    }

    return 'Other';
  }
}

const expensePaymentService = ExpensePaymentService();

NormalizedExpensePayment normalizeExpensePaymentMetadata({
  required String paymentMethod,
  String? paymentNetwork,
  String? paymentChannel,
  int? cardProfileId,
}) {
  return expensePaymentService.normalizeExpensePaymentMetadata(
    paymentMethod: paymentMethod,
    paymentNetwork: paymentNetwork,
    paymentChannel: paymentChannel,
    cardProfileId: cardProfileId,
  );
}

bool isCashExpensePayment({
  required String paymentMethod,
  String? paymentChannel,
}) {
  return expensePaymentService.isCashExpensePayment(
    paymentMethod: paymentMethod,
    paymentChannel: paymentChannel,
  );
}

bool isCardExpenseChannel(String? paymentChannel) {
  return expensePaymentService.isCardExpenseChannel(paymentChannel);
}

/// Infers the canonical payment method string from the user-selected
/// [network] and [channel]. Used as a hint before calling
/// [normalizeExpensePaymentMetadata], which performs the authoritative
/// normalization.
///
/// This logic is shared by [ExpenseFormScreen] and [SmsExpenseScreen] to
/// avoid duplicating the same channel/network → method mapping.
String resolvePaymentMethodHint(String? network, String channel) {
  return expensePaymentService.resolvePaymentMethodHint(network, channel);
}