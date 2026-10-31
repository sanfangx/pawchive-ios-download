import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import 'common/cupertino_helpers.dart';
import 'history/history_screen.dart';
import 'home/home_screen.dart';
import 'settings/settings_screen.dart';

class MainTabScaffold extends ConsumerStatefulWidget {
  const MainTabScaffold({super.key});

  @override
  ConsumerState<MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends ConsumerState<MainTabScaffold> {
  late final CupertinoTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController(
      initialIndex: ref.read(selectedTabIndexProvider),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for programmatic tab switches (e.g. from History to Home)
    ref.listen<int>(selectedTabIndexProvider, (prev, next) {
      if (_tabController.index != next) {
        _tabController.index = next;
      }
    });

    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        backgroundColor: AppColors.barBackground.withAlpha(240),
        activeColor: AppColors.primary,
        inactiveColor: AppColors.textSecondary,
        border: const Border(
          top: BorderSide(
            color: AppColors.separator,
            width: 0.5,
          ),
        ),
        onTap: (index) {
          HapticFeedback.selectionClick();
          ref.read(selectedTabIndexProvider.notifier).state = index;
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_arrow_down),
            activeIcon: Icon(CupertinoIcons.square_arrow_down_fill),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.clock),
            activeIcon: Icon(CupertinoIcons.clock_fill),
            label: '历史',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.gear_alt),
            activeIcon: Icon(CupertinoIcons.gear_alt_fill),
            label: '设置',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return const HomeScreen();
          case 1:
            return const HistoryScreen();
          case 2:
            return const SettingsScreen();
          default:
            return const HomeScreen();
        }
      },
    );
  }
}
