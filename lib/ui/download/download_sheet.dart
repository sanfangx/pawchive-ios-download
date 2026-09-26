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
    final taskState = ref.watch(downloadTaskProvider);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
          const SizedBox(height: 16),

          // Header title & icon
          Row(
            children: [
              _buildStatusIcon(taskState.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusTitle(taskState),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusSubtitle(taskState),
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
              if (taskState.isActive)
                Text(
                  taskState.currentSpeed,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Native Cupertino Progress Indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: AppColors.secondaryCard,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final progress = taskState.status == DownloadStatus.completed
                      ? 1.0
                      : (taskState.totalCount > 0
                          ? taskState.progress.clamp(0.0, 1.0)
                          : 0.0);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: constraints.maxWidth * progress,
                      color: taskState.status == DownloadStatus.failed
                          ? AppColors.destructive
                          : AppColors.primary,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // TrollStore Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(CupertinoIcons.bolt_fill,
                    size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '巨魔无限后台特权已生效，可直接锁屏或切后台',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          if (taskState.isActive)
            CupertinoButton(
              color: AppColors.secondaryCard,
              borderRadius: BorderRadius.circular(12),
              onPressed: () {
                ref.read(downloadTaskProvider.notifier).cancelDownload();
              },
              child: const Text(
                '取消任务',
                style: TextStyle(
                  color: AppColors.destructive,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (taskState.status == DownloadStatus.completed)
            Row(
              children: [
                if (taskState.resultPath != null) ...[
                  Expanded(
                    child: CupertinoButton(
                      color: AppColors.secondaryCard,
                      borderRadius: BorderRadius.circular(12),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Share.shareXFiles([XFile(taskState.resultPath!)]);
                      },
                      child: const Text(
                        '分享 ZIP',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: CupertinoButton(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(downloadTaskProvider.notifier).reset();
                    },
                    child: const Text(
                      '完成',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (taskState.status == DownloadStatus.failed ||
              taskState.status == DownloadStatus.cancelled)
            CupertinoButton(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(downloadTaskProvider.notifier).reset();
              },
              child: const Text(
                '关闭',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return const CupertinoActivityIndicator(radius: 12);
      case DownloadStatus.savingToAlbum:
        return const Icon(CupertinoIcons.photo_on_rectangle,
            color: AppColors.primary, size: 28);
      case DownloadStatus.packingZip:
        return const Icon(CupertinoIcons.archivebox_fill,
            color: CupertinoColors.activeOrange, size: 28);
      case DownloadStatus.completed:
        return const Icon(CupertinoIcons.checkmark_circle_fill,
            color: AppColors.success, size: 28);
      case DownloadStatus.failed:
        return const Icon(CupertinoIcons.xmark_circle_fill,
            color: AppColors.destructive, size: 28);
      case DownloadStatus.cancelled:
        return const Icon(CupertinoIcons.slash_circle,
            color: AppColors.textSecondary, size: 28);
      case DownloadStatus.idle:
        return const Icon(CupertinoIcons.arrow_down_circle,
            color: AppColors.primary, size: 28);
    }
  }

  String _getStatusTitle(DownloadTaskState state) {
    switch (state.status) {
      case DownloadStatus.downloading:
        return '正在高速下载...';
      case DownloadStatus.savingToAlbum:
        return '正在写入系统相册...';
      case DownloadStatus.packingZip:
        return '正在打包 ZIP 归档...';
      case DownloadStatus.completed:
        return '全部导出完成！';
      case DownloadStatus.failed:
        return '导出遇到错误';
      case DownloadStatus.cancelled:
        return '任务已取消';
      case DownloadStatus.idle:
        return '准备就绪';
    }
  }

  String _getStatusSubtitle(DownloadTaskState state) {
    switch (state.status) {
      case DownloadStatus.downloading:
        return '已完成 ${state.completedCount} / ${state.totalCount} 项 (${(state.progress * 100).toStringAsFixed(0)}%)';
      case DownloadStatus.savingToAlbum:
        return '正在无损导入专属相簿...';
      case DownloadStatus.packingZip:
        return '正在写入 Documents 目录...';
      case DownloadStatus.completed:
        return state.exportMode == ExportMode.zip
            ? '已保存至 iPhone“文件”App -> Documents'
            : '已保存至 iOS 系统相册专属相簿';
      case DownloadStatus.failed:
        return state.errorMessage ?? '部分文件请求超时或网络异常';
      case DownloadStatus.cancelled:
        return '已中止未完成的媒体下载';
      case DownloadStatus.idle:
        return '';
    }
  }
}
