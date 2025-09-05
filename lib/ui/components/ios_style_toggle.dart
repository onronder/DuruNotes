import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Production-grade iOS-style toggle switch
/// Optimized for both iOS and Android with proper accessibility
class IOSStyleToggle extends StatefulWidget {
  const IOSStyleToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.width = 50,
    this.height = 28,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  final bool value;
  final Function(bool) onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final double width;
  final double height;
  final Duration animationDuration;

  @override
  State<IOSStyleToggle> createState() => _IOSStyleToggleState();
}

class _IOSStyleToggleState extends State<IOSStyleToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _positionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    if (widget.value) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(IOSStyleToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Calculate colors based on current state
    final backgroundColor = widget.value
        ? (widget.activeColor ?? 
            (isDark ? const Color(0xFF667eea) : theme.colorScheme.primary))
        : (widget.inactiveColor ?? 
            (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300));
    
    return Semantics(
      label: widget.value ? 'Enabled' : 'Disabled',
      value: widget.value.toString(),
      onTap: _handleTap,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final thumbPosition = _positionAnimation.value * 
                (widget.width - widget.height);
            
            return AnimatedContainer(
              duration: widget.animationDuration,
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(widget.height / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Thumb
                  AnimatedPositioned(
                    duration: widget.animationDuration,
                    curve: Curves.easeInOut,
                    left: thumbPosition + 3,
                    top: 3,
                    child: AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: widget.height - 6,
                            height: widget.height - 6,
                            decoration: BoxDecoration(
                              color: widget.thumbColor ?? Colors.white,
                              borderRadius: BorderRadius.circular(
                                (widget.height - 6) / 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Enhanced settings list tile with iOS-style toggle
class SettingsToggleTile extends StatelessWidget {
  const SettingsToggleTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
    this.activeColor,
    this.inactiveColor,
  });

  final String title;
  final bool value;
  final Function(bool) onChanged;
  final String? subtitle;
  final Widget? leading;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.02)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: leading,
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isDark 
                ? Colors.white.withOpacity(0.9)
                : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark 
                      ? Colors.white.withOpacity(0.6)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: IOSStyleToggle(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
        ),
        onTap: () => onChanged(!value),
      ),
    );
  }
}

/// Settings section with glassmorphic design
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
  });

  final String title;
  final List<Widget> children;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: isDark 
                      ? const Color(0xFF667eea)
                      : theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isDark 
                      ? Colors.white.withOpacity(0.6)
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        
        // Section content
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withOpacity(0.03)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: isDark
                ? Border.all(
                    color: Colors.white.withOpacity(0.05),
                    width: 0.5,
                  )
                : Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                    width: 0.5,
                  ),
            boxShadow: isDark 
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            children: children.asMap().entries.map((entry) {
              final index = entry.key;
              final child = entry.value;
              
              return Column(
                children: [
                  child,
                  if (index < children.length - 1)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDark 
                          ? Colors.white.withOpacity(0.05)
                          : theme.colorScheme.outlineVariant.withOpacity(0.3),
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
