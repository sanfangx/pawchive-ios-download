import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/download_task.dart';
import '../../models/post_detail.dart';
import '../../providers/download_provider.dart';
import '../../providers/post_provider.dart';
import '../download/download_sheet.dart';
import 'image_viewer_screen.dart';

class GalleryScreen extends ConsumerWidget {
  final PostDetail post;

  const GalleryScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch current post details for selection updates
    final postAsync = ref.watch(postDetailProvider);
    final currentPost = postAsync.value ?? post;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          currentPost.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        previousPageTitle: '首页',
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // 1. Author and Post Header Card
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemGroupedBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.systemGrey5.withAlpha(50),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: CachedNetworkImage(
                                imageUrl: currentPost.authorAvatarUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                placeholder: (context, _) => Container(
                                  color: CupertinoColors.systemGrey5,
                                  child: const CupertinoActivityIndicator(),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: CupertinoColors.systemGrey5,
                                  child: const Icon(CupertinoIcons.person_fill,
                                      color: CupertinoColors.systemGrey),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentPost.authorName,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: CupertinoColors.label,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.activeBlue
                                              .withAlpha(30),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          currentPost.target.service
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: CupertinoColors.activeBlue,
                                          ),
                                        ),
                                      ),
                                      if (currentPost.publishedAt.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          currentPost.publishedAt.length > 10
                                              ? currentPost.publishedAt
                                                  .substring(0, 10)
                                              : currentPost.publishedAt,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color:
                                                CupertinoColors.secondaryLabel,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentPost.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Selection Toolbar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '已选 ${currentPost.selectedCount} / 共 ${currentPost.totalCount} 项',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          onPressed: () {
                            ref
                                .read(postDetailProvider.notifier)
                                .selectAll(!currentPost.isAllSelected);
                          },
                          child: Text(
                            currentPost.isAllSelected ? '取消全选' : '全选',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.activeBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Media Grid (3 Columns)
                SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 120, // space for floating bottom bar
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = currentPost.items[index];
                        return GestureDetector(
                          onTap: () {
                            if (item.isVideo) {
                              // Video: toggle selection directly (no playback required)
                              ref
                                  .read(postDetailProvider.notifier)
                                  .toggleItemSelection(item.id);
                            } else {
                              // Image: open fullscreen viewer
                              final imageItems = currentPost.items
                                  .where((i) => !i.isVideo)
                                  .toList();
                              final imgIdx = imageItems.indexOf(item);
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (_) => ImageViewerScreen(
                                    items: imageItems,
                                    initialIndex: imgIdx >= 0 ? imgIdx : 0,
                                  ),
                                ),
                              );
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Thumbnail Image
                                CachedNetworkImage(
                                  imageUrl: item.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, _) => Container(
                                    color: CupertinoColors.systemGrey5,
                                    child: const Center(
                                      child: CupertinoActivityIndicator(
                                          radius: 10),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: CupertinoColors.systemGrey5,
                                    child: const Icon(
                                      CupertinoIcons.photo,
                                      color: CupertinoColors.systemGrey3,
                                    ),
                                  ),
                                ),

                                // Video badge indicator
                                if (item.isVideo)
                                  Positioned(
                                    bottom: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withAlpha(160),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons.play_arrow_solid,
                                            size: 10,
                                            color: CupertinoColors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'VIDEO',
                                            style: TextStyle(
                                              color: CupertinoColors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // Checkmark selection button (Top Right)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      ref
                                          .read(postDetailProvider.notifier)
                                          .toggleItemSelection(item.id);
                                    },
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: item.isSelected
                                            ? CupertinoColors.activeBlue
                                            : Colors.black.withAlpha(80),
                                        border: Border.all(
                                          color: CupertinoColors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: item.isSelected
                                          ? const Icon(
                                              CupertinoIcons.checkmark,
                                              size: 16,
                                              color: CupertinoColors.white,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: currentPost.items.length,
                    ),
                  ),
                ),
              ],
            ),

            // 4. Floating Action Capsule at bottom
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemGroupedBackground
                      .withAlpha(240),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Pack ZIP button
                    Expanded(
                      child: CupertinoButton(
                        color: CupertinoColors.systemGrey5,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        borderRadius: BorderRadius.circular(22),
                        onPressed: currentPost.hasSelection
                            ? () => _startExport(context, ref, currentPost,
                                ExportMode.zip)
                            : null,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.archivebox,
                                size: 18, color: CupertinoColors.activeBlue),
                            SizedBox(width: 6),
                            Text(
                              '打包为 ZIP',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.activeBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Save to Photos button
                    Expanded(
                      child: CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        borderRadius: BorderRadius.circular(22),
                        onPressed: currentPost.hasSelection
                            ? () => _startExport(context, ref, currentPost,
                                ExportMode.album)
                            : null,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.photo,
                                size: 18, color: CupertinoColors.white),
                            SizedBox(width: 6),
                            Text(
                              '存入相册',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startExport(
    BuildContext context,
    WidgetRef ref,
    PostDetail post,
    ExportMode mode,
  ) {
    // Show download bottom sheet
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DownloadSheet(),
    );

    // Trigger export in background
    ref.read(downloadTaskProvider.notifier).startExport(
          post: post,
          selectedItems: post.selectedItems,
          mode: mode,
        );
  }
}
