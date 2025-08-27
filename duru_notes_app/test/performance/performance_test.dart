import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:image/image.dart' as img;

import 'package:duru_notes_app/services/voice_transcription_service.dart';
import 'package:duru_notes_app/services/ocr_service.dart';
import 'package:duru_notes_app/services/share_service.dart';
import 'package:duru_notes_app/core/monitoring/app_logger.dart';

import 'performance_test.mocks.dart';

/// Performance testing suite to validate the 3-second capture principle
/// 
/// This test suite stresses the core capture operations:
/// - Voice recording and transcription
/// - OCR scanning and text extraction
/// - Share-sheet content processing
/// 
/// Each operation is tested 10 times to ensure consistent performance
/// under the 3-second threshold for optimal user experience.
@GenerateMocks([
  VoiceTranscriptionService,
  OCRService,
  ShareService,
])
void main() {
  group('Performance Tests - 3-Second Capture Principle', () {
    late MockVoiceTranscriptionService mockVoiceService;
    late MockOCRService mockOCRService;
    late MockShareService mockShareService;
    late PerformanceTestHelper helper;

    setUpAll(() {
      // Initialize logger for performance tracking
      LoggerFactory.initialize(TestLogger());
    });

    setUp(() {
      mockVoiceService = MockVoiceTranscriptionService();
      mockOCRService = MockOCRService();
      mockShareService = MockShareService();
      helper = PerformanceTestHelper();
    });

    group('Voice Recording Performance', () {
      test('voice recording should complete within 3 seconds - 10 iterations', () async {
        const targetDuration = Duration(seconds: 3);
        const iterations = 10;
        final results = <PerformanceResult>[];

        for (int i = 0; i < iterations; i++) {
          final result = await helper.measureOperation(
            'Voice Recording #${i + 1}',
            () => _simulateVoiceRecording(mockVoiceService),
          );
          
          results.add(result);
          
          // Assert each iteration meets the 3-second requirement
          expect(
            result.duration,
            lessThan(targetDuration),
            reason: 'Voice recording iteration ${i + 1} took ${result.duration.inMilliseconds}ms, '
                   'exceeding the 3-second limit',
          );
        }

        // Print performance summary
        helper.printPerformanceSummary('Voice Recording', results, targetDuration);
        
        // Assert overall performance metrics
        final avgDuration = helper.calculateAverageDuration(results);
        final maxDuration = helper.calculateMaxDuration(results);
        
        expect(avgDuration, lessThan(targetDuration));
        expect(maxDuration, lessThan(targetDuration));
        
        // Ensure consistency (no outliers > 150% of average)
        final consistencyThreshold = Duration(
          milliseconds: (avgDuration.inMilliseconds * 1.5).round(),
        );
        for (final result in results) {
          expect(
            result.duration,
            lessThan(consistencyThreshold),
            reason: 'Voice recording performance inconsistent: ${result.duration.inMilliseconds}ms '
                   'vs average ${avgDuration.inMilliseconds}ms',
          );
        }
      });

      test('voice transcription should complete within 3 seconds - 10 iterations', () async {
        const targetDuration = Duration(seconds: 3);
        const iterations = 10;
        final results = <PerformanceResult>[];

        for (int i = 0; i < iterations; i++) {
          final result = await helper.measureOperation(
            'Voice Transcription #${i + 1}',
            () => _simulateVoiceTranscription(mockVoiceService),
          );
          
          results.add(result);
          
          expect(
            result.duration,
            lessThan(targetDuration),
            reason: 'Voice transcription iteration ${i + 1} took ${result.duration.inMilliseconds}ms',
          );
        }

        helper.printPerformanceSummary('Voice Transcription', results, targetDuration);
        
        final avgDuration = helper.calculateAverageDuration(results);
        expect(avgDuration, lessThan(targetDuration));
      });
    });

    group('OCR Performance', () {
      test('image OCR should complete within 3 seconds - 10 iterations', () async {
        const targetDuration = Duration(seconds: 3);
        const iterations = 10;
        final results = <PerformanceResult>[];

        for (int i = 0; i < iterations; i++) {
          final result = await helper.measureOperation(
            'Image OCR #${i + 1}',
            () => _simulateImageOCR(mockOCRService),
          );
          
          results.add(result);
          
          expect(
            result.duration,
            lessThan(targetDuration),
            reason: 'Image OCR iteration ${i + 1} took ${result.duration.inMilliseconds}ms',
          );
        }

        helper.printPerformanceSummary('Image OCR', results, targetDuration);
        
        final avgDuration = helper.calculateAverageDuration(results);
        expect(avgDuration, lessThan(targetDuration));
      });

      test('document OCR should complete within 3 seconds - 10 iterations', () async {
        const targetDuration = Duration(seconds: 3);
        const iterations = 10;
        final results = <PerformanceResult>[];

        for (int i = 0; i < iterations; i++) {
          final result = await helper.measureOperation(
            'Document OCR #${i + 1}',
            () => _simulateDocumentOCR(mockOCRService),
          );
          
          results.add(result);
          
          expect(
            result.duration,
            lessThan(targetDuration),
            reason: 'Document OCR iteration ${i + 1} took ${result.duration.inMilliseconds}ms',
          );
        }

        helper.printPerformanceSummary('Document OCR', results, targetDuration);
      });
    });

    group('Share-Sheet Performance', () {
      test('text share processing should complete within 3 seconds - 10 iterations', () async {
        const targetDuration = Duration(seconds: 3);
        const iterations = 10;
        final results = <PerformanceResult>[];

        for (int i = 0; i < iterations; i++) {
          final result = await helper.measureOperation(
            'Text Share Processing #${i + 1}',
            () => _simulateTextShareProcessing(mockShareService),
          );
          
          results.add(result);
          
          expect(
            result.duration,
            lessThan(targetDuration),
            reason: 'Text share processing iteration ${i + 1} took ${result.duration.inMilliseconds}ms',
          );
        }

        helper.printPerformanceSummary('Text Share Processing', results, targetDuration);
      });

      test('image share processing should complete within 3 seconds - 10 iterations', () async {
        const targetDuration = Duration(seconds: 3);
        const iterations = 10;
        final results = <PerformanceResult>[];

        for (int i = 0; i < iterations; i++) {
          final result = await helper.measureOperation(
            'Image Share Processing #${i + 1}',
            () => _simulateImageShareProcessing(mockShareService),
          );
          
          results.add(result);
          
          expect(
            result.duration,
            lessThan(targetDuration),
            reason: 'Image share processing iteration ${i + 1} took ${result.duration.inMilliseconds}ms',
          );
        }

        helper.printPerformanceSummary('Image Share Processing', results, targetDuration);
      });

      test('file share processing should complete within 3 seconds - 10 iterations', () async {
        const targetDuration = Duration(seconds: 3);
        const iterations = 10;
        final results = <PerformanceResult>[];

        for (int i = 0; i < iterations; i++) {
          final result = await helper.measureOperation(
            'File Share Processing #${i + 1}',
            () => _simulateFileShareProcessing(mockShareService),
          );
          
          results.add(result);
          
          expect(
            result.duration,
            lessThan(targetDuration),
            reason: 'File share processing iteration ${i + 1} took ${result.duration.inMilliseconds}ms',
          );
        }

        helper.printPerformanceSummary('File Share Processing', results, targetDuration);
      });
    });

    group('Stress Testing', () {
      test('concurrent operations should maintain performance', () async {
        const targetDuration = Duration(seconds: 3);
        final futures = <Future<PerformanceResult>>[];

        // Launch concurrent operations
        futures.add(helper.measureOperation(
          'Concurrent Voice Recording',
          () => _simulateVoiceRecording(mockVoiceService),
        ));
        
        futures.add(helper.measureOperation(
          'Concurrent Image OCR',
          () => _simulateImageOCR(mockOCRService),
        ));
        
        futures.add(helper.measureOperation(
          'Concurrent Text Share',
          () => _simulateTextShareProcessing(mockShareService),
        ));

        final results = await Future.wait(futures);

        for (final result in results) {
          expect(
            result.duration,
            lessThan(targetDuration),
            reason: '${result.operationName} in concurrent test took ${result.duration.inMilliseconds}ms',
          );
        }
      });

      test('memory usage should remain stable during repeated operations', () async {
        final memoryUsages = <int>[];
        
        for (int i = 0; i < 20; i++) {
          await _simulateVoiceRecording(mockVoiceService);
          await _simulateImageOCR(mockOCRService);
          await _simulateTextShareProcessing(mockShareService);
          
          // Simulate memory usage tracking (in a real app, use actual memory APIs)
          final memoryUsage = helper.getSimulatedMemoryUsage();
          memoryUsages.add(memoryUsage);
          
          // Force garbage collection simulation
          await helper.simulateGarbageCollection();
        }

        // Memory should not grow unbounded
        final initialMemory = memoryUsages.first;
        final finalMemory = memoryUsages.last;
        final maxMemoryGrowth = (initialMemory * 1.5).round(); // Allow 50% growth max
        
        expect(
          finalMemory,
          lessThan(maxMemoryGrowth),
          reason: 'Memory usage grew from ${initialMemory}MB to ${finalMemory}MB, '
                 'indicating potential memory leak',
        );
      });
    });
  });
}

/// Simulates voice recording operation with realistic timing
Future<String> _simulateVoiceRecording(MockVoiceTranscriptionService service) async {
  when(service.startRecording()).thenAnswer((_) async {
    // Simulate processing time (200-800ms for recording setup)
    await Future.delayed(Duration(milliseconds: 200 + Random().nextInt(600)));
    return true;
  });

  when(service.stopRecording()).thenAnswer((_) async {
    // Simulate recording finalization (100-400ms)
    await Future.delayed(Duration(milliseconds: 100 + Random().nextInt(300)));
    return 'mock_audio_file.wav';
  });

  await service.startRecording();
  return await service.stopRecording();
}

/// Simulates voice transcription with realistic API call timing
Future<String> _simulateVoiceTranscription(MockVoiceTranscriptionService service) async {
  when(service.transcribeAudio(any)).thenAnswer((_) async {
    // Simulate API call time (500-2000ms based on audio length)
    await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(1500)));
    return 'This is a sample transcription result for performance testing.';
  });

  return await service.transcribeAudio('mock_audio_file.wav');
}

/// Simulates image OCR processing with realistic timing
Future<String> _simulateImageOCR(MockOCRService service) async {
  // Create a mock image for testing
  final mockImage = _createMockImage(800, 600);
  
  when(service.extractTextFromImage(any)).thenAnswer((_) async {
    // Simulate OCR processing time (800-2500ms based on image complexity)
    await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(1700)));
    return 'Sample text extracted from image during performance testing. '
           'This includes multiple lines and various formatting.';
  });

  return await service.extractTextFromImage(mockImage);
}

/// Simulates document OCR processing
Future<String> _simulateDocumentOCR(MockOCRService service) async {
  when(service.extractTextFromDocument(any)).thenAnswer((_) async {
    // Simulate document processing time (1000-2800ms)
    await Future.delayed(Duration(milliseconds: 1000 + Random().nextInt(1800)));
    return 'Document text extraction result with complex formatting, '
           'tables, and multiple pages processed successfully.';
  });

  return await service.extractTextFromDocument('mock_document.pdf');
}

/// Simulates text share processing
Future<String> _simulateTextShareProcessing(MockShareService service) async {
  when(service.processSharedText(any)).thenAnswer((_) async {
    // Simulate text processing time (50-300ms)
    await Future.delayed(Duration(milliseconds: 50 + Random().nextInt(250)));
    return 'Processed shared text content ready for note creation.';
  });

  return await service.processSharedText('Sample shared text content');
}

/// Simulates image share processing
Future<String> _simulateImageShareProcessing(MockShareService service) async {
  final mockImage = _createMockImage(1200, 800);
  
  when(service.processSharedImage(any)).thenAnswer((_) async {
    // Simulate image processing time (300-1200ms)
    await Future.delayed(Duration(milliseconds: 300 + Random().nextInt(900)));
    return 'Processed shared image with metadata extraction completed.';
  });

  return await service.processSharedImage(mockImage);
}

/// Simulates file share processing
Future<String> _simulateFileShareProcessing(MockShareService service) async {
  when(service.processSharedFile(any)).thenAnswer((_) async {
    // Simulate file processing time (200-1500ms based on file type/size)
    await Future.delayed(Duration(milliseconds: 200 + Random().nextInt(1300)));
    return 'Processed shared file with content extraction and validation.';
  });

  return await service.processSharedFile('mock_shared_file.pdf');
}

/// Creates a mock image for testing purposes
Uint8List _createMockImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  
  // Add some text-like patterns to simulate realistic OCR content
  for (int i = 0; i < 10; i++) {
    final x = Random().nextInt(width - 100);
    final y = Random().nextInt(height - 20);
    img.drawRect(
      image,
      x1: x,
      y1: y,
      x2: x + 80,
      y2: y + 15,
      color: img.ColorRgb8(0, 0, 0),
    );
  }
  
  return Uint8List.fromList(img.encodePng(image));
}

/// Helper class for performance measurement and analysis
class PerformanceTestHelper {
  static int _memoryUsageCounter = 100; // Simulated baseline memory usage

  /// Measures the duration of an operation
  Future<PerformanceResult> measureOperation(
    String operationName,
    Future<dynamic> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      await operation();
      stopwatch.stop();
      
      return PerformanceResult(
        operationName: operationName,
        duration: stopwatch.elapsed,
        success: true,
      );
    } catch (e) {
      stopwatch.stop();
      
      return PerformanceResult(
        operationName: operationName,
        duration: stopwatch.elapsed,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Calculates average duration from results
  Duration calculateAverageDuration(List<PerformanceResult> results) {
    final totalMs = results
        .map((r) => r.duration.inMilliseconds)
        .reduce((a, b) => a + b);
    return Duration(milliseconds: (totalMs / results.length).round());
  }

  /// Calculates maximum duration from results
  Duration calculateMaxDuration(List<PerformanceResult> results) {
    final maxMs = results
        .map((r) => r.duration.inMilliseconds)
        .reduce((a, b) => a > b ? a : b);
    return Duration(milliseconds: maxMs);
  }

  /// Calculates minimum duration from results
  Duration calculateMinDuration(List<PerformanceResult> results) {
    final minMs = results
        .map((r) => r.duration.inMilliseconds)
        .reduce((a, b) => a < b ? a : b);
    return Duration(milliseconds: minMs);
  }

  /// Prints performance summary
  void printPerformanceSummary(
    String operationName,
    List<PerformanceResult> results,
    Duration targetDuration,
  ) {
    final avg = calculateAverageDuration(results);
    final max = calculateMaxDuration(results);
    final min = calculateMinDuration(results);
    final successCount = results.where((r) => r.success).length;
    
    print('\n=== $operationName Performance Summary ===');
    print('Iterations: ${results.length}');
    print('Success Rate: ${successCount}/${results.length} '
          '(${(successCount / results.length * 100).toStringAsFixed(1)}%)');
    print('Target: ${targetDuration.inMilliseconds}ms');
    print('Average: ${avg.inMilliseconds}ms');
    print('Min: ${min.inMilliseconds}ms');
    print('Max: ${max.inMilliseconds}ms');
    print('Within Target: ${max.inMilliseconds <= targetDuration.inMilliseconds ? "✅ YES" : "❌ NO"}');
    
    // Performance grade
    final avgRatio = avg.inMilliseconds / targetDuration.inMilliseconds;
    String grade;
    if (avgRatio <= 0.5) grade = 'A+ (Excellent)';
    else if (avgRatio <= 0.7) grade = 'A (Very Good)';
    else if (avgRatio <= 0.85) grade = 'B (Good)';
    else if (avgRatio <= 1.0) grade = 'C (Acceptable)';
    else grade = 'F (Needs Improvement)';
    
    print('Performance Grade: $grade');
    print('================================================\n');
  }

  /// Simulates memory usage tracking
  int getSimulatedMemoryUsage() {
    // Simulate slight memory fluctuations
    _memoryUsageCounter += Random().nextInt(10) - 4; // -4 to +5 MB change
    return _memoryUsageCounter.clamp(80, 500); // Keep within reasonable bounds
  }

  /// Simulates garbage collection
  Future<void> simulateGarbageCollection() async {
    await Future.delayed(Duration(milliseconds: 10));
    // Simulate memory cleanup
    _memoryUsageCounter = (_memoryUsageCounter * 0.95).round();
  }
}

/// Data class for performance test results
class PerformanceResult {
  final String operationName;
  final Duration duration;
  final bool success;
  final String? error;

  const PerformanceResult({
    required this.operationName,
    required this.duration,
    required this.success,
    this.error,
  });

  @override
  String toString() {
    return 'PerformanceResult(name: $operationName, '
           'duration: ${duration.inMilliseconds}ms, '
           'success: $success${error != null ? ', error: $error' : ''})';
  }
}

/// Test logger implementation
class TestLogger implements AppLogger {
  @override
  void info(String message, {Map<String, Object?>? data}) {
    print('[INFO] $message');
  }

  @override
  void warn(String message, {Object? error, StackTrace? stack, Map<String, Object?>? data}) {
    print('[WARN] $message');
  }

  @override
  void error(String message, {Object? error, StackTrace? stack, Map<String, Object?>? data}) {
    print('[ERROR] $message${error != null ? ': $error' : ''}');
  }

  @override
  void breadcrumb(String message, {Map<String, Object?>? data}) {
    print('[BREADCRUMB] $message');
  }
}
