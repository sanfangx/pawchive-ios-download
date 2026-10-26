import 'dart:convert';

class AppSettings {
  final int concurrency;
  final int autoRetryCount;
  final bool chunkAcceleration;
  final bool exifAlignEnabled;
  final bool trollStoreKeepAlive;
  final bool notifyOnComplete;
  final bool hapticFeedbackEnabled;
  final bool cleanCacheAfterAlbumSave;

  const AppSettings({
    this.concurrency = 4,
    this.autoRetryCount = 3,
    this.chunkAcceleration = false,
    this.exifAlignEnabled = false,
    this.trollStoreKeepAlive = true,
    this.notifyOnComplete = true,
    this.hapticFeedbackEnabled = true,
    this.cleanCacheAfterAlbumSave = true,
  });

  AppSettings copyWith({
    int? concurrency,
    int? autoRetryCount,
    bool? chunkAcceleration,
    bool? exifAlignEnabled,
    bool? trollStoreKeepAlive,
    bool? notifyOnComplete,
    bool? hapticFeedbackEnabled,
    bool? cleanCacheAfterAlbumSave,
  }) {
    return AppSettings(
      concurrency: concurrency ?? this.concurrency,
      autoRetryCount: autoRetryCount ?? this.autoRetryCount,
      chunkAcceleration: chunkAcceleration ?? this.chunkAcceleration,
      exifAlignEnabled: exifAlignEnabled ?? this.exifAlignEnabled,
      trollStoreKeepAlive: trollStoreKeepAlive ?? this.trollStoreKeepAlive,
      notifyOnComplete: notifyOnComplete ?? this.notifyOnComplete,
      hapticFeedbackEnabled:
          hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      cleanCacheAfterAlbumSave:
          cleanCacheAfterAlbumSave ?? this.cleanCacheAfterAlbumSave,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'concurrency': concurrency,
      'autoRetryCount': autoRetryCount,
      'chunkAcceleration': chunkAcceleration,
      'exifAlignEnabled': exifAlignEnabled,
      'trollStoreKeepAlive': trollStoreKeepAlive,
      'notifyOnComplete': notifyOnComplete,
      'hapticFeedbackEnabled': hapticFeedbackEnabled,
      'cleanCacheAfterAlbumSave': cleanCacheAfterAlbumSave,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      concurrency: map['concurrency'] as int? ?? 4,
      autoRetryCount: map['autoRetryCount'] as int? ?? 3,
      chunkAcceleration: map['chunkAcceleration'] as bool? ?? false,
      exifAlignEnabled: map['exifAlignEnabled'] as bool? ?? false,
      trollStoreKeepAlive: map['trollStoreKeepAlive'] as bool? ?? true,
      notifyOnComplete: map['notifyOnComplete'] as bool? ?? true,
      hapticFeedbackEnabled: map['hapticFeedbackEnabled'] as bool? ?? true,
      cleanCacheAfterAlbumSave:
          map['cleanCacheAfterAlbumSave'] as bool? ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory AppSettings.fromJson(String source) =>
      AppSettings.fromMap(json.decode(source) as Map<String, dynamic>);
}
