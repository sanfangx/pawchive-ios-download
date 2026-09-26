import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loaded = await StorageService.loadSettings();
    state = loaded;
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    state = newSettings;
    await StorageService.saveSettings(newSettings);
  }

  Future<void> updateConcurrency(int concurrency) async {
    final updated = state.copyWith(concurrency: concurrency);
    await updateSettings(updated);
  }

  Future<void> toggleCustomAlbum(bool value) async {
    final updated = state.copyWith(customAlbum: value);
    await updateSettings(updated);
  }

  Future<void> toggleExifAlign(bool value) async {
    final updated = state.copyWith(exifAlignEnabled: value);
    await updateSettings(updated);
  }

  Future<void> toggleTrollStoreKeepAlive(bool value) async {
    final updated = state.copyWith(trollStoreKeepAlive: value);
    await updateSettings(updated);
  }

  Future<void> toggleNotifyOnComplete(bool value) async {
    final updated = state.copyWith(notifyOnComplete: value);
    await updateSettings(updated);
  }

  Future<void> toggleHapticFeedback(bool value) async {
    final updated = state.copyWith(hapticFeedbackEnabled: value);
    await updateSettings(updated);
  }

  Future<void> toggleCleanCache(bool value) async {
    final updated = state.copyWith(cleanCacheAfterAlbumSave: value);
    await updateSettings(updated);
  }
}
