import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/media_item.dart';
import 'storage_service.dart';

typedef ProgressCallback = void Function({
  required int completedCount,
  required int totalCount,
  required double overallProgress,
  required String speedStr,
  required String currentFileName,
});

class DownloadService {
  /// Clean up temporary media files left in [results] and prune empty batch directories.
  static Future<void> cleanupTempResults(List<MediaItem> results) {
    return StorageService.deleteTempFilesForMedia(
      results.map((i) => i.localPath),
    );
  }

  final Dio _dio;
  CancelToken? _cancelToken;
  bool _isCancelled = false;

  DownloadService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(minutes: 5),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
                  'Referer': 'https://pawchive.pw/',
                },
              ),
            );

  void cancel() {
    _isCancelled = true;
    _cancelToken?.cancel('用户取消下载');
  }

  /// Sanitize filename for local filesystem
  static String sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  /// Downloads the selected media items concurrently with queue control
  Future<List<MediaItem>> downloadBatch({
    required List<MediaItem> items,
    required int concurrency,
    required ProgressCallback onProgress,
  }) async {
    _isCancelled = false;
    _cancelToken = CancelToken();

    final tempDir = await getTemporaryDirectory();
    final downloadDir = Directory(p.join(tempDir.path, 'pawchive_downloads'));
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    final totalCount = items.length;
    int completedCount = 0;
    int totalBytesDownloaded = 0;
    final stopwatch = Stopwatch()..start();

    // Map to keep track of updated items
    final List<MediaItem> results = List.from(items);

    // Speed calculator helper
    String calculateSpeed() {
      final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
      if (elapsedSec <= 0 || totalBytesDownloaded <= 0) return '0 KB/s';
      final bytesPerSec = totalBytesDownloaded / elapsedSec;
      if (bytesPerSec >= 1024 * 1024) {
        return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
      } else {
        return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
      }
    }

    final batchId =
        'batch_${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(items)}';
    final batchDir = Directory(p.join(downloadDir.path, batchId));
    if (!await batchDir.exists()) {
      await batchDir.create(recursive: true);
    }

    if (_isCancelled) {
      await StorageService.deleteDirectoryQuietly(batchDir);
      throw Exception('下载已取消');
    }

    // Aggregate per-item progress across concurrent workers so progress stays monotonic and throttled.
    final itemProgress = List<double>.filled(totalCount, 0.0);
    double maxOverallProgress = 0.0;
    final emitStopwatch = Stopwatch()..start();
    int lastEmitMs = -100;

    void emitProgress(String fileName, {bool force = false}) {
      if (_isCancelled) return;
      final nowMs = emitStopwatch.elapsedMilliseconds;
      if (!force && nowMs - lastEmitMs < 100) return;
      lastEmitMs = nowMs;

      final rawSum = itemProgress.fold<double>(0.0, (sum, value) => sum + value);
      final aggregated =
          totalCount > 0 ? (rawSum / totalCount).clamp(0.0, 1.0) : 0.0;
      if (aggregated > maxOverallProgress) {
        maxOverallProgress = aggregated;
      }

      onProgress(
        completedCount: completedCount,
        totalCount: totalCount,
        overallProgress: maxOverallProgress,
        speedStr: calculateSpeed(),
        currentFileName: fileName,
      );
    }

    // Worker queue
    int nextIndex = 0;
    final activeWorkers = <Future<void>>[];

    Future<void> runWorker() async {
      while (true) {
        if (_isCancelled) break;
        if (nextIndex >= items.length) break;
        final currentIndex = nextIndex++;
        if (currentIndex >= items.length) break;

        final item = items[currentIndex];
        final indexWidth = items.length.toString().length.clamp(2, 6);
        final paddedIndex =
            (currentIndex + 1).toString().padLeft(indexWidth, '0');
        var rawName = item.name.trim().isEmpty ? 'media' : item.name;
        if (p.extension(rawName).isEmpty) {
          final pathExt = p.extension(item.path.split('?').first);
          rawName = pathExt.isNotEmpty
              ? '$rawName$pathExt'
              : '$rawName${item.isVideo ? '.mp4' : '.jpg'}';
        }
        final safeName = sanitizeFilename('${paddedIndex}_$rawName');
        final savePath = p.join(batchDir.path, safeName);

        try {
          emitProgress(item.name);

          // Download with fallback support
          bool success = false;
          String targetUrl = item.downloadUrl;

          for (int retry = 0; retry < 2; retry++) {
            if (_isCancelled) break;
            int itemDownloadedBytes = 0;
            itemProgress[currentIndex] = 0.0;
            try {
              if (retry == 1 && item.fallbackUrl != null) {
                targetUrl = item.fallbackUrl!;
              }

              await _dio.download(
                targetUrl,
                savePath,
                cancelToken: _cancelToken,
                deleteOnError: true,
                onReceiveProgress: (received, total) {
                  if (_isCancelled) return;
                  final diff = received - itemDownloadedBytes;
                  if (diff > 0) {
                    itemDownloadedBytes = received;
                    totalBytesDownloaded += diff;
                  }
                  if (total > 0) {
                    final itemFraction = (received / total).clamp(0.0, 1.0);
                    if (itemFraction > itemProgress[currentIndex]) {
                      itemProgress[currentIndex] = itemFraction;
                    }
                  }
                  emitProgress(item.name);
                },
              );
              success = true;
              break;
            } catch (err) {
              if (_isCancelled) rethrow;
              if (retry == 1 || item.fallbackUrl == null) {
                rethrow;
              }
            }
          }

          if (success) {
            itemProgress[currentIndex] = 1.0;
            completedCount++;
            results[currentIndex] = item.copyWith(
              isDownloaded: true,
              localPath: savePath,
              downloadProgress: 1.0,
            );
          }
        } catch (e) {
          if (_isCancelled) break;
          itemProgress[currentIndex] = 0.0;
          results[currentIndex] = item.copyWith(
            isDownloaded: false,
            errorMessage: e.toString(),
            downloadProgress: 0.0,
          );
        }

        emitProgress(item.name, force: true);
      }
    }

    final workerCount = concurrency.clamp(1, 8);
    for (int i = 0; i < workerCount; i++) {
      activeWorkers.add(runWorker());
    }

    await Future.wait(activeWorkers);
    stopwatch.stop();
    emitStopwatch.stop();

    if (_isCancelled) {
      await StorageService.deleteDirectoryQuietly(batchDir);
      throw Exception('下载已取消');
    }

    return results;
  }
}
