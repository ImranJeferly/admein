class AdPerformance {
  final String adId;
  int viewCount;
  double playedSeconds;
  int clickCount;
  DateTime lastUpdated;

  AdPerformance({
    required this.adId,
    this.viewCount = 0,
    this.playedSeconds = 0.0,
    this.clickCount = 0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory AdPerformance.fromJson(Map<String, dynamic> json) {
    return AdPerformance(
      adId: json['ad_id'],
      viewCount: json['view_count'] ?? 0,
      playedSeconds: (json['played_seconds'] ?? 0.0).toDouble(),
      clickCount: json['click_count'] ?? 0,
      lastUpdated: DateTime.parse(json['last_updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ad_id': adId,
      'view_count': viewCount,
      'played_seconds': playedSeconds,
      'click_count': clickCount,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}

class RideRating {
  final int rating; // 1-5 stars
  final DateTime timestamp;

  RideRating({
    required this.rating,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory RideRating.fromJson(Map<String, dynamic> json) {
    return RideRating(
      rating: json['rating'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}