import 'dart:io';
import '../domain/processing.dart';

class ProcessingFailure implements Exception {
  final ProcessingError error;
  ProcessingFailure(
    ProcessingErrorCode code,
    String message, {
    String? diagnostic,
  }) : error = ProcessingError(code, message, diagnostic: diagnostic);
}

class PreparedOutput {
  final File target, partial;
  const PreparedOutput(this.target, this.partial);
}

abstract interface class LocalOutputStorage {
  Future<PreparedOutput> prepare(ProcessingRequest request);
  int? freeBytes(String directory);
  // Synchronous commit lets cancellation and publication share one Dart turn.
  // Must fail without replacing an existing final output.
  void publish(PreparedOutput output);
  Future<void> cleanup(PreparedOutput output);
}

ProcessingFailure fileFailure(FileSystemException e) {
  final code = switch (e.osError?.errorCode) {
    5 || 13 => ProcessingErrorCode.permissionDenied,
    39 || 112 || 28 => ProcessingErrorCode.insufficientStorage,
    80 || 183 || 17 => ProcessingErrorCode.outputConflict,
    _ => ProcessingErrorCode.unknown,
  };
  return ProcessingFailure(
    code,
    'Unable to access processing storage.',
    diagnostic: e.osError?.message,
  );
}
