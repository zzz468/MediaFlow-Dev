import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../infrastructure/processing_engine_factory.dart';
import 'processing_operation_manager.dart';

final processingOperationManagerProvider = Provider<ProcessingOperationManager>(
  (ref) {
    final manager = ProcessingOperationManager(createMediaProcessingEngine());
    ref.onDispose(() => manager.dispose());
    return manager;
  },
);
