/// Feature-flagged factory for creating block widgets
/// 
/// This factory uses feature flags to determine whether to use legacy or
/// refactored block widgets, enabling gradual rollout of new implementations.

import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/models/note_block.dart';
import 'package:duru_notes/ui/widgets/blocks/hierarchical_todo_block_widget.dart';
import 'package:duru_notes/ui/widgets/blocks/todo_block_widget.dart';
import 'package:duru_notes/ui/widgets/blocks/unified_block_editor.dart' as unified;
import 'package:flutter/material.dart';

/// Factory class for creating block widgets based on feature flags
class FeatureFlaggedBlockFactory {
  static final FeatureFlags _featureFlags = FeatureFlags.instance;
  
  /// Create a todo block widget based on feature flags
  static Widget createTodoBlock({
    required NoteBlock block,
    required String? noteId,
    required int position,
    required bool isFocused,
    required Function(NoteBlock) onChanged,
    required Function(bool) onFocusChanged,
    required VoidCallback onNewLine,
    int indentLevel = 0,
    Function(int)? onIndentChanged,
    String? parentTaskId,
  }) {
    if (_featureFlags.useNewBlockEditor) {
      print('[FeatureFlags] ✅ Using HIERARCHICAL TodoBlockWidget');
      
      // Use the new hierarchical todo block with enhanced features
      return HierarchicalTodoBlockWidget(
        block: block,
        noteId: noteId,
        position: position,
        indentLevel: indentLevel,
        isFocused: isFocused,
        onChanged: onChanged,
        onFocusChanged: onFocusChanged,
        onNewLine: onNewLine,
        onIndentChanged: onIndentChanged ?? (_) {},
        parentTaskId: parentTaskId,
      );
    } else {
      print('[FeatureFlags] ⚠️ Using LEGACY TodoBlockWidget');
      
      // Use the legacy todo block
      return TodoBlockWidget(
        block: block,
        noteId: noteId,
        position: position,
        isFocused: isFocused,
        onChanged: onChanged,
        onFocusChanged: onFocusChanged,
        onNewLine: onNewLine,
      );
    }
  }
  
  /// Create a block editor based on feature flags
  static Widget createBlockEditor({
    required String noteId,
    required List<NoteBlock> blocks,
    required Function(List<NoteBlock>) onBlocksChanged,
    ScrollController? scrollController,
    FocusNode? focusNode,
  }) {
    if (_featureFlags.useNewBlockEditor && _featureFlags.useRefactoredComponents) {
      print('[FeatureFlags] ✅ Using UNIFIED BlockEditor');
      
      // Use the unified block editor with all refactored features
      return unified.UnifiedBlockEditor(
        noteId: noteId,
        initialBlocks: blocks,
        onBlocksChanged: onBlocksChanged,
        scrollController: scrollController,
        focusNode: focusNode,
      );
    } else {
      print('[FeatureFlags] ⚠️ Using LEGACY block editor components');
      
      // For now, return a simple column with todo blocks
      // In a real implementation, this would use the legacy block editor
      return Column(
        children: blocks.map((block) {
          final index = blocks.indexOf(block);
          return createTodoBlock(
            block: block,
            noteId: noteId,
            position: index,
            isFocused: false,
            onChanged: (updatedBlock) {
              final newBlocks = List<NoteBlock>.from(blocks);
              newBlocks[index] = updatedBlock;
              onBlocksChanged(newBlocks);
            },
            onFocusChanged: (_) {},
            onNewLine: () {},
          );
        }).toList(),
      );
    }
  }
  
  /// Check if hierarchical features should be enabled
  static bool shouldUseHierarchicalFeatures() {
    return _featureFlags.useNewBlockEditor && _featureFlags.useRefactoredComponents;
  }
  
  /// Check if unified block editor should be used
  static bool shouldUseUnifiedEditor() {
    return _featureFlags.useNewBlockEditor && _featureFlags.useRefactoredComponents;
  }
  
  /// Log current feature flag state for debugging
  static void logFeatureFlagState() {
    print('=== Feature Flag State ===');
    print('useUnifiedReminders: ${_featureFlags.useUnifiedReminders}');
    print('useNewBlockEditor: ${_featureFlags.useNewBlockEditor}');
    print('useRefactoredComponents: ${_featureFlags.useRefactoredComponents}');
    print('useUnifiedPermissionManager: ${_featureFlags.useUnifiedPermissionManager}');
    print('========================');
  }
}

/// Extension on BuildContext for easy feature flag access in widgets
extension FeatureFlaggedBlockContext on BuildContext {
  /// Check if hierarchical todo blocks should be used
  bool get useHierarchicalTodoBlocks => FeatureFlags.instance.useNewBlockEditor;
  
  /// Check if unified block editor should be used
  bool get useUnifiedBlockEditor => FeatureFlags.instance.useNewBlockEditor && FeatureFlags.instance.useRefactoredComponents;
  
  /// Create a todo block widget with feature flag awareness
  Widget createFeatureFlaggedTodoBlock({
    required NoteBlock block,
    required String? noteId,
    required int position,
    required bool isFocused,
    required Function(NoteBlock) onChanged,
    required Function(bool) onFocusChanged,
    required VoidCallback onNewLine,
  }) {
    return FeatureFlaggedBlockFactory.createTodoBlock(
      block: block,
      noteId: noteId,
      position: position,
      isFocused: isFocused,
      onChanged: onChanged,
      onFocusChanged: onFocusChanged,
      onNewLine: onNewLine,
    );
  }
}
