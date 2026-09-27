import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/download_task.dart';
import '../../providers/download_provider.dart';
import '../common/cupertino_helpers.dart';

class DownloadSheet extends ConsumerWidget {
  const DownloadSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managerState = ref.watch(downloadTaskProvider);
    final tasks = managerState.tasks;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Drag handle
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.tertiaryCard,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Header with title & minimize button
          Row(
            children: [
              Expanded(
                child: Text(
                  '下载任务管理',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // Clear completed button if any finished
              if (managerState.finishedTasks.isNotEmpty)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onPressed: () {
                    ref.read(downloadTaskProvider.notifier).clearCompleted();
                  },
                  child: const Text(
                    '清空完成',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

              // Minimize / Run in background button
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: AppColors.secondaryCard,
                borderRadius: BorderRadius.circular(16),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.chevron_down,
                        size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      '收起后台',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Scrollable Tasks List
          Flexible(
            child: tasks.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.arrow_down_circle,
                              size: 40, color: AppColors.secondaryCard),
                          SizedBox(height: 10),
                          Text(
                            '暂无下载任务',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _buildTaskCard(context, ref, task);
                    },
                  ),
          ),
          const SizedBox(height: 14),

          // 5. Bottom "Continue Browsing" button
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(vertical: 13),
            borderRadius: BorderRadius.circular(16),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              managerState.hasActiveTasks ? '收起面板并继续浏览其他帖子' : '完成',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
      BuildContext context, WidgetRef ref, DownloadTask task) {
    final isZip = task.exportMode == ExportMode.zip;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: task.isRunning
              ? AppColors.primary.withAlpha(80)
              : AppColors.separator,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top title, mode tag & action button
          Row(
            children: [
              _buildStatusIcon(task.status),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.postTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isZip ? 'ZIP' : '相册',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          task.authorName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Action button (Cancel / Share / Retry+Delete)
              if (task.isActive)
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () {
                    ref.read(downloadTaskProvider.notifier).cancelTask(task.id);
                  },
                  child: const Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.destructive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (task.status == DownloadStatus.completed &&
                  isZip &&
                  task.resultPath != null)
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: AppColors.primary.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () {
                    Share.shareXFiles([XFile(task.resultPath!)]);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.share,
                          size: 13, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        '分享',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              // ⑧ 失败/取消任务：显示重试 + 删除两个按钮
              else if (task.status == DownloadStatus.failed ||
                  task.status == DownloadStatus.cancelled)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      color: AppColors.primary.withAlpha(35),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () {
                        ref
                            .read(downloadTaskProvider.notifier)
                            .retryTask(task.id);
                      },
                      child: const Text(
                        '重试',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        ref
                            .read(downloadTaskProvider.notifier)
                            .removeTask(task.id);
                      },
                      child: const Icon(
                        CupertinoIcons.trash,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                )
              else
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    ref
                        .read(downloadTaskProvider.notifier)
                        .removeTask(task.id);
                  },
                  child: const Icon(
                    CupertinoIcons.trash,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),

          // Progress bar & detail line
          if (task.isActive) ...[
            const SizedBox(height: 10),
            // ⑦ 进度条平滑动画（TweenAnimationBuilder）
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 6,
                color: AppColors.cardBackground,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0.0,
                    end: task.status == DownloadStatus.queued
                        ? 0.0
                        : task.progress.clamp(0.02, 1.0),
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  builder: (ctx, value, child) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value,
                      child: Container(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getTaskStatusSubtitle(task),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (task.currentSpeed.isNotEmpty &&
                    task.status == DownloadStatus.downloading)
                  Text(
                    task.currentSpeed,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              _getTaskStatusSubtitle(task),
              style: TextStyle(
                fontSize: 11,
                color: task.status == DownloadStatus.failed
                    ? AppColors.destructive
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.queued:
        return const Icon(CupertinoIcons.clock_fill,
            color: AppColors.textSecondary, size: 20);
      case DownloadStatus.downloading:
        return const CupertinoActivityIndicator(radius: 10);
      case DownloadStatus.savingToAlbum:
        return const Icon(CupertinoIcons.photo_on_rectangle,
            color: AppColors.primary, size: 20);
      case DownloadStatus.packingZip:
        return const Icon(CupertinoIcons.archivebox_fill,
            color: CupertinoColors.activeOrange, size: 20);
      case DownloadStatus.completed:
        return const Icon(CupertinoIcons.checkmark_circle_fill,
            color: AppColors.success, size: 20);
      case DownloadStatus.failed:
        return const Icon(CupertinoIcons.xmark_circle_fill,
            color: AppColors.destructive, size: 20);
      case DownloadStatus.cancelled:
        return const Icon(CupertinoIcons.slash_circle,
            color: AppColors.textSecondary, size: 20);
    }
  }

  String _getTaskStatusSubtitle(DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.queued:
        return '等待中 · ${task.totalCount} 项';
      case DownloadStatus.downloading:
        return '${task.completedCount}/${task.totalCount} 项 (${(task.progress * 100).toStringAsFixed(0)}%)';
      case DownloadStatus.savingToAlbum:
        return '正在保存至相册...';
      case DownloadStatus.packingZip:
        return '正在打包 ZIP...';
      case DownloadStatus.completed:
        return task.exportMode == ExportMode.zip
            ? '已保存至 Documents · ${task.completedCount} 项'
            : '已存入相册 · ${task.completedCount} 项';
      case DownloadStatus.failed:
        return task.errorMessage ?? '下载失败';
      case DownloadStatus.cancelled:
        return '已取消';
    }
  }
}
