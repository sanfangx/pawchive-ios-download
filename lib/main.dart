import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/notification_service.dart';
import 'ui/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background notification system
  await NotificationService.initialize();

  runApp(
    const ProviderScope(
      child: PawchiveApp(),
    ),
  );
}

class PawchiveApp extends StatelessWidget {
  const PawchiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Pawchive Downloader',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
        barBackgroundColor: CupertinoColors.secondarySystemGroupedBackground,
      ),
      home: HomeScreen(),
    );
  }
}
