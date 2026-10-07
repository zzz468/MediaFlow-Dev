import 'dart:io';
import '../domain/processing.dart';
import 'android/android_processing_engine.dart';
import 'windows/windows_processing_engine.dart';

MediaProcessingEngine createMediaProcessingEngine() {
  if (Platform.isWindows) return WindowsProcessingEngine();
  if (Platform.isAndroid) return AndroidProcessingEngine();
  return _UnavailableEngine();
}

class _UnavailableEngine implements MediaProcessingEngine {
  @override
  Future<ProcessingResult> process(
    ProcessingRequest r, {
    void Function(ProcessingProgress)? onProgress,
  }) async => ProcessingResult.failure(
    r,
    ProcessingError(
      ProcessingErrorCode.platformUnavailable,
      'Processing is unavailable on this platform.',
    ),
  );
  @override
  Future<bool> cancel(String id) async => false;
  @override
  Future<void> dispose() async {}
}
