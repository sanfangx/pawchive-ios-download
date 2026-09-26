import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/media_item.dart';

typedef ProgressCallback = void Function({
  required int completedCount,
  required int totalCount,
  required double overallProgress,
  required String speedStr,
  required String currentFileName,
});

class DownloadService {
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
        final safeName = sanitizeFilename('${currentIndex + 1}_${item.name}');
        final savePath = p.join(downloadDir.path, safeName);

        try {
          onProgress(
            completedCount: completedCount,
            totalCount: totalCount,
            overallProgress: completedCount / totalCount,
            speedStr: calculateSpeed(),
            currentFileName: item.name,
          );

          // Download with fallback support
          int itemDownloadedBytes = 0;
          bool success = false;
          String targetUrl = item.downloadUrl;

          for (int retry = 0; retry < 2; retry++) {
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
                  final diff = received - itemDownloadedBytes;
                  if (diff > 0) {
                    itemDownloadedBytes = received;
                    totalBytesDownloaded += diff;
                  }
                  onProgress(
                    completedCount: completedCount,
                    totalCount: totalCount,
                    overallProgress:
                        (completedCount + (total > 0 ? received / total : 0)) /
                            totalCount,
                    speedStr: calculateSpeed(),
                    currentFileName: item.name,
                  );
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
            completedCount++;
            results[currentIndex] = item.copyWith(
              isDownloaded: true,
              localPath: savePath,
              downloadProgress: 1.0,
            );
          }
        } catch (e) {
          if (_isCancelled) break;
          results[currentIndex] = item.copyWith(
            isDownloaded: false,
            errorMessage: e.toString(),
            downloadProgress: 0.0,
          );
        }

        onProgress(
          completedCount: completedCount,
          totalCount: totalCount,
          overallProgress: completedCount / totalCount,
          speedStr: calculateSpeed(),
          currentFileName: item.name,
        );
      }
    }

    final workerCount = concurrency.clamp(1, 8);
    for (int i = 0; i < workerCount; i++) {
      activeWorkers.add(runWorker());
    }

    await Future.wait(activeWorkers);
    stopwatch.stop();

    if (_isCancelled) {
      throw Exception('下载已取消');
    }

    return results;
  }
}
