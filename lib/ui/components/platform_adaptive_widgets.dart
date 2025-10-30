/// Platform-Adaptive UI Components for Duru Notes
///
/// Components that adapt to platform conventions while maintaining
/// brand consistency across iOS, Android, Web, Mac, and Windows.
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../theme/cross_platform_tokens.dart';

/// Platform-adaptive button that feels native on each platform
class DuruButton extends StatelessWidget {
  const DuruButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = DuruButtonVariant.primary,
    this.size = DuruButtonSize.medium,
    this.isLoading = false,
    this.isEnabled = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final DuruButtonVariant variant;
  final DuruButtonSize size;
  final bool isLoading;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    if (DuruPlatform.isIOS) {
      return _buildCupertinoButton(context);
    } else {
      return _buildMaterialButton(context);
    }
  }

  Widget _buildCupertinoButton(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;

    switch (variant) {
      case DuruButtonVariant.primary:
        backgroundColor = DuruColors.primary;
        foregroundColor = Colors.white;
        break;
      case DuruButtonVariant.secondary:
        backgroundColor = DuruColors.accent;
        foregroundColor = Colors.white;
        break;
      case DuruButtonVariant.outlined:
        backgroundColor = Colors.transparent;
        foregroundColor = DuruColors.primary;
        break;
      case DuruButtonVariant.text:
        backgroundColor = Colors.transparent;
        foregroundColor = DuruColors.primary;
        break;
    }

    return CupertinoButton(
      onPressed: isEnabled && !isLoading ? onPressed : null,
      color:
          variant != DuruButtonVariant.text &&
              variant != DuruButtonVariant.outlined
          ? backgroundColor
          : null,
      borderRadius: DuruBorderRadius.button(),
      padding: _getPadding(),
      child: _buildButtonContent(context, foregroundColor),
    );
  }

  Widget _buildMaterialButton(BuildContext context) {
    switch (variant) {
      case DuruButtonVariant.primary:
        return FilledButton(
          onPressed: isEnabled && !isLoading ? onPressed : null,
          style: _getMaterialButtonStyle(context),
          child: _buildButtonContent(context, Colors.white),
        );
      case DuruButtonVariant.secondary:
        return FilledButton.tonal(
          onPressed: isEnabled && !isLoading ? onPressed : null,
          style: _getMaterialButtonStyle(context),
          child: _buildButtonContent(context, DuruColors.primary),
        );
      case DuruButtonVariant.outlined:
        return OutlinedButton(
          onPressed: isEnabled && !isLoading ? onPressed : null,
          style: _getMaterialButtonStyle(context),
          child: _buildButtonContent(context, DuruColors.primary),
        );
      case DuruButtonVariant.text:
        return TextButton(
          onPressed: isEnabled && !isLoading ? onPressed : null,
          style: _getMaterialButtonStyle(context),
          child: _buildButtonContent(context, DuruColors.primary),
        );
    }
  }

  ButtonStyle _getMaterialButtonStyle(BuildContext context) {
    return ButtonStyle(
      minimumSize: WidgetStateProperty.all(DuruTouchTargets.buttonSize),
      padding: WidgetStateProperty.all(_getPadding()),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: DuruBorderRadius.button()),
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case DuruButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: DuruSpacing.sm,
          vertical: DuruSpacing.xs,
        );
      case DuruButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: DuruSpacing.md,
          vertical: DuruSpacing.sm,
        );
      case DuruButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: DuruSpacing.lg,
          vertical: DuruSpacing.md,
        );
    }
  }

  Widget _buildButtonContent(BuildContext context, Color textColor) {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return DefaultTextStyle(
      style: DuruTypography.bodyLarge(
        context,
      ).copyWith(color: textColor, fontWeight: FontWeight.w500),
      child: child,
    );
  }
}

enum DuruButtonVariant { primary, secondary, outlined, text }

enum DuruButtonSize { small, medium, large }

/// Platform-adaptive card with proper elevation and styling
class DuruCard extends StatelessWidget {
  const DuruCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding,
    this.elevation,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? elevation;

  @override
  Widget build(BuildContext context) {
    final cardElevation = elevation ?? DuruElevation.card;
    final cardPadding = padding ?? EdgeInsets.all(DuruSpacing.cardPadding);

    if (DuruPlatform.isDesktop) {
      // Desktop uses subtle borders instead of shadows
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: DuruBorderRadius.card(),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: DuruBorderRadius.card(),
            child: Padding(padding: cardPadding, child: child),
          ),
        ),
      );
    }

    return Card(
      margin: margin,
      elevation: cardElevation,
      shape: RoundedRectangleBorder(borderRadius: DuruBorderRadius.card()),
      child: InkWell(
        onTap: onTap,
        borderRadius: DuruBorderRadius.card(),
        child: Padding(padding: cardPadding, child: child),
      ),
    );
  }
}

/// Platform-adaptive text field with proper styling
class DuruTextField extends StatelessWidget {
  const DuruTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.prefixIcon,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final bool enabled;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final Widget? prefixIcon;

  @override
  Widget build(BuildContext context) {
    if (DuruPlatform.isIOS) {
      return _buildCupertinoTextField(context);
    } else {
      return _buildMaterialTextField(context);
    }
  }

  Widget _buildCupertinoTextField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: DuruTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
          SizedBox(height: DuruSpacing.xs),
        ],
        CupertinoTextField(
          controller: controller,
          placeholder: hintText,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          obscureText: obscureText,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: errorText != null
                  ? DuruColors.error
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: DuruBorderRadius.input(),
          ),
          padding: EdgeInsets.all(DuruSpacing.md),
          suffix: suffixIcon,
          prefix: prefixIcon,
        ),
        if (errorText != null) ...[
          SizedBox(height: DuruSpacing.xs),
          Text(
            errorText!,
            style: DuruTypography.bodyLarge(
              context,
            ).copyWith(color: DuruColors.error, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildMaterialTextField(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      obscureText: obscureText,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: DuruTypography.bodyLarge(context),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        errorText: errorText,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
        border: OutlineInputBorder(borderRadius: DuruBorderRadius.input()),
        contentPadding: EdgeInsets.all(DuruSpacing.md),
      ),
    );
  }
}

/// Platform-adaptive icon button with proper touch targets
class DuruIconButton extends StatelessWidget {
  const DuruIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.size,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.onSurface;
    final iconSize = size ?? 24.0;

    Widget button;

    if (DuruPlatform.isIOS) {
      button = CupertinoButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        minimumSize: Size(DuruTouchTargets.minSize, DuruTouchTargets.minSize),
        child: Icon(icon, color: iconColor, size: iconSize),
      );
    } else {
      button = IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: iconColor,
        iconSize: iconSize,
        constraints: BoxConstraints(
          minWidth: DuruTouchTargets.minSize,
          minHeight: DuruTouchTargets.minSize,
        ),
      );
    }

    // Ensure WCAG-compliant touch target
    return SizedBox(
      width: DuruTouchTargets.minSize,
      height: DuruTouchTargets.minSize,
      child: tooltip != null
          ? Tooltip(message: tooltip!, child: button)
          : button,
    );
  }
}

/// Platform-adaptive list tile with proper spacing and touch targets
class DuruListTile extends StatelessWidget {
  const DuruListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final minHeight = DuruTouchTargets.listItemMinHeight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: DuruSpacing.screenPadding,
              vertical: DuruSpacing.itemSpacing,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 16), // DuruSpacing.md
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (title != null)
                        DefaultTextStyle(
                          style: DuruTypography.bodyLarge(context),
                          child: title!,
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8), // DuruSpacing.xs
                        DefaultTextStyle(
                          style: DuruTypography.bodyLarge(context).copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          child: subtitle!,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 16), // DuruSpacing.md
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Platform-adaptive app bar
class DuruAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DuruAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.centerTitle,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final bool? centerTitle;

  @override
  Widget build(BuildContext context) {
    if (DuruPlatform.isIOS) {
      return CupertinoNavigationBar(
        middle: title,
        leading: leading,
        trailing: actions?.isNotEmpty == true
            ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
            : null,
        backgroundColor:
            backgroundColor ??
            DuruColors.getNavigationColor(context).withValues(alpha: 0.9),
        border: null,
      );
    }

    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: DuruElevation.appBar,
      centerTitle: centerTitle ?? DuruPlatform.isIOS,
      scrolledUnderElevation: 0,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(DuruSpacing.appBarHeight);
}

/// Platform-adaptive loading indicator
class DuruLoadingIndicator extends StatelessWidget {
  const DuruLoadingIndicator({super.key, this.size = 24.0, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final indicatorColor = color ?? DuruColors.primary;

    if (DuruPlatform.isIOS) {
      return CupertinoActivityIndicator(
        radius: size / 2,
        color: indicatorColor,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
      ),
    );
  }
}

/// Platform-adaptive divider
class DuruDivider extends StatelessWidget {
  const DuruDivider({super.key, this.height, this.thickness, this.color});

  final double? height;
  final double? thickness;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height ?? DuruSpacing.md,
      thickness: thickness ?? 1,
      color:
          color ?? Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
    );
  }
}
