# Quick Capture Widget - Production-Grade Implementation Plan

## Executive Summary
Full-stack implementation of a Quick Capture home screen widget for Duru Notes across Flutter, iOS (WidgetKit), Android (App Widget), with Supabase backend integration. The widget enables users to quickly capture notes directly from their home screen without opening the main app.

## Architecture Overview

### System Components
1. **Flutter Service Layer**: `QuickCaptureService` orchestrating note creation
2. **Platform Channels**: Bidirectional communication between Flutter and native widgets
3. **iOS WidgetKit**: SwiftUI-based widget with App Group storage
4. **Android App Widget**: RemoteViews-based widget with PendingIntent handling
5. **Backend Services**: Supabase RPC functions and metadata indexing
6. **Analytics & Monitoring**: Event tracking and performance monitoring

### Data Flow
```
User Tap on Widget → Native Platform Code → Platform Channel → 
Flutter Service → NotesRepository → Supabase → Sync → Widget Refresh
```

## Phase 1: Backend Infrastructure (Days 1-2)

### 1.1 Database Migration
```sql
-- File: supabase/migrations/20250120_quick_capture_widget.sql

-- Add index for quick capture notes filtering
CREATE INDEX IF NOT EXISTS idx_notes_metadata_source 
ON public.notes ((encrypted_metadata->>'source')) 
WHERE encrypted_metadata IS NOT NULL;

-- Add index for widget-tagged notes
CREATE INDEX IF NOT EXISTS idx_notes_metadata_widget 
ON public.notes ((encrypted_metadata->>'source')) 
WHERE encrypted_metadata->>'source' = 'widget';

-- Create function for retrieving recent widget captures
CREATE OR REPLACE FUNCTION public.rpc_get_quick_capture_summaries(
    p_user_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    snippet TEXT,
    created_at TIMESTAMPTZ,
    metadata JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Use current user if not specified
    IF p_user_id IS NULL THEN
        p_user_id := auth.uid();
    END IF;
    
    -- Check RLS
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    
    RETURN QUERY
    SELECT 
        n.id,
        n.title,
        LEFT(n.body, 100) as snippet,
        n.created_at,
        n.encrypted_metadata::jsonb
    FROM public.notes n
    WHERE 
        n.user_id = p_user_id
        AND n.deleted = false
        AND n.encrypted_metadata->>'source' = 'widget'
    ORDER BY n.created_at DESC
    LIMIT p_limit;
END;
$$;

-- Add RLS policy for the RPC function
GRANT EXECUTE ON FUNCTION public.rpc_get_quick_capture_summaries TO authenticated;

-- Performance optimization: partial index
CREATE INDEX IF NOT EXISTS idx_notes_widget_recent 
ON public.notes (user_id, created_at DESC) 
WHERE deleted = false 
  AND encrypted_metadata->>'source' = 'widget';
```

### 1.2 Edge Function for Widget Data
```typescript
// File: supabase/functions/quick-capture-widget/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

interface QuickCaptureRequest {
  text: string
  templateId?: string
  attachments?: string[]
  platform: 'ios' | 'android'
}

serve(async (req) => {
  try {
    // CORS headers for web widget support
    if (req.method === 'OPTIONS') {
      return new Response('ok', {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      })
    }

    // Auth check
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'No authorization header' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const body: QuickCaptureRequest = await req.json()
    
    // Rate limiting check
    const rateLimitKey = `widget_capture:${user.id}`
    const { data: rateLimitData } = await supabase
      .from('rate_limits')
      .select('count, window_start')
      .eq('key', rateLimitKey)
      .single()
    
    const now = new Date()
    const windowStart = rateLimitData?.window_start 
      ? new Date(rateLimitData.window_start) 
      : new Date(now.getTime() - 60000) // 1 minute window
    
    if (rateLimitData && now.getTime() - windowStart.getTime() < 60000) {
      if (rateLimitData.count >= 10) { // Max 10 captures per minute
        return new Response(JSON.stringify({ error: 'Rate limit exceeded' }), {
          status: 429,
          headers: { 'Content-Type': 'application/json' },
        })
      }
    }

    // Create note with metadata
    const noteData = {
      user_id: user.id,
      title: `Quick Capture - ${new Date().toLocaleString()}`,
      body: body.text,
      encrypted_metadata: JSON.stringify({
        source: 'widget',
        entry_point: body.platform,
        template_id: body.templateId,
        widget_version: '1.0.0',
        capture_timestamp: new Date().toISOString(),
      }),
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }

    const { data: note, error: noteError } = await supabase
      .from('notes')
      .insert(noteData)
      .select()
      .single()

    if (noteError) {
      console.error('Note creation error:', noteError)
      return new Response(JSON.stringify({ error: 'Failed to create note' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Add widget tag
    await supabase.from('note_tags').insert({
      note_id: note.id,
      tag: 'widget',
      user_id: user.id,
    })

    // Update rate limit
    await supabase.from('rate_limits').upsert({
      key: rateLimitKey,
      count: (rateLimitData?.count ?? 0) + 1,
      window_start: windowStart.toISOString(),
    })

    // Track analytics event
    await supabase.from('analytics_events').insert({
      user_id: user.id,
      event_type: 'quick_capture.widget_note_created',
      properties: {
        platform: body.platform,
        text_length: body.text.length,
        has_template: !!body.templateId,
        has_attachments: !!(body.attachments?.length),
      },
      created_at: new Date().toISOString(),
    })

    return new Response(
      JSON.stringify({ 
        success: true, 
        noteId: note.id,
        message: 'Note created successfully' 
      }),
      { 
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    console.error('Widget capture error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
})
```

## Phase 2: Flutter Service Layer (Days 2-3)

### 2.1 Quick Capture Service Implementation
```dart
// File: lib/services/quick_capture_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/models/note.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/services/attachment_service.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling quick capture from home screen widgets
class QuickCaptureService {
  QuickCaptureService({
    required NotesRepository notesRepository,
    required AttachmentService attachmentService,
    required IncomingMailFolderManager folderManager,
    required AnalyticsService analytics,
    required AppLogger logger,
  }) : _notesRepository = notesRepository,
       _attachmentService = attachmentService,
       _folderManager = folderManager,
       _analytics = analytics,
       _logger = logger;

  final NotesRepository _notesRepository;
  final AttachmentService _attachmentService;
  final IncomingMailFolderManager _folderManager;
  final AnalyticsService _analytics;
  final AppLogger _logger;

  static const String _cacheKey = 'quick_capture_cache';
  static const String _pendingCapturesKey = 'pending_quick_captures';
  static const int _maxCacheSize = 10;
  static const int _maxRetries = 3;

  /// Platform channel for widget communication
  static const MethodChannel _channel = MethodChannel('com.fittechs.durunotes/quick_capture');

  /// Initialize the service and set up platform channel handlers
  Future<void> initialize() async {
    _logger.info('Initializing QuickCaptureService');
    
    _channel.setMethodCallHandler(_handleMethodCall);
    
    // Process any pending captures from offline mode
    await _processPendingCaptures();
    
    // Update widget cache with recent captures
    await updateWidgetCache();
    
    _analytics.event('quick_capture.service_initialized');
  }

  /// Handle method calls from native widgets
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    _logger.debug('Received method call: ${call.method}', data: call.arguments);
    
    try {
      switch (call.method) {
        case 'captureNote':
          return await _handleCaptureNote(call.arguments);
        case 'getRecentCaptures':
          return await _handleGetRecentCaptures(call.arguments);
        case 'getTemplates':
          return await _handleGetTemplates();
        case 'checkAuthStatus':
          return await _handleCheckAuthStatus();
        default:
          throw PlatformException(
            code: 'UNKNOWN_METHOD',
            message: 'Unknown method: ${call.method}',
          );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error handling method call: ${call.method}',
        error: e,
        stackTrace: stackTrace,
      );
      
      _analytics.trackError(
        'quick_capture.method_call_error',
        context: call.method,
        properties: {'error': e.toString()},
      );
      
      throw PlatformException(
        code: 'HANDLER_ERROR',
        message: e.toString(),
        details: stackTrace.toString(),
      );
    }
  }

  /// Create a note from widget capture
  Future<Map<String, dynamic>> _handleCaptureNote(Map<dynamic, dynamic> args) async {
    final text = args['text'] as String?;
    final templateId = args['templateId'] as String?;
    final attachments = (args['attachments'] as List?)?.cast<String>();
    final platform = args['platform'] as String? ?? 'unknown';
    
    if (text == null || text.isEmpty) {
      throw ArgumentError('Text cannot be empty');
    }
    
    _analytics.startTiming('quick_capture.create_note');
    
    try {
      // Check authentication
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        // Store for later when user logs in
        await _storePendingCapture(text, templateId, attachments, platform);
        return {
          'success': false,
          'error': 'NOT_AUTHENTICATED',
          'message': 'Please sign in to capture notes',
        };
      }
      
      // Apply template if specified
      String finalText = text;
      String? title;
      if (templateId != null) {
        final template = await _getTemplate(templateId);
        if (template != null) {
          finalText = template['content']!.replaceAll('{{text}}', text);
          title = template['title'];
        }
      }
      
      // Create note with metadata
      final metadata = <String, dynamic>{
        'source': 'widget',
        'entry_point': platform,
        'widget_version': '1.0.0',
        'capture_timestamp': DateTime.now().toIso8601String(),
      };
      
      if (templateId != null) {
        metadata['template_id'] = templateId;
      }
      
      // Create the note
      final note = await _notesRepository.createOrUpdate(
        title: title ?? 'Quick Capture - ${DateTime.now().toLocal()}',
        body: finalText,
        tags: {'widget', 'quick-capture'},
        metadataJson: metadata,
      );
      
      if (note == null) {
        throw Exception('Failed to create note');
      }
      
      // Add to Inbox folder
      try {
        await _folderManager.addNoteToIncomingMail(note.id);
      } catch (e) {
        _logger.warning('Failed to add note to Inbox folder', data: {'error': e.toString()});
      }
      
      // Handle attachments if present
      if (attachments != null && attachments.isNotEmpty) {
        await _processAttachments(note.id, attachments);
      }
      
      // Update widget cache
      await updateWidgetCache();
      
      _analytics.endTiming(
        'quick_capture.create_note',
        properties: {
          'success': true,
          'platform': platform,
          'has_template': templateId != null,
          'has_attachments': attachments?.isNotEmpty ?? false,
          'text_length': text.length,
        },
      );
      
      _analytics.event('quick_capture.widget_note_created', properties: {
        'platform': platform,
        'note_id': note.id,
      });
      
      return {
        'success': true,
        'noteId': note.id,
        'message': 'Note created successfully',
      };
      
    } catch (e) {
      _analytics.endTiming(
        'quick_capture.create_note',
        properties: {
          'success': false,
          'error': e.toString(),
        },
      );
      
      // Store for retry if network issue
      if (_isNetworkError(e)) {
        await _storePendingCapture(text, templateId, attachments, platform);
        return {
          'success': false,
          'error': 'OFFLINE',
          'message': 'Note saved offline and will sync when connected',
        };
      }
      
      rethrow;
    }
  }

  /// Get recent quick captures for widget display
  Future<List<Map<String, dynamic>>> _handleGetRecentCaptures(Map<dynamic, dynamic> args) async {
    final limit = args['limit'] as int? ?? 5;
    
    try {
      // Try to get from cache first for faster response
      final cached = await _getCachedCaptures();
      if (cached.isNotEmpty) {
        return cached.take(limit).toList();
      }
      
      // Fetch from database
      final notes = await _notesRepository.getRecentlyViewedNotes(limit: limit);
      
      final captures = notes.map((note) {
        return {
          'id': note.id,
          'title': note.title,
          'snippet': note.body.length > 100 
            ? '${note.body.substring(0, 100)}...' 
            : note.body,
          'createdAt': note.updatedAt.toIso8601String(),
        };
      }).toList();
      
      // Update cache
      await _updateCache(captures);
      
      return captures;
      
    } catch (e) {
      _logger.error('Failed to get recent captures', error: e);
      return [];
    }
  }

  /// Get available templates for quick capture
  Future<List<Map<String, String>>> _handleGetTemplates() async {
    // TODO: Implement template system
    return [
      {
        'id': 'meeting',
        'name': 'Meeting Notes',
        'icon': '📝',
        'content': '## Meeting Notes\\n\\nDate: {{date}}\\nAttendees:\\n\\nAgenda:\\n- {{text}}\\n\\nAction Items:\\n- [ ] ',
      },
      {
        'id': 'todo',
        'name': 'Quick Todo',
        'icon': '✅',
        'content': '## Todo\\n\\n- [ ] {{text}}\\n\\nDue: ',
      },
      {
        'id': 'idea',
        'name': 'Idea',
        'icon': '💡',
        'content': '## Idea\\n\\n{{text}}\\n\\nNext Steps:\\n1. ',
      },
    ];
  }

  /// Check authentication status
  Future<Map<String, dynamic>> _handleCheckAuthStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    return {
      'isAuthenticated': user != null,
      'userId': user?.id,
      'email': user?.email,
    };
  }

  /// Update widget cache with recent captures
  Future<void> updateWidgetCache() async {
    try {
      final notes = await _notesRepository.getRecentlyViewedNotes(limit: _maxCacheSize);
      
      final captures = notes.map((note) {
        final metadata = note.encryptedMetadata != null 
          ? jsonDecode(note.encryptedMetadata!) 
          : {};
        
        return {
          'id': note.id,
          'title': note.title,
          'snippet': note.body.length > 100 
            ? '${note.body.substring(0, 100)}...' 
            : note.body,
          'createdAt': note.updatedAt.toIso8601String(),
          'isWidget': metadata['source'] == 'widget',
        };
      }).toList();
      
      await _updateCache(captures);
      
      // Notify native widgets to refresh
      await _notifyWidgetRefresh();
      
    } catch (e) {
      _logger.error('Failed to update widget cache', error: e);
    }
  }

  /// Store a pending capture for later sync
  Future<void> _storePendingCapture(
    String text,
    String? templateId,
    List<String>? attachments,
    String platform,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingCapturesKey) ?? [];
    
    final capture = jsonEncode({
      'text': text,
      'templateId': templateId,
      'attachments': attachments,
      'platform': platform,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    pending.add(capture);
    await prefs.setStringList(_pendingCapturesKey, pending);
    
    _logger.info('Stored pending capture for later sync');
  }

  /// Process pending captures after reconnection
  Future<void> _processPendingCaptures() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingCapturesKey) ?? [];
    
    if (pending.isEmpty) return;
    
    _logger.info('Processing ${pending.length} pending captures');
    
    final failed = <String>[];
    
    for (final captureJson in pending) {
      try {
        final capture = jsonDecode(captureJson) as Map<String, dynamic>;
        
        await _handleCaptureNote({
          'text': capture['text'],
          'templateId': capture['templateId'],
          'attachments': capture['attachments'],
          'platform': capture['platform'],
        });
        
      } catch (e) {
        _logger.error('Failed to process pending capture', error: e);
        failed.add(captureJson);
      }
    }
    
    // Keep failed captures for next retry
    await prefs.setStringList(_pendingCapturesKey, failed);
    
    if (failed.isEmpty) {
      _analytics.event('quick_capture.pending_captures_processed', properties: {
        'count': pending.length,
      });
    }
  }

  /// Process attachments for a note
  Future<void> _processAttachments(String noteId, List<String> attachmentPaths) async {
    // TODO: Implement attachment processing
    _logger.info('Processing ${attachmentPaths.length} attachments for note $noteId');
  }

  /// Get cached captures
  Future<List<Map<String, dynamic>>> _getCachedCaptures() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    
    if (cached == null) return [];
    
    try {
      final list = jsonDecode(cached) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      _logger.error('Failed to decode cache', error: e);
      return [];
    }
  }

  /// Update cache with new captures
  Future<void> _updateCache(List<Map<String, dynamic>> captures) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(captures));
  }

  /// Notify native widgets to refresh
  Future<void> _notifyWidgetRefresh() async {
    try {
      await _channel.invokeMethod('refreshWidget');
    } catch (e) {
      _logger.debug('Widget refresh notification failed', data: {'error': e.toString()});
    }
  }

  /// Get a template by ID
  Future<Map<String, String>?> _getTemplate(String templateId) async {
    final templates = await _handleGetTemplates();
    return templates.firstWhere(
      (t) => t['id'] == templateId,
      orElse: () => {},
    );
  }

  /// Check if error is network-related
  bool _isNetworkError(dynamic error) {
    return error.toString().contains('network') ||
           error.toString().contains('connection') ||
           error.toString().contains('offline');
  }

  /// Dispose the service
  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}
```

### 2.2 Provider Registration
```dart
// Add to lib/providers.dart

/// Quick Capture Service provider
final quickCaptureServiceProvider = Provider<QuickCaptureService>((ref) {
  // Only create if authenticated
  ref.watch(authStateChangesProvider);
  final client = Supabase.instance.client;
  
  if (client.auth.currentUser == null) {
    throw StateError('QuickCaptureService requested without authentication');
  }
  
  final service = QuickCaptureService(
    notesRepository: ref.watch(notesRepositoryProvider),
    attachmentService: ref.watch(attachmentServiceProvider),
    folderManager: ref.watch(incomingMailFolderManagerProvider),
    analytics: ref.watch(analyticsProvider),
    logger: ref.watch(loggerProvider),
  );
  
  // Initialize the service
  service.initialize().catchError((error) {
    ref.watch(loggerProvider).error(
      'Failed to initialize QuickCaptureService',
      error: error,
    );
  });
  
  ref.onDispose(service.dispose);
  
  return service;
});
```

## Phase 3: iOS WidgetKit Implementation (Days 3-4)

### 3.1 Widget Target Setup
```swift
// File: ios/QuickCaptureWidget/QuickCaptureWidget.swift

import WidgetKit
import SwiftUI
import Intents

// MARK: - Widget Entry
struct QuickCaptureEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let recentCaptures: [QuickCapture]
    let isAuthenticated: Bool
}

// MARK: - Quick Capture Model
struct QuickCapture: Codable, Identifiable {
    let id: String
    let title: String
    let snippet: String
    let createdAt: Date
    let isWidget: Bool
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Widget Provider
struct QuickCaptureProvider: IntentTimelineProvider {
    let sharedDefaults = UserDefaults(suiteName: "group.com.fittechs.duruNotesApp")
    
    func placeholder(in context: Context) -> QuickCaptureEntry {
        QuickCaptureEntry(
            date: Date(),
            configuration: ConfigurationIntent(),
            recentCaptures: QuickCapture.placeholders,
            isAuthenticated: true
        )
    }
    
    func getSnapshot(
        for configuration: ConfigurationIntent,
        in context: Context,
        completion: @escaping (QuickCaptureEntry) -> Void
    ) {
        let entry = QuickCaptureEntry(
            date: Date(),
            configuration: configuration,
            recentCaptures: loadRecentCaptures(),
            isAuthenticated: checkAuthStatus()
        )
        completion(entry)
    }
    
    func getTimeline(
        for configuration: ConfigurationIntent,
        in context: Context,
        completion: @escaping (Timeline<QuickCaptureEntry>) -> Void
    ) {
        var entries: [QuickCaptureEntry] = []
        
        let currentDate = Date()
        let recentCaptures = loadRecentCaptures()
        let isAuthenticated = checkAuthStatus()
        
        // Create timeline entries for the next hour
        for hourOffset in 0..<6 {
            let entryDate = Calendar.current.date(
                byAdding: .minute,
                value: hourOffset * 10,
                to: currentDate
            )!
            
            let entry = QuickCaptureEntry(
                date: entryDate,
                configuration: configuration,
                recentCaptures: recentCaptures,
                isAuthenticated: isAuthenticated
            )
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func loadRecentCaptures() -> [QuickCapture] {
        guard let data = sharedDefaults?.data(forKey: "quick_capture_cache"),
              let captures = try? JSONDecoder().decode([QuickCapture].self, from: data) else {
            return []
        }
        return Array(captures.prefix(5))
    }
    
    private func checkAuthStatus() -> Bool {
        return sharedDefaults?.bool(forKey: "is_authenticated") ?? false
    }
}

// MARK: - Widget Views
struct QuickCaptureWidgetView: View {
    let entry: QuickCaptureEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: QuickCaptureEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text.badge.plus")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                
                Text("Quick Capture")
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
            }
            
            if entry.isAuthenticated {
                Link(destination: URL(string: "durunotes://quick-capture/new")!) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        
                        Text("New Note")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if let recent = entry.recentCaptures.first {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recent.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text(recent.timeAgo)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Link(destination: URL(string: "durunotes://auth/login")!) {
                    VStack(spacing: 4) {
                        Image(systemName: "person.circle")
                            .font(.title)
                            .foregroundColor(.secondary)
                        
                        Text("Sign in to capture")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct MediumWidgetView: View {
    let entry: QuickCaptureEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "note.text.badge.plus")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                
                Text("Quick Capture")
                    .font(.headline)
                
                Spacer()
                
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if entry.isAuthenticated {
                // Quick action buttons
                HStack(spacing: 12) {
                    QuickActionButton(
                        icon: "plus.circle.fill",
                        title: "New Note",
                        url: "durunotes://quick-capture/new"
                    )
                    
                    QuickActionButton(
                        icon: "doc.text",
                        title: "Meeting",
                        url: "durunotes://quick-capture/template/meeting"
                    )
                    
                    QuickActionButton(
                        icon: "checkmark.circle",
                        title: "Todo",
                        url: "durunotes://quick-capture/template/todo"
                    )
                    
                    QuickActionButton(
                        icon: "lightbulb",
                        title: "Idea",
                        url: "durunotes://quick-capture/template/idea"
                    )
                }
                
                // Recent captures
                if !entry.recentCaptures.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        ForEach(entry.recentCaptures.prefix(2)) { capture in
                            Link(destination: URL(string: "durunotes://note/\(capture.id)")!) {
                                HStack {
                                    if capture.isWidget {
                                        Image(systemName: "sparkle")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Text(capture.title)
                                        .font(.caption)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text(capture.timeAgo)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                SignInPromptView()
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct LargeWidgetView: View {
    let entry: QuickCaptureEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "note.text.badge.plus")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Quick Capture")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if entry.isAuthenticated {
                // Quick actions grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    QuickActionCard(
                        icon: "plus.circle.fill",
                        title: "New Note",
                        description: "Capture a quick thought",
                        url: "durunotes://quick-capture/new",
                        color: .blue
                    )
                    
                    QuickActionCard(
                        icon: "doc.text",
                        title: "Meeting",
                        description: "Meeting notes template",
                        url: "durunotes://quick-capture/template/meeting",
                        color: .purple
                    )
                    
                    QuickActionCard(
                        icon: "checkmark.circle",
                        title: "Todo",
                        description: "Create a quick task",
                        url: "durunotes://quick-capture/template/todo",
                        color: .green
                    )
                    
                    QuickActionCard(
                        icon: "lightbulb",
                        title: "Idea",
                        description: "Capture an idea",
                        url: "durunotes://quick-capture/template/idea",
                        color: .orange
                    )
                }
                
                // Recent captures list
                if !entry.recentCaptures.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Captures")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(entry.recentCaptures) { capture in
                            Link(destination: URL(string: "durunotes://note/\(capture.id)")!) {
                                HStack {
                                    if capture.isWidget {
                                        Image(systemName: "sparkle")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(capture.title)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        
                                        Text(capture.snippet)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(capture.timeAgo)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            } else {
                SignInPromptView()
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Helper Views
struct QuickActionButton: View {
    let icon: String
    let title: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let description: String
    let url: String
    let color: Color
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct SignInPromptView: View {
    var body: some View {
        Link(destination: URL(string: "durunotes://auth/login")!) {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                
                Text("Sign in to Duru Notes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Capture notes directly from your home screen")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}

// MARK: - Widget Configuration
@main
struct QuickCaptureWidget: Widget {
    let kind: String = "QuickCaptureWidget"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: ConfigurationIntent.self,
            provider: QuickCaptureProvider()
        ) { entry in
            QuickCaptureWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Capture")
        .description("Quickly capture notes from your home screen")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Placeholder Data
extension QuickCapture {
    static let placeholders = [
        QuickCapture(
            id: "1",
            title: "Meeting Notes",
            snippet: "Discussed Q1 roadmap and priorities...",
            createdAt: Date().addingTimeInterval(-3600),
            isWidget: true
        ),
        QuickCapture(
            id: "2",
            title: "Shopping List",
            snippet: "Milk, eggs, bread, coffee...",
            createdAt: Date().addingTimeInterval(-7200),
            isWidget: false
        )
    ]
}
```

### 3.2 Widget Communication Bridge
```swift
// File: ios/QuickCaptureWidget/QuickCaptureBridge.swift

import Foundation
import Flutter

class QuickCaptureBridge: NSObject {
    static let shared = QuickCaptureBridge()
    
    private let sharedDefaults = UserDefaults(suiteName: "group.com.fittechs.duruNotesApp")
    private let channelName = "com.fittechs.durunotes/quick_capture"
    
    private override init() {
        super.init()
    }
    
    // MARK: - Flutter Channel Registration
    func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler(handleMethodCall)
    }
    
    // MARK: - Method Call Handler
    private func handleMethodCall(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "refreshWidget":
            refreshWidget()
            result(nil)
            
        case "updateCache":
            if let args = call.arguments as? [String: Any],
               let captures = args["captures"] as? [[String: Any]] {
                updateCache(captures: captures)
                result(true)
            } else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Invalid arguments for updateCache",
                    details: nil
                ))
            }
            
        case "setAuthStatus":
            if let args = call.arguments as? [String: Any],
               let isAuthenticated = args["isAuthenticated"] as? Bool {
                setAuthStatus(isAuthenticated: isAuthenticated)
                result(true)
            } else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Invalid arguments for setAuthStatus",
                    details: nil
                ))
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Widget Operations
    private func refreshWidget() {
        DispatchQueue.main.async {
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
    
    private func updateCache(captures: [[String: Any]]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: captures)
            sharedDefaults?.set(data, forKey: "quick_capture_cache")
            sharedDefaults?.synchronize()
            refreshWidget()
        } catch {
            print("Failed to update widget cache: \(error)")
        }
    }
    
    private func setAuthStatus(isAuthenticated: Bool) {
        sharedDefaults?.set(isAuthenticated, forKey: "is_authenticated")
        sharedDefaults?.synchronize()
        refreshWidget()
    }
    
    // MARK: - Deep Link Handling
    func handleDeepLink(_ url: URL) -> Bool {
        guard url.scheme == "durunotes" else { return false }
        
        let components = url.pathComponents
        guard components.count >= 2 else { return false }
        
        switch components[1] {
        case "quick-capture":
            handleQuickCapture(components: Array(components.dropFirst(2)))
            return true
            
        case "note":
            if components.count >= 3 {
                handleOpenNote(noteId: components[2])
                return true
            }
            
        default:
            break
        }
        
        return false
    }
    
    private func handleQuickCapture(components: [String]) {
        guard !components.isEmpty else { return }
        
        switch components[0] {
        case "new":
            openQuickCaptureEditor(templateId: nil)
            
        case "template":
            if components.count >= 2 {
                openQuickCaptureEditor(templateId: components[1])
            }
            
        default:
            break
        }
    }
    
    private func openQuickCaptureEditor(templateId: String?) {
        // Invoke Flutter method to open editor
        guard let controller = getFlutterViewController() else { return }
        
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        var args: [String: Any] = ["action": "open_editor"]
        if let templateId = templateId {
            args["templateId"] = templateId
        }
        
        channel.invokeMethod("openQuickCapture", arguments: args)
    }
    
    private func handleOpenNote(noteId: String) {
        guard let controller = getFlutterViewController() else { return }
        
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        channel.invokeMethod("openNote", arguments: ["noteId": noteId])
    }
    
    private func getFlutterViewController() -> FlutterViewController? {
        guard let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate,
              let viewController = appDelegate.window?.rootViewController as? FlutterViewController else {
            return nil
        }
        return viewController
    }
}
```

## Phase 4: Android App Widget Implementation (Days 4-5)

### 4.1 App Widget Provider
```kotlin
// File: android/app/src/main/kotlin/com/fittechs/duruNotesApp/widget/QuickCaptureAppWidgetProvider.kt

package com.fittechs.duruNotesApp.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.fittechs.duruNotesApp.MainActivity
import com.fittechs.duruNotesApp.R
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.text.SimpleDateFormat
import java.util.*

class QuickCaptureAppWidgetProvider : AppWidgetProvider() {
    
    companion object {
        const val ACTION_NEW_NOTE = "com.fittechs.duruNotesApp.ACTION_NEW_NOTE"
        const val ACTION_TEMPLATE = "com.fittechs.duruNotesApp.ACTION_TEMPLATE"
        const val ACTION_REFRESH = "com.fittechs.duruNotesApp.ACTION_REFRESH"
        const val EXTRA_TEMPLATE_ID = "template_id"
        
        private const val PREFS_NAME = "QuickCaptureWidget"
        private const val KEY_CACHE = "quick_capture_cache"
        private const val KEY_AUTH = "is_authenticated"
    }
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            ACTION_NEW_NOTE -> handleNewNote(context)
            ACTION_TEMPLATE -> handleTemplate(context, intent)
            ACTION_REFRESH -> refreshAllWidgets(context)
        }
    }
    
    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_quick_capture)
        
        // Check authentication status
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isAuthenticated = prefs.getBoolean(KEY_AUTH, false)
        
        if (isAuthenticated) {
            setupAuthenticatedView(context, views)
        } else {
            setupUnauthenticatedView(context, views)
        }
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
    
    private fun setupAuthenticatedView(context: Context, views: RemoteViews) {
        // Show authenticated UI
        views.setViewVisibility(R.id.authenticated_layout, RemoteViews.VISIBLE)
        views.setViewVisibility(R.id.unauthenticated_layout, RemoteViews.GONE)
        
        // Set up new note button
        val newNoteIntent = Intent(context, QuickCaptureAppWidgetProvider::class.java).apply {
            action = ACTION_NEW_NOTE
        }
        val newNotePendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            newNoteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_new_note, newNotePendingIntent)
        
        // Set up template buttons
        setupTemplateButton(context, views, R.id.btn_meeting, "meeting")
        setupTemplateButton(context, views, R.id.btn_todo, "todo")
        setupTemplateButton(context, views, R.id.btn_idea, "idea")
        
        // Load and display recent captures
        loadRecentCaptures(context, views)
        
        // Set up refresh button
        val refreshIntent = Intent(context, QuickCaptureAppWidgetProvider::class.java).apply {
            action = ACTION_REFRESH
        }
        val refreshPendingIntent = PendingIntent.getBroadcast(
            context,
            1,
            refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_refresh, refreshPendingIntent)
    }
    
    private fun setupUnauthenticatedView(context: Context, views: RemoteViews) {
        // Show sign-in prompt
        views.setViewVisibility(R.id.authenticated_layout, RemoteViews.GONE)
        views.setViewVisibility(R.id.unauthenticated_layout, RemoteViews.VISIBLE)
        
        // Set up sign-in button
        val signInIntent = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse("durunotes://auth/login")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val signInPendingIntent = PendingIntent.getActivity(
            context,
            0,
            signInIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_sign_in, signInPendingIntent)
    }
    
    private fun setupTemplateButton(
        context: Context,
        views: RemoteViews,
        buttonId: Int,
        templateId: String
    ) {
        val intent = Intent(context, QuickCaptureAppWidgetProvider::class.java).apply {
            action = ACTION_TEMPLATE
            putExtra(EXTRA_TEMPLATE_ID, templateId)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            buttonId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(buttonId, pendingIntent)
    }
    
    private fun loadRecentCaptures(context: Context, views: RemoteViews) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val cacheJson = prefs.getString(KEY_CACHE, null) ?: return
        
        try {
            val gson = Gson()
            val type = object : TypeToken<List<QuickCapture>>() {}.type
            val captures: List<QuickCapture> = gson.fromJson(cacheJson, type)
            
            if (captures.isNotEmpty()) {
                views.setViewVisibility(R.id.recent_captures_layout, RemoteViews.VISIBLE)
                
                // Display up to 3 recent captures
                captures.take(3).forEachIndexed { index, capture ->
                    val titleViewId = when (index) {
                        0 -> R.id.recent_title_1
                        1 -> R.id.recent_title_2
                        2 -> R.id.recent_title_3
                        else -> return@forEachIndexed
                    }
                    
                    val timeViewId = when (index) {
                        0 -> R.id.recent_time_1
                        1 -> R.id.recent_time_2
                        2 -> R.id.recent_time_3
                        else -> return@forEachIndexed
                    }
                    
                    val layoutId = when (index) {
                        0 -> R.id.recent_item_1
                        1 -> R.id.recent_item_2
                        2 -> R.id.recent_item_3
                        else -> return@forEachIndexed
                    }
                    
                    views.setTextViewText(titleViewId, capture.title)
                    views.setTextViewText(timeViewId, formatTimeAgo(capture.createdAt))
                    views.setViewVisibility(layoutId, RemoteViews.VISIBLE)
                    
                    // Set click handler to open note
                    val openNoteIntent = Intent(context, MainActivity::class.java).apply {
                        data = Uri.parse("durunotes://note/${capture.id}")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val openNotePendingIntent = PendingIntent.getActivity(
                        context,
                        100 + index,
                        openNoteIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(layoutId, openNotePendingIntent)
                }
            } else {
                views.setViewVisibility(R.id.recent_captures_layout, RemoteViews.GONE)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            views.setViewVisibility(R.id.recent_captures_layout, RemoteViews.GONE)
        }
    }
    
    private fun formatTimeAgo(timestamp: String): String {
        return try {
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            val date = sdf.parse(timestamp) ?: return ""
            
            val now = System.currentTimeMillis()
            val diff = now - date.time
            
            when {
                diff < 60000 -> "just now"
                diff < 3600000 -> "${diff / 60000}m ago"
                diff < 86400000 -> "${diff / 3600000}h ago"
                diff < 604800000 -> "${diff / 86400000}d ago"
                else -> SimpleDateFormat("MMM d", Locale.getDefault()).format(date)
            }
        } catch (e: Exception) {
            ""
        }
    }
    
    private fun handleNewNote(context: Context) {
        val intent = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse("durunotes://quick-capture/new")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        context.startActivity(intent)
    }
    
    private fun handleTemplate(context: Context, intent: Intent) {
        val templateId = intent.getStringExtra(EXTRA_TEMPLATE_ID) ?: return
        
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse("durunotes://quick-capture/template/$templateId")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        context.startActivity(launchIntent)
    }
    
    private fun refreshAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, QuickCaptureAppWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
        
        onUpdate(context, appWidgetManager, appWidgetIds)
    }
    
    data class QuickCapture(
        val id: String,
        val title: String,
        val snippet: String,
        val createdAt: String,
        val isWidget: Boolean
    )
}
```

### 4.2 Widget Layout
```xml
<!-- File: android/app/src/main/res/layout/widget_quick_capture.xml -->

<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="12dp"
    android:background="@drawable/widget_background">
    
    <!-- Header -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical"
        android:paddingBottom="8dp">
        
        <ImageView
            android:layout_width="20dp"
            android:layout_height="20dp"
            android:src="@drawable/ic_note_add"
            android:tint="?android:attr/colorAccent" />
        
        <TextView
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Quick Capture"
            android:textSize="16sp"
            android:textStyle="bold"
            android:paddingStart="8dp" />
        
        <ImageButton
            android:id="@+id/btn_refresh"
            android:layout_width="24dp"
            android:layout_height="24dp"
            android:src="@drawable/ic_refresh"
            android:background="?android:attr/selectableItemBackgroundBorderless"
            android:contentDescription="Refresh" />
    </LinearLayout>
    
    <!-- Authenticated Layout -->
    <LinearLayout
        android:id="@+id/authenticated_layout"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical"
        android:visibility="visible">
        
        <!-- Main Action Button -->
        <LinearLayout
            android:id="@+id/btn_new_note"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal"
            android:gravity="center"
            android:padding="12dp"
            android:background="@drawable/button_primary"
            android:clickable="true"
            android:focusable="true">
            
            <ImageView
                android:layout_width="20dp"
                android:layout_height="20dp"
                android:src="@drawable/ic_add_circle"
                android:tint="@android:color/white" />
            
            <TextView
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="New Note"
                android:textColor="@android:color/white"
                android:textSize="14sp"
                android:textStyle="bold"
                android:paddingStart="8dp" />
        </LinearLayout>
        
        <!-- Template Buttons -->
        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal"
            android:layout_marginTop="8dp">
            
            <LinearLayout
                android:id="@+id/btn_meeting"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:orientation="vertical"
                android:gravity="center"
                android:padding="8dp"
                android:background="@drawable/button_secondary"
                android:layout_marginEnd="4dp"
                android:clickable="true"
                android:focusable="true">
                
                <ImageView
                    android:layout_width="16dp"
                    android:layout_height="16dp"
                    android:src="@drawable/ic_meeting" />
                
                <TextView
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:text="Meeting"
                    android:textSize="10sp"
                    android:layout_marginTop="2dp" />
            </LinearLayout>
            
            <LinearLayout
                android:id="@+id/btn_todo"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:orientation="vertical"
                android:gravity="center"
                android:padding="8dp"
                android:background="@drawable/button_secondary"
                android:layout_marginHorizontal="4dp"
                android:clickable="true"
                android:focusable="true">
                
                <ImageView
                    android:layout_width="16dp"
                    android:layout_height="16dp"
                    android:src="@drawable/ic_check_circle" />
                
                <TextView
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:text="Todo"
                    android:textSize="10sp"
                    android:layout_marginTop="2dp" />
            </LinearLayout>
            
            <LinearLayout
                android:id="@+id/btn_idea"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:orientation="vertical"
                android:gravity="center"
                android:padding="8dp"
                android:background="@drawable/button_secondary"
                android:layout_marginStart="4dp"
                android:clickable="true"
                android:focusable="true">
                
                <ImageView
                    android:layout_width="16dp"
                    android:layout_height="16dp"
                    android:src="@drawable/ic_lightbulb" />
                
                <TextView
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:text="Idea"
                    android:textSize="10sp"
                    android:layout_marginTop="2dp" />
            </LinearLayout>
        </LinearLayout>
        
        <!-- Recent Captures -->
        <LinearLayout
            android:id="@+id/recent_captures_layout"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="vertical"
            android:layout_marginTop="12dp"
            android:visibility="gone">
            
            <TextView
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="RECENT"
                android:textSize="10sp"
                android:textStyle="bold"
                android:alpha="0.6"
                android:paddingBottom="4dp" />
            
            <!-- Recent Item 1 -->
            <LinearLayout
                android:id="@+id/recent_item_1"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:orientation="horizontal"
                android:padding="4dp"
                android:visibility="gone"
                android:clickable="true"
                android:focusable="true"
                android:background="?android:attr/selectableItemBackground">
                
                <TextView
                    android:id="@+id/recent_title_1"
                    android:layout_width="0dp"
                    android:layout_height="wrap_content"
                    android:layout_weight="1"
                    android:textSize="12sp"
                    android:maxLines="1"
                    android:ellipsize="end" />
                
                <TextView
                    android:id="@+id/recent_time_1"
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:textSize="10sp"
                    android:alpha="0.6" />
            </LinearLayout>
            
            <!-- Recent Item 2 -->
            <LinearLayout
                android:id="@+id/recent_item_2"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:orientation="horizontal"
                android:padding="4dp"
                android:visibility="gone"
                android:clickable="true"
                android:focusable="true"
                android:background="?android:attr/selectableItemBackground">
                
                <TextView
                    android:id="@+id/recent_title_2"
                    android:layout_width="0dp"
                    android:layout_height="wrap_content"
                    android:layout_weight="1"
                    android:textSize="12sp"
                    android:maxLines="1"
                    android:ellipsize="end" />
                
                <TextView
                    android:id="@+id/recent_time_2"
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:textSize="10sp"
                    android:alpha="0.6" />
            </LinearLayout>
            
            <!-- Recent Item 3 -->
            <LinearLayout
                android:id="@+id/recent_item_3"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:orientation="horizontal"
                android:padding="4dp"
                android:visibility="gone"
                android:clickable="true"
                android:focusable="true"
                android:background="?android:attr/selectableItemBackground">
                
                <TextView
                    android:id="@+id/recent_title_3"
                    android:layout_width="0dp"
                    android:layout_height="wrap_content"
                    android:layout_weight="1"
                    android:textSize="12sp"
                    android:maxLines="1"
                    android:ellipsize="end" />
                
                <TextView
                    android:id="@+id/recent_time_3"
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:textSize="10sp"
                    android:alpha="0.6" />
            </LinearLayout>
        </LinearLayout>
    </LinearLayout>
    
    <!-- Unauthenticated Layout -->
    <LinearLayout
        android:id="@+id/unauthenticated_layout"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:orientation="vertical"
        android:gravity="center"
        android:visibility="gone">
        
        <ImageView
            android:layout_width="48dp"
            android:layout_height="48dp"
            android:src="@drawable/ic_person_add"
            android:alpha="0.6" />
        
        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="Sign in to Duru Notes"
            android:textSize="14sp"
            android:textStyle="bold"
            android:layout_marginTop="8dp" />
        
        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="Capture notes from home screen"
            android:textSize="11sp"
            android:alpha="0.6"
            android:layout_marginTop="4dp" />
        
        <Button
            android:id="@+id/btn_sign_in"
            android:layout_width="wrap_content"
            android:layout_height="36dp"
            android:text="Sign In"
            android:textSize="12sp"
            android:layout_marginTop="12dp" />
    </LinearLayout>
</LinearLayout>
```

## Phase 5: Testing Strategy (Day 5)

### 5.1 Unit Tests
```dart
// File: test/services/quick_capture_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:duru_notes/services/quick_capture_service.dart';

void main() {
  group('QuickCaptureService', () {
    late QuickCaptureService service;
    late MockNotesRepository mockRepository;
    late MockAnalyticsService mockAnalytics;
    
    setUp(() {
      mockRepository = MockNotesRepository();
      mockAnalytics = MockAnalyticsService();
      
      service = QuickCaptureService(
        notesRepository: mockRepository,
        attachmentService: MockAttachmentService(),
        folderManager: MockFolderManager(),
        analytics: mockAnalytics,
        logger: MockLogger(),
      );
    });
    
    test('creates note with widget metadata', () async {
      // Arrange
      when(mockRepository.createOrUpdate(any)).thenAnswer(
        (_) async => MockLocalNote(),
      );
      
      // Act
      final result = await service.captureNote(
        text: 'Test note',
        platform: 'ios',
      );
      
      // Assert
      expect(result['success'], true);
      verify(mockRepository.createOrUpdate(
        title: argThat(contains('Quick Capture')),
        body: 'Test note',
        metadataJson: argThat(
          allOf(
            containsPair('source', 'widget'),
            containsPair('entry_point', 'ios'),
          ),
        ),
      )).called(1);
    });
    
    test('stores pending capture when offline', () async {
      // Arrange
      when(mockRepository.createOrUpdate(any))
        .thenThrow(NetworkException());
      
      // Act
      final result = await service.captureNote(
        text: 'Offline note',
        platform: 'android',
      );
      
      // Assert
      expect(result['success'], false);
      expect(result['error'], 'OFFLINE');
      // Verify pending capture was stored
    });
    
    test('applies template correctly', () async {
      // Test template application
    });
    
    test('handles rate limiting', () async {
      // Test rate limit enforcement
    });
  });
}
```

### 5.2 Widget Tests
```dart
// File: test/ui/quick_capture_widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Quick Capture UI', () {
    testWidgets('shows sign-in prompt when unauthenticated', (tester) async {
      // Test unauthenticated state
    });
    
    testWidgets('opens editor on widget tap', (tester) async {
      // Test widget interaction
    });
    
    testWidgets('displays recent captures', (tester) async {
      // Test recent captures display
    });
  });
}
```

### 5.3 Integration Tests
```dart
// File: integration_test/quick_capture_flow_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Quick Capture E2E', () {
    testWidgets('complete quick capture flow', (tester) async {
      // Test end-to-end flow
    });
  });
}
```

## Phase 6: Monitoring & Analytics (Day 6)

### 6.1 Analytics Events
```dart
// Analytics events to track:
- quick_capture.widget_tap
- quick_capture.widget_note_created
- quick_capture.widget_failure
- quick_capture.template_used
- quick_capture.offline_capture
- quick_capture.sync_completed
- quick_capture.rate_limit_hit
```

### 6.2 Performance Metrics
```dart
// Performance metrics to monitor:
- Widget refresh latency
- Note creation time
- Cache hit rate
- Sync queue size
- Platform channel response time
```

### 6.3 Error Tracking
```dart
// Error scenarios to handle:
- Authentication failures
- Network timeouts
- Rate limiting
- Storage quota exceeded
- Platform channel errors
```

## Production Checklist

### Pre-Launch
- [ ] Database migrations deployed and tested
- [ ] Edge functions deployed with rate limiting
- [ ] iOS App Group configured correctly
- [ ] Android widget metadata in manifest
- [ ] Deep link routing tested on both platforms
- [ ] Offline mode tested thoroughly
- [ ] Analytics events verified in dashboard
- [ ] Performance benchmarks met (<1.5s tap-to-editor)
- [ ] Accessibility labels implemented
- [ ] Localization strings added for all languages

### Launch Day
- [ ] Monitor error rates in Sentry
- [ ] Check widget refresh performance
- [ ] Verify analytics events flowing
- [ ] Monitor database query performance
- [ ] Check rate limit effectiveness
- [ ] Review user feedback channels

### Post-Launch
- [ ] A/B test template effectiveness
- [ ] Optimize cache invalidation strategy
- [ ] Review and adjust rate limits
- [ ] Implement user-requested templates
- [ ] Performance optimization based on metrics

## Documentation

### User Documentation
- Widget installation guide
- Template customization
- Troubleshooting guide
- FAQ section

### Developer Documentation
- Architecture overview
- API documentation
- Testing procedures
- Deployment process
- Monitoring setup

## Risk Mitigation

### Technical Risks
1. **Platform Channel Failures**: Implement fallback to web view
2. **Widget Update Delays**: Use push notifications as backup trigger
3. **Storage Quota**: Implement cache rotation and cleanup
4. **Rate Limiting**: Progressive backoff with user feedback

### Security Considerations
1. **App Group Security**: Encrypt sensitive data in shared storage
2. **Deep Link Validation**: Validate all deep link parameters
3. **Authentication Token**: Secure token storage and refresh
4. **Data Privacy**: No PII in widget cache

## Success Metrics

### KPIs
- Widget installation rate: >30% of active users
- Daily widget interactions: >2 per user
- Note creation success rate: >95%
- Tap-to-editor latency: <1.5 seconds
- Widget crash rate: <0.1%

### User Satisfaction
- App Store rating improvement
- Reduced time to capture notes
- Increased daily active users
- Higher note creation frequency

## Timeline

### Week 1
- Days 1-2: Backend infrastructure
- Days 2-3: Flutter service layer
- Days 3-4: iOS WidgetKit
- Days 4-5: Android App Widget
- Day 5: Testing
- Day 6: Monitoring setup

### Week 2
- Days 7-8: Bug fixes and optimization
- Days 9-10: Beta testing
- Days 11-12: Production deployment
- Days 13-14: Monitoring and iteration

## Conclusion

This production-grade implementation plan provides a comprehensive approach to building the Quick Capture widget feature. The architecture is designed for reliability, performance, and scalability while maintaining code quality and user experience standards. The phased approach allows for iterative development and testing, ensuring a smooth rollout to production.
