import 'package:flutter/material.dart';

/// Breakpoints for responsive design
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double largeDesktop = 1800;

  // Foldable device states
  static const double foldedWidth = 400;
  static const double unfoldedWidth = 800;
}

/// Device type enum
enum DeviceType { mobile, tablet, desktop, foldable }

/// Responsive layout widget that adapts to different screen sizes
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.mobile,
    super.key,
    this.tablet,
    this.desktop,
    this.foldable,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? foldable;

  static DeviceType getDeviceType(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    // Check for foldable device characteristics
    if (_isFoldable(width, height)) {
      return DeviceType.foldable;
    }

    if (width < Breakpoints.mobile) {
      return DeviceType.mobile;
    } else if (width < Breakpoints.tablet) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  static bool _isFoldable(double width, double height) {
    // Detect foldable by aspect ratio and size
    final aspectRatio = width / height;

    // Unfolded state: very wide aspect ratio
    if (aspectRatio > 1.8 && width > Breakpoints.unfoldedWidth) {
      return true;
    }

    // Check for specific foldable dimensions
    // Samsung Galaxy Fold, Surface Duo, etc.
    if ((width > 700 && width < 850) || (height > 700 && height < 850)) {
      if (aspectRatio > 1.5 || aspectRatio < 0.7) {
        return true;
      }
    }

    return false;
  }

  static bool isMobile(BuildContext context) =>
      getDeviceType(context) == DeviceType.mobile;

  static bool isTablet(BuildContext context) =>
      getDeviceType(context) == DeviceType.tablet;

  static bool isDesktop(BuildContext context) =>
      getDeviceType(context) == DeviceType.desktop;

  static bool isFoldable(BuildContext context) =>
      getDeviceType(context) == DeviceType.foldable;

  @override
  Widget build(BuildContext context) {
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.foldable:
        return foldable ?? tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.mobile:
      default:
        return mobile;
    }
  }
}

/// Responsive grid that adapts column count based on screen size
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    required this.children,
    super.key,
    this.minItemWidth = 200,
    this.maxCrossAxisExtent = 400,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double maxCrossAxisExtent;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / minItemWidth).floor().clamp(1, 6);

        return GridView.builder(
          padding: padding,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: runSpacing,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

/// Master-detail layout for tablets and desktops
class MasterDetailLayout extends StatelessWidget {
  const MasterDetailLayout({
    required this.master,
    required this.detail,
    super.key,
    this.masterWidth = 350,
    this.minMasterWidth = 250,
    this.maxMasterWidth = 450,
    this.showDivider = true,
    this.isResizable = true,
  });

  final Widget master;
  final Widget detail;
  final double masterWidth;
  final double minMasterWidth;
  final double maxMasterWidth;
  final bool showDivider;
  final bool isResizable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceType = ResponsiveLayout.getDeviceType(context);

    // On mobile, show only master or detail based on navigation
    if (deviceType == DeviceType.mobile) {
      return master; // Navigation will handle showing detail
    }

    // On tablet/desktop, show side-by-side
    return Row(
      children: [
        // Master pane
        SizedBox(
          width: masterWidth.clamp(minMasterWidth, maxMasterWidth),
          child: master,
        ),

        // Divider
        if (showDivider)
          VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),

        // Detail pane
        Expanded(child: detail),
      ],
    );
  }
}

/// Adaptive navigation that switches between bottom nav, rail, and drawer
class AdaptiveNavigation extends StatelessWidget {
  const AdaptiveNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    super.key,
    this.floatingActionButton,
    this.appBar,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveLayout.getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        return _buildMobileLayout(context);
      case DeviceType.tablet:
      case DeviceType.foldable:
        return _buildTabletLayout(context);
      case DeviceType.desktop:
        return _buildDesktopLayout(context);
    }
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.selected,
            destinations: destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: d.icon,
                    selectedIcon: d.selectedIcon,
                    label: Text(d.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            extended: true,
            destinations: destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: d.icon,
                    selectedIcon: d.selectedIcon,
                    label: Text(d.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Responsive padding that adapts to screen size
class ResponsivePadding extends StatelessWidget {
  const ResponsivePadding({
    required this.child,
    super.key,
    this.mobilePadding = const EdgeInsets.all(16),
    this.tabletPadding = const EdgeInsets.all(24),
    this.desktopPadding = const EdgeInsets.all(32),
  });

  final Widget child;
  final EdgeInsetsGeometry mobilePadding;
  final EdgeInsetsGeometry tabletPadding;
  final EdgeInsetsGeometry desktopPadding;

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveLayout.getDeviceType(context);

    EdgeInsetsGeometry padding;
    switch (deviceType) {
      case DeviceType.desktop:
        padding = desktopPadding;
        break;
      case DeviceType.tablet:
      case DeviceType.foldable:
        padding = tabletPadding;
        break;
      case DeviceType.mobile:
      default:
        padding = mobilePadding;
    }

    return Padding(padding: padding, child: child);
  }
}

/// Responsive text that scales based on screen size
class ResponsiveText extends StatelessWidget {
  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.mobileScale = 1.0,
    this.tabletScale = 1.1,
    this.desktopScale = 1.2,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  final String text;
  final TextStyle? style;
  final double mobileScale;
  final double tabletScale;
  final double desktopScale;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveLayout.getDeviceType(context);

    double scale;
    switch (deviceType) {
      case DeviceType.desktop:
        scale = desktopScale;
        break;
      case DeviceType.tablet:
      case DeviceType.foldable:
        scale = tabletScale;
        break;
      case DeviceType.mobile:
      default:
        scale = mobileScale;
    }

    return Text(
      text,
      style: style,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      textScaleFactor: scale,
    );
  }
}
