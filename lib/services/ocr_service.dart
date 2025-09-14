import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:flutter/services.dart';
// OCR functionality temporarily disabled - uncomment when google_mlkit_text_recognition is added
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// OCR (Optical Character Recognition) service for extracting text from images
/// Note: OCR functionality is currently disabled. To enable, uncomment the google_mlkit_text_recognition import
/// and add the package to pubspec.yaml
class OCRService {
  OCRService({
    AppLogger? logger,
    AnalyticsService? analytics,
  })  : _logger = logger ?? LoggerFactory.instance,
        _analytics = analytics ?? AnalyticsFactory.instance;

  final AppLogger _logger;
  final AnalyticsService _analytics;
  final ImagePicker _imagePicker = ImagePicker();
  // TextRecognizer? _textRecognizer;

  /// Initialize the OCR service
  void _initializeRecognizer() {
    // OCR temporarily disabled
    // _textRecognizer ??= TextRecognizer();
  }

  /// Pick image from camera and extract text
  Future<String?> pickAndScanImage({ImageSource source = ImageSource.camera}) async {
    try {
      _analytics.startTiming('ocr_scan');
      _initializeRecognizer();
      
      // Pick image
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80, // Reduce quality for faster processing
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image == null) {
        _analytics.endTiming('ocr_scan', properties: {
          'success': false,
          'reason': 'no_image_selected',
        });
        return null;
      }
      
      // Extract text from image
      final text = await extractTextFromImagePath(image.path);
      
      _analytics.endTiming('ocr_scan', properties: {
        'success': text != null,
        'text_length': text?.length ?? 0,
        'source': source.name,
      });
      
      return text;
    } catch (e) {
      _logger.error('Failed to pick and scan image', error: e);
      _analytics.endTiming('ocr_scan', properties: {
        'success': false,
        'error': e.toString(),
      });
      return null;
    }
  }

  /// Extract text from image file path
  Future<String?> extractTextFromImagePath(String imagePath) async {
    try {
      _analytics.startTiming('ocr_extract_text');
      _initializeRecognizer();
      
      // OCR temporarily disabled - return empty text
      const extractedText = 'OCR functionality is temporarily disabled';
      
      // final inputImage = InputImage.fromFilePath(imagePath);
      // final recognizedText = await _textRecognizer!.processImage(inputImage);
      // final extractedText = recognizedText.text;
      
      _analytics.endTiming('ocr_extract_text', properties: {
        'success': extractedText.isNotEmpty,
        'text_length': extractedText.length,
        'blocks_detected': 0, // recognizedText.blocks.length,
        'lines_detected': 0, // recognizedText.blocks.map((block) => block.lines.length).fold(0, (a, b) => a + b),
      });
      
      _analytics.featureUsed('ocr_text_extracted', properties: {
        'text_length': extractedText.length,
        'word_count': extractedText.split(' ').where((w) => w.isNotEmpty).length,
        'block_count': 0, // recognizedText.blocks.length,
      });
      
      _logger.info('Text extracted from image', data: {
        'text_length': extractedText.length,
        'blocks': 0, // recognizedText.blocks.length,
      });
      
      return extractedText.isNotEmpty ? extractedText : null;
    } catch (e) {
      _logger.error('Failed to extract text from image', error: e, data: {
        'image_path': imagePath,
      });
      
      _analytics.endTiming('ocr_extract_text', properties: {
        'success': false,
        'error': e.toString(),
      });
      
      return null;
    }
  }

  /// Extract structured text data from image (with positioning info)
  Future<OCRResult?> extractStructuredText(String imagePath) async {
    try {
      _initializeRecognizer();
      
      // OCR temporarily disabled - return empty blocks
      final blocks = <OCRTextBlock>[];
      _logger.info('OCR service is currently disabled - structured text scanning unavailable');
      
      // final inputImage = InputImage.fromFilePath(imagePath);
      // final recognizedText = await _textRecognizer!.processImage(inputImage);
      
      /* OCR loop disabled
      for (final textBlock in recognizedText.blocks) {
        final lines = <OCRTextLine>[];
        
        for (final line in textBlock.lines) {
          final elements = <OCRTextElement>[];
          
          for (final element in line.elements) {
            elements.add(OCRTextElement(
              text: element.text,
              confidence: element.confidence,
              boundingBox: element.boundingBox,
            ));
          }
          
          lines.add(OCRTextLine(
            text: line.text,
            confidence: line.confidence,
            boundingBox: line.boundingBox,
            elements: elements,
          ));
        }
        
        blocks.add(OCRTextBlock(
          text: textBlock.text,
          confidence: 1, // Default confidence since ML Kit doesn't provide it
          boundingBox: textBlock.boundingBox,
          lines: lines,
        ));
      }
      */
      
      final result = OCRResult(
        fullText: '', // recognizedText.text,
        blocks: blocks,
      );
      
      _analytics.featureUsed('ocr_structured_extraction', properties: {
        'blocks_count': blocks.length,
        'total_confidence': blocks.isNotEmpty 
            ? blocks.map((b) => b.confidence ?? 0.0).reduce((a, b) => a + b) / blocks.length
            : 0.0,
      });
      
      return result;
    } catch (e) {
      _logger.error('Failed to extract structured text', error: e);
      return null;
    }
  }

  /// Scan image from camera
  Future<String?> scanFromCamera() async {
    return pickAndScanImage();
  }

  /// Scan image from gallery
  Future<String?> scanFromGallery() async {
    return pickAndScanImage(source: ImageSource.gallery);
  }

  /// Check if OCR is available on this device
  Future<bool> isAvailable() async {
    // OCR temporarily disabled
    return false;
    /*
    try {
      _initializeRecognizer();
      return _textRecognizer != null;
    } catch (e) {
      return false;
    }
    */
  }

  /// Get supported languages for OCR
  List<String> getSupportedLanguages() {
    // MLKit supports many languages, but we'll return common ones
    return [
      'en', // English
      'es', // Spanish
      'fr', // French
      'de', // German
      'it', // Italian
      'pt', // Portuguese
      'ru', // Russian
      'ja', // Japanese
      'ko', // Korean
      'zh', // Chinese
      'ar', // Arabic
      'hi', // Hindi
    ];
  }

  /// Dispose of resources
  void dispose() {
    // OCR temporarily disabled
    // _textRecognizer?.close();
    // _textRecognizer = null;
  }
}

/// OCR result containing structured text data
class OCRResult {
  
  const OCRResult({
    required this.fullText,
    required this.blocks,
  });
  final String fullText;
  final List<OCRTextBlock> blocks;
}

/// OCR text block
class OCRTextBlock {
  
  const OCRTextBlock({
    required this.text,
    required this.boundingBox, required this.lines, this.confidence,
  });
  final String text;
  final double? confidence;
  final Rect boundingBox;
  final List<OCRTextLine> lines;
}

/// OCR text line
class OCRTextLine {
  
  const OCRTextLine({
    required this.text,
    required this.boundingBox, required this.elements, this.confidence,
  });
  final String text;
  final double? confidence;
  final Rect boundingBox;
  final List<OCRTextElement> elements;
}

/// OCR text element (word)
class OCRTextElement {
  
  const OCRTextElement({
    required this.text,
    required this.boundingBox, this.confidence,
  });
  final String text;
  final double? confidence;
  final Rect boundingBox;
}
