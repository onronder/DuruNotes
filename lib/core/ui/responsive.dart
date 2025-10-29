import 'package:flutter/material.dart';

class AppBreakpoints {
  static bool isCompact(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return size.width < 380 || (size.width < 400 && scale > 1.1);
  }

  static EdgeInsets screenPadding(BuildContext context) {
    return isCompact(context)
        ? const EdgeInsets.symmetric(horizontal: 12)
        : const EdgeInsets.symmetric(horizontal: 16);
  }

  /// Clamp the text scale factor for control UI while keeping content readable.
  /// Uses the modern TextScaler API introduced in Flutter 3.12+.
  static Widget clampControlsTextScale({
    required BuildContext context,
    required Widget child,
  }) {
    final mq = MediaQuery.of(context);
    final maxScale = isCompact(context) ? 1.2 : 1.3;
    final current = mq.textScaler.scale(1.0);
    final clamped = current > maxScale ? maxScale : current;
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(clamped)),
      child: child,
    );
  }
}
