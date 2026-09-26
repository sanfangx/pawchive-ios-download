import 'dart:io';
import 'package:gal/gal.dart';
import '../models/media_item.dart';

class AlbumService {
  /// Sanitize album name for iOS Photos app
  static String formatAlbumName({
    required String prefix,
    required String author,
    required String title,
  }) {
    final cleanAuthor = author.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
    final cleanTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
    final combined = '$prefix $cleanAuthor - $cleanTitle';
    // Limit length to avoid iOS Photos truncation
    if (combined.length > 60) {
      return '${combined.substring(0, 57)}...';
    }
    return combined;
  }

  /// Save downloaded media items to iOS Album and optionally clear temp files
  static Future<int> saveToAlbum({
    required List<MediaItem> items,
    required String albumName,
    bool cleanCacheAfterSave = true,
    void Function(int current, int total)? onProgress,
  }) async {
    // Check and request photo access permission
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: true);
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
            await Gal.putVideo(path, album: albumName);
          } else {
            await Gal.putImage(path, album: albumName);
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
