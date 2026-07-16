import '../../../core/models/media_link.dart';

enum LinkParsingStatus { idle, invalid, valid }

enum ParserExecutionStatus {
  idle,
  waitingForParsing,
  parsing,
  succeeded,
  failed,
}

class LinkParserState {
  const LinkParserState({
    this.input = '',
    this.uri,
    this.selectedPlatform = MediaPlatform.unknown,
    this.inputStatus = LinkParsingStatus.idle,
    this.parserStatus = ParserExecutionStatus.idle,
    this.errorMessage,
  });

  final String input;
  final Uri? uri;
  final MediaPlatform selectedPlatform;
  final LinkParsingStatus inputStatus;
  final ParserExecutionStatus parserStatus;
  final String? errorMessage;

  bool get hasInput => input.trim().isNotEmpty;
  bool get isReadyForParsing =>
      parserStatus == ParserExecutionStatus.waitingForParsing;
}
