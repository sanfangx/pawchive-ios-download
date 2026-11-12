import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/media_item.dart';
import '../../services/download_service.dart';
import '../common/cupertino_helpers.dart';

class ImageViewerScreen extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showBars = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentImage(MediaItem item) async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (!mounted) return;
          showCupertinoToast(context, '未获得相册权限，无法保存图片', isError: true);
          return;
        }
      }

      final tempDir = await getTemporaryDirectory();
      final ext = item.name.contains('.')
          ? p.extension(item.name)
          : (item.isVideo ? '.mp4' : '.jpg');
      final safeName = DownloadService.sanitizeFilename(
          'pawchive_${DateTime.now().millisecondsSinceEpoch}$ext');
      final savePath = p.join(tempDir.path, safeName);

      final dio = Dio();
      await dio.download(
        item.downloadUrl,
        savePath,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
            'Referer': 'https://pawchive.pw/',
          },
        ),
      );

      if (item.isVideo) {
        await Gal.putVideo(savePath);
      } else {
        await Gal.putImage(savePath);
      }

      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      if (!mounted) return;
      HapticFeedback.lightImpact();
      showCupertinoToast(context, '已成功保存到系统相册');
    } catch (e) {
      if (!mounted) return;
      showCupertinoToast(context, '保存失败: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ⑩ 长按弹出操作菜单
  void _showLongPressMenu(BuildContext context, MediaItem item) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _saveCurrentImage(item);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.arrow_down_to_line, size: 18),
                SizedBox(width: 8),
                Text('保存原图至系统相册'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              Share.shareUri(Uri.parse(item.downloadUrl));
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.share, size: 18),
                SizedBox(width: 8),
                Text('分享原图链接'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.items[_currentIndex];

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        children: [
          // 1. PageView for swiping
          GestureDetector(
            onTap: () {
              setState(() {
                _showBars = !_showBars;
              });
            },
            // ⑩ 长按弹出 ActionSheet
            onLongPress: () => _showLongPressMenu(context, currentItem),
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: item.thumbnailUrl,
                      fit: BoxFit.contain,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholder: (context, url) => const Center(
                        child: CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.exclamationmark_triangle,
                              color: CupertinoColors.systemRed, size: 40),
                          SizedBox(height: 8),
                          Text('无法加载图片',
                              style: TextStyle(color: CupertinoColors.white)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Top Bar with animated fade (⑪)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showBars ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: IgnorePointer(
                ignoring: !_showBars,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 12,
                    left: 16,
                    right: 16,
                  ),
                  color: Colors.black.withAlpha(150),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.back,
                            color: CupertinoColors.white, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentItem.name,
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_currentIndex + 1} / ${widget.items.length}',
                              style: const TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _isSaving
                            ? null
                            : () => _saveCurrentImage(currentItem),
                        child: _isSaving
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                                radius: 9,
                              )
                            : const Icon(
                                CupertinoIcons.arrow_down_to_line,
                                color: CupertinoColors.white,
                                size: 24,
                              ),
                      ),
                      const SizedBox(width: 14),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.share,
                            color: CupertinoColors.white, size: 24),
                        onPressed: () {
                          Share.shareUri(Uri.parse(currentItem.downloadUrl));
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
