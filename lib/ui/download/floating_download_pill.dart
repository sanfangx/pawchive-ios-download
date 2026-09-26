import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/download_task.dart';
import '../../providers/download_provider.dart';
import '../common/cupertino_helpers.dart';
import 'download_sheet.dart';

class FloatingDownloadPill extends ConsumerWidget {
  const FloatingDownloadPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managerState = ref.watch(downloadTaskProvider);

    if (!managerState.hasTasks) {
      return const SizedBox.shrink();
    }

    final hasActive = managerState.hasActiveTasks;
    final primary = managerState.primaryTask;

    return GestureDetector(
      onTap: () {
        showCupertinoModalPopup(
          context: context,
          barrierDismissible: true,
          builder: (_) => const DownloadSheet(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withAlpha(248),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasActive
                ? AppColors.primary.withAlpha(120)
                : AppColors.separator,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(100),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Leading status indicator
                if (hasActive)
                  const CupertinoActivityIndicator(radius: 9)
                else
                  const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: AppColors.success,
                    size: 20,
                  ),
                const SizedBox(width: 10),

                // Main status text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getTitle(managerState, primary),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasActive && primary != null && primary.currentSpeed.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              primary.currentSpeed,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getSubtitle(managerState, primary),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Trailing action or expand chevron
                if (!hasActive)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      ref.read(downloadTaskProvider.notifier).clearCompleted();
                    },
                    child: const Icon(
                      CupertinoIcons.xmark_circle,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '详情',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          CupertinoIcons.chevron_up,
                          size: 10,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Mini progress bar when active
            if (hasActive) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Container(
                  height: 3,
                  color: AppColors.secondaryCard,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: managerState.overallProgress.clamp(0.02, 1.0),
                      child: Container(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTitle(DownloadManagerState state, DownloadTask? primary) {
    if (state.hasActiveTasks) {
      if (state.activeCount > 1) {
        return '${state.activeCount} 个下载任务进行中';
      }
      return primary?.postTitle ?? '正在下载媒体...';
    }
    return primary != null ? '已完成: ${primary.postTitle}' : '所有任务均已导出完成';
  }

  String _getSubtitle(DownloadManagerState state, DownloadTask? primary) {
    if (state.hasActiveTasks) {
      if (primary != null) {
        final modeStr = primary.exportMode == ExportMode.zip ? 'ZIP 归档' : '相册保存';
        if (primary.status == DownloadStatus.queued) {
          return '排队等待中 · 共 ${primary.totalCount} 项 ($modeStr)';
        } else if (primary.status == DownloadStatus.savingToAlbum) {
          return '正在写入系统相册... (${primary.completedCount}/${primary.totalCount})';
        } else if (primary.status == DownloadStatus.packingZip) {
          return '正在打包 ZIP... (${primary.completedCount}/${primary.totalCount})';
        }
        return '已完成 ${primary.completedCount} / ${primary.totalCount} 项 (${(primary.progress * 100).toStringAsFixed(0)}%) · $modeStr';
      }
      return '后台下载中，点击查看详情';
    }
    return '已保存完成，点击查看或分享文件';
  }
}
