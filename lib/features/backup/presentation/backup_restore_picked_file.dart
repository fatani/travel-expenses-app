import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Reads bytes from a [PlatformFile] returned by the restore file picker.
///
/// Prefers in-memory [PlatformFile.bytes]; falls back to [PlatformFile.path].
Future<List<int>?> readRestorePickedFileBytes(PlatformFile file) async {
  final hasBytes = file.bytes != null;
  final hasPath = file.path != null;
  if (kDebugMode) {
    debugPrint(
      'backup restore pick: name=${file.name}, size=${file.size}, '
      'hasBytes=$hasBytes, hasPath=$hasPath',
    );
  }

  if (file.bytes != null) {
    return file.bytes!;
  }

  final path = file.path;
  if (path != null) {
    try {
      return await File(path).readAsBytes();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('backup restore pick file read failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  return null;
}
