import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/download_task.dart';
import '../../models/post_detail.dart';
import '../../providers/download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/post_provider.dart';
import '../../services/url_parser.dart';
import '../common/cupertino_helpers.dart';
import '../download/download_sheet.dart';
import '../gallery/image_viewer_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Check if there's any pending URL from History tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(pendingUrlToLoadProvider);
      if (pending != null && pending.isNotEmpty) {
        _urlController.text = pending;
        ref.read(pendingUrlToLoadProvider.notifier).state = null;
        _parseAndLoad(pending);
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // Unified "粘贴并解析" (Paste & Parse) action
  Future<void> _pasteAndParse() async {
    HapticFeedback.selectionClick();
    String textToParse = _urlController.text.trim();

    // If input is empty, read directly from clipboard
    if (textToParse.isEmpty) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.trim().isNotEmpty) {
        textToParse = data.text!.trim();
        _urlController.text = textToParse;
      } else {
        if (!mounted) return;
        showCupertinoToast(
          context,
          '剪贴板中未找到文本，请输入或复制链接后重试',
          isError: true,
        );
        return;
      }
    }

    _parseAndLoad(textToParse);
  }

  Future<void> _parseAndLoad(String inputUrl) async {
    final target = UrlParser.parse(inputUrl);
    if (target == null) {
      showCupertinoToast(
        context,
        '未能识别有效的 Pawchive 帖子链接，支持格式:\nhttps://pawchive.pw/{service}/user/{uid}/post/{pid}',
        isError: true,
      );
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(postDetailProvider.notifier).fetchPost(target);
      final postAsync = ref.read(postDetailProvider);
      final detail = postAsync.value;

      if (detail == null) {
        if (postAsync.hasError) {
          throw postAsync.error!;
        }
        throw Exception('未能获取到帖子数据');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        showCupertinoToast(
          context,
          '成功解析 ${detail.totalCount} 项媒体',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        showCupertinoToast(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  void _startExport(
    BuildContext context,
    WidgetRef ref,
    PostDetail post,
    ExportMode mode,
  ) {
    ref.read(downloadTaskProvider.notifier).startExport(
          post: post,
          selectedItems: post.selectedItems,
          mode: mode,
        );

    showCupertinoModalPopup(
      context: context,
      barrierDismissible: true,
      builder: (_) => const DownloadSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for cross-tab intent to load a post (from History Tab)
    ref.listen<String?>(pendingUrlToLoadProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        _urlController.text = next;
        ref.read(pendingUrlToLoadProvider.notifier).state = null;
        _parseAndLoad(next);
      }
    });

    final postAsync = ref.watch(postDetailProvider);
    final currentPost = postAsync.value;
    final downloadState = ref.watch(downloadTaskProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.barBackground,
        border: null,
        middle: const Text(
          'Pawchive',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        // If post is loaded, allow clearing it
        leading: currentPost != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _urlController.clear();
                  ref.read(postDetailProvider.notifier).reset();
                },
                child: const Text(
                  '清空',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            : null,
        // Trailing download tasks shortcut button
        trailing: downloadState.hasTasks
            ? GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  showCupertinoModalPopup(
                    context: context,
                    barrierDismissible: true,
                    builder: (_) => const DownloadSheet(),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: downloadState.hasActiveTasks
                        ? AppColors.primary.withAlpha(40)
                        : AppColors.secondaryCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: downloadState.hasActiveTasks
                          ? AppColors.primary
                          : AppColors.separator,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (downloadState.hasActiveTasks)
                        const CupertinoActivityIndicator(radius: 6)
                      else
                        const Icon(
                          CupertinoIcons.checkmark_alt,
                          size: 14,
                          color: AppColors.success,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        downloadState.hasActiveTasks
                            ? '${downloadState.activeCount} 任务'
                            : '已完成',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: downloadState.hasActiveTasks
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // 1. Unified Link Input & "粘贴并解析" Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.separator.withAlpha(90),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // URL Input
                          Expanded(
                            child: CupertinoTextField(
                              controller: _urlController,
                              placeholder: '输入或粘贴帖子链接...',
                              prefix: const Padding(
                                padding: EdgeInsets.only(left: 10, right: 6),
                                child: Icon(
                                  CupertinoIcons.link,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              placeholderStyle: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              cursorColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 10,
                              ),
                              decoration: const BoxDecoration(
                                color: CupertinoColors.transparent,
                              ),
                              clearButtonMode: OverlayVisibilityMode.editing,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.go,
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) _parseAndLoad(val.trim());
                              },
                            ),
                          ),
                          const SizedBox(width: 6),

                          // "粘贴并解析" Primary Button
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                            onPressed: _isLoading ? null : _pasteAndParse,
                            child: _isLoading
                                ? const CupertinoActivityIndicator(
                                    color: CupertinoColors.white,
                                    radius: 8,
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.arrow_down_doc_fill,
                                        size: 15,
                                        color: CupertinoColors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '粘贴并解析',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: CupertinoColors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Loading State Indicator
                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoActivityIndicator(radius: 14),
                            SizedBox(height: 14),
                            Text(
                              '正在提取帖子高清媒体，请稍候...',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (currentPost != null) ...[
                  // 3. Post Info Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.separator.withAlpha(70),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Author Avatar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CachedNetworkImage(
                                imageUrl: currentPost.authorAvatarUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                placeholder: (context, _) => Container(
                                  color: AppColors.secondaryCard,
                                  child: const CupertinoActivityIndicator(radius: 6),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.secondaryCard,
                                  child: const Icon(
                                    CupertinoIcons.person_fill,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Post Title & Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          currentPost.authorName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withAlpha(35),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          currentPost.target.service.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    currentPost.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. Selection Toolbar (Includes "全选除了首图"!)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Count status
                          Text(
                            '已选 ${currentPost.selectedCount} / 共 ${currentPost.totalCount} 项',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),

                          // Selection options
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 全选 (Select All)
                              _buildSelectionActionButton(
                                label: '全选',
                                isHighlighted: currentPost.isAllSelected,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(postDetailProvider.notifier)
                                      .selectAll(true);
                                },
                              ),
                              const SizedBox(width: 6),

                              // 全选除了首图 (Select All Except First!)
                              _buildSelectionActionButton(
                                label: '全选除首图',
                                isHighlighted: currentPost.isAllExceptFirstSelected,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(postDetailProvider.notifier)
                                      .selectAllExceptFirst();
                                },
                              ),
                              const SizedBox(width: 6),

                              // 取消全选 (Clear Selection)
                              if (currentPost.hasSelection)
                                _buildSelectionActionButton(
                                  label: '取消',
                                  isHighlighted: false,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    ref
                                        .read(postDetailProvider.notifier)
                                        .selectAll(false);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. Media Grid (3 Columns)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 100), // clearance for bottom action dock
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = currentPost.items[index];
                          final isFirstItem = index == 0;

                          return GestureDetector(
                            onTap: () {
                              if (item.isVideo) {
                                ref
                                    .read(postDetailProvider.notifier)
                                    .toggleItemSelection(item.id);
                              } else {
                                final imageItems = currentPost.items
                                    .where((i) => !i.isVideo)
                                    .toList();
                                final imgIdx = imageItems.indexOf(item);
                                Navigator.of(context).push(
                                  PageRouteBuilder(
                                    opaque: false,
                                    barrierColor: CupertinoColors.black,
                                    transitionDuration:
                                        const Duration(milliseconds: 200),
                                    reverseTransitionDuration:
                                        const Duration(milliseconds: 200),
                                    pageBuilder: (context, animation,
                                            secondaryAnimation) =>
                                        ImageViewerScreen(
                                      items: imageItems,
                                      initialIndex:
                                          imgIdx >= 0 ? imgIdx : 0,
                                    ),
                                    transitionsBuilder: (context, animation,
                                        secondaryAnimation, child) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    },
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
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholder: (context, _) => Container(
                                      color: AppColors.secondaryCard,
                                      child: const Center(
                                        child: CupertinoActivityIndicator(radius: 8),
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

                                  // "首图" Tag Badge (Index == 0)
                                  if (isFirstItem)
                                    Positioned(
                                      top: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(180),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: AppColors.primary.withAlpha(140),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: const Text(
                                          '首图',
                                          style: TextStyle(
                                            color: CupertinoColors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Video Badge Indicator
                                  if (item.isVideo)
                                    Positioned(
                                      bottom: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(170),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              CupertinoIcons.play_arrow_solid,
                                              size: 10,
                                              color: CupertinoColors.white,
                                            ),
                                            SizedBox(width: 3),
                                            Text(
                                              'VIDEO',
                                              style: TextStyle(
                                                color: CupertinoColors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // 44x44 Checkbox Touch Target at Top-Right
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        ref
                                            .read(postDetailProvider.notifier)
                                            .toggleItemSelection(item.id);
                                      },
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        padding: const EdgeInsets.only(top: 6, right: 6),
                                        alignment: Alignment.topRight,
                                        child: Container(
                                          width: 24,
                                          height: 24,
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
                                                  size: 14,
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
              ],
            ),

            // 7. Bottom Dock: Export Action Bar (Frosted Glass, above tab bar)
            if (currentPost != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground.withAlpha(210),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.separator.withAlpha(90),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // 打包为 ZIP 按钮
                          Expanded(
                            child: CupertinoButton(
                              color: AppColors.secondaryCard,
                              disabledColor: AppColors.secondaryCard.withAlpha(80),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              borderRadius: BorderRadius.circular(16),
                              onPressed: currentPost.hasSelection
                                  ? () => _startExport(
                                        context,
                                        ref,
                                        currentPost,
                                        ExportMode.zip,
                                      )
                                  : null,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.archivebox,
                                    size: 16,
                                    color: currentPost.hasSelection
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    currentPost.hasSelection
                                        ? '打包 ZIP (${currentPost.selectedCount})'
                                        : '打包为 ZIP',
                                    style: TextStyle(
                                      fontSize: 13,
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
                          const SizedBox(width: 10),

                          // 存入相册按钮
                          Expanded(
                            child: CupertinoButton(
                              color: AppColors.primary,
                              disabledColor: AppColors.primary.withAlpha(60),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              borderRadius: BorderRadius.circular(16),
                              onPressed: currentPost.hasSelection
                                  ? () => _startExport(
                                        context,
                                        ref,
                                        currentPost,
                                        ExportMode.album,
                                      )
                                  : null,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.photo,
                                    size: 16,
                                    color: currentPost.hasSelection
                                        ? CupertinoColors.white
                                        : CupertinoColors.white.withAlpha(100),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    currentPost.hasSelection
                                        ? '存入相册 (${currentPost.selectedCount})'
                                        : '存入相册',
                                    style: TextStyle(
                                      fontSize: 13,
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

  Widget _buildSelectionActionButton({
    required String label,
    required bool isHighlighted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.primary.withAlpha(45)
              : AppColors.secondaryCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isHighlighted
                ? AppColors.primary
                : AppColors.separator.withAlpha(70),
            width: 0.6,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isHighlighted ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
