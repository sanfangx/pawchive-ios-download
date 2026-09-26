import 'dart:convert';

class HistoryItem {
  final String url;
  final String title;
  final String authorName;
  final String authorAvatarUrl;
  final String coverUrl;
  final int mediaCount;
  final String service;
  final DateTime savedAt;

  const HistoryItem({
    required this.url,
    required this.title,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.coverUrl,
    required this.mediaCount,
    required this.service,
    required this.savedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'title': title,
      'authorName': authorName,
      'authorAvatarUrl': authorAvatarUrl,
      'coverUrl': coverUrl,
      'mediaCount': mediaCount,
      'service': service,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      url: map['url'] as String? ?? '',
      title: map['title'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorAvatarUrl: map['authorAvatarUrl'] as String? ?? '',
      coverUrl: map['coverUrl'] as String? ?? '',
      mediaCount: map['mediaCount'] as int? ?? 0,
      service: map['service'] as String? ?? '',
      savedAt: DateTime.tryParse(map['savedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory HistoryItem.fromJson(String source) =>
      HistoryItem.fromMap(json.decode(source) as Map<String, dynamic>);
}
