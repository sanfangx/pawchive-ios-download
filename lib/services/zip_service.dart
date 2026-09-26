import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/media_item.dart';

class ZipService {
  /// Format safe ZIP archive name
  static String formatZipName({
    required String author,
    required String postId,
  }) {
    final cleanAuthor =
        author.replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_').trim();
    final cleanPostId =
        postId.replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_').trim();
    return '[Pawchive]_${cleanAuthor}_$cleanPostId.zip';
  }

  /// Package downloaded media into a .zip file in Documents directory
  static Future<String> packageZip({
    required List<MediaItem> items,
    required String zipFileName,
    bool cleanCacheAfterPack = true,
    void Function(int current, int total)? onProgress,
  }) async {
    final docDir = await getApplicationDocumentsDirectory();
    final zipFilePath = p.join(docDir.path, zipFileName);

    final downloadedItems =
        items.where((i) => i.isDownloaded && i.localPath != null).toList();

    if (downloadedItems.isEmpty) {
      throw Exception('没有已下载的文件可供打包');
    }

    // If existing zip exists, delete it first to ensure clean archive
    final existingFile = File(zipFilePath);
    if (await existingFile.exists()) {
      await existingFile.delete();
    }

    final encoder = ZipFileEncoder();
    encoder.create(zipFilePath, level: 0);

    for (int i = 0; i < downloadedItems.length; i++) {
      final item = downloadedItems[i];
      final file = File(item.localPath!);
      if (await file.exists()) {
        encoder.addFile(file, p.basename(item.localPath!));
      }
      onProgress?.call(i + 1, downloadedItems.length);
    }

    encoder.close();

    // Clean up temporary downloaded files
    if (cleanCacheAfterPack) {
      for (final item in downloadedItems) {
        try {
          final f = File(item.localPath!);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
      }
    }

    return zipFilePath;
  }
}
