import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/history_item.dart';

class StorageService {
  static const String _keySettings = 'pawchive_app_settings';
  static const String _keyHistory = 'pawchive_post_history';
  static const int _maxHistoryCount = 50;

  /// Load app settings
  static Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keySettings);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        return AppSettings.fromJson(jsonStr);
      } catch (_) {}
    }
    return const AppSettings();
  }

  /// Save app settings
  static Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySettings, settings.toJson());
  }

  /// Load recent parsing history
  static Future<List<HistoryItem>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyHistory);
    if (list != null) {
      return list.map((itemStr) {
        try {
          return HistoryItem.fromJson(itemStr);
        } catch (_) {
          return null;
        }
      }).whereType<HistoryItem>().toList();
    }
    return [];
  }

  /// Add an item to history (de-duplicates by url and moves to top, max 50 items)
  static Future<void> addHistory(HistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadHistory();

    // Remove if already exists with same URL
    current.removeWhere((h) => h.url == item.url);
    current.insert(0, item);

    if (current.length > _maxHistoryCount) {
      current.removeRange(_maxHistoryCount, current.length);
    }

    final stringList = current.map((h) => h.toJson()).toList();
    await prefs.setStringList(_keyHistory, stringList);
  }

  /// Delete a single history item by url
  static Future<void> deleteHistory(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadHistory();
    current.removeWhere((h) => h.url == url);
    final stringList = current.map((h) => h.toJson()).toList();
    await prefs.setStringList(_keyHistory, stringList);
  }

  /// Clear all history
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistory);
  }

  /// Calculate total temporary cache directory size
  static Future<int> getCacheSizeBytes() async {
    int total = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity
            in tempDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (_) {}
    return total;
  }

  /// Format byte size into readable string
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Clear temporary download cache
  static Future<void> clearTempCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
