import 'media_item.dart';
import 'post_target.dart';

class PostDetail {
  final PostTarget target;
  final String id;
  final String title;
  final String authorName;
  final String authorAvatarUrl;
  final String publishedAt;
  final String contentHtml;
  final List<MediaItem> items;

  const PostDetail({
    required this.target,
    required this.id,
    required this.title,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.publishedAt,
    required this.contentHtml,
    required this.items,
  });

  int get totalCount => items.length;
  int get selectedCount => items.where((i) => i.isSelected).length;
  List<MediaItem> get selectedItems => items.where((i) => i.isSelected).toList();
  bool get hasSelection => selectedCount > 0;
  bool get isAllSelected => items.isNotEmpty && selectedCount == items.length;

  PostDetail copyWith({
    PostTarget? target,
    String? id,
    String? title,
    String? authorName,
    String? authorAvatarUrl,
    String? publishedAt,
    String? contentHtml,
    List<MediaItem>? items,
  }) {
    return PostDetail(
      target: target ?? this.target,
      id: id ?? this.id,
      title: title ?? this.title,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      contentHtml: contentHtml ?? this.contentHtml,
      items: items ?? this.items,
    );
  }
}
