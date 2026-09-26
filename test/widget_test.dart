import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawchive_download/models/media_item.dart';
import 'package:pawchive_download/models/post_detail.dart';
import 'package:pawchive_download/providers/post_provider.dart';
import 'package:pawchive_download/services/url_parser.dart';

void main() {
  group('UrlParser Tests', () {
    test('Correctly parses standard Pawchive post URL', () {
      const url =
          'https://pawchive.pw/patreon/user/30500811/post/170445231';
      final target = UrlParser.parse(url);
      expect(target, isNotNull);
      expect(target?.service, equals('patreon'));
      expect(target?.userId, equals('30500811'));
      expect(target?.postId, equals('170445231'));
    });

    test('Correctly extracts Pawchive URL from messy text', () {
      const text =
          'Hey check this out: https://pawchive.pw/fanbox/user/98765/post/54321 thanks!';
      final target = UrlParser.parse(text);
      expect(target, isNotNull);
      expect(target?.service, equals('fanbox'));
      expect(target?.userId, equals('98765'));
      expect(target?.postId, equals('54321'));
    });

    test('Rejects invalid URLs', () {
      expect(UrlParser.parse('https://google.com'), isNull);
      expect(UrlParser.parse('hello world'), isNull);
    });
  });

  group('MediaItem & Selection Tests', () {
    test('MediaItem defaults to isSelected == false', () {
      const item = MediaItem(
        id: '1',
        name: 'test.jpg',
        path: '/test.jpg',
        downloadUrl: 'https://example.com/test.jpg',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        isVideo: false,
      );
      expect(item.isSelected, isFalse);
    });

    test('PostDetail selection statistics calculate correctly', () {
      final target = UrlParser.parse('https://pawchive.pw/patreon/user/1/post/1')!;
      const item1 = MediaItem(
        id: '1',
        name: 'test1.jpg',
        path: '/test1.jpg',
        downloadUrl: 'https://example.com/test1.jpg',
        thumbnailUrl: 'https://example.com/thumb1.jpg',
        isVideo: false,
        isSelected: false,
      );
      const item2 = MediaItem(
        id: '2',
        name: 'test2.jpg',
        path: '/test2.jpg',
        downloadUrl: 'https://example.com/test2.jpg',
        thumbnailUrl: 'https://example.com/thumb2.jpg',
        isVideo: false,
        isSelected: true,
      );

      final post = PostDetail(
        target: target,
        id: '1',
        title: 'Test Post',
        authorName: 'Author',
        authorAvatarUrl: '',
        publishedAt: '2026-09-27',
        contentHtml: '',
        items: [item1, item2],
      );

      expect(post.totalCount, equals(2));
      expect(post.selectedCount, equals(1));
      expect(post.hasSelection, isTrue);
      expect(post.isAllSelected, isFalse);
    });

    test('PostDetailNotifier setPost, selectAll, and toggleItemSelection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final target = UrlParser.parse('https://pawchive.pw/patreon/user/1/post/1')!;
      const item1 = MediaItem(
        id: '1',
        name: '1.jpg',
        path: '/1.jpg',
        downloadUrl: 'url1',
        thumbnailUrl: 'thumb1',
        isVideo: false,
      );
      const item2 = MediaItem(
        id: '2',
        name: '2.jpg',
        path: '/2.jpg',
        downloadUrl: 'url2',
        thumbnailUrl: 'thumb2',
        isVideo: false,
      );

      final post = PostDetail(
        target: target,
        id: '1',
        title: 'Test',
        authorName: 'Author',
        authorAvatarUrl: '',
        publishedAt: '',
        contentHtml: '',
        items: [item1, item2],
      );

      final notifier = container.read(postDetailProvider.notifier);
      notifier.setPost(post);

      // Verify initial state: 0 selected
      var state = container.read(postDetailProvider).value!;
      expect(state.selectedCount, equals(0));
      expect(state.hasSelection, isFalse);

      // Toggle item 1
      notifier.toggleItemSelection('1');
      state = container.read(postDetailProvider).value!;
      expect(state.selectedCount, equals(1));
      expect(state.items.firstWhere((i) => i.id == '1').isSelected, isTrue);
      expect(state.items.firstWhere((i) => i.id == '2').isSelected, isFalse);

      // Select All
      notifier.selectAll(true);
      state = container.read(postDetailProvider).value!;
      expect(state.selectedCount, equals(2));
      expect(state.isAllSelected, isTrue);

      // Deselect All
      notifier.selectAll(false);
      state = container.read(postDetailProvider).value!;
      expect(state.selectedCount, equals(0));
      expect(state.hasSelection, isFalse);
    });
  });
}
