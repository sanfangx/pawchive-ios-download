import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/history_item.dart';
import '../models/post_detail.dart';
import '../models/post_target.dart';
import '../services/pawchive_api.dart';
import 'history_provider.dart';

final pawchiveApiProvider = Provider<PawchiveApi>((ref) => PawchiveApi());

final postDetailProvider =
    StateNotifierProvider<PostDetailNotifier, AsyncValue<PostDetail?>>((ref) {
  return PostDetailNotifier(ref);
});

class PostDetailNotifier extends StateNotifier<AsyncValue<PostDetail?>> {
  final Ref _ref;

  PostDetailNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> fetchPost(PostTarget target) async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(pawchiveApiProvider);
      final detail = await api.fetchPost(target);
      state = AsyncValue.data(detail);

      // Save to history automatically
      if (detail.items.isNotEmpty) {
        final historyItem = HistoryItem(
          url: target.rawUrl,
          title: detail.title,
          authorName: detail.authorName,
          authorAvatarUrl: detail.authorAvatarUrl,
          coverUrl: detail.items.first.thumbnailUrl,
          mediaCount: detail.totalCount,
          service: target.service,
          savedAt: DateTime.now(),
        );
        _ref.read(historyProvider.notifier).addHistory(historyItem);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void toggleItemSelection(String id) {
    state.whenData((detail) {
      if (detail == null) return;
      final updatedItems = detail.items.map((item) {
        if (item.id == id) {
          return item.copyWith(isSelected: !item.isSelected);
        }
        return item;
      }).toList();
      state = AsyncValue.data(detail.copyWith(items: updatedItems));
    });
  }

  void selectAll(bool select) {
    state.whenData((detail) {
      if (detail == null) return;
      final updatedItems = detail.items.map((item) {
        return item.copyWith(isSelected: select);
      }).toList();
      state = AsyncValue.data(detail.copyWith(items: updatedItems));
    });
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
