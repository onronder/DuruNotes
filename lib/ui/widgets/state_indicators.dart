import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/cross_platform_tokens.dart';

/// Modern empty state widget with gradient design
class ModernEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Color>? gradientColors;

  const ModernEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = gradientColors ??
        [
          DuruColors.primary,
          DuruColors.accent,
        ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with gradient background
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors[0].withValues(alpha: 0.15),
                    colors[1].withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: colors[0].withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24.0),

            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),

            // Subtitle
            if (subtitle != null) ...[
              const SizedBox(height: 8.0),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: (isDark ? Colors.white : Colors.black87)
                      .withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Action button
            if (action != null) ...[
              const SizedBox(height: 32.0),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Modern loading state with animated gradient
class ModernLoadingState extends StatefulWidget {
  final String? message;
  final bool showProgress;
  final double? progress;

  const ModernLoadingState({
    super.key,
    this.message,
    this.showProgress = false,
    this.progress,
  });

  @override
  State<ModernLoadingState> createState() => _ModernLoadingStateState();
}

class _ModernLoadingStateState extends State<ModernLoadingState>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loading indicator
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  DuruColors.primary.withValues(alpha: 0.1),
                  DuruColors.accent.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rotating gradient ring
                RotationTransition(
                  turns: _rotationAnimation,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          DuruColors.primary,
                          DuruColors.accent,
                          DuruColors.primary,
                        ],
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),

                // Progress indicator
                if (widget.showProgress && widget.progress != null)
                  Text(
                    '${(widget.progress! * 100).round()}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: DuruColors.primary,
                    ),
                  )
                else
                  Icon(
                    CupertinoIcons.arrow_2_circlepath,
                    color: DuruColors.primary,
                    size: 24,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24.0),

          // Loading message
          if (widget.message != null)
            Text(
              widget.message!,
              style: TextStyle(
                fontSize: 14,
                color: (isDark ? Colors.white : Colors.black87)
                    .withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),

          // Progress bar
          if (widget.showProgress && widget.progress != null) ...[
            const SizedBox(height: 24.0),
            Container(
              width: 200,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: widget.progress!.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [DuruColors.primary, DuruColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modern error state with retry action
class ModernErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final String? details;
  final VoidCallback? onRetry;
  final IconData? icon;
  final bool isWarning;

  const ModernErrorState({
    super.key,
    required this.title,
    this.message,
    this.details,
    this.onRetry,
    this.icon,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final errorColor = isWarning ? Colors.orange : Colors.red;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: errorColor.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: errorColor.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      errorColor.withValues(alpha: 0.15),
                      errorColor.withValues(alpha: 0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon ??
                      (isWarning
                          ? CupertinoIcons.exclamationmark_triangle_fill
                          : CupertinoIcons.xmark_circle_fill),
                  size: 40,
                  color: errorColor,
                ),
              ),
              const SizedBox(height: 24.0),

              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              // Message
              if (message != null) ...[
                const SizedBox(height: 8.0),
                Text(
                  message!,
                  style: TextStyle(
                    fontSize: 14,
                    color: (isDark ? Colors.white : Colors.black87)
                        .withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              // Details (expandable)
              if (details != null) ...[
                const SizedBox(height: 16.0),
                ExpansionTile(
                  title: Text(
                    'Technical Details',
                    style: TextStyle(
                      fontSize: 12,
                      color: (isDark ? Colors.white : Colors.black87)
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        details!,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: (isDark ? Colors.white : Colors.black87)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Retry button
              if (onRetry != null) ...[
                const SizedBox(height: 32.0),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(CupertinoIcons.refresh, size: 18),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: errorColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer loading effect for content placeholders
class ModernShimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ModernShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ModernShimmer> createState() => _ModernShimmerState();
}

class _ModernShimmerState extends State<ModernShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _shimmerAnimation.value, -0.3),
              end: Alignment(1.0 + _shimmerAnimation.value, 0.3),
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.05),
                    ]
                  : [
                      Colors.grey.withValues(alpha: 0.2),
                      Colors.grey.withValues(alpha: 0.3),
                      Colors.grey.withValues(alpha: 0.2),
                    ],
            ),
          ),
        );
      },
    );
  }
}

/// Content loading skeleton
class ModernContentSkeleton extends StatelessWidget {
  final int itemCount;

  const ModernContentSkeleton({
    super.key,
    this.itemCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title skeleton
              ModernShimmer(
                width: 200,
                height: 20,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8.0),
              // Content skeleton
              ModernShimmer(
                width: double.infinity,
                height: 14,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              ModernShimmer(
                width: double.infinity,
                height: 14,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              ModernShimmer(
                width: 150,
                height: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      },
    );
  }
}