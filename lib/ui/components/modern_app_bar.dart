import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Modern app bar with gradient and platform-adaptive design
class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ModernAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.bottom,
    this.elevation = 0,
    this.centerTitle,
    this.showGradient = true,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double elevation;
  final bool? centerTitle;
  final bool showGradient;
  final Color? backgroundColor;

  @override
  Size get preferredSize {
    double height = DuruSpacing.appBarHeight;
    // Don't add extra height for subtitle since it fits within the app bar
    if (bottom != null) height += bottom!.preferredSize.height;
    return Size.fromHeight(height);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: showGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  DuruColors.primary,
                  DuruColors.primary.withOpacity(0.8),
                  DuruColors.accent.withOpacity(0.6),
                ],
              )
            : null,
        color: !showGradient
            ? (backgroundColor ?? theme.colorScheme.surface)
            : null,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: DuruSpacing.appBarHeight,
              padding: EdgeInsets.symmetric(horizontal: DuruSpacing.sm),
              child: Row(
                children: [
                  if (leading != null)
                    leading!
                  else if (Navigator.of(context).canPop())
                    IconButton(
                      icon: Icon(
                        DuruPlatform.isIOS
                            ? CupertinoIcons.back
                            : Icons.arrow_back,
                        color: showGradient ? Colors.white : null,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  if (centerTitle != true) SizedBox(width: DuruSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: centerTitle == true
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: DuruPlatform.isIOS ? 17 : 20,
                              fontWeight: FontWeight.w600,
                              color: showGradient
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (subtitle != null)
                          Flexible(
                            child: Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 11,
                                color: showGradient
                                    ? Colors.white.withOpacity(0.8)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}

/// Modern tab bar for app bar bottom
class ModernTabBar extends StatelessWidget implements PreferredSizeWidget {
  const ModernTabBar({
    super.key,
    required this.tabs,
    required this.controller,
    this.isScrollable = false,
    this.onTap,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
  });

  final List<Widget> tabs;
  final TabController controller;
  final bool isScrollable;
  final Function(int)? onTap;
  final Color? indicatorColor;
  final Color? labelColor;
  final Color? unselectedLabelColor;

  @override
  Size get preferredSize => Size.fromHeight(DuruSpacing.tabBarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
      child: TabBar(
        controller: controller,
        tabs: tabs,
        isScrollable: isScrollable,
        onTap: onTap,
        indicatorColor: indicatorColor ?? Colors.white,
        indicatorWeight: 3,
        indicatorPadding: EdgeInsets.symmetric(horizontal: DuruSpacing.md),
        labelColor: labelColor ?? Colors.white,
        unselectedLabelColor:
            unselectedLabelColor ?? Colors.white.withOpacity(0.7),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Modern sliver app bar for scrolling screens
class ModernSliverAppBar extends StatelessWidget {
  const ModernSliverAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.expandedHeight = 200.0,
    this.floating = false,
    this.pinned = true,
    this.snap = false,
    this.actions,
    this.flexibleSpace,
    this.bottom,
    this.heroContent,
  });

  final String title;
  final String? subtitle;
  final double expandedHeight;
  final bool floating;
  final bool pinned;
  final bool snap;
  final List<Widget>? actions;
  final Widget? flexibleSpace;
  final PreferredSizeWidget? bottom;
  final Widget? heroContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: floating,
      pinned: pinned,
      snap: snap,
      elevation: 0,
      backgroundColor: Colors.transparent,
      actions: actions,
      flexibleSpace: flexibleSpace ??
          FlexibleSpaceBar(
            title: pinned
                ? Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    DuruColors.primary,
                    DuruColors.primary.withOpacity(0.8),
                    DuruColors.accent.withOpacity(0.6),
                  ],
                ),
              ),
              child: SafeArea(
                child: heroContent ??
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!pinned) ...[
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (subtitle != null) ...[
                            SizedBox(height: DuruSpacing.sm),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
              ),
            ),
          ),
      bottom: bottom,
    );
  }
}

/// Action button for app bars
class ModernAppBarAction extends StatelessWidget {
  const ModernAppBarAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badge,
    this.isWhite = true,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final String? badge;
  final bool isWhite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget button = IconButton(
      icon: Icon(
        icon,
        color: isWhite ? Colors.white : theme.colorScheme.onSurface,
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      tooltip: tooltip,
    );

    if (badge != null) {
      button = Stack(
        children: [
          button,
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: DuruColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return button;
  }
}