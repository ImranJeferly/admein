class NewsModel {
  final String title;
  final String? description;
  final String? imageUrl;
  final String sourceUrl;
  final String? publishDate;

  NewsModel({
    required this.title,
    this.description,
    this.imageUrl,
    required this.sourceUrl,
    this.publishDate,
  });

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    return NewsModel(
      title: json['title'] ?? 'No title',
      description: json['description'],
      imageUrl: json['image_url'],
      sourceUrl: json['source_url'] ?? '',
      publishDate: json['pubDate'],
    );
  }

  String get formattedDate {
    if (publishDate == null) return '';
    try {
      final date = DateTime.parse(publishDate!);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return publishDate ?? '';
    }
  }
}