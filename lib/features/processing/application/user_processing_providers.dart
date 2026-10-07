import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../settings/application/settings_controller.dart';
import '../../downloader/data/local_download_file_store.dart';
import '../domain/local_media.dart';
import '../infrastructure/local_media_input.dart';
import '../infrastructure/user_processing_storage.dart';
import '../infrastructure/processing_history_repository.dart';
import 'processing_providers.dart';
import 'user_processing_controller.dart';

final localMediaInputProvider = Provider<LocalMediaInput>(
  (ref) => PlatformLocalMediaInput(),
);
final processingHistoryRepositoryProvider =
    Provider<ProcessingHistoryRepository>(
      (ref) => JsonProcessingHistoryRepository(),
    );
final userProcessingStorageProvider = Provider<UserProcessingStorage>(
  (ref) => LocalUserProcessingStorage(
    finalDirectory: () async {
      final configured = ref.read(appSettingsProvider).defaultDownloadDirectory;
      if (configured != null && configured.isNotEmpty) {
        return Directory(configured);
      }
      return LocalDownloadFileStore.resolveDefaultDownloadDirectory();
    },
  ),
);
final userProcessingProvider =
    NotifierProvider<UserProcessingNotifier, UserProcessingState>(
      UserProcessingNotifier.new,
    );
final processingHistoryProvider = StreamProvider<List<ProcessingHistoryItem>>((
  ref,
) {
  final controller = ref.watch(userProcessingProvider.notifier).controller;
  return Stream.multi((stream) {
    final subscription = controller.historyChanges.listen(
      stream.add,
      onError: stream.addError,
    );
    var active = true;
    controller.initialized.then((_) {
      if (active) stream.add(List.unmodifiable(controller.history));
    });
    stream.onCancel = () {
      active = false;
      return subscription.cancel();
    };
  });
});

class UserProcessingNotifier extends Notifier<UserProcessingState> {
  late UserProcessingController controller;
  @override
  UserProcessingState build() {
    controller = UserProcessingController(
      manager: ref.read(processingOperationManagerProvider),
      inputGateway: ref.read(localMediaInputProvider),
      storage: ref.read(userProcessingStorageProvider),
      repository: ref.read(processingHistoryRepositoryProvider),
    );
    final subscription = controller.changes.listen((next) => state = next);
    ref.onDispose(() {
      unawaited(subscription.cancel());
      unawaited(controller.dispose());
    });
    return controller.state;
  }
}
