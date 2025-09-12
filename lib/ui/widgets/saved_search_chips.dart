// lib/ui/widgets/saved_search_chips.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/search/saved_search_registry.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/core/haptic_utils.dart';
import 'package:duru_notes/core/animation_config.dart';
import 'package:duru_notes/core/accessibility_utils.dart';
import 'package:duru_notes/core/debounce_utils.dart';

typedef SavedSearchTap = void Function(SavedSearchPreset preset);
typedef CustomSearchTap = void Function(SavedSearch search);
typedef TagCountProvider = Future<Map<String, int>> Function();
typedef FolderCountProvider = Future<int> Function(String folderName);

class SavedSearchChips extends ConsumerStatefulWidget {
  final SavedSearchTap onTap;
  final CustomSearchTap? onCustomSearchTap;
  final EdgeInsets padding;
  final bool hideZeroCount;
  final TagCountProvider? getTagCounts;
  final FolderCountProvider? getFolderCount;
  final Widget? trailingWidget;

  const SavedSearchChips({
    super.key,
    required this.onTap,
    this.onCustomSearchTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    this.hideZeroCount = false,
    this.getTagCounts,
    this.getFolderCount,
    this.trailingWidget,
  });

  @override
  ConsumerState<SavedSearchChips> createState() => _SavedSearchChipsState();
}

class _SavedSearchChipsState extends ConsumerState<SavedSearchChips> {
  Map<String, int> _counts = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void didUpdateWidget(SavedSearchChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload counts if providers changed
    if (oldWidget.getTagCounts != widget.getTagCounts ||
        oldWidget.getFolderCount != widget.getFolderCount) {
      _loadCounts();
    }
  }

  Future<void> _loadCounts() async {
    if (widget.getTagCounts == null && widget.getFolderCount == null) {
      return; // No providers, no counts to load
    }
    
    setState(() => _loading = true);
    try {
      final counts = <String, int>{};
      
      // Load tag counts
      if (widget.getTagCounts != null) {
        final tagCounts = await widget.getTagCounts!();
        counts.addAll(tagCounts);
      }
      
      // Load folder count for Inbox
      if (widget.getFolderCount != null) {
        for (final preset in SavedSearchRegistry.presets) {
          if (preset.folderName != null) {
            final count = await widget.getFolderCount!(preset.folderName!);
            counts['folder:${preset.folderName}'] = count;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _counts = counts;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading counts: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  int? _getCountForPreset(SavedSearchPreset preset) {
    if (preset.tag != null) {
      return _counts[preset.tag];
    } else if (preset.folderName != null) {
      return _counts['folder:${preset.folderName}'];
    }
    return null;
  }

  bool _shouldShowPreset(SavedSearchPreset preset) {
    if (!widget.hideZeroCount) return true;
    
    // Always show Inbox (folder-based, not tag-based)
    if (preset.folderName != null) return true;
    
    // Check count
    final count = _getCountForPreset(preset);
    return count == null || count > 0;
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      constraints: const BoxConstraints(minWidth: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visiblePresets = SavedSearchRegistry.presets
        .where(_shouldShowPreset)
        .toList();
    
    // Watch custom saved searches from database
    final customSearchesAsync = ref.watch(savedSearchesStreamProvider);

    if (visiblePresets.isEmpty && !_loading && 
        customSearchesAsync.maybeWhen(data: (s) => s.isEmpty, orElse: () => true)) {
      return const SizedBox.shrink();
    }

    // Build all chips list
    final List<Widget> allChips = [];
    
    // Loading indicator
    if (_loading && visiblePresets.isEmpty) {
      allChips.add(
        const SizedBox(
          height: AccessibilityUtils.minTouchTarget,
          width: AccessibilityUtils.minTouchTarget,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    } else {
      // Preset chips
      allChips.addAll(
        visiblePresets.map((preset) {
          final count = _getCountForPreset(preset);
          final showBadge = count != null && count > 0;
          
          return _buildPresetChip(preset, count, showBadge);
        }),
      );
      
      // Custom saved searches
      allChips.addAll(
        customSearchesAsync.maybeWhen(
          data: (searches) => searches.map((search) {
            return _buildCustomSearchChip(search);
          }).toList(),
          orElse: () => [],
        ),
      );
    }
    
    // Add trailing widget if provided
    if (widget.trailingWidget != null) {
      allChips.add(widget.trailingWidget!);
    }
    
    if (allChips.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Debounce UI updates to animation frame
    DebounceUtils.debounceFrame('saved_search_chips_update', () {
      if (mounted) setState(() {});
    });
    
    return SizedBox(
      height: AccessibilityUtils.minTouchTarget + 8, // 44dp + padding
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        physics: const ClampingScrollPhysics(),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: allChips.length,
        itemBuilder: (context, index) => AnimatedSwitcher(
          duration: AnimationConfig.standard,
          switchInCurve: AnimationConfig.enterCurve,
          switchOutCurve: AnimationConfig.exitCurve,
          child: allChips[index],
        ),
      ),
    );
  }
  
  Widget _buildPresetChip(SavedSearchPreset preset, int? count, bool showBadge) {
    final semanticLabel = count != null && count > 0
        ? '${preset.label}, $count items'
        : preset.label;
    
    return AccessibilityUtils.semanticChip(
      label: semanticLabel,
      selected: false,
      onTap: () => widget.onTap(preset),
      child: ActionChip(
        avatar: Icon(preset.icon, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(preset.label),
            if (showBadge) ...[
              const SizedBox(width: 6),
              _buildBadge(count!),
            ],
          ],
        ),
        onPressed: () {
          HapticUtils.selection();
          widget.onTap(preset);
        },
      ),
    );
  }
  
  Widget _buildCustomSearchChip(SavedSearch search) {
    return AccessibilityUtils.semanticChip(
      label: search.name,
      selected: false,
      onTap: () {
        if (widget.onCustomSearchTap != null) {
          widget.onCustomSearchTap!(search);
        }
      },
      child: ActionChip(
        avatar: Icon(
          search.isPinned ? Icons.bookmark : Icons.bookmark_border,
          size: 18,
        ),
        label: Text(search.name),
        onPressed: () {
          HapticUtils.selection();
          if (widget.onCustomSearchTap != null) {
            widget.onCustomSearchTap!(search);
          }
        },
      ),
    );
  }
}