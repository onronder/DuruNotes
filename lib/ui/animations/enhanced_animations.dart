import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Collection of enhanced animations and visual effects
///
/// Features:
/// - Spring physics animations
/// - Parallax scrolling
/// - Morphing transitions
/// - Particle effects
/// - Glass morphism
/// - Skeleton loading
/// - Ripple effects

// ============================================================================
// Spring Animations
// ============================================================================

/// Spring-based animation controller
class SpringAnimationController {
  SpringAnimationController({
    required TickerProvider vsync,
    this.stiffness = 180,
    this.damping = 12,
  }) {
    _controller = AnimationController(vsync: vsync);
    _simulation = SpringSimulation(
      SpringDescription(mass: 1, stiffness: stiffness, damping: damping),
      0, // Start
      1, // End
      0, // Velocity
    );
  }

  late final AnimationController _controller;
  late final SpringSimulation _simulation;
  final double stiffness;
  final double damping;

  Animation<double> get animation => _controller;

  void animate({double from = 0, double to = 1}) {
    _controller.animateWith(_simulation);
  }

  void dispose() {
    _controller.dispose();
  }
}

/// Bouncy scale transition
class BouncyScaleTransition extends StatefulWidget {
  const BouncyScaleTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.curve = Curves.elasticOut,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  @override
  State<BouncyScaleTransition> createState() => _BouncyScaleTransitionState();
}

class _BouncyScaleTransitionState extends State<BouncyScaleTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _scaleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: widget.child,
    );
  }
}

// ============================================================================
// Parallax Scrolling
// ============================================================================

/// Parallax scrolling background
class ParallaxBackground extends StatelessWidget {
  const ParallaxBackground({
    super.key,
    required this.scrollController,
    required this.children,
    this.parallaxFactor = 0.5,
  });

  final ScrollController scrollController;
  final List<Widget> children;
  final double parallaxFactor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, child) {
        final offset = scrollController.hasClients
            ? scrollController.offset * parallaxFactor
            : 0.0;

        return Stack(
          children: [
            for (int i = 0; i < children.length; i++)
              Positioned(
                top: -offset * (i + 1) * 0.3,
                left: 0,
                right: 0,
                child: children[i],
              ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// Morphing Transitions
// ============================================================================

/// Hero-like morphing animation between two widgets
class MorphingContainer extends StatefulWidget {
  const MorphingContainer({
    super.key,
    required this.child,
    required this.morphKey,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeInOut,
  });

  final Widget child;
  final String morphKey;
  final Duration duration;
  final Curve curve;

  @override
  State<MorphingContainer> createState() => _MorphingContainerState();
}

class _MorphingContainerState extends State<MorphingContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_animation.value * math.pi),
          alignment: Alignment.center,
          child: _animation.value < 0.5
              ? widget.child
              : Transform(
                  transform: Matrix4.identity()..rotateY(math.pi),
                  alignment: Alignment.center,
                  child: widget.child,
                ),
        );
      },
    );
  }
}

// ============================================================================
// Glass Morphism
// ============================================================================

/// Glass morphism effect container
class GlassMorphicContainer extends StatelessWidget {
  const GlassMorphicContainer({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.2,
    this.borderRadius = 20,
    this.border,
    this.gradient,
    this.shadowColor,
  });

  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final Border? border;
  final Gradient? gradient;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: shadowColor ?? colorScheme.shadow.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              gradient:
                  gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.surface.withValues(alpha: opacity),
                      colorScheme.surface.withValues(alpha: opacity * 0.5),
                    ],
                  ),
              borderRadius: BorderRadius.circular(borderRadius),
              border:
                  border ??
                  Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Skeleton Loading
// ============================================================================

/// Skeleton loading placeholder with shimmer effect
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    this.width,
    this.height = 20,
    this.borderRadius = 4,
    this.baseColor,
    this.highlightColor,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(
      begin: -1,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor =
        widget.baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final highlightColor = widget.highlightColor ?? theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Ripple Effects
// ============================================================================

/// Custom ripple effect with configurable properties
class CustomRipple extends StatefulWidget {
  const CustomRipple({
    super.key,
    required this.child,
    this.color,
    this.duration = const Duration(milliseconds: 600),
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final Duration duration;
  final VoidCallback? onTap;

  @override
  State<CustomRipple> createState() => _CustomRippleState();
}

class _CustomRippleState extends State<CustomRipple>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _scaleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(begin: 0.5, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
    });
    _controller.forward(from: 0);
    HapticFeedback.selectionClick();
  }

  void _handleTap() {
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rippleColor = widget.color ?? theme.colorScheme.primary;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTap: _handleTap,
      child: Stack(
        children: [
          widget.child,
          if (_tapPosition != null)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Positioned.fill(
                  child: CustomPaint(
                    painter: RipplePainter(
                      center: _tapPosition!,
                      radius: _scaleAnimation.value * 200,
                      color: rippleColor.withValues(
                        alpha: _fadeAnimation.value,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Custom painter for ripple effect
class RipplePainter extends CustomPainter {
  const RipplePainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  final Offset center;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (!center.dx.isFinite ||
        !center.dy.isFinite ||
        !radius.isFinite ||
        radius <= 0) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.color != color;
  }
}

// ============================================================================
// Staggered Animations
// ============================================================================

/// Staggered animation list for sequential animations
class StaggeredAnimationList extends StatefulWidget {
  const StaggeredAnimationList({
    super.key,
    required this.children,
    this.delay = const Duration(milliseconds: 100),
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOut,
  });

  final List<Widget> children;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  @override
  State<StaggeredAnimationList> createState() => _StaggeredAnimationListState();
}

class _StaggeredAnimationListState extends State<StaggeredAnimationList>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    _createAnimations();
    _startAnimations();
  }

  void _createAnimations() {
    for (int i = 0; i < widget.children.length; i++) {
      final controller = AnimationController(
        duration: widget.duration,
        vsync: this,
      );

      final animation = Tween<double>(
        begin: 0,
        end: 1,
      ).animate(CurvedAnimation(parent: controller, curve: widget.curve));

      _controllers.add(controller);
      _animations.add(animation);
    }
  }

  void _startAnimations() async {
    for (int i = 0; i < _controllers.length; i++) {
      await Future<void>.delayed(widget.delay);
      if (mounted) {
        _controllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < widget.children.length; i++)
          AnimatedBuilder(
            animation: _animations[i],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - _animations[i].value)),
                child: Opacity(opacity: _animations[i].value, child: child),
              );
            },
            child: widget.children[i],
          ),
      ],
    );
  }
}

// ============================================================================
// Floating Action Button with Menu
// ============================================================================

/// Expandable FAB with menu items
class ExpandableFab extends StatefulWidget {
  const ExpandableFab({
    super.key,
    required this.distance,
    required this.children,
  });

  final double distance;
  final List<Widget> children;

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }

    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.distance * 2,
      height: widget.distance * 2,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          ..._buildExpandingActionButtons(),
          _buildTapToCloseFab(),
          _buildMainFab(),
        ],
      ),
    );
  }

  List<Widget> _buildExpandingActionButtons() {
    final children = <Widget>[];
    final count = widget.children.length;
    final angleStep = math.pi / (count + 1);

    for (int i = 0; i < count; i++) {
      final angle = angleStep * (i + 1);

      children.add(
        AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            return Positioned(
              left:
                  widget.distance -
                  (widget.distance * math.cos(angle) * _expandAnimation.value),
              top:
                  widget.distance -
                  (widget.distance * math.sin(angle) * _expandAnimation.value),
              child: Transform.scale(
                scale: _expandAnimation.value,
                child: Opacity(opacity: _expandAnimation.value, child: child),
              ),
            );
          },
          child: widget.children[i],
        ),
      );
    }

    return children;
  }

  Widget _buildTapToCloseFab() {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return IgnorePointer(
          ignoring: !_isExpanded,
          child: GestureDetector(
            onTap: _toggle,
            child: Container(
              width: widget.distance * 3,
              height: widget.distance * 3,
              color: Colors.transparent,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainFab() {
    return FloatingActionButton(
      heroTag: 'animated_fab_main', // PRODUCTION FIX: Unique hero tag
      onPressed: _toggle,
      child: AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _expandAnimation.value * math.pi / 4,
            child: Icon(_isExpanded ? Icons.close : Icons.add),
          );
        },
      ),
    );
  }
}
