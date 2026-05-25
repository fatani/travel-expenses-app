import '../domain/expense.dart';
import '../domain/expense_payment.dart';

/// Primary Quick Add payment chip keys (UI only).
const String kQuickAddPaymentCash = 'cash';
const String kQuickAddPaymentCard = 'card';
const String kQuickAddPaymentOther = 'other';

const List<String> kQuickAddPrimaryPaymentChipKeys = <String>[
  kQuickAddPaymentCash,
  kQuickAddPaymentCard,
  kQuickAddPaymentOther,
];

/// Maps a stored expense to a compact Quick Add chip key.
String quickAddPaymentChipKeyFromExpense(Expense expense) {
  if (isCashExpensePayment(
    paymentMethod: expense.paymentMethod,
    paymentChannel: expense.paymentChannel,
  )) {
    return kQuickAddPaymentCash;
  }
  if (isCardLikeQuickAddExpense(expense)) {
    return kQuickAddPaymentCard;
  }
  return kQuickAddPaymentOther;
}

/// Normalizes legacy chip keys (e.g. `card:42`, raw payment method strings).
String normalizeQuickAddPaymentChipKey(String? key) {
  if (key == null || key.trim().isEmpty) {
    return kQuickAddPaymentCash;
  }

  final trimmed = key.trim();
  if (kQuickAddPrimaryPaymentChipKeys.contains(trimmed)) {
    return trimmed;
  }

  if (trimmed.startsWith('card:')) {
    return kQuickAddPaymentCard;
  }

  final lower = trimmed.toLowerCase();
  if (lower == 'cash') {
    return kQuickAddPaymentCash;
  }
  if (isCardLikeQuickAddPaymentToken(lower)) {
    return kQuickAddPaymentCard;
  }
  return kQuickAddPaymentOther;
}

bool isCardLikeQuickAddExpense(Expense expense) {
  if (expense.cardProfileId != null) {
    return true;
  }

  if (isCardLikeQuickAddPaymentToken(expense.paymentMethod)) {
    return true;
  }

  if (isCardExpenseChannel(expense.paymentChannel)) {
    return true;
  }

  final channel = expense.paymentChannel?.trim().toLowerCase() ?? '';
  if (channel == 'apple pay' || channel == 'google pay') {
    return true;
  }

  final network = expense.paymentNetwork?.trim().toLowerCase() ?? '';
  if (network == 'visa' ||
      network == 'mastercard' ||
      network == 'mada' ||
      network == 'apple pay' ||
      network == 'google pay') {
    return true;
  }

  return false;
}

bool isCardLikeQuickAddPaymentToken(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }

  if (normalized == 'credit card' ||
      normalized == 'debit card' ||
      normalized == 'card' ||
      normalized == 'mobile wallet') {
    return true;
  }

  if (normalized == 'visa' ||
      normalized == 'mastercard' ||
      normalized == 'mada' ||
      normalized == 'apple pay' ||
      normalized == 'google pay') {
    return true;
  }

  return false;
}

/// Payment payload for Quick Save (no card profile inference).
class QuickAddPaymentPayload {
  const QuickAddPaymentPayload({
    required this.method,
    required this.network,
    required this.channel,
    required this.cardProfileId,
  });

  final String method;
  final String network;
  final String? channel;
  final int? cardProfileId;
}

QuickAddPaymentPayload quickAddPaymentPayloadForChip(String chipKey) {
  switch (normalizeQuickAddPaymentChipKey(chipKey)) {
    case kQuickAddPaymentCash:
      return const QuickAddPaymentPayload(
        method: 'Cash',
        network: '',
        channel: 'Cash',
        cardProfileId: null,
      );
    case kQuickAddPaymentCard:
      return const QuickAddPaymentPayload(
        method: 'Credit Card',
        network: '',
        channel: 'POS Purchase',
        cardProfileId: null,
      );
    case kQuickAddPaymentOther:
    default:
      return const QuickAddPaymentPayload(
        method: 'Other',
        network: '',
        channel: 'Other',
        cardProfileId: null,
      );
  }
}

/// Values passed to [ExpenseFormScreen.initialPaymentMethod] from Quick Add.
String quickAddPaymentMethodForAddDetails(String chipKey) {
  switch (normalizeQuickAddPaymentChipKey(chipKey)) {
    case kQuickAddPaymentCash:
      return 'Cash';
    case kQuickAddPaymentCard:
      return 'Card';
    case kQuickAddPaymentOther:
    default:
      return 'Other';
  }
}
