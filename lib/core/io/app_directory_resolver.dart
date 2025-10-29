import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Returns the platform application documents directory when available.
///
/// On platforms or test environments where the path_provider plugin is not
/// registered, this falls back to a stable directory under system temp so that
/// file-based workflows still operate without resorting to mocks.
Future<Directory> resolveAppDocumentsDirectory({
  String namespace = 'duru_notes',
}) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  } on MissingPluginException catch (_) {
    return _fallbackDirectory(namespace, 'app_docs');
  } on UnimplementedError catch (_) {
    return _fallbackDirectory(namespace, 'app_docs');
  }
}

Future<Directory> resolveTemporaryDirectory({
  String namespace = 'duru_notes',
}) async {
  try {
    final directory = await getTemporaryDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  } on MissingPluginException catch (_) {
    return _fallbackDirectory(namespace, 'tmp');
  } on UnimplementedError catch (_) {
    return _fallbackDirectory(namespace, 'tmp');
  }
}

Directory? _cachedDocumentsDir;
Directory? _cachedTempDir;

Future<Directory> _fallbackDirectory(String namespace, String kind) async {
  final cached = kind == 'app_docs' ? _cachedDocumentsDir : _cachedTempDir;
  if (cached != null && await cached.exists()) {
    return cached;
  }

  final basePath = p.join(Directory.systemTemp.path, namespace, kind);
  final directory = Directory(basePath);
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  if (kind == 'app_docs') {
    _cachedDocumentsDir = directory;
  } else {
    _cachedTempDir = directory;
  }
  return directory;
}
