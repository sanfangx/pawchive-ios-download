import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active tab index in the main tab scaffold (0: 首页, 1: 历史, 2: 设置)
final selectedTabIndexProvider = StateProvider<int>((ref) => 0);

/// Pending URL to be loaded on the Home tab when navigated from History
final pendingUrlToLoadProvider = StateProvider<String?>((ref) => null);
