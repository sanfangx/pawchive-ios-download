import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/download_task.dart';
import '../../models/post_detail.dart';
import '../../providers/download_provider.dart';
import '../../providers/post_provider.dart';
import '../common/cupertino_helpers.dart';
import '../download/download_sheet.dart';
import '../download/floating_download_pill.dart';
import 'image_viewer_screen.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  final PostDetail post;

  const GalleryScreen({super.key, required this.post});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(postDetailProvider).value;
      if (current == null || current.id != widget.post.id) {
        ref.read(postDetailProvider.notifier).setPost(widget.post);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch current post details for selection updates
    final postAsync = ref.watch(postDetailProvider);
    final currentPost = (postAsync.value != null &&
            postAsync.value!.id == widget.post.id)
        ? postAsync.value!
        : widget.post;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.barBackground,
        border: null,
        middle: Text(
          currentPost.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
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
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
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
                                  color: AppColors.secondaryCard,
                                  child: const CupertinoActivityIndicator(),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.secondaryCard,
                                  child: const Icon(CupertinoIcons.person_fill,
                                      color: AppColors.textSecondary),
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
                                      color: AppColors.textPrimary,
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
                                          color: AppColors.primary
                                              .withAlpha(35),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          currentPost.target.service
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
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
                                            color: AppColors.textSecondary,
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
                            color: AppColors.textPrimary,
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
                            color: AppColors.textSecondary,
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(postDetailProvider.notifier)
                                .selectAll(!currentPost.isAllSelected);
                          },
                          child: Text(
                            currentPost.isAllSelected ? '取消全选' : '全选',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
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
                    bottom: 170, // space for action bar + floating download pill
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
                                    color: AppColors.secondaryCard,
                                    child: const Center(
                                      child: CupertinoActivityIndicator(
                                          radius: 10),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: AppColors.secondaryCard,
                                    child: const Icon(
                                      CupertinoIcons.photo,
                                      color: AppColors.textSecondary,
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
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // Checkmark selection button (Top Right, 44x44 touch hit area)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      ref
                                          .read(postDetailProvider.notifier)
                                          .toggleItemSelection(item.id);
                                    },
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      padding: const EdgeInsets.only(
                                          top: 6, right: 6),
                                      alignment: Alignment.topRight,
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: item.isSelected
                                              ? AppColors.primary
                                              : Colors.black.withAlpha(120),
                                          border: Border.all(
                                            color: item.isSelected
                                                ? AppColors.primary
                                                : Colors.white.withAlpha(200),
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

            // 4. Floating Download Pill above action bar
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 76,
              child: const FloatingDownloadPill(),
            ),

            // 5. Floating Action Capsule at bottom (frosted glass)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground.withAlpha(190),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppColors.separator,
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(80),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Pack ZIP button
                        Expanded(
                          child: CupertinoButton(
                            color: AppColors.secondaryCard,
                            disabledColor: AppColors.secondaryCard.withAlpha(80),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            borderRadius: BorderRadius.circular(22),
                            onPressed: currentPost.hasSelection
                                ? () => _startExport(context, ref, currentPost,
                                    ExportMode.zip)
                                : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.archivebox,
                                  size: 18,
                                  color: currentPost.hasSelection
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '打包为 ZIP',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: currentPost.hasSelection
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Save to Photos button
                        Expanded(
                          child: CupertinoButton(
                            color: AppColors.primary,
                            disabledColor: AppColors.primary.withAlpha(60),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            borderRadius: BorderRadius.circular(22),
                            onPressed: currentPost.hasSelection
                                ? () => _startExport(context, ref, currentPost,
                                    ExportMode.album)
                                : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.photo,
                                  size: 18,
                                  color: currentPost.hasSelection
                                      ? CupertinoColors.white
                                      : CupertinoColors.white.withAlpha(100),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '存入相册',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: currentPost.hasSelection
                                        ? CupertinoColors.white
                                        : CupertinoColors.white.withAlpha(100),
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
    // 1. Trigger export in background queue
    ref.read(downloadTaskProvider.notifier).startExport(
          post: post,
          selectedItems: post.selectedItems,
          mode: mode,
        );

    // 2. Show download bottom sheet with barrierDismissible: true so user can dismiss anytime
    showCupertinoModalPopup(
      context: context,
      barrierDismissible: true,
      builder: (_) => const DownloadSheet(),
    );
  }
}
