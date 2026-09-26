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
    StateNotifierProvider<DownloadTaskNotifier, DownloadTaskState>((ref) {
  return DownloadTaskNotifier(ref);
});

class DownloadTaskNotifier extends StateNotifier<DownloadTaskState> {
  final Ref _ref;

  DownloadTaskNotifier(this._ref) : super(const DownloadTaskState());

  void cancelDownload() {
    _ref.read(downloadServiceProvider).cancel();
    state = state.copyWith(status: DownloadStatus.cancelled);
  }

  void reset() {
    state = const DownloadTaskState();
  }

  /// Start downloading and exporting selected items
  Future<void> startExport({
    required PostDetail post,
    required List<MediaItem> selectedItems,
    required ExportMode mode,
  }) async {
    final settings = _ref.read(settingsProvider);
    final downloadService = _ref.read(downloadServiceProvider);

    if (selectedItems.isEmpty) return;

    state = DownloadTaskState(
      status: DownloadStatus.downloading,
      exportMode: mode,
      totalCount: selectedItems.length,
      completedCount: 0,
      failedCount: 0,
      progress: 0.0,
      currentSpeed: '0 KB/s',
      currentFileName: selectedItems.first.name,
    );

    try {
      // 1. Download files to temporary directory
      final downloadedResults = await downloadService.downloadBatch(
        items: selectedItems,
        concurrency: settings.concurrency,
        onProgress: ({
          required int completedCount,
          required int totalCount,
          required double overallProgress,
          required String speedStr,
          required String currentFileName,
        }) {
          state = state.copyWith(
            completedCount: completedCount,
            totalCount: totalCount,
            progress: overallProgress,
            currentSpeed: speedStr,
            currentFileName: currentFileName,
          );
        },
      );

      final successDownloaded =
          downloadedResults.where((i) => i.isDownloaded).toList();
      final failedCount = selectedItems.length - successDownloaded.length;

      if (successDownloaded.isEmpty) {
        throw Exception('所有媒体文件下载均失败，请检查网络连接');
      }

      // 2. Export based on mode
      if (mode == ExportMode.album) {
        state = state.copyWith(status: DownloadStatus.savingToAlbum);
        final albumName = AlbumService.formatAlbumName(
          prefix: settings.albumNamePrefix,
          author: post.authorName,
          title: post.title,
        );

        final savedCount = await AlbumService.saveToAlbum(
          items: successDownloaded,
          albumName: albumName,
          cleanCacheAfterSave: settings.cleanCacheAfterAlbumSave,
        );

        state = state.copyWith(
          status: DownloadStatus.completed,
          completedCount: savedCount,
          failedCount: failedCount,
          progress: 1.0,
        );
      } else {
        state = state.copyWith(status: DownloadStatus.packingZip);
        final zipFileName = ZipService.formatZipName(
          author: post.authorName,
          postId: post.id,
        );

        final zipPath = await ZipService.packageZip(
          items: successDownloaded,
          zipFileName: zipFileName,
          cleanCacheAfterPack: true,
        );

        state = state.copyWith(
          status: DownloadStatus.completed,
          completedCount: successDownloaded.length,
          failedCount: failedCount,
          progress: 1.0,
          resultPath: zipPath,
        );
      }

      // 3. Notifications and Haptics
      if (settings.hapticFeedbackEnabled) {
        NotificationService.triggerHaptic();
      }
      if (settings.notifyOnComplete) {
        NotificationService.showDownloadComplete(
          title: post.title,
          totalCount: state.completedCount,
          isZip: mode == ExportMode.zip,
        );
      }
    } catch (e) {
      if (state.status != DownloadStatus.cancelled) {
        state = state.copyWith(
          status: DownloadStatus.failed,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }
}
