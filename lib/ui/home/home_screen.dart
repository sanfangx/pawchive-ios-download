import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/history_provider.dart';
import '../../providers/post_provider.dart';
import '../../services/url_parser.dart';
import '../common/cupertino_helpers.dart';
import '../gallery/gallery_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
      });
    }
  }

  Future<void> _parseAndNavigate(String inputUrl) async {
    final target = UrlParser.parse(inputUrl);
    if (target == null) {
      showCupertinoToast(
        context,
        '未能识别有效的 Pawchive 帖子链接，请确认格式为:\nhttps://pawchive.pw/{service}/user/{uid}/post/{pid}',
        isError: true,
      );
      return;
    }

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
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => GalleryScreen(post: detail),
          ),
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

  @override
  Widget build(BuildContext context) {
    final historyList = ref.watch(historyProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: CustomScrollView(
        slivers: [
          // iOS Large Title Navigation Bar
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Pawchive'),
            backgroundColor: AppColors.barBackground,
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.gear,
                  color: AppColors.primary, size: 24),
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ),

          // Main input card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '提取帖子媒体',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '输入帖子链接，自动解析提取高清原图与视频',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Input field with paste button
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: _urlController,
                            placeholder: '粘贴 pawchive.pw 帖子链接',
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
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryCard,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            clearButtonMode: OverlayVisibilityMode.editing,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.go,
                            onSubmitted: (val) {
                              if (val.isNotEmpty) _parseAndNavigate(val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          color: AppColors.secondaryCard,
                          borderRadius: BorderRadius.circular(10),
                          onPressed: _pasteFromClipboard,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.doc_on_clipboard,
                                  size: 16, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                '粘贴',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Parse Action Button
                    CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_urlController.text.trim().isNotEmpty) {
                                _parseAndNavigate(_urlController.text.trim());
                              } else {
                                showCupertinoToast(
                                  context,
                                  '请先输入或粘贴帖子链接',
                                  isError: true,
                                );
                              }
                            },
                      child: _isLoading
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.arrow_right_circle_fill,
                                    size: 18),
                                SizedBox(width: 8),
                                Text(
                                  '解析帖子媒体',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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

          // History Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '历史记录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (historyList.isNotEmpty)
                    CupertinoButton(
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
                                  ref
                                      .read(historyProvider.notifier)
                                      .clearAll();
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
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // History Cards List
          if (historyList.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.clock,
                        size: 48,
                        color: AppColors.secondaryCard,
                      ),
                      SizedBox(height: 12),
                      Text(
                        '暂无解析历史记录',
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
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = historyList[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: CupertinoListTile(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        leadingSize: 50,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: item.coverUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (context, _) => Container(
                              color: AppColors.secondaryCard,
                              child: const CupertinoActivityIndicator(),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.secondaryCard,
                              child: const Icon(CupertinoIcons.photo,
                                  color: AppColors.textSecondary),
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
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Text(
                                item.authorName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
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
                            ],
                          ),
                        ),
                        trailing: const Icon(
                          CupertinoIcons.forward,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () {
                          _urlController.text = item.url;
                          _parseAndNavigate(item.url);
                        },
                      ),
                    );
                  },
                  childCount: historyList.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 30),
          ),
        ],
      ),
    );
  }
}
