class MediaItem {
  final String id;
  final String name;
  final String path;
  final String downloadUrl;
  final String thumbnailUrl;
  final String? fallbackUrl;
  final bool isVideo;
  final bool previewOnly;
  final bool isSelected;
  final double downloadProgress;
  final bool isDownloaded;
  final String? localPath;
  final String? errorMessage;

  const MediaItem({
    required this.id,
    required this.name,
    required this.path,
    required this.downloadUrl,
    required this.thumbnailUrl,
    this.fallbackUrl,
    required this.isVideo,
    this.previewOnly = false,
    this.isSelected = true,
    this.downloadProgress = 0.0,
    this.isDownloaded = false,
    this.localPath,
    this.errorMessage,
  });

  MediaItem copyWith({
    String? id,
    String? name,
    String? path,
    String? downloadUrl,
    String? thumbnailUrl,
    String? fallbackUrl,
    bool? isVideo,
    bool? previewOnly,
    bool? isSelected,
    double? downloadProgress,
    bool? isDownloaded,
    String? localPath,
    String? errorMessage,
  }) {
    return MediaItem(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fallbackUrl: fallbackUrl ?? this.fallbackUrl,
      isVideo: isVideo ?? this.isVideo,
      previewOnly: previewOnly ?? this.previewOnly,
      isSelected: isSelected ?? this.isSelected,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static bool checkIsVideo(String filenameOrPath) {
    final lower = filenameOrPath.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv');
  }

  static bool checkIsImage(String filenameOrPath) {
    final lower = filenameOrPath.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp');
  }
}
