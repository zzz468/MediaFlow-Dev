import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/download_history_entry.dart';

final downloadHistoryViewModelProvider =
    NotifierProvider<DownloadHistoryViewModel, DownloadHistoryState>(
      DownloadHistoryViewModel.new,
    );

class DownloadHistoryViewModel extends Notifier<DownloadHistoryState> {
  @override
  DownloadHistoryState build() => const DownloadHistoryState();
}

class DownloadHistoryState {
  const DownloadHistoryState({this.entries = const []});

  final List<DownloadHistoryEntry> entries;

  bool get isEmpty => entries.isEmpty;
}
