// lib/ui/widgets/saved_search_chips.dart
import 'package:flutter/material.dart';
import 'package:duru_notes/search/saved_search_registry.dart';

typedef SavedSearchTap = void Function(SavedSearchPreset preset);
typedef TagCountProvider = Future<Map<String, int>> Function();
typedef FolderCountProvider = Future<int> Function(String folderName);

class SavedSearchChips extends StatefulWidget {
  final SavedSearchTap onTap;
  final EdgeInsets padding;
  final bool hideZeroCount;
  final TagCountProvider? getTagCounts;
  final FolderCountProvider? getFolderCount;

  const SavedSearchChips({
    super.key,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    this.hideZeroCount = false,
    this.getTagCounts,
    this.getFolderCount,
  });

  @override
  State<SavedSearchChips> createState() => _SavedSearchChipsState();
}

class _SavedSearchChipsState extends State<SavedSearchChips> {
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

    if (visiblePresets.isEmpty && !_loading) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: widget.padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_loading && visiblePresets.isEmpty)
              const SizedBox(
                height: 32,
                width: 32,
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              ...visiblePresets.map((preset) {
                final count = _getCountForPreset(preset);
                final showBadge = count != null && count > 0;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(preset.icon, size: 18),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(preset.label),
                        if (showBadge) ...[
                          const SizedBox(width: 6),
                          _buildBadge(count),
                        ],
                      ],
                    ),
                    onPressed: () => widget.onTap(preset),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}