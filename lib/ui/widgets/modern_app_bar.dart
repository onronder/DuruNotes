import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Modern app bar with gradient background
class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Color> gradientColors;
  final List<Widget>? actions;
  final Widget? leading;
  final IconData? leadingIcon;
  final VoidCallback? onLeadingPressed;

  const ModernAppBar({
    super.key,
    required this.title,
    required this.gradientColors,
    this.actions,
    this.leading,
    this.leadingIcon,
    this.onLeadingPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: leading ??
            (leadingIcon != null
                ? IconButton(
                    icon: Icon(leadingIcon, color: Colors.white),
                    onPressed: onLeadingPressed ?? () => Navigator.of(context).pop(),
                  )
                : null),
        actions: actions,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
    );
  }
}