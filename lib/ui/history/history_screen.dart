import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/history_item.dart';
import '../../providers/history_provider.dart';
import '../../providers/navigation_provider.dart';
import '../common/cupertino_helpers.dart';

enum HistoryViewMode {
  byTime,
  byAuthor,
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryViewMode _viewMode = HistoryViewMode.byTime;
  final Set<String> _collapsedAuthors = {};

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;

    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    if (isToday) {
      return '今天 $hour:$minute';
    } else if (isYesterday) {
      return '昨天 $hour:$minute';
    } else if (dt.year == now.year) {
      return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hour:$minute';
    } else {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
  }

  void _navigateToPost(String url) {
    HapticFeedback.selectionClick();
    ref.read(pendingUrlToLoadProvider.notifier).state = url;
    ref.read(selectedTabIndexProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context) {
    final historyList = ref.watch(historyProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.barBackground,
        border: null,
        middle: const Text(
          '历史记录',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: historyList.isNotEmpty
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  showCupertinoDialog(
                    context: context,
                    builder: (ctx) => CupertinoAlertDialog(
                      title: const Text('清空历史记录'),
                      content: const Text('确定要清空所有解析历史记录吗？'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('取消'),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          onPressed: () {
                            ref.read(historyProvider.notifier).clearAll();
                            setState(() {
                              _collapsedAuthors.clear();
                            });
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('清空'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text(
                  '清空',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.destructive,
                  ),
                ),
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Segmented Switcher for View Modes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<HistoryViewMode>(
                  groupValue: _viewMode,
                  backgroundColor: AppColors.secondaryCard,
                  thumbColor: AppColors.cardBackground,
                  children: const {
                    HistoryViewMode.byTime: Padding(
                      padding: EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.clock, size: 14, color: AppColors.textPrimary),
                          SizedBox(width: 6),
                          Text(
                            '按时间排序',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    HistoryViewMode.byAuthor: Padding(
                      padding: EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.person_2, size: 14, color: AppColors.textPrimary),
                          SizedBox(width: 6),
                          Text(
                            '按作者收纳',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  },
                  onValueChanged: (val) {
                    if (val != null) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _viewMode = val;
                      });
                    }
                  },
                ),
              ),
            ),

            // Content List
            Expanded(
              child: historyList.isEmpty
                  ? _buildEmptyState()
                  : (_viewMode == HistoryViewMode.byTime
                      ? _buildTimeSortedList(historyList)
                      : _buildAuthorGroupedList(historyList)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.clock,
            size: 52,
            color: AppColors.secondaryCard,
          ),
          SizedBox(height: 14),
          Text(
            '暂无解析历史记录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '在首页提取帖子后，记录将自动保存在这里',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 1. 按时间排序列表
  Widget _buildTimeSortedList(List<HistoryItem> list) {
    final bottomOffset = 50.0 + MediaQuery.viewPaddingOf(context).bottom + 20.0;
    // Already sorted by savedAt descending in storage/provider
    return ListView.builder(
      padding: EdgeInsets.only(left: 16, right: 16, top: 4, bottom: bottomOffset),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return _buildHistoryItemTile(item);
      },
    );
  }

  // 2. 按作者分类收纳列表
  Widget _buildAuthorGroupedList(List<HistoryItem> list) {
    final bottomOffset = 50.0 + MediaQuery.viewPaddingOf(context).bottom + 20.0;
    // Group posts by authorName
    final Map<String, List<HistoryItem>> authorMap = {};
    for (final item in list) {
      final author = item.authorName.isNotEmpty ? item.authorName : '未知作者';
      authorMap.putIfAbsent(author, () => []).add(item);
    }

    // Sort authors by most recent item time
    final authors = authorMap.keys.toList()
      ..sort((a, b) {
        final aLatest = authorMap[a]!.first.savedAt;
        final bLatest = authorMap[b]!.first.savedAt;
        return bLatest.compareTo(aLatest);
      });

    return ListView.builder(
      padding: EdgeInsets.only(left: 16, right: 16, top: 4, bottom: bottomOffset),
      itemCount: authors.length,
      itemBuilder: (context, index) {
        final authorName = authors[index];
        final authorPosts = authorMap[authorName]!;
        final isExpanded = !_collapsedAuthors.contains(authorName);
        final firstItem = authorPosts.first;
        final totalMedia = authorPosts.fold<int>(0, (sum, e) => sum + e.mediaCount);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.separator.withAlpha(80),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Author Header
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (_collapsedAuthors.contains(authorName)) {
                      _collapsedAuthors.remove(authorName);
                    } else {
                      _collapsedAuthors.add(authorName);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Author Avatar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: firstItem.authorAvatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: firstItem.authorAvatarUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                placeholder: (context, _) => Container(
                                  color: AppColors.secondaryCard,
                                  child: const CupertinoActivityIndicator(radius: 8),
                                ),
                                errorWidget: (context, url, error) => _buildFallbackAvatar(authorName),
                              )
                            : _buildFallbackAvatar(authorName),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authorName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${authorPosts.length} 个帖子 · 共 $totalMedia 项媒体',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded Posts List
              if (isExpanded) ...[
                Container(
                  height: 0.5,
                  color: AppColors.separator.withAlpha(60),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: authorPosts.length,
                  separatorBuilder: (context, idx) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    height: 0.5,
                    color: AppColors.separator.withAlpha(40),
                  ),
                  itemBuilder: (context, postIdx) {
                    final post = authorPosts[postIdx];
                    return CupertinoListTile(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      leadingSize: 48,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: post.coverUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (context, _) => Container(
                            color: AppColors.secondaryCard,
                            child: const CupertinoActivityIndicator(radius: 6),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.secondaryCard,
                            child: const Icon(CupertinoIcons.photo, size: 20, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      title: Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            Text(
                              _formatDate(post.savedAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(35),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${post.mediaCount} 项',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: const Icon(
                        CupertinoIcons.arrow_right_circle,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      onTap: () => _navigateToPost(post.url),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackAvatar(String name) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Container(
      width: 40,
      height: 40,
      color: AppColors.secondaryCard,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildHistoryItemTile(HistoryItem item) {
    return Dismissible(
      key: Key(item.url),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.destructive,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          CupertinoIcons.delete,
          color: CupertinoColors.white,
          size: 22,
        ),
      ),
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        ref.read(historyProvider.notifier).deleteHistory(item.url);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.separator.withAlpha(60),
            width: 0.5,
          ),
        ),
        child: CupertinoListTile(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          leadingSize: 60,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: item.coverUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder: (context, _) => Container(
                color: AppColors.secondaryCard,
                child: const CupertinoActivityIndicator(radius: 8),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppColors.secondaryCard,
                child: const Icon(CupertinoIcons.photo, color: AppColors.textSecondary),
              ),
            ),
          ),
          title: Text(
            item.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    item.authorName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.mediaCount} 项',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(item.savedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          trailing: const Icon(
            CupertinoIcons.forward,
            size: 16,
            color: AppColors.textSecondary,
          ),
          onTap: () => _navigateToPost(item.url),
        ),
      ),
    );
  }
}
