import 'media_item.dart';

enum ExportMode { album, zip }

enum DownloadStatus {
  queued,
  downloading,
  savingToAlbum,
  packingZip,
  completed,
  failed,
  cancelled,
}

class DownloadTask {
  final String id;
  final String postTitle;
  final String authorName;
  final ExportMode exportMode;
  final List<MediaItem> items;
  final DownloadStatus status;
  final int totalCount;
  final int completedCount;
  final int failedCount;
  final double progress;
  final String currentSpeed;
  final String currentFileName;
  final String? errorMessage;
  final String? resultPath;
  final DateTime createdAt;

  const DownloadTask({
    required this.id,
    required this.postTitle,
    required this.authorName,
    required this.exportMode,
    required this.items,
    this.status = DownloadStatus.queued,
    required this.totalCount,
    this.completedCount = 0,
    this.failedCount = 0,
    this.progress = 0.0,
    this.currentSpeed = '0 KB/s',
    this.currentFileName = '',
    this.errorMessage,
    this.resultPath,
    required this.createdAt,
  });

  bool get isActive =>
      status == DownloadStatus.queued ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.savingToAlbum ||
      status == DownloadStatus.packingZip;

  bool get isRunning =>
      status == DownloadStatus.downloading ||
      status == DownloadStatus.savingToAlbum ||
      status == DownloadStatus.packingZip;

  bool get isFinished =>
      status == DownloadStatus.completed ||
      status == DownloadStatus.failed ||
      status == DownloadStatus.cancelled;

  DownloadTask copyWith({
    DownloadStatus? status,
    int? totalCount,
    int? completedCount,
    int? failedCount,
    double? progress,
    String? currentSpeed,
    String? currentFileName,
    String? errorMessage,
    String? resultPath,
    bool clearErrorMessage = false,
    bool clearResultPath = false,
  }) {
    return DownloadTask(
      id: id,
      postTitle: postTitle,
      authorName: authorName,
      exportMode: exportMode,
      items: items,
      status: status ?? this.status,
      totalCount: totalCount ?? this.totalCount,
      completedCount: completedCount ?? this.completedCount,
      failedCount: failedCount ?? this.failedCount,
      progress: progress ?? this.progress,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentFileName: currentFileName ?? this.currentFileName,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      resultPath: clearResultPath ? null : (resultPath ?? this.resultPath),
      createdAt: createdAt,
    );
  }
}

class DownloadManagerState {
  final List<DownloadTask> tasks;

  const DownloadManagerState({
    this.tasks = const [],
  });

  bool get hasTasks => tasks.isNotEmpty;
  bool get hasActiveTasks => tasks.any((t) => t.isActive);
  int get activeCount => tasks.where((t) => t.isActive).length;
  int get queuedCount =>
      tasks.where((t) => t.status == DownloadStatus.queued).length;

  List<DownloadTask> get activeTasks =>
      tasks.where((t) => t.isActive).toList();
  List<DownloadTask> get finishedTasks =>
      tasks.where((t) => t.isFinished).toList();

  /// The task currently in progress
  DownloadTask? get runningTask => tasks
          .where((t) => t.isRunning)
          .isNotEmpty
      ? tasks.firstWhere((t) => t.isRunning)
      : null;

  /// Primary task for quick display on pills/bars
  DownloadTask? get primaryTask {
    if (runningTask != null) return runningTask;
    final active = activeTasks;
    if (active.isNotEmpty) return active.first;
    return tasks.isNotEmpty ? tasks.first : null;
  }

  double get overallProgress {
    final active = activeTasks;
    if (active.isEmpty) return 0.0;
    final sum = active.fold<double>(0.0, (prev, t) => prev + t.progress);
    return (sum / active.length).clamp(0.0, 1.0);
  }

  DownloadManagerState copyWith({
    List<DownloadTask>? tasks,
  }) {
    return DownloadManagerState(
      tasks: tasks ?? this.tasks,
    );
  }
}
