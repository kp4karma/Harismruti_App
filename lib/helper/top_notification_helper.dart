import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/utils/app_color.dart';

enum AppNotificationType { info, success, error }

class TopNotification {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show({
    String? title,
    required String message,
    AppNotificationType type = AppNotificationType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Get.overlayContext != null
        ? Overlay.of(Get.overlayContext!)
        : null;
    if (overlay == null || message.trim().isEmpty) return;

    _timer?.cancel();
    _entry?.remove();

    _entry = OverlayEntry(
      builder: (context) => _TopNotificationCard(
        title: title,
        message: message,
        type: type,
        onClose: dismiss,
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(duration, dismiss);
  }

  static void success(String message, {String? title}) {
    show(title: title, message: message, type: AppNotificationType.success);
  }

  static void error(String message, {String? title}) {
    show(title: title, message: message, type: AppNotificationType.error);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _TopNotificationCard extends StatelessWidget {
  final String? title;
  final String message;
  final AppNotificationType type;
  final VoidCallback onClose;

  const _TopNotificationCard({
    required this.title,
    required this.message,
    required this.type,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 10;
    final color = switch (type) {
      AppNotificationType.success => const Color(0xFF167A3C),
      AppNotificationType.error => const Color(0xFFC62828),
      AppNotificationType.info => primaryColor,
    };
    final icon = switch (type) {
      AppNotificationType.success => CupertinoIcons.checkmark_circle_fill,
      AppNotificationType.error => CupertinoIcons.exclamationmark_circle_fill,
      AppNotificationType.info => CupertinoIcons.info_circle_fill,
    };

    return Positioned(
      top: top,
      left: 14,
      right: 14,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -18, end: 0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, offset, child) {
              return Transform.translate(
                offset: Offset(0, offset),
                child: Opacity(opacity: 1 - (offset.abs() / 18), child: child),
              );
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(246),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withAlpha(42)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(24),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((title ?? '').trim().isNotEmpty) ...[
                          Text(
                            title!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF241A17),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.black.withAlpha(176),
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClose,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(
                        CupertinoIcons.xmark,
                        color: Colors.black.withAlpha(120),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
