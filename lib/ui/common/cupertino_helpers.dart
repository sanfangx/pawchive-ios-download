import 'package:flutter/cupertino.dart';

class AppColors {
  static const primary = CupertinoColors.activeBlue;
  static const background = CupertinoColors.systemGroupedBackground;
  static const cardBackground = CupertinoColors.secondarySystemGroupedBackground;
  static const textPrimary = CupertinoColors.label;
  static const textSecondary = CupertinoColors.secondaryLabel;
  static const separator = CupertinoColors.separator;
  static const success = CupertinoColors.activeGreen;
  static const destructive = CupertinoColors.destructiveRed;
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
