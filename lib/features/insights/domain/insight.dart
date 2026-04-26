enum InsightType {
  spike,
  categoryDrift,
  fees,
}

class Insight {
  const Insight({
    required this.type,
    this.category,
    this.percentage,
    this.multiplier,
    this.tripName,
    this.tripId,
    this.contributorTripCount,
  });

  final InsightType type;
  final String? category;
  final int? percentage;
  final double? multiplier;
  final String? tripName;
  final String? tripId;
  final int? contributorTripCount;
}
