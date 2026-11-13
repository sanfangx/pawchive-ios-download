import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pawchive_download/models/app_settings.dart';
import 'package:pawchive_download/models/download_task.dart';
import 'package:pawchive_download/models/history_item.dart';
import 'package:pawchive_download/models/media_item.dart';
import 'package:pawchive_download/models/post_detail.dart';
import 'package:pawchive_download/providers/download_provider.dart';
import 'package:pawchive_download/providers/history_provider.dart';
import 'package:pawchive_download/providers/post_provider.dart';
import 'package:pawchive_download/services/album_service.dart';
import 'package:pawchive_download/services/download_service.dart';
import 'package:pawchive_download/services/url_parser.dart';
import 'package:pawchive_download/services/zip_service.dart';
import 'package:pawchive_download/ui/download/download_sheet.dart';
import 'package:pawchive_download/ui/gallery/image_viewer_screen.dart';
import 'package:pawchive_download/ui/history/history_screen.dart';
import 'package:pawchive_download/ui/main_tab_scaffold.dart';

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

      // Select All Except First
      notifier.selectAllExceptFirst();
      state = container.read(postDetailProvider).value!;
      expect(state.selectedCount, equals(1));
      expect(state.items[0].isSelected, isFalse);
      expect(state.items[1].isSelected, isTrue);
      expect(state.isAllExceptFirstSelected, isTrue);
    });
  });

  group('DownloadManager & Multi-Task Tests', () {
    test('DownloadTask state getters and copyWith', () {
      final task = DownloadTask(
        id: 'task_1',
        postTitle: 'Post 1',
        authorName: 'Author 1',
        exportMode: ExportMode.zip,
        items: const [],
        status: DownloadStatus.queued,
        totalCount: 5,
        createdAt: DateTime.now(),
      );

      expect(task.isActive, isTrue);
      expect(task.isFinished, isFalse);

      final running = task.copyWith(
        status: DownloadStatus.downloading,
        completedCount: 2,
        progress: 0.4,
      );
      expect(running.isRunning, isTrue);
      expect(running.completedCount, equals(2));

      final completed = running.copyWith(
        status: DownloadStatus.completed,
        completedCount: 5,
        progress: 1.0,
        resultPath: '/path/to/archive.zip',
      );
      expect(completed.isFinished, isTrue);
      expect(completed.isActive, isFalse);
      expect(completed.resultPath, equals('/path/to/archive.zip'));
    });

    test('DownloadManagerState multi-task metrics', () {
      final task1 = DownloadTask(
        id: 'task_1',
        postTitle: 'Post 1',
        authorName: 'Author 1',
        exportMode: ExportMode.zip,
        items: const [],
        status: DownloadStatus.downloading,
        totalCount: 10,
        completedCount: 5,
        progress: 0.5,
        createdAt: DateTime.now(),
      );

      final task2 = DownloadTask(
        id: 'task_2',
        postTitle: 'Post 2',
        authorName: 'Author 2',
        exportMode: ExportMode.album,
        items: const [],
        status: DownloadStatus.queued,
        totalCount: 4,
        completedCount: 0,
        progress: 0.0,
        createdAt: DateTime.now(),
      );

      final manager = DownloadManagerState(tasks: [task1, task2]);

      expect(manager.hasTasks, isTrue);
      expect(manager.hasActiveTasks, isTrue);
      expect(manager.activeCount, equals(2));
      expect(manager.queuedCount, equals(1));
      expect(manager.runningTask?.id, equals('task_1'));
      expect(manager.overallProgress, equals(0.25)); // (0.5 + 0.0) / 2
    });

    test('DownloadTaskNotifier cancel and clear completed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(downloadTaskProvider.notifier);

      // Manually simulate state with 1 active and 1 completed task
      final activeTask = DownloadTask(
        id: 't_active',
        postTitle: 'Active',
        authorName: 'Author',
        exportMode: ExportMode.album,
        items: const [],
        status: DownloadStatus.downloading,
        totalCount: 3,
        createdAt: DateTime.now(),
      );
      final completedTask = DownloadTask(
        id: 't_done',
        postTitle: 'Done',
        authorName: 'Author',
        exportMode: ExportMode.zip,
        items: const [],
        status: DownloadStatus.completed,
        totalCount: 5,
        createdAt: DateTime.now(),
      );

      // Directly verify cancellation
      notifier.cancelTask(activeTask.id);
      notifier.clearCompleted();

      final state = container.read(downloadTaskProvider);
      expect(state.tasks.where((t) => t.id == completedTask.id), isEmpty);
    });

    testWidgets('ImageViewerScreen renders without errors', (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: ImageViewerScreen(
            items: [
              MediaItem(
                id: '1',
                name: '1.jpg',
                path: '/1.jpg',
                downloadUrl: 'https://example.com/1.jpg',
                thumbnailUrl: 'https://example.com/thumb.jpg',
                isVideo: false,
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    test('AppSettings serialization does not include customAlbum or albumNamePrefix', () {
      const settings = AppSettings(
        concurrency: 5,
        cleanCacheAfterAlbumSave: false,
      );
      final map = settings.toMap();
      expect(map.containsKey('customAlbum'), isFalse);
      expect(map.containsKey('albumNamePrefix'), isFalse);

      final restored = AppSettings.fromMap(map);
      expect(restored.concurrency, equals(5));
      expect(restored.cleanCacheAfterAlbumSave, isFalse);
    });

    testWidgets('MainTabScaffold renders 3 tabs (首页, 历史, 设置)', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: CupertinoApp(
            home: MainTabScaffold(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('首页'), findsWidgets);
      expect(find.text('历史'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('HistoryScreen author grouping folds/unfolds independently without cross-author bug', (tester) async {
      final item1 = HistoryItem(
        url: 'https://pawchive.pw/patreon/user/1/post/101',
        title: 'Post by Alice',
        authorName: 'Alice',
        authorAvatarUrl: '',
        coverUrl: '',
        mediaCount: 3,
        service: 'patreon',
        savedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final item2 = HistoryItem(
        url: 'https://pawchive.pw/patreon/user/2/post/102',
        title: 'Post by Bob',
        authorName: 'Bob',
        authorAvatarUrl: '',
        coverUrl: '',
        mediaCount: 5,
        service: 'patreon',
        savedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            historyProvider.overrideWith((ref) => FakeHistoryNotifier([item1, item2])),
          ],
          child: const CupertinoApp(
            home: HistoryScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to "按作者收纳"
      await tester.tap(find.text('按作者收纳'));
      await tester.pump(const Duration(milliseconds: 300));

      // Initially both authors are expanded
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Post by Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Post by Bob'), findsOneWidget);

      // Tap first author "Alice" -> Alice should collapse, Bob should REMAIN EXPANDED
      await tester.tap(find.text('Alice'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Post by Alice'), findsNothing);
      expect(find.text('Post by Bob'), findsOneWidget);

      // Tap first author "Alice" again -> Alice should re-expand, Bob still expanded
      await tester.tap(find.text('Alice'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Post by Alice'), findsOneWidget);
      expect(find.text('Post by Bob'), findsOneWidget);

      // Tap second author "Bob" -> Bob collapses, Alice remains expanded
      await tester.tap(find.text('Bob'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Post by Alice'), findsOneWidget);
      expect(find.text('Post by Bob'), findsNothing);
    });

    testWidgets('HomeScreen shows download action dock above tab bar when items are selected', (tester) async {
      final target = UrlParser.parse('https://pawchive.pw/patreon/user/1/post/1')!;
      const item1 = MediaItem(
        id: '1',
        name: 'img1.jpg',
        path: '/img1.jpg',
        downloadUrl: 'https://example.com/1.jpg',
        thumbnailUrl: 'https://example.com/thumb1.jpg',
        isVideo: false,
        isSelected: false,
      );
      const item2 = MediaItem(
        id: '2',
        name: 'img2.jpg',
        path: '/img2.jpg',
        downloadUrl: 'https://example.com/2.jpg',
        thumbnailUrl: 'https://example.com/thumb2.jpg',
        isVideo: false,
        isSelected: false,
      );

      final post = PostDetail(
        target: target,
        id: '1',
        title: 'Test Post Photos',
        authorName: 'Artist',
        authorAvatarUrl: '',
        publishedAt: '2026-11-12',
        contentHtml: '',
        items: [item1, item2],
      );

      final container = ProviderContainer();
      container.read(postDetailProvider.notifier).setPost(post);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CupertinoApp(
            home: MainTabScaffold(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the dock buttons exist and are initially unselected
      expect(find.text('打包为 ZIP'), findsOneWidget);
      expect(find.text('下载到相册'), findsOneWidget);

      // Check vertical positioning: download dock must be above the tab bar
      final downloadBtnCenter = tester.getCenter(find.text('下载到相册'));
      final tabHomeCenter = tester.getCenter(find.text('首页'));
      expect(downloadBtnCenter.dy < tabHomeCenter.dy, isTrue);

      // Tap "全选" to select both images
      await tester.tap(find.text('全选'));
      await tester.pump(const Duration(milliseconds: 300));

      // Now selection count is reflected on download button
      expect(find.text('下载到相册 (2)'), findsOneWidget);
      expect(find.text('打包 ZIP (2)'), findsOneWidget);

      // Tap "下载到相册 (2)"
      await tester.tap(find.text('下载到相册 (2)'));
      await tester.pump(const Duration(milliseconds: 300));

      // DownloadSheet popup appears
      expect(find.byType(DownloadSheet), findsOneWidget);
    });
  });

  group('Media Order Preservation Tests', () {
    const MethodChannel pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    const MethodChannel albumChannel =
        MethodChannel('pawchive_download/album');
    const MethodChannel galChannel = MethodChannel('gal');

    test('computeOrderedCreationTimestampsMs spaces items strictly ascending', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000100000);
      final batch1 = AlbumService.computeOrderedCreationTimestampsMs(
        5,
        now: now,
      );
      expect(batch1.length, equals(5));
      for (int i = 1; i < batch1.length; i++) {
        expect(batch1[i], greaterThan(batch1[i - 1]));
      }
      expect(batch1.last, lessThan(now.millisecondsSinceEpoch));

      // Back-to-back batch shortly after still advances strictly beyond batch1
      final soon = now.add(const Duration(seconds: 2));
      final batch2 = AlbumService.computeOrderedCreationTimestampsMs(
        4,
        now: soon,
        previousEndMs: batch1.last,
      );
      expect(batch2.first, greaterThan(batch1.last));
      for (int i = 1; i < batch2.length; i++) {
        expect(batch2[i], greaterThan(batch2[i - 1]));
      }
      expect(batch2.last, lessThan(soon.millisecondsSinceEpoch));
    });

    test('DownloadService zero-pads 12+ concurrent downloads and ZipService preserves order', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final tempRoot = Directory.systemTemp.createTempSync('pawchive_order_test_');
      final docsDir = Directory(p.join(tempRoot.path, 'docs'))..createSync();
      final tmpDir = Directory(p.join(tempRoot.path, 'tmp'))..createSync();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(pathProviderChannel, (call) async {
        if (call.method == 'getTemporaryDirectory') return tmpDir.path;
        if (call.method == 'getApplicationDocumentsDirectory') return docsDir.path;
        return tempRoot.path;
      });

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final seg = int.tryParse(req.uri.pathSegments.last) ?? 0;
        // Delay earlier items longer so concurrent workers finish out of order
        await Future.delayed(Duration(milliseconds: (12 - seg) * 8));
        req.response.statusCode = HttpStatus.ok;
        req.response.add(List<int>.filled(64, seg));
        await req.response.close();
      });

      try {
        final items = List<MediaItem>.generate(12, (index) {
          final isExtensionless = index == 11;
          return MediaItem(
            id: 'item_$index',
            name: isExtensionless ? 'page_last' : 'page_${index + 1}.jpg',
            path: isExtensionless ? '/files/last.png' : '/files/${index + 1}.jpg',
            downloadUrl: 'http://127.0.0.1:${server.port}/$index',
            thumbnailUrl: 'http://127.0.0.1:${server.port}/$index',
            isVideo: false,
            isSelected: true,
          );
        });

        final service = DownloadService();
        final downloaded = await HttpOverrides.runWithHttpOverrides(
          () => service.downloadBatch(
            items: items,
            concurrency: 4,
            onProgress: ({
              required completedCount,
              required totalCount,
              required overallProgress,
              required speedStr,
              required currentFileName,
            }) {},
          ),
          _DirectHttpOverrides(),
        );

        expect(downloaded.length, equals(12));
        expect(downloaded.every((e) => e.isDownloaded && e.localPath != null), isTrue);

        final fileNames = downloaded.map((e) => p.basename(e.localPath!)).toList();
        expect(fileNames[0], equals('01_page_1.jpg'));
        expect(fileNames[1], equals('02_page_2.jpg'));
        expect(fileNames[9], equals('10_page_10.jpg'));
        expect(fileNames[11], equals('12_page_last.png'));

        // Lexicographical sort order must match original post order
        final lexSorted = List<String>.from(fileNames)..sort();
        expect(lexSorted, equals(fileNames));

        // ZipService preserves exact order and zero-padded names
        final zipPath = await ZipService.packageZip(
          items: downloaded,
          zipFileName: 'order_test.zip',
          cleanCacheAfterPack: true,
        );
        final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
        final archiveNames = archive.files.map((f) => f.name).toList();
        expect(archiveNames, equals(fileNames));
      } finally {
        await server.close(force: true);
        messenger.setMockMethodCallHandler(pathProviderChannel, null);
        if (tempRoot.existsSync()) {
          tempRoot.deleteSync(recursive: true);
        }
      }
    });

    test('AlbumService invokes iOS bridge sequentially in post order with ascending creationDate', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      AlbumService.resetOrderState();
      AlbumService.debugOverrideIsIos = true;

      final tempRoot = Directory.systemTemp.createTempSync('pawchive_album_test_');
      final batchDir = Directory(p.join(tempRoot.path, 'batch_123'))..createSync();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final savedCalls = <Map<String, dynamic>>[];

      messenger.setMockMethodCallHandler(galChannel, (call) async {
        if (call.method == 'hasAccess' || call.method == 'requestAccess') {
          return true;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(albumChannel, (call) async {
        if (call.method == 'saveMediaWithCreationDate') {
          savedCalls.add(Map<String, dynamic>.from(call.arguments as Map));
        }
        return null;
      });

      try {
        final items = List<MediaItem>.generate(10, (index) {
          final prefix = (index + 1).toString().padLeft(2, '0');
          final file = File(p.join(batchDir.path, '${prefix}_img.jpg'))
            ..writeAsBytesSync([1, 2, 3, index]);
          return MediaItem(
            id: 'att_$index',
            name: 'img.jpg',
            path: '/img.jpg',
            downloadUrl: 'https://example.com/$index.jpg',
            thumbnailUrl: 'https://example.com/t_$index.jpg',
            isVideo: index == 9,
            isDownloaded: true,
            localPath: file.path,
          );
        });

        final savedCount = await AlbumService.saveToAlbum(
          items: items,
          cleanCacheAfterSave: true,
        );

        expect(savedCount, equals(10));
        expect(savedCalls.length, equals(10));

        for (int i = 0; i < 10; i++) {
          final prefix = (i + 1).toString().padLeft(2, '0');
          expect(p.basename(savedCalls[i]['path'] as String), equals('${prefix}_img.jpg'));
          expect(savedCalls[i]['isVideo'], equals(i == 9));
          if (i > 0) {
            expect(
              savedCalls[i]['creationTimestampMs'] as int,
              greaterThan(savedCalls[i - 1]['creationTimestampMs'] as int),
            );
          }
        }

        // Batch directory should be cleaned up once empty
        expect(batchDir.existsSync(), isFalse);
      } finally {
        AlbumService.debugOverrideIsIos = null;
        AlbumService.resetOrderState();
        messenger.setMockMethodCallHandler(galChannel, null);
        messenger.setMockMethodCallHandler(albumChannel, null);
        if (tempRoot.existsSync()) {
          tempRoot.deleteSync(recursive: true);
        }
      }
    });
  });
}

class _DirectHttpOverrides extends HttpOverrides {}

class FakeHistoryNotifier extends HistoryNotifier {
  FakeHistoryNotifier(List<HistoryItem> initial) : super() {
    state = initial;
  }

  @override
  Future<void> loadHistory() async {}
}
