import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Generate mocks for Supabase components
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  Session,
  User,
  AuthResponse,
  PostgrestClient,
  PostgrestQueryBuilder,
  PostgrestFilterBuilder,
  PostgrestBuilder,
])
import 'mock_supabase.mocks.dart';

// Export the generated mocks
export 'mock_supabase.mocks.dart';

/// Helper class to setup common mock behaviors
class MockSupabaseSetup {
  static MockSupabaseClient createMockClient() {
    final mockClient = MockSupabaseClient();
    final mockAuth = MockGoTrueClient();
    final mockPostgrest = MockPostgrestClient();
    
    when(mockClient.auth).thenReturn(mockAuth);
    when(mockClient.from(any)).thenReturn(MockPostgrestQueryBuilder());
    
    // Default to no session
    when(mockAuth.currentSession).thenReturn(null);
    when(mockAuth.currentUser).thenReturn(null);
    
    return mockClient;
  }

  static MockUser createMockUser({
    String id = 'test-user-123',
    String email = 'test@example.com',
  }) {
    final mockUser = MockUser();
    when(mockUser.id).thenReturn(id);
    when(mockUser.email).thenReturn(email);
    when(mockUser.createdAt).thenReturn(DateTime.now().toIso8601String());
    return mockUser;
  }

  static MockSession createMockSession({
    MockUser? user,
    String accessToken = 'mock-access-token',
  }) {
    final mockSession = MockSession();
    final mockUser = user ?? createMockUser();
    
    when(mockSession.user).thenReturn(mockUser);
    when(mockSession.accessToken).thenReturn(accessToken);
    when(mockSession.expiresAt).thenReturn(
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
    );
    
    return mockSession;
  }

  static MockAuthResponse createMockAuthResponse({
    MockUser? user,
    MockSession? session,
  }) {
    final mockResponse = MockAuthResponse();
    final mockUser = user ?? createMockUser();
    final mockSession = session ?? createMockSession(user: mockUser);
    
    when(mockResponse.user).thenReturn(mockUser);
    when(mockResponse.session).thenReturn(mockSession);
    
    return mockResponse;
  }

  static void setupSuccessfulAuth(
    MockGoTrueClient mockAuth, {
    String email = 'test@example.com',
    String password = 'ValidPassword123!',
    MockUser? user,
  }) {
    final mockUser = user ?? createMockUser(email: email);
    final mockResponse = createMockAuthResponse(user: mockUser);
    final mockSession = createMockSession(user: mockUser);
    
    when(mockAuth.signInWithPassword(email: email, password: password))
        .thenAnswer((_) async => mockResponse);
    
    when(mockAuth.signUp(email: email, password: password))
        .thenAnswer((_) async => mockResponse);
    
    // Update session state after successful auth
    when(mockAuth.currentSession).thenReturn(mockSession);
    when(mockAuth.currentUser).thenReturn(mockUser);
  }

  static void setupFailedAuth(
    MockGoTrueClient mockAuth, {
    String email = 'invalid@example.com',
    String password = 'wrongpassword',
    String errorMessage = 'Invalid login credentials',
  }) {
    when(mockAuth.signInWithPassword(email: email, password: password))
        .thenThrow(AuthException(errorMessage));
    
    when(mockAuth.signUp(email: email, password: password))
        .thenThrow(AuthException(errorMessage));
  }

  static void setupSignOut(MockGoTrueClient mockAuth) {
    when(mockAuth.signOut()).thenAnswer((_) async {
      // Clear session state
      when(mockAuth.currentSession).thenReturn(null);
      when(mockAuth.currentUser).thenReturn(null);
    });
  }

  static void setupPostgrestMocks(MockSupabaseClient mockClient) {
    final mockQueryBuilder = MockPostgrestQueryBuilder();
    final mockFilterBuilder = MockPostgrestFilterBuilder();
    final mockBuilder = MockPostgrestBuilder();
    
    when(mockClient.from(any)).thenReturn(mockQueryBuilder);
    
    // Setup common query methods
    when(mockQueryBuilder.select(any)).thenReturn(mockFilterBuilder);
    when(mockQueryBuilder.insert(any)).thenReturn(mockBuilder);
    when(mockQueryBuilder.update(any)).thenReturn(mockFilterBuilder);
    when(mockQueryBuilder.delete()).thenReturn(mockFilterBuilder);
    
    // Setup filter methods
    when(mockFilterBuilder.eq(any, any)).thenReturn(mockFilterBuilder);
    when(mockFilterBuilder.neq(any, any)).thenReturn(mockFilterBuilder);
    when(mockFilterBuilder.gt(any, any)).thenReturn(mockFilterBuilder);
    when(mockFilterBuilder.lt(any, any)).thenReturn(mockFilterBuilder);
    when(mockFilterBuilder.order(any)).thenReturn(mockFilterBuilder);
    when(mockFilterBuilder.limit(any)).thenReturn(mockFilterBuilder);
    
    // Setup execution methods with default empty responses
    when(mockFilterBuilder.execute()).thenAnswer((_) async => []);
    when(mockBuilder.execute()).thenAnswer((_) async => []);
  }

  static void setupNotesTable(MockSupabaseClient mockClient) {
    setupPostgrestMocks(mockClient);
    
    // Mock notes table responses
    final mockNotes = [
      {
        'id': 'note-1',
        'title': 'Test Note',
        'body': 'Test content',
        'updated_at': DateTime.now().toIso8601String(),
        'deleted': false,
      },
    ];
    
    final mockQueryBuilder = MockPostgrestQueryBuilder();
    final mockFilterBuilder = MockPostgrestFilterBuilder();
    
    when(mockClient.from('notes')).thenReturn(mockQueryBuilder);
    when(mockQueryBuilder.select(any)).thenReturn(mockFilterBuilder);
    when(mockFilterBuilder.execute()).thenAnswer((_) async => mockNotes);
  }
}
