import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/parser_service.dart';
import '../domain/link_parser_state.dart';
import '../domain/parser_result.dart';

final parserServiceProvider = Provider<ParserService>((ref) {
  final service = createDefaultParserService();
  ref.onDispose(service.close);
  return service;
});

final linkParserViewModelProvider =
    NotifierProvider<LinkParserViewModel, LinkParserState>(
      LinkParserViewModel.new,
    );

class LinkParserViewModel extends Notifier<LinkParserState> {
  late ParserService _parserService;

  @override
  LinkParserState build() {
    _parserService = ref.watch(parserServiceProvider);
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
        inputStatus: LinkParsingStatus.invalid,
        parserStatus: ParserExecutionStatus.failed,
        errorMessage: '请输入有效的 http 或 https 链接。',
      );
      return;
    }

    state = LinkParserState(
      input: value,
      uri: uri,
      selectedPlatform: _parserService.detectPlatform(uri),
      inputStatus: LinkParsingStatus.valid,
      parserStatus: ParserExecutionStatus.readyToParse,
    );
  }

  Future<void> parse() async {
    final uri = state.uri;
    if (uri == null || state.inputStatus != LinkParsingStatus.valid) {
      return;
    }

    state = LinkParserState(
      input: state.input,
      uri: uri,
      selectedPlatform: state.selectedPlatform,
      inputStatus: LinkParsingStatus.valid,
      parserStatus: ParserExecutionStatus.parsing,
    );

    final result = await _parserService.parseUri(uri);
    switch (result) {
      case ParserContentSuccess(:final mediaContent):
        state = LinkParserState(
          input: state.input,
          uri: uri,
          selectedPlatform: mediaContent.platform,
          inputStatus: LinkParsingStatus.valid,
          parserStatus: ParserExecutionStatus.succeeded,
          mediaContent: mediaContent,
        );
      case ParserSuccess(:final videoInfo):
        state = LinkParserState(
          input: state.input,
          uri: uri,
          selectedPlatform: videoInfo.platform,
          inputStatus: LinkParsingStatus.valid,
          parserStatus: ParserExecutionStatus.succeeded,
          videoInfo: videoInfo,
        );
      case ParserFailure(:final message):
        state = LinkParserState(
          input: state.input,
          uri: uri,
          selectedPlatform: state.selectedPlatform,
          inputStatus: LinkParsingStatus.valid,
          parserStatus: ParserExecutionStatus.failed,
          errorMessage: message,
        );
    }
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
