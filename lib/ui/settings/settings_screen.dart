import 'dart:io';
import 'package:flutter/cupertino.dart';
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
  List<FileSystemEntity> _zipFiles = [];

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
        _versionStr = 'v${info.version}+${info.buildNumber} (TrollStore Build)';
      });
    }
  }

  Future<void> _refreshStorageInfo() async {
    final bytes = await StorageService.getCacheSizeBytes();
    final docDir = await getApplicationDocumentsDirectory();
    final files = docDir.existsSync()
        ? docDir.listSync().where((e) => e.path.endsWith('.zip')).toList()
        : <FileSystemEntity>[];

    if (mounted) {
      setState(() {
        _cacheSizeStr = StorageService.formatBytes(bytes);
        _zipFiles = files;
      });
    }
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
        previousPageTitle: '首页',
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          children: [
            const SizedBox(height: 16),

            // Group 1: 下载与性能
            _buildSectionHeader('下载与性能'),
            CupertinoListSection.insetGrouped(
              backgroundColor: AppColors.background,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              children: [
                CupertinoListTile(
                  title: const Text('下载并发数',
                      style: TextStyle(color: AppColors.textPrimary)),
                  additionalInfo: Text(
                    '${settings.concurrency} 线程',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                const CupertinoListTile(
                  title: Text('大文件智能断点续传',
                      style: TextStyle(color: AppColors.textPrimary)),
                  trailing: Icon(CupertinoIcons.checkmark_alt,
                      color: AppColors.success),
                ),
              ],
            ),

            // Group 2: 相册与导出偏好
            _buildSectionHeader('相册与导出偏好'),
            CupertinoListSection.insetGrouped(
              backgroundColor: AppColors.background,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              children: [
                CupertinoListTile(
                  title: const Text('创建独立专属相簿',
                      style: TextStyle(color: AppColors.textPrimary)),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.customAlbum,
                    onChanged: (val) => notifier.toggleCustomAlbum(val),
                  ),
                ),
                CupertinoListTile(
                  title: const Text('存入相册后清理临时缓存',
                      style: TextStyle(color: AppColors.textPrimary)),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.cleanCacheAfterAlbumSave,
                    onChanged: (val) => notifier.toggleCleanCache(val),
                  ),
                ),
              ],
            ),

            // Group 3: 后台与通知
            _buildSectionHeader('后台与通知'),
            CupertinoListSection.insetGrouped(
              backgroundColor: AppColors.background,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.bolt_fill,
                      color: AppColors.primary),
                  title: const Text('无限后台保活',
                      style: TextStyle(color: AppColors.textPrimary)),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.trollStoreKeepAlive,
                    onChanged: (val) => notifier.toggleTrollStoreKeepAlive(val),
                  ),
                ),
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.bell_fill,
                      color: CupertinoColors.systemIndigo),
                  title: const Text('任务完成通知',
                      style: TextStyle(color: AppColors.textPrimary)),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.notifyOnComplete,
                    onChanged: (val) => notifier.toggleNotifyOnComplete(val),
                  ),
                ),
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.waveform,
                      color: CupertinoColors.systemTeal),
                  title: const Text('完成触感震动',
                      style: TextStyle(color: AppColors.textPrimary)),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.hapticFeedbackEnabled,
                    onChanged: (val) => notifier.toggleHapticFeedback(val),
                  ),
                ),
              ],
            ),

            // Group 4: ZIP 归档
            _buildSectionHeader('ZIP 归档'),
            CupertinoListSection.insetGrouped(
              backgroundColor: AppColors.background,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              children: [
                CupertinoListTile(
                  title: const Text('ZIP 数量',
                      style: TextStyle(color: AppColors.textPrimary)),
                  additionalInfo: Text(
                    '${_zipFiles.length} 个',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                if (_zipFiles.isNotEmpty)
                  ..._zipFiles.map((file) {
                    final filename = file.path.split(Platform.pathSeparator).last;
                    return CupertinoListTile(
                      leading: const Icon(CupertinoIcons.archivebox_fill,
                          color: CupertinoColors.activeOrange),
                      title: Text(filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textPrimary)),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.share,
                            size: 20, color: AppColors.primary),
                        onPressed: () {
                          Share.shareXFiles([XFile(file.path)]);
                        },
                      ),
                    );
                  })
                else
                  const CupertinoListTile(
                    title: Text('暂无 ZIP 文件',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
              ],
            ),

            // Group 5: 缓存
            _buildSectionHeader('缓存'),
            CupertinoListSection.insetGrouped(
              backgroundColor: AppColors.background,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              children: [
                CupertinoListTile(
                  title: const Text('缓存占用',
                      style: TextStyle(color: AppColors.textPrimary)),
                  additionalInfo: Text(
                    _cacheSizeStr,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                CupertinoListTile(
                  title: const Text(
                    '清空缓存',
                    style: TextStyle(color: AppColors.destructive),
                  ),
                  trailing: const Icon(CupertinoIcons.delete,
                      color: AppColors.destructive, size: 20),
                  onTap: () async {
                    await StorageService.clearTempCache();
                    await _refreshStorageInfo();
                    if (context.mounted) {
                      showCupertinoToast(context, '缓存已清理完毕');
                    }
                  },
                ),
              ],
            ),

            // Group 6: 关于
            _buildSectionHeader('关于应用'),
            CupertinoListSection.insetGrouped(
              backgroundColor: AppColors.background,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              children: [
                CupertinoListTile(
                  title: const Text('应用版本',
                      style: TextStyle(color: AppColors.textPrimary)),
                  additionalInfo: Text(_versionStr,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
