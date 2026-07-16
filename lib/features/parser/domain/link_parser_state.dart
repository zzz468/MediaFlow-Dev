import '../../../core/models/media_link.dart';

enum LinkParsingStatus { idle, invalid, waitingForParsing }

class LinkParserState {
  const LinkParserState({
    this.input = '',
    this.uri,
    this.platform = MediaPlatform.unknown,
    this.status = LinkParsingStatus.idle,
    this.errorMessage,
  });

  final String input;
  final Uri? uri;
  final MediaPlatform platform;
  final LinkParsingStatus status;
  final String? errorMessage;

  bool get hasInput => input.trim().isNotEmpty;
  bool get isReadyForParsing => status == LinkParsingStatus.waitingForParsing;
}
