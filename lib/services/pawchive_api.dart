import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/media_item.dart';
import '../models/post_detail.dart';
import '../models/post_target.dart';

class PawchiveApi {
  final Dio _dio;

  PawchiveApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
                  'Accept': 'application/json, text/plain, */*',
                  'Referer': 'https://pawchive.pw/',
                },
              ),
            );

  /// Fetch full post detail and all valid media items
  Future<PostDetail> fetchPost(PostTarget target) async {
    try {
      final postResponse = await _dio.get(target.apiEndpoint);
      if (postResponse.statusCode != 200 || postResponse.data == null) {
        throw Exception('无法获取帖子数据，服务器返回状态码: ${postResponse.statusCode}');
      }

      final postJson = postResponse.data is String
          ? json.decode(postResponse.data as String) as Map<String, dynamic>
          : postResponse.data as Map<String, dynamic>;

      // Fetch author profile
      String authorName = target.userId;
      try {
        final profileResponse = await _dio.get(target.profileEndpoint);
        if (profileResponse.statusCode == 200 && profileResponse.data != null) {
          final profileJson = profileResponse.data is String
              ? json.decode(profileResponse.data as String)
                  as Map<String, dynamic>
              : profileResponse.data as Map<String, dynamic>;
          authorName = profileJson['name'] as String? ??
              profileJson['public_id'] as String? ??
              target.userId;
        }
      } catch (_) {
        // Fallback to userId if profile fetch fails
      }

      final title = postJson['title'] as String? ?? '无标题帖子';
      final publishedAt = postJson['published'] as String? ??
          postJson['added'] as String? ??
          '';
      final contentHtml = postJson['content'] as String? ?? '';

      final List<MediaItem> mediaList = [];
      int itemCounter = 0;

      // 1. Process main `file` field if exists
      if (postJson['file'] != null && postJson['file'] is Map) {
        final f = postJson['file'] as Map<String, dynamic>;
        final path = f['path'] as String?;
        final name = f['name'] as String? ?? 'file_$itemCounter';
        final previewOnly = f['preview_only'] == true;

        if (path != null && (MediaItem.checkIsImage(name) || MediaItem.checkIsVideo(name) || MediaItem.checkIsImage(path))) {
          itemCounter++;
          mediaList.add(_createMediaItem(
            id: 'file_$itemCounter',
            name: name,
            path: path,
            previewOnly: previewOnly,
          ));
        }
      }

      // 2. Process `attachments` list
      if (postJson['attachments'] != null && postJson['attachments'] is List) {
        final attachments = postJson['attachments'] as List;
        for (final att in attachments) {
          if (att is Map) {
            final m = att as Map<String, dynamic>;
            final path = m['path'] as String?;
            final name = m['name'] as String? ?? 'attachment_$itemCounter';
            final previewOnly = m['preview_only'] == true;

            if (path != null && (MediaItem.checkIsImage(name) || MediaItem.checkIsVideo(name) || MediaItem.checkIsImage(path))) {
              itemCounter++;
              mediaList.add(_createMediaItem(
                id: 'att_${m['id'] ?? itemCounter}',
                name: name,
                path: path,
                previewOnly: previewOnly,
              ));
            }
          }
        }
      }

      return PostDetail(
        target: target,
        id: postJson['id']?.toString() ?? target.postId,
        title: title,
        authorName: authorName,
        authorAvatarUrl: target.avatarUrl,
        publishedAt: publishedAt,
        contentHtml: contentHtml,
        items: mediaList,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('帖子未找到 (404)，请检查链接是否正确或该帖子已被删除');
      } else if (e.response?.statusCode == 429) {
        throw Exception('访问过于频繁 (429)，请稍后再试');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('网络请求超时，请检查您的网络连接或代理设置');
      }
      throw Exception('网络请求失败: ${e.message}');
    } catch (e) {
      throw Exception('解析帖子失败: $e');
    }
  }

  MediaItem _createMediaItem({
    required String id,
    required String name,
    required String path,
    required bool previewOnly,
  }) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final isVideo = MediaItem.checkIsVideo(name) || MediaItem.checkIsVideo(path);
    final thumbnailUrl = 'https://img.pawchive.pw/thumbnail/data$cleanPath';

    String downloadUrl;
    String? fallbackUrl;

    if (previewOnly) {
      downloadUrl = thumbnailUrl;
    } else {
      downloadUrl =
          'https://file.pawchive.pw/data$cleanPath?f=${Uri.encodeComponent(name)}';
      fallbackUrl = thumbnailUrl;
    }

    return MediaItem(
      id: id,
      name: name,
      path: cleanPath,
      downloadUrl: downloadUrl,
      thumbnailUrl: thumbnailUrl,
      fallbackUrl: fallbackUrl,
      isVideo: isVideo,
      previewOnly: previewOnly,
    );
  }
}
