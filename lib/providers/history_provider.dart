import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/history_item.dart';
import '../services/storage_service.dart';

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HistoryItem>>((ref) {
  return HistoryNotifier();
});

class HistoryNotifier extends StateNotifier<List<HistoryItem>> {
  HistoryNotifier() : super([]) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    final list = await StorageService.loadHistory();
    state = list;
  }

  Future<void> addHistory(HistoryItem item) async {
    await StorageService.addHistory(item);
    await loadHistory();
  }

  Future<void> deleteHistory(String url) async {
    await StorageService.deleteHistory(url);
    await loadHistory();
  }

  Future<void> clearAll() async {
    await StorageService.clearHistory();
    state = [];
  }
}
