import 'dart:io';
import 'package:gal/gal.dart';
import '../models/media_item.dart';

class AlbumService {
  /// Save downloaded media items to iOS Album and optionally clear temp files
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

    int savedCount = 0;
    final downloadedItems =
        items.where((i) => i.isDownloaded && i.localPath != null).toList();

    for (int i = 0; i < downloadedItems.length; i++) {
      final item = downloadedItems[i];
      final path = item.localPath!;
      final file = File(path);

      if (await file.exists()) {
        try {
          if (item.isVideo) {
            await Gal.putVideo(path);
          } else {
            await Gal.putImage(path);
          }
          savedCount++;

          // Delete temp cache immediately to prevent 2x storage bloat
          if (cleanCacheAfterSave) {
            try {
              await file.delete();
            } catch (_) {}
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
