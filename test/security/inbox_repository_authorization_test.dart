import 'dart:async';

import 'package:duru_notes/domain/entities/inbox_item.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/inbox_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'inbox_repository_authorization_test.mocks.dart';

const _tableName = 'clipper_inbox';
const _emailSourceType = 'email_in';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<SupabaseQueryBuilder>(),
  MockSpec<PostgrestFilterBuilder<dynamic>>(),
  MockSpec<PostgrestFilterBuilder<List<Map<String, dynamic>>>>(
    as: #SelectFilterBuilderMock,
  ),
  MockSpec<PostgrestTransformBuilder<Map<String, dynamic>?>>(
    as: #SingleResultBuilderMock,
  ),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late InboxRepository repository;
  late _SupabaseHarness harness;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    when(mockClient.auth).thenReturn(mockAuth);
    when(mockUser.id).thenReturn('user-a');

    harness = _SupabaseHarness(client: mockClient);
    repository = InboxRepository(client: mockClient);
  });

  group('InboxRepository authorization', () {
    test(
      'getById returns item for current user and scopes by userId',
      () async {
        when(mockAuth.currentUser).thenReturn(mockUser);
        final singleBuilder = SingleResultBuilderMock();
        _stubFuture<Map<String, dynamic>?>(
          filter: singleBuilder,
          future: Future.value(null),
        );
        when(
          harness.selectFilter.maybeSingle(),
        ).thenAnswer((_) => singleBuilder);

        final item = await repository.getById('item-1');

        expect(item, isNull);
        verify(harness.selectFilter.eq('id', 'item-1')).called(1);
        verify(harness.selectFilter.eq('user_id', 'user-a')).called(1);
        verify(harness.selectFilter.maybeSingle()).called(1);
      },
    );

    test('getById returns null when unauthenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final result = await repository.getById('item-1');

      expect(result, isNull);
      verifyNever(mockClient.from(any));
    });

    test('getUnprocessed filters by userId', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      harness.stubSelectRows(const []);

      final items = await repository.getUnprocessed();

      expect(items, isEmpty);
      verify(harness.selectFilter.eq('user_id', 'user-a')).called(1);
      verify(
        harness.selectFilter.filter('converted_to_note_id', 'is', 'null'),
      ).called(1);
      verify(
        harness.selectFilter.order('created_at', ascending: false),
      ).called(1);
    });

    test('create assigns current userId to payload', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      harness.stubMutationSuccess();

      final item = domain.InboxItem(
        id: 'new-item',
        userId: 'user-b',
        sourceType: _emailSourceType,
        payload: {'subject': 'Hello'},
        createdAt: DateTime.utc(2025, 10, 29),
      );

      final created = await repository.create(item);

      expect(created.userId, 'user-a');
      expect(harness.lastInsertPayload?['user_id'], 'user-a');
      verify(harness.query.insert(any)).called(1);
    });

    test('create throws when not authenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final item = domain.InboxItem(
        id: 'new-item',
        userId: 'user-a',
        sourceType: _emailSourceType,
        payload: const {},
        createdAt: DateTime.utc(2025, 10, 29),
      );

      await expectLater(repository.create(item), throwsStateError);
      verifyNever(mockClient.from(any));
    });

    test('update enforces user isolation', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      harness.stubMutationSuccess();

      final item = domain.InboxItem(
        id: 'item-1',
        userId: 'user-a',
        sourceType: _emailSourceType,
        payload: const {},
        createdAt: DateTime.utc(2025, 10, 29),
      );

      await repository.update(item);

      verify(harness.mutationFilter.eq('id', 'item-1')).called(1);
      verify(harness.mutationFilter.eq('user_id', 'user-a')).called(1);
    });

    test('markAsProcessed scopes update to owning user', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      harness.stubMutationSuccess();

      await repository.markAsProcessed('item-1', noteId: 'note-1');

      verify(harness.mutationFilter.eq('id', 'item-1')).called(1);
      verify(harness.mutationFilter.eq('user_id', 'user-a')).called(1);
    });

    test('delete uses user filter', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      harness.stubMutationSuccess();

      await repository.delete('item-1');

      verify(harness.mutationFilter.eq('id', 'item-1')).called(1);
      verify(harness.mutationFilter.eq('user_id', 'user-a')).called(1);
    });

    test('deleteProcessed limits to current user', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      harness.stubMutationSuccess();

      await repository.deleteProcessed();

      verify(harness.mutationFilter.eq('user_id', 'user-a')).called(1);
      verify(
        harness.mutationFilter.not('converted_to_note_id', 'is', 'null'),
      ).called(1);
    });

    test('getUnprocessedCount only counts current user items', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      harness.stubSelectRows(const []);

      final count = await repository.getUnprocessedCount();

      expect(count, 0);
      verify(harness.selectFilter.eq('user_id', 'user-a')).called(1);
      verify(
        harness.selectFilter.filter('converted_to_note_id', 'is', 'null'),
      ).called(1);
    });

    test('getStatsBySourceType aggregates per user', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      harness.stubSelectRows(const []);

      final stats = await repository.getStatsBySourceType();

      expect(stats, isEmpty);
      verify(harness.selectFilter.eq('user_id', 'user-a')).called(1);
    });

    test('cleanupOldItems only touches current user data', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      harness.stubMutationSuccess();

      await repository.cleanupOldItems(daysToKeep: 30);

      verify(harness.mutationFilter.eq('user_id', 'user-a')).called(1);
      verify(harness.mutationFilter.lt('created_at', any)).called(1);
    });
  });
}

class _SupabaseHarness {
  _SupabaseHarness({required MockSupabaseClient client})
    : _client = client,
      query = MockSupabaseQueryBuilder(),
      selectFilter = SelectFilterBuilderMock(),
      mutationFilter = MockPostgrestFilterBuilder() {
    _configure();
  }

  final MockSupabaseClient _client;
  final MockSupabaseQueryBuilder query;
  final SelectFilterBuilderMock selectFilter;
  final MockPostgrestFilterBuilder mutationFilter;

  Map<String, dynamic>? lastInsertPayload;

  void _configure() {
    when(_client.from(_tableName)).thenAnswer((_) => query);

    when(query.select()).thenAnswer((_) => selectFilter);
    when(query.select(any)).thenAnswer((_) => selectFilter);
    when(query.update(any)).thenAnswer((_) => mutationFilter);
    when(query.delete()).thenAnswer((_) => mutationFilter);
    when(query.insert(any)).thenAnswer((invocation) {
      final payload =
          invocation.positionalArguments.first as Map<dynamic, dynamic>;
      lastInsertPayload = payload.cast<String, dynamic>();
      return mutationFilter;
    });
    _stubSelectChaining(selectFilter);
    _stubMutationChaining(mutationFilter);
  }

  void stubSelectRows(List<Map<String, dynamic>> rows) {
    _stubFuture<List<Map<String, dynamic>>>(
      filter: selectFilter,
      future: Future.value(rows),
    );
  }

  void stubMutationSuccess() {
    _stubFuture<dynamic>(
      filter: mutationFilter,
      future: Future.value(<dynamic>[]),
    );
  }
}

void _stubSelectChaining(SelectFilterBuilderMock filter) {
  when(filter.eq(any, any)).thenAnswer((_) => filter);
  when(filter.filter(any, any, any)).thenAnswer((_) => filter);
  when(
    filter.order(any, ascending: anyNamed('ascending')),
  ).thenAnswer((_) => filter);
  when(filter.not(any, any, any)).thenAnswer((_) => filter);
  when(filter.gte(any, any)).thenAnswer((_) => filter);
  when(filter.lte(any, any)).thenAnswer((_) => filter);
  when(filter.lt(any, any)).thenAnswer((_) => filter);
}

void _stubMutationChaining(MockPostgrestFilterBuilder filter) {
  when(filter.eq(any, any)).thenAnswer((_) => filter);
  when(filter.filter(any, any, any)).thenAnswer((_) => filter);
  when(filter.not(any, any, any)).thenAnswer((_) => filter);
  when(filter.gte(any, any)).thenAnswer((_) => filter);
  when(filter.lte(any, any)).thenAnswer((_) => filter);
  when(filter.lt(any, any)).thenAnswer((_) => filter);
}

void _stubFuture<T>({required dynamic filter, required Future<T> future}) {
  when(filter.then(any, onError: anyNamed('onError'))).thenAnswer((invocation) {
    final onValue =
        invocation.positionalArguments[0] as dynamic Function(dynamic);
    final onError = invocation.namedArguments[#onError] as Function?;
    return future.then(onValue, onError: onError);
  });
  when(filter.catchError(any, test: anyNamed('test'))).thenAnswer((invocation) {
    final handler = invocation.positionalArguments[0] as Function;
    final test = invocation.namedArguments[#test] as bool Function(Object)?;
    return future.catchError(handler, test: test);
  });
  when(filter.whenComplete(any)).thenAnswer((invocation) {
    final action =
        invocation.positionalArguments[0] as FutureOr<void> Function();
    return future.whenComplete(action);
  });
  when(filter.timeout(any, onTimeout: anyNamed('onTimeout'))).thenAnswer((
    invocation,
  ) {
    final duration = invocation.positionalArguments[0] as Duration;
    final onTimeout =
        invocation.namedArguments[#onTimeout] as FutureOr<T> Function()?;
    return future.timeout(duration, onTimeout: onTimeout);
  });
  when(filter.asStream()).thenAnswer((_) => future.asStream());
}
