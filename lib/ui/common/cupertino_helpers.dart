import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

// ---------------------------------------------------------------------------
// Lightweight auto-dismiss Toast (Overlay-based, no user interaction needed)
// ---------------------------------------------------------------------------

void showCupertinoToast(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(milliseconds: 2500),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _CupertinoToastWidget(
      message: message,
      isError: isError,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );

  overlay.insert(entry);
  Future.delayed(duration, () {
    if (entry.mounted) entry.remove();
  });
}

// ---------------------------------------------------------------------------
// Confirm dialog – use for destructive / critical errors requiring user ack
// ---------------------------------------------------------------------------

void showCupertinoConfirmToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
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

// ---------------------------------------------------------------------------
// Internal Toast widget with slide-in + fade-in/out animation
// ---------------------------------------------------------------------------

class _CupertinoToastWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _CupertinoToastWidget({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_CupertinoToastWidget> createState() => _CupertinoToastWidgetState();
}

class _CupertinoToastWidgetState extends State<_CupertinoToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 12,
      left: 24,
      right: 24,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: CupertinoColors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isError
                        ? AppColors.destructive.withAlpha(220)
                        : AppColors.cardBackground.withAlpha(230),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.isError
                          ? AppColors.destructive.withAlpha(100)
                          : AppColors.separator,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.isError
                            ? CupertinoIcons.exclamationmark_circle_fill
                            : CupertinoIcons.checkmark_circle_fill,
                        color: widget.isError
                            ? CupertinoColors.white
                            : AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: widget.isError
                                ? CupertinoColors.white
                                : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
