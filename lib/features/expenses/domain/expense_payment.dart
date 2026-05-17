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
    // Mobile Wallet is a payment rail/wrapper around an actual card.
    // Map it to Card as the real financial source.
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
