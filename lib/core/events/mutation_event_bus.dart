import 'dart:async';

/// Types of entities that can emit mutation events.
enum MutationEntity { note, task, reminder }

/// Describes the mutation that occurred.
enum MutationKind { created, updated, deleted }

/// Simple payload used to broadcast local mutations across the app.
class MutationEvent {
  const MutationEvent({
    required this.entity,
    required this.kind,
    required this.entityId,
    this.parentId,
    this.traceId,
    this.metadata = const <String, dynamic>{},
  });

  final MutationEntity entity;
  final MutationKind kind;
  final String entityId;
  final String? parentId;
  final String? traceId;
  final Map<String, dynamic> metadata;
}

/// Lightweight mutation bus for coordinating cache refreshes and diagnostics.
class MutationEventBus {
  MutationEventBus._();

  static final MutationEventBus instance = MutationEventBus._();

  final StreamController<MutationEvent> _controller =
      StreamController<MutationEvent>.broadcast();

  Stream<MutationEvent> get stream => _controller.stream;

  void emit(MutationEvent event) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(event);
  }

  void emitNote({
    required MutationKind kind,
    required String noteId,
    String? traceId,
    Map<String, dynamic>? metadata,
  }) {
    emit(
      MutationEvent(
        entity: MutationEntity.note,
        kind: kind,
        entityId: noteId,
        traceId: traceId,
        metadata: metadata ?? const <String, dynamic>{},
      ),
    );
  }

  void emitTask({
    required MutationKind kind,
    required String taskId,
    String? noteId,
    String? traceId,
    Map<String, dynamic>? metadata,
  }) {
    emit(
      MutationEvent(
        entity: MutationEntity.task,
        kind: kind,
        entityId: taskId,
        parentId: noteId,
        traceId: traceId,
        metadata: metadata ?? const <String, dynamic>{},
      ),
    );
  }

  void emitReminder({
    required MutationKind kind,
    required String reminderId,
    String? noteId,
    String? traceId,
    Map<String, dynamic>? metadata,
  }) {
    emit(
      MutationEvent(
        entity: MutationEntity.reminder,
        kind: kind,
        entityId: reminderId,
        parentId: noteId,
        traceId: traceId,
        metadata: metadata ?? const <String, dynamic>{},
      ),
    );
  }
}
