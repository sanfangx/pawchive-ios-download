enum ExportMode { album, zip }

enum DownloadStatus {
  idle,
  downloading,
  savingToAlbum,
  packingZip,
  completed,
  failed,
  cancelled,
}

class DownloadTaskState {
  final DownloadStatus status;
  final ExportMode exportMode;
  final int totalCount;
  final int completedCount;
  final int failedCount;
  final double progress;
  final String currentSpeed;
  final String currentFileName;
  final String? errorMessage;
  final String? resultPath;

  const DownloadTaskState({
    this.status = DownloadStatus.idle,
    this.exportMode = ExportMode.album,
    this.totalCount = 0,
    this.completedCount = 0,
    this.failedCount = 0,
    this.progress = 0.0,
    this.currentSpeed = '0 KB/s',
    this.currentFileName = '',
    this.errorMessage,
    this.resultPath,
  });

  bool get isActive =>
      status == DownloadStatus.downloading ||
      status == DownloadStatus.savingToAlbum ||
      status == DownloadStatus.packingZip;

  bool get isFinished =>
      status == DownloadStatus.completed ||
      status == DownloadStatus.failed ||
      status == DownloadStatus.cancelled;

  DownloadTaskState copyWith({
    DownloadStatus? status,
    ExportMode? exportMode,
    int? totalCount,
    int? completedCount,
    int? failedCount,
    double? progress,
    String? currentSpeed,
    String? currentFileName,
    String? errorMessage,
    String? resultPath,
  }) {
    return DownloadTaskState(
      status: status ?? this.status,
      exportMode: exportMode ?? this.exportMode,
      totalCount: totalCount ?? this.totalCount,
      completedCount: completedCount ?? this.completedCount,
      failedCount: failedCount ?? this.failedCount,
      progress: progress ?? this.progress,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentFileName: currentFileName ?? this.currentFileName,
      errorMessage: errorMessage ?? this.errorMessage,
      resultPath: resultPath ?? this.resultPath,
    );
  }
}
