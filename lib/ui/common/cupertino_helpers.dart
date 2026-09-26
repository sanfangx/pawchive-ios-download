import 'package:flutter/cupertino.dart';

class AppColors {
  static const primary = Color(0xFF0A84FF); // iOS System Blue in Dark Mode
  static const background = Color(0xFF000000); // True OLED Black Scaffold
  static const barBackground = Color(0xFF121214); // Navigation / Tab Bar Dark
  static const cardBackground = Color(0xFF1C1C1E); // Elevated Dark Card / Tile
  static const secondaryCard = Color(0xFF2C2C2E); // Input / Secondary surface
  static const tertiaryCard = Color(0xFF3A3A3C); // Tertiary surface
  static const textPrimary = Color(0xFFFFFFFF); // Pure White
  static const textSecondary = Color(0xFF8E8E93); // Secondary Label
  static const separator = Color(0xFF38383A); // Separator
  static const success = Color(0xFF30D158); // iOS Green
  static const destructive = Color(0xFFFF453A); // iOS Red
}

void showCupertinoToast(BuildContext context, String message, {bool isError = false}) {
  showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(isError ? '提示' : '操作成功'),
      content: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Text(message),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('好的'),
        ),
      ],
    ),
  );
}
