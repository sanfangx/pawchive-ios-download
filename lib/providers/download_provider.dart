import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/download_task.dart';
import '../models/media_item.dart';
import '../models/post_detail.dart';
import '../services/album_service.dart';
import '../services/download_service.dart';
import '../services/notification_service.dart';
import '../services/zip_service.dart';
import 'settings_provider.dart';

final downloadServiceProvider =
    Provider<DownloadService>((ref) => DownloadService());

final downloadTaskProvider =
    StateNotifierProvider<DownloadTaskNotifier, DownloadManagerState>((ref) {
  return DownloadTaskNotifier(ref);
});

class DownloadTaskNotifier extends StateNotifier<DownloadManagerState> {
  final Ref _ref;
  bool _isProcessing = false;
  final Map<String, DownloadService> _activeServices = {};

  DownloadTaskNotifier(this._ref) : super(const DownloadManagerState());

  /// Enqueue an export task and start the queue processor
  String startExport({
    required PostDetail post,
    required List<MediaItem> selectedItems,
    required ExportMode mode,
  }) {
    if (selectedItems.isEmpty) return '';

    final taskId =
        'task_${DateTime.now().millisecondsSinceEpoch}_${state.tasks.length}';
    final newTask = DownloadTask(
      id: taskId,
      postTitle: post.title,
      authorName: post.authorName,
      exportMode: mode,
      items: selectedItems,
      status: DownloadStatus.queued,
      totalCount: selectedItems.length,
      createdAt: DateTime.now(),
    );

    // Prepend new task so newer tasks appear first in UI
    state = state.copyWith(tasks: [newTask, ...state.tasks]);

    // Kick off queue processing
    _processQueue();
    return taskId;
  }

  bool _isTaskCancelled(String taskId) {
    if (!mounted) return true;
    final idx = state.tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return true;
    return state.tasks[idx].status == DownloadStatus.cancelled;
  }

  void _onExportProgress(String taskId, int current, int total) {
    if (!mounted || _isTaskCancelled(taskId)) return;
    final phaseProgress = total > 0 ? 0.85 + 0.14 * (current / total) : 0.85;
    _updateTask(taskId, (t) {
      if (t.status == DownloadStatus.cancelled) return t;
      final nextProgress = phaseProgress > t.progress
          ? phaseProgress.clamp(0.0, 0.99)
          : t.progress;
      return t.copyWith(
        completedCount: current,
        progress: nextProgress,
      );
    });
  }

  void cancelTask(String taskId) {
    final service = _activeServices[taskId];
    if (service != null) {
      service.cancel();
      _activeServices.remove(taskId);
    }

    _updateTask(taskId, (t) => t.copyWith(status: DownloadStatus.cancelled));
  }

  void cancelAll() {
    for (final task in state.activeTasks) {
      cancelTask(task.id);
    }
  }

  void clearCompleted() {
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.isActive).toList(),
    );
  }

  void removeTask(String taskId) {
    cancelTask(taskId);
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != taskId).toList(),
    );
  }

  /// Retry a failed or cancelled task by resetting its state and re-queuing
  void retryTask(String taskId) {
    _updateTask(
      taskId,
      (t) => t.copyWith(
        status: DownloadStatus.queued,
        progress: 0.0,
        completedCount: 0,
        failedCount: 0,
        currentSpeed: '',
        currentFileName: '',
        clearErrorMessage: true,
        clearResultPath: true,
      ),
    );
    _processQueue();
  }

  void _updateTask(
      String taskId, DownloadTask Function(DownloadTask) updater) {
    if (!mounted) return;
    state = state.copyWith(
      tasks: state.tasks.map((t) => t.id == taskId ? updater(t) : t).toList(),
    );
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (mounted) {
        // Find next queued task (oldest queued first: FIFO)
        final queuedList = state.tasks
            .where((t) => t.status == DownloadStatus.queued)
            .toList();
        if (queuedList.isEmpty) break;

        // Since we prepended newer tasks, the oldest queued is the last in queuedList
        final currentTask = queuedList.last;
        await _executeTask(currentTask);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _executeTask(DownloadTask task) async {
    if (!mounted) return;
    // Double check if cancelled before starting
    final currentStatus = state.tasks
        .firstWhere((t) => t.id == task.id, orElse: () => task)
        .status;
    if (currentStatus == DownloadStatus.cancelled) return;

    final settings = _ref.read(settingsProvider);
    final downloadService = DownloadService();
    _activeServices[task.id] = downloadService;

    _updateTask(
      task.id,
      (t) => t.copyWith(
        status: DownloadStatus.downloading,
        currentSpeed: '0 KB/s',
        currentFileName: t.items.first.name,
      ),
    );

    try {
      // 1. Download files to temporary directory
      final downloadedResults = await downloadService.downloadBatch(
        items: task.items,
        concurrency: settings.concurrency,
        onProgress: ({
          required int completedCount,
          required int totalCount,
          required double overallProgress,
          required String speedStr,
          required String currentFileName,
        }) {
          _updateTask(task.id, (t) {
            if (t.status == DownloadStatus.cancelled) return t;
            final mappedProgress = (overallProgress * 0.85).clamp(0.0, 0.85);
            final nextProgress =
                mappedProgress > t.progress ? mappedProgress : t.progress;
            return t.copyWith(
              completedCount: completedCount,
              totalCount: totalCount,
              progress: nextProgress,
              currentSpeed: speedStr,
              currentFileName: currentFileName,
            );
          });
        },
      );

      _activeServices.remove(task.id);

      if (_isTaskCancelled(task.id)) {
        await DownloadService.cleanupTempResults(downloadedResults);
        return;
      }

      final successDownloaded =
          downloadedResults.where((i) => i.isDownloaded).toList();

      if (successDownloaded.isEmpty) {
        throw Exception('所有媒体文件下载均失败，请检查网络');
      }

      // 2. Export based on mode
      late final int exportedCount;
      String? resultZipPath;
      if (task.exportMode == ExportMode.album) {
        _updateTask(
          task.id,
          (t) => t.copyWith(status: DownloadStatus.savingToAlbum),
        );

        final savedCount = await AlbumService.saveToAlbum(
          items: successDownloaded,
          cleanCacheAfterSave: settings.cleanCacheAfterAlbumSave,
          onProgress: (current, total) =>
              _onExportProgress(task.id, current, total),
          isCancelled: () => _isTaskCancelled(task.id),
        );

        if (_isTaskCancelled(task.id)) return;

        if (savedCount == 0) {
          await DownloadService.cleanupTempResults(successDownloaded);
          throw Exception('所有媒体保存至相册均失败，请检查相册权限或文件格式');
        }
        exportedCount = savedCount;
      } else {
        _updateTask(
          task.id,
          (t) => t.copyWith(status: DownloadStatus.packingZip),
        );

        final zipFileName = ZipService.formatZipName(
          author: task.authorName,
          postId: task.id,
        );

        resultZipPath = await ZipService.packageZip(
          items: successDownloaded,
          zipFileName: zipFileName,
          cleanCacheAfterPack: true,
          onProgress: (current, total) =>
              _onExportProgress(task.id, current, total),
          isCancelled: () => _isTaskCancelled(task.id),
        );

        if (_isTaskCancelled(task.id)) return;

        exportedCount = successDownloaded.length;
      }

      if (_isTaskCancelled(task.id)) return;

      final totalFailedCount =
          (task.items.length - exportedCount).clamp(0, task.items.length);

      _updateTask(
        task.id,
        (t) => t.copyWith(
          status: DownloadStatus.completed,
          completedCount: exportedCount,
          failedCount: totalFailedCount,
          progress: 1.0,
          resultPath: resultZipPath,
        ),
      );

      // 3. Notifications and Haptics
      if (settings.hapticFeedbackEnabled) {
        NotificationService.triggerHaptic();
      }
      if (settings.notifyOnComplete) {
        await NotificationService.showDownloadComplete(
          title: task.postTitle,
          totalCount: exportedCount,
          failedCount: totalFailedCount,
          isZip: task.exportMode == ExportMode.zip,
        );
      }
    } catch (e) {
      _activeServices.remove(task.id);
      if (!mounted) return;
      final current =
          state.tasks.firstWhere((t) => t.id == task.id, orElse: () => task);
      if (current.status != DownloadStatus.cancelled) {
        _updateTask(
          task.id,
          (t) => t.copyWith(
            status: DownloadStatus.failed,
            errorMessage: e.toString().replaceAll('Exception: ', ''),
          ),
        );
      }
    }
  }
}
