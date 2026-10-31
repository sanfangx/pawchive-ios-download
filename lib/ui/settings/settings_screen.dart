import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/settings_provider.dart';
import '../../services/storage_service.dart';
import '../common/cupertino_helpers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _cacheSizeStr = '计算中...';
  String _versionStr = '读取中...';
  List<File> _zipFiles = [];

  @override
  void initState() {
    super.initState();
    _refreshStorageInfo();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _versionStr = 'v${info.version}+${info.buildNumber}';
      });
    }
  }

  Future<void> _refreshStorageInfo() async {
    final bytes = await StorageService.getCacheSizeBytes();
    final docDir = await getApplicationDocumentsDirectory();
    final files = docDir.existsSync()
        ? docDir
            .listSync()
            .whereType<File>()
            .where((e) => e.path.toLowerCase().endsWith('.zip'))
            .toList()
        : <File>[];

    // Sort zip files by modification time descending
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    if (mounted) {
      setState(() {
        _cacheSizeStr = StorageService.formatBytes(bytes);
        _zipFiles = files;
      });
    }
  }

  void _confirmDeleteZip(File file) {
    final filename = file.path.split(Platform.pathSeparator).last;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除压缩包'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text('确定要删除以下 ZIP 归档吗？\n$filename'),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await file.delete();
                HapticFeedback.lightImpact();
                await _refreshStorageInfo();
                if (mounted) {
                  showCupertinoToast(context, '已删除压缩包');
                }
              } catch (_) {}
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppColors.barBackground,
        border: null,
        middle: Text(
          '设置',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          children: [
            // 1. 下载与任务
            CupertinoListSection.insetGrouped(
              backgroundColor: AppColors.background,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.separator.withAlpha(70),
                  width: 0.5,
                ),
              ),
              header: const Text(
                '下载与任务',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              footer: const Text(
                '无限后台保活解除系统 Watchdog 杀后台限制，锁屏或退至后台持续高速下载。',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              children: [
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.speedometer,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: const Text(
                    '下载并发数',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  additionalInfo: Text(
                    '${settings.concurrency} 线程',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                  child: CupertinoSlider(
                    value: settings.concurrency.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      notifier.updateConcurrency(val.round());
                    },
                  ),
                ),
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.bolt_fill,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: const Text(
                    '无限后台保活',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.trollStoreKeepAlive,
                    onChanged: (val) => notifier.toggleTrollStoreKeepAlive(val),
                  ),
                ),
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.bell_fill,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: const Text(
                    '任务完成通知',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.notifyOnComplete,
                    onChanged: (val) => notifier.toggleNotifyOnComplete(val),
                  ),
                ),
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.waveform,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: const Text(
                    '操作触感震动',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.hapticFeedbackEnabled,
                    onChanged: (val) => notifier.toggleHapticFeedback(val),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 2. 存储与缓存
            CupertinoListSection.insetGrouped(
              backgroundColor: AppColors.background,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.separator.withAlpha(70),
                  width: 0.5,
                ),
              ),
              header: const Text(
                '存储与缓存',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              children: [
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.photo_on_rectangle,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: const Text(
                    '存入相册后清理临时缓存',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.cleanCacheAfterAlbumSave,
                    onChanged: (val) => notifier.toggleCleanCache(val),
                  ),
                ),
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.trash,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: const Text(
                    '图片与网络缓存',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  additionalInfo: Text(
                    _cacheSizeStr,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    color: AppColors.secondaryCard,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      await StorageService.clearTempCache();
                      await _refreshStorageInfo();
                      if (context.mounted) {
                        showCupertinoToast(context, '缓存清理完毕');
                      }
                    },
                    child: const Text(
                      '清空',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 3. 本地 ZIP 归档
            CupertinoListSection.insetGrouped(
              backgroundColor: AppColors.background,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.separator.withAlpha(70),
                  width: 0.5,
                ),
              ),
              header: Text(
                '已导出的 ZIP 归档 (${_zipFiles.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              footer: const Text(
                '归档文件保存在 App Documents 目录，支持在 iOS 原生“文件”App 中直接查看与 AirDrop 分享。',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              children: _zipFiles.isEmpty
                  ? [
                      const CupertinoListTile(
                        leading: Icon(
                          CupertinoIcons.archivebox,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        title: Text(
                          '暂无导出的 ZIP 文件',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ]
                  : _zipFiles.map((file) {
                      final filename = file.path.split(Platform.pathSeparator).last;
                      final sizeBytes = file.existsSync() ? file.lengthSync() : 0;
                      final sizeText = StorageService.formatBytes(sizeBytes);

                      return CupertinoListTile(
                        leading: const Icon(
                          CupertinoIcons.archivebox_fill,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        title: Text(
                          filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          sizeText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Share button
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                Share.shareXFiles([XFile(file.path)]);
                              },
                              child: const Icon(
                                CupertinoIcons.share,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                            // Delete button
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              onPressed: () => _confirmDeleteZip(file),
                              child: const Icon(
                                CupertinoIcons.trash,
                                size: 18,
                                color: AppColors.destructive,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
            ),

            const SizedBox(height: 14),

            // 4. 关于应用
            CupertinoListSection.insetGrouped(
              backgroundColor: AppColors.background,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.separator.withAlpha(70),
                  width: 0.5,
                ),
              ),
              header: const Text(
                '关于',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              children: [
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.info_circle_fill,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: const Text(
                    'Pawchive Downloader',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    '专为 TrollStore / iOS 定制',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  additionalInfo: Text(
                    _versionStr,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
