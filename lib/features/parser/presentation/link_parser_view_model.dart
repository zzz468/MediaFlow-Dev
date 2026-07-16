import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/url_platform_detector.dart';
import '../domain/link_parser_state.dart';
import '../domain/platform_detector.dart';

final platformDetectorProvider = Provider<PlatformDetector>(
  (ref) => const UrlPlatformDetector(),
);

final linkParserViewModelProvider =
    NotifierProvider<LinkParserViewModel, LinkParserState>(
      LinkParserViewModel.new,
    );

class LinkParserViewModel extends Notifier<LinkParserState> {
  late PlatformDetector _platformDetector;

  @override
  LinkParserState build() {
    _platformDetector = ref.watch(platformDetectorProvider);
    return const LinkParserState();
  }

  void updateInput(String value) {
    final input = value.trim();
    if (input.isEmpty) {
      state = const LinkParserState();
      return;
    }

    final uri = Uri.tryParse(input);
    if (uri == null || !_isSupportedWebUrl(uri)) {
      state = LinkParserState(
        input: value,
        status: LinkParsingStatus.invalid,
        errorMessage: '请输入有效的 http 或 https 链接。',
      );
      return;
    }

    state = LinkParserState(
      input: value,
      uri: uri,
      platform: _platformDetector.detect(uri),
      status: LinkParsingStatus.waitingForParsing,
    );
  }

  void clear() {
    state = const LinkParserState();
  }

  bool _isSupportedWebUrl(Uri uri) {
    if (uri.host.isEmpty) {
      return false;
    }

    return uri.scheme == 'http' || uri.scheme == 'https';
  }
}
