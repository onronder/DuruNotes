import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

/// Provides functions to capture an image from the camera and perform
/// optical character recognition (OCR) on the captured image. This
/// service requests the necessary camera permission, launches the camera
/// via [ImagePicker], and uses Google ML Kit's text recognizer to
/// extract text from the image. The service should be disposed when no
/// longer needed to release native resources.
class OCRService {
  OCRService()
      : _picker = ImagePicker(),
        _textRecognizer = TextRecognizer();

  final ImagePicker _picker;
  final TextRecognizer _textRecognizer;

  /// Captures an image using the device camera and runs text recognition on
  /// the captured image. Returns the recognized text as a single string, or
  /// `null` if the user cancels the capture, the permission is denied or
  /// recognition fails. The caller is responsible for disposing the
  /// [OCRService] when done.
  Future<String?> pickAndScanImage() async {
    // Request camera permission if not already granted.
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      return null;
    }

    // Open the camera to capture an image.
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) {
      return null;
    }

    final File file = File(pickedFile.path);
    final inputImage = InputImage.fromFile(file);
    try {
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (_) {
      // On any exception, return null to indicate failure.
      return null;
    }
  }

  /// Releases resources held by the underlying text recognizer. Should be
  /// called when the service is no longer needed.
  void dispose() {
    _textRecognizer.close();
  }
}