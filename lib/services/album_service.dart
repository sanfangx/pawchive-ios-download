import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import '../models/media_item.dart';
import 'storage_service.dart';

class AlbumService {
  static const MethodChannel _channel = MethodChannel('pawchive_download/album');

  static int? _lastBatchEndMs;

  @visibleForTesting
  static bool? debugOverrideIsIos;

  @visibleForTesting
  static void resetOrderState() {
    _lastBatchEndMs = null;
  }

  /// Compute strictly increasing creation timestamps (ms since epoch) so iOS Photos
  /// displays saved assets in original post order regardless of embedded EXIF dates.
  @visibleForTesting
  static List<int> computeOrderedCreationTimestampsMs(
    int count, {
    DateTime? now,
    int? previousEndMs,
  }) {
    if (count <= 0) return const [];

    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final effectiveLastEnd = previousEndMs ?? _lastBatchEndMs;

    int stepMs = 1000;
    int baseMs = nowMs - count * stepMs;

    if (effectiveLastEnd != null) {
      final gapMs = nowMs - effectiveLastEnd;
      if (gapMs >= (count + 1) * 1000) {
        stepMs = 1000;
        baseMs = nowMs - count * stepMs;
      } else if (gapMs >= count * 20) {
        stepMs = gapMs ~/ (count + 1);
        baseMs = effectiveLastEnd + stepMs;
      } else {
        stepMs = 50;
        baseMs = effectiveLastEnd + stepMs;
      }
    }

    return List<int>.generate(count, (index) => baseMs + index * stepMs);
  }

  static Future<void> _saveSingleMedia({
    required String path,
    required bool isVideo,
    required int creationTimestampMs,
  }) async {
    final useIosChannel = debugOverrideIsIos ?? Platform.isIOS;
    if (useIosChannel) {
      try {
        await _channel.invokeMethod<void>('saveMediaWithCreationDate', {
          'path': path,
          'isVideo': isVideo,
          'creationTimestampMs': creationTimestampMs,
        });
        return;
      } on MissingPluginException {
        // Fall back to Gal when the native channel is unavailable
      }
    }

    if (isVideo) {
      await Gal.putVideo(path);
    } else {
      await Gal.putImage(path);
    }
  }

  /// Save downloaded media items to iOS Album in post order and optionally clear temp files
  static Future<int> saveToAlbum({
    required List<MediaItem> items,
    bool cleanCacheAfterSave = true,
    void Function(int current, int total)? onProgress,
  }) async {
    // Check and request photo access permission
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        throw Exception('未获得相册写入权限，无法将媒体存入系统相册');
      }
    }

    final downloadedItems =
        items.where((i) => i.isDownloaded && i.localPath != null).toList();
    if (downloadedItems.isEmpty) {
      return 0;
    }

    final timestamps = computeOrderedCreationTimestampsMs(downloadedItems.length);
    _lastBatchEndMs = timestamps.last;

    int savedCount = 0;

    for (int i = 0; i < downloadedItems.length; i++) {
      final item = downloadedItems[i];
      final path = item.localPath!;
      final file = File(path);

      if (await file.exists()) {
        try {
          await _saveSingleMedia(
            path: path,
            isVideo: item.isVideo,
            creationTimestampMs: timestamps[i],
          );
          savedCount++;

          // Delete temp cache immediately to prevent 2x storage bloat
          if (cleanCacheAfterSave) {
            await StorageService.deleteTempFileAndPruneBatchDir(file);
          }
        } catch (e) {
          // Continue saving remaining items
        }
      }

      onProgress?.call(i + 1, downloadedItems.length);
    }

    return savedCount;
  }
}
