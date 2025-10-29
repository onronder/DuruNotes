import 'package:duru_notes/domain/entities/task.dart' as domain;

/// Task hierarchy node for tree operations with domain entities
///
/// This is the domain-layer version of TaskHierarchyNode, using domain.Task
/// instead of drift NoteTask models. This ensures UI components work with
/// decrypted, domain-layer entities.
class DomainTaskHierarchyNode {
  DomainTaskHierarchyNode({
    required this.task,
    required this.children,
    this.parent,
  });

  final domain.Task task;
  final List<DomainTaskHierarchyNode> children;
  DomainTaskHierarchyNode? parent;

  /// Get all descendants (children, grandchildren, etc.)
  List<DomainTaskHierarchyNode> getAllDescendants() {
    final descendants = <DomainTaskHierarchyNode>[];
    for (final child in children) {
      descendants.add(child);
      descendants.addAll(child.getAllDescendants());
    }
    return descendants;
  }

  /// Check if this node is an ancestor of another node
  bool isAncestorOf(DomainTaskHierarchyNode other) {
    DomainTaskHierarchyNode? current = other.parent;
    while (current != null) {
      if (current.task.id == task.id) return true;
      current = current.parent;
    }
    return false;
  }

  /// Get path from root to this node
  List<DomainTaskHierarchyNode> getPathFromRoot() {
    final path = <DomainTaskHierarchyNode>[];
    DomainTaskHierarchyNode? current = this;

    while (current != null) {
      path.insert(0, current);
      current = current.parent;
    }

    return path;
  }
}
