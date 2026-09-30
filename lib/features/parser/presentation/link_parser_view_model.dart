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
  int _operation = 0;
  bool _loginPending = false;
  Uri? _continuation;
  bool _resumed = false;

  @override
  LinkParserState build() {
    _operation++;
    _continuation = null;
    _parserService = ref.watch(parserServiceProvider);
    return const LinkParserState();
  }

  void updateInput(String value) {
    _operation++;
    _continuation = null;
    _resumed = false;
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
    if (state.parserStatus == ParserExecutionStatus.parsing || _loginPending) {
      return;
    }
    final uri = state.uri;
    if (uri == null || state.inputStatus != LinkParsingStatus.valid) {
      return;
    }

    final operation = ++_operation;
    _continuation = null;
    _resumed = false;
    await _execute(uri, operation);
  }

  Future<void> _execute(Uri uri, int operation) async {
    final input = state.input;
    state = LinkParserState(
      input: state.input,
      uri: uri,
      selectedPlatform: state.selectedPlatform,
      inputStatus: LinkParsingStatus.valid,
      parserStatus: ParserExecutionStatus.parsing,
    );

    final result = await _parserService.parseUri(uri);
    if (operation != _operation || !ref.mounted) return;
    switch (result) {
      case ParserContentSuccess(:final mediaContent):
        state = LinkParserState(
          input: input,
          uri: uri,
          selectedPlatform: mediaContent.platform,
          inputStatus: LinkParsingStatus.valid,
          parserStatus: ParserExecutionStatus.succeeded,
          mediaContent: mediaContent,
        );
      case ParserSuccess(:final videoInfo):
        state = LinkParserState(
          input: input,
          uri: uri,
          selectedPlatform: videoInfo.platform,
          inputStatus: LinkParsingStatus.valid,
          parserStatus: ParserExecutionStatus.succeeded,
          videoInfo: videoInfo,
        );
      case ParserFailure(:final message, :final code):
        if (!_resumed &&
            (code == ParserFailureCode.sessionRequired ||
                code == ParserFailureCode.sessionExpired)) {
          _continuation = uri;
        }
        state = LinkParserState(
          input: state.input,
          uri: uri,
          selectedPlatform: state.selectedPlatform,
          inputStatus: LinkParsingStatus.valid,
          parserStatus: ParserExecutionStatus.failed,
          errorMessage: message,
          errorCode: _resumed ? ParserFailureCode.parseFailed : code,
        );
    }
  }

  void clear() {
    _operation++;
    _continuation = null;
    state = const LinkParserState();
  }

  Future<void> loginAndContinue() async {
    final uri = _continuation;
    final login = _parserService.establishSession;
    if (uri == null || login == null || _loginPending || _resumed) return;
    final operation = _operation;
    _loginPending = true;
    _continuation = null;
    final input = state.input;
    state = LinkParserState(
      input: input,
      uri: uri,
      selectedPlatform: state.selectedPlatform,
      inputStatus: LinkParsingStatus.valid,
      parserStatus: ParserExecutionStatus.parsing,
    );
    bool ready;
    try {
      ready = await login();
    } catch (_) {
      ready = false;
    }
    _loginPending = false;
    if (operation != _operation || !ref.mounted) return;
    if (!ready) {
      state = LinkParserState(
        input: input,
        uri: uri,
        selectedPlatform: state.selectedPlatform,
        inputStatus: LinkParsingStatus.valid,
        parserStatus: ParserExecutionStatus.failed,
        errorCode: ParserFailureCode.userCancelledLogin,
        errorMessage: '登录未完成，已取消本次解析。',
      );
      return;
    }
    _resumed = true;
    await _execute(uri, operation);
  }

  bool _isSupportedWebUrl(Uri uri) {
    if (uri.host.isEmpty) {
      return false;
    }

    return uri.scheme == 'http' || uri.scheme == 'https';
  }
}
