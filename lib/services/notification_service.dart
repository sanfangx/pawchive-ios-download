import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Initialize local notification plugin for iOS
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings: initSettings);
    _isInitialized = true;
  }

  /// Request iOS notification permissions
  static Future<bool?> requestPermissions() async {
    return await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Trigger haptic feedback
  static Future<void> triggerHaptic() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Send download completion notification banner
  static Future<void> showDownloadComplete({
    required String title,
    required int totalCount,
    required bool isZip,
  }) async {
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      iOS: iosDetails,
    );

    final actionText = isZip ? '已成功打包为 ZIP 归档' : '已成功存入系统相册';

    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: 'Pawchive 下载完成',
      body: '《$title》共 $totalCount 项媒体 $actionText',
      notificationDetails: platformDetails,
    );
  }
}
