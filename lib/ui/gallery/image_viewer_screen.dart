import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/media_item.dart';

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

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.items[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. PageView for swiping
          GestureDetector(
            onTap: () {
              setState(() {
                _showBars = !_showBars;
              });
            },
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
                      imageUrl: item.downloadUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Center(
                        child: CachedNetworkImage(
                          imageUrl: item.thumbnailUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, _) => const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => CachedNetworkImage(
                        imageUrl: item.thumbnailUrl,
                        fit: BoxFit.contain,
                        errorWidget: (context, url, error) => const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.exclamationmark_triangle,
                                color: CupertinoColors.systemRed, size: 40),
                            SizedBox(height: 8),
                            Text('无法加载原图',
                                style: TextStyle(color: CupertinoColors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Top Bar
          if (_showBars)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
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
        ],
      ),
    );
  }
}
