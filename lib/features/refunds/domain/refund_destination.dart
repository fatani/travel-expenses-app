enum RefundDestination {
  cash,
  card,
}

extension RefundDestinationCodec on RefundDestination {
  String get value {
    switch (this) {
      case RefundDestination.cash:
        return 'cash';
      case RefundDestination.card:
        return 'card';
    }
  }

  static RefundDestination fromValue(String raw) {
    switch (raw) {
      case 'cash':
        return RefundDestination.cash;
      case 'card':
        return RefundDestination.card;
      default:
        throw FormatException('Unknown RefundDestination: $raw');
    }
  }
}
