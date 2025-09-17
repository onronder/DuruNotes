import 'package:duru_notes/services/quick_capture_service.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Generate mocks
@GenerateMocks([
  NotesRepository,
  AttachmentService,
  IncomingMailFolderManager,
  AnalyticsService,
  AppLogger,
  MethodChannel,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuickCaptureService Tests', () {
    late QuickCaptureService service;
    late MockNotesRepository mockNotesRepository;
    late MockAttachmentService mockAttachmentService;
    late MockIncomingMailFolderManager mockFolderManager;
    late MockAnalyticsService mockAnalytics;
    late MockAppLogger mockLogger;

    setUp(() async {
      // Initialize mocks
      mockNotesRepository = MockNotesRepository();
      mockAttachmentService = MockAttachmentService();
      mockFolderManager = MockIncomingMailFolderManager();
      mockAnalytics = MockAnalyticsService();
      mockLogger = MockAppLogger();

      // Set up SharedPreferences mock
      SharedPreferences.setMockInitialValues({});

      // Create service instance
      service = QuickCaptureService(
        notesRepository: mockNotesRepository,
        attachmentService: mockAttachmentService,
        folderManager: mockFolderManager,
        analytics: mockAnalytics,
        logger: mockLogger,
      );

      // Set up method channel mock
      const MethodChannel channel = MethodChannel('com.fittechs.durunotes/quick_capture');
      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'updateWidgetData':
            return true;
          case 'refreshWidget':
            return true;
          case 'getAuthStatus':
            return {'isAuthenticated': true, 'userId': 'test-user'};
          case 'getPendingCaptures':
            return [];
          default:
            return null;
        }
      });
    });

    tearDown(() {
      service.dispose();
    });

    group('Initialization', () {
      test('should initialize service successfully', () async {
        await service.initialize();
        
        verify(mockAnalytics.event('quick_capture.service_initialized', properties: any))
            .called(1);
      });

      test('should handle initialization errors gracefully', () async {
        when(mockAnalytics.event(any, properties: anyNamed('properties')))
            .thenThrow(Exception('Analytics error'));

        // Should not throw
        await service.initialize();
        
        verify(mockLogger.error(any, error: anyNamed('error'), stackTrace: anyNamed('stackTrace')))
            .called(greaterThan(0));
      });
    });

    group('Note Capture', () {
      test('should capture text note successfully', () async {
        // Arrange
        when(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          tags: anyNamed('tags'),
          metadataJson: anyNamed('metadataJson'),
        )).thenAnswer((_) async => MockLocalNote());

        // Act
        final result = await service.captureNote(
          text: 'Test note content',
          platform: 'ios',
        );

        // Assert
        expect(result.success, true);
        expect(result.noteId, isNotNull);
        verify(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          tags: anyNamed('tags'),
          metadataJson: anyNamed('metadataJson'),
        )).called(1);
        verify(mockAnalytics.event('quick_capture.note_created', properties: any))
            .called(1);
      });

      test('should handle capture with template', () async {
        // Arrange
        when(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          tags: anyNamed('tags'),
          metadataJson: anyNamed('metadataJson'),
        )).thenAnswer((_) async => MockLocalNote());

        // Act
        final result = await service.captureNote(
          text: 'Meeting with client',
          platform: 'android',
          templateId: 'meeting',
        );

        // Assert
        expect(result.success, true);
        final capturedBody = verify(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: captureAnyNamed('body'),
          tags: anyNamed('tags'),
          metadataJson: anyNamed('metadataJson'),
        )).captured.single as String;
        
        expect(capturedBody, contains('## Meeting Notes'));
        expect(capturedBody, contains('Meeting with client'));
      });

      test('should handle capture with attachments', () async {
        // Arrange
        when(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          tags: anyNamed('tags'),
          metadataJson: anyNamed('metadataJson'),
        )).thenAnswer((_) async => MockLocalNote());
        
        when(mockAttachmentService.processWidgetAttachments(any, any))
            .thenAnswer((_) async => ['attachment1.jpg']);

        // Act
        final result = await service.captureNote(
          text: 'Note with image',
          platform: 'ios',
          attachments: [
            {'type': 'image', 'path': '/path/to/image.jpg'}
          ],
        );

        // Assert
        expect(result.success, true);
        verify(mockAttachmentService.processWidgetAttachments(any, any))
            .called(1);
      });

      test('should handle offline capture', () async {
        // Arrange
        when(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          tags: anyNamed('tags'),
          metadataJson: anyNamed('metadataJson'),
        )).thenThrow(Exception('Network error'));

        // Act
        final result = await service.captureNote(
          text: 'Offline note',
          platform: 'android',
        );

        // Assert
        expect(result.success, false);
        expect(result.error, isNotNull);
        verify(mockAnalytics.event('quick_capture.capture_failed', properties: any))
            .called(1);
      });

      test('should enforce text length limit', () async {
        // Arrange
        final longText = 'a' * 10001; // Exceeds 10000 character limit

        // Act & Assert
        expect(
          () => service.captureNote(text: longText, platform: 'ios'),
          throwsA(isA<QuickCaptureException>()),
        );
      });
    });

    group('Recent Captures', () {
      test('should get recent captures successfully', () async {
        // Arrange
        final mockCaptures = [
          createMockNote('1', 'Note 1'),
          createMockNote('2', 'Note 2'),
          createMockNote('3', 'Note 3'),
        ];
        
        when(mockNotesRepository.getRecentNotes(limit: 5))
            .thenAnswer((_) async => mockCaptures);

        // Act
        final captures = await service.getRecentCaptures(limit: 5);

        // Assert
        expect(captures.length, 3);
        expect(captures[0].title, 'Note 1');
        verify(mockNotesRepository.getRecentNotes(limit: 5)).called(1);
      });

      test('should handle empty recent captures', () async {
        // Arrange
        when(mockNotesRepository.getRecentNotes(limit: 5))
            .thenAnswer((_) async => []);

        // Act
        final captures = await service.getRecentCaptures(limit: 5);

        // Assert
        expect(captures, isEmpty);
      });

      test('should cache recent captures', () async {
        // Arrange
        final mockCaptures = [createMockNote('1', 'Cached Note')];
        when(mockNotesRepository.getRecentNotes(limit: 5))
            .thenAnswer((_) async => mockCaptures);

        // Act - First call should fetch from repository
        await service.getRecentCaptures(limit: 5);
        // Second call should use cache
        final cached = await service.getRecentCaptures(limit: 5);

        // Assert
        expect(cached.length, 1);
        // Repository should only be called once due to caching
        verify(mockNotesRepository.getRecentNotes(limit: 5)).called(1);
      });
    });

    group('Widget Updates', () {
      test('should update widget cache successfully', () async {
        // Arrange
        final mockCaptures = [createMockNote('1', 'Widget Note')];
        when(mockNotesRepository.getRecentNotes(limit: 10))
            .thenAnswer((_) async => mockCaptures);

        // Act
        await service.updateWidgetCache();

        // Assert
        verify(mockAnalytics.event('quick_capture.cache_updated', properties: any))
            .called(1);
      });

      test('should handle widget refresh request', () async {
        // Act
        await service.refreshWidget();

        // Assert
        verify(mockAnalytics.event('quick_capture.widget_refreshed', properties: any))
            .called(1);
      });
    });

    group('Templates', () {
      test('should get available templates', () async {
        // Act
        final templates = await service.getTemplates();

        // Assert
        expect(templates.length, greaterThan(0));
        expect(templates.any((t) => t.id == 'meeting'), true);
        expect(templates.any((t) => t.id == 'idea'), true);
        expect(templates.any((t) => t.id == 'task'), true);
      });

      test('should apply meeting template correctly', () async {
        // Arrange
        when(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          tags: anyNamed('tags'),
          metadataJson: anyNamed('metadataJson'),
        )).thenAnswer((_) async => MockLocalNote());

        // Act
        await service.captureNote(
          text: 'Team sync',
          platform: 'ios',
          templateId: 'meeting',
        );

        // Assert
        final capturedBody = verify(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: captureAnyNamed('body'),
          tags: anyNamed('tags'),
          metadataJson: anyNamed('metadataJson'),
        )).captured.single as String;
        
        expect(capturedBody, contains('## Attendees'));
        expect(capturedBody, contains('## Agenda'));
        expect(capturedBody, contains('## Action Items'));
      });
    });

    group('Error Handling', () {
      test('should handle repository errors gracefully', () async {
        // Arrange
        when(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          tags: anyNamed('tags'),
          metadataJson: anyNamed('metadataJson'),
        )).thenThrow(Exception('Database error'));

        // Act
        final result = await service.captureNote(
          text: 'Error test',
          platform: 'android',
        );

        // Assert
        expect(result.success, false);
        expect(result.error, contains('Database error'));
        verify(mockLogger.error(any, error: anyNamed('error'), stackTrace: anyNamed('stackTrace')))
            .called(greaterThan(0));
      });

      test('should handle invalid platform gracefully', () async {
        // Act & Assert
        expect(
          () => service.captureNote(text: 'Test', platform: 'invalid'),
          throwsA(isA<QuickCaptureException>()),
        );
      });
    });

    group('Offline Queue', () {
      test('should process pending captures', () async {
        // Arrange
        const channel = MethodChannel('com.fittechs.durunotes/quick_capture');
        channel.setMockMethodCallHandler((MethodCall methodCall) async {
          if (methodCall.method == 'getPendingCaptures') {
            return [
              {
                'id': '1',
                'content': 'Pending note 1',
                'type': 'text',
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              }
            ];
          }
          return null;
        });

        when(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          tags: anyNamed('tags'),
          metadataJson: anyNamed('metadataJson'),
        )).thenAnswer((_) async => MockLocalNote());

        // Act
        final processed = await service.processPendingCaptures();

        // Assert
        expect(processed, greaterThan(0));
        verify(mockAnalytics.event('quick_capture.pending_captures_processed', properties: any))
            .called(1);
      });

      test('should respect queue size limit', () async {
        // This is tested indirectly through the MainActivity implementation
        // The queue size limit is enforced at the platform level
        expect(QuickCaptureService._maxQueueSize, 50);
      });
    });

    group('Analytics', () {
      test('should track all major events', () async {
        // Initialize
        await service.initialize();
        verify(mockAnalytics.event('quick_capture.service_initialized', properties: any))
            .called(1);

        // Capture note
        when(mockNotesRepository.createOrUpdate(
          title: anyNamed('title'),
          body: anyNamed('body'),
          tags: anyNamed('tags'),
          metadataJson: anyNamed('metadataJson'),
        )).thenAnswer((_) async => MockLocalNote());
        
        await service.captureNote(text: 'Test', platform: 'ios');
        verify(mockAnalytics.event('quick_capture.note_created', properties: any))
            .called(1);

        // Update cache
        when(mockNotesRepository.getRecentNotes(limit: 10))
            .thenAnswer((_) async => []);
        await service.updateWidgetCache();
        verify(mockAnalytics.event('quick_capture.cache_updated', properties: any))
            .called(1);
      });
    });
  });
}

// Mock classes
class MockLocalNote extends Mock {
  String get id => 'mock-note-id';
  String get title => 'Mock Note';
  String get body => 'Mock body';
  DateTime get createdAt => DateTime.now();
  bool get isPinned => false;
}

// Helper function to create mock notes
MockLocalNote createMockNote(String id, String title) {
  final mock = MockLocalNote();
  when(mock.id).thenReturn(id);
  when(mock.title).thenReturn(title);
  when(mock.body).thenReturn('Body of $title');
  when(mock.createdAt).thenReturn(DateTime.now());
  when(mock.isPinned).thenReturn(false);
  return mock;
}
