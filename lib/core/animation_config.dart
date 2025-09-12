import 'package:flutter/material.dart';

/// Standardized animation configurations for consistent UI motion
class AnimationConfig {
  AnimationConfig._();
  
  /// Standard duration for most UI animations (140ms)
  static const Duration standard = Duration(milliseconds: 140);
  
  /// Fast duration for quick transitions (100ms)
  static const Duration fast = Duration(milliseconds: 100);
  
  /// Slow duration for complex animations (200ms)
  static const Duration slow = Duration(milliseconds: 200);
  
  /// Extra slow for page transitions (300ms)
  static const Duration pageTransition = Duration(milliseconds: 300);
  
  /// Standard curve for most animations
  static const Curve standardCurve = Curves.fastOutSlowIn;
  
  /// Curve for appearing elements
  static const Curve enterCurve = Curves.easeOut;
  
  /// Curve for disappearing elements
  static const Curve exitCurve = Curves.easeIn;
  
  /// Curve for continuous animations
  static const Curve smoothCurve = Curves.easeInOut;
  
  /// Create a standard AnimatedSwitcher
  static AnimatedSwitcher createSwitcher({
    required Widget child,
    Duration? duration,
  }) {
    return AnimatedSwitcher(
      duration: duration ?? standard,
      switchInCurve: enterCurve,
      switchOutCurve: exitCurve,
      child: child,
    );
  }
  
  /// Create a standard page route transition
  static PageRouteBuilder<T> createPageRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      settings: settings,
      transitionDuration: pageTransition,
      reverseTransitionDuration: pageTransition,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.02);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: standardCurve),
        );
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
}
