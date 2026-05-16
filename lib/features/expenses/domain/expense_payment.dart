bool isCashExpensePayment({
  required String paymentMethod,
  String? paymentChannel,
}) {
  final normalizedPaymentMethod = paymentMethod.trim().toLowerCase();
  final normalizedPaymentChannel = paymentChannel?.trim().toLowerCase();
  return normalizedPaymentMethod == 'cash' || normalizedPaymentChannel == 'cash';
}
