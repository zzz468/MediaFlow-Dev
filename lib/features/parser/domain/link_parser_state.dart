import '../../../core/models/media_link.dart';
import 'media_content.dart';
import 'video_info.dart';

enum LinkParsingStatus { idle, invalid, valid }

enum ParserExecutionStatus {
  waitingForInput,
  readyToParse,
  parsing,
  succeeded,
  failed,
}

extension ParserExecutionStatusDisplayName on ParserExecutionStatus {
  String get displayName {
    return switch (this) {
      ParserExecutionStatus.waitingForInput => '等待输入',
      ParserExecutionStatus.readyToParse => '等待解析',
      ParserExecutionStatus.parsing => '解析中',
      ParserExecutionStatus.succeeded => '解析成功',
      ParserExecutionStatus.failed => '解析失败',
    };
  }
}

class LinkParserState {
  const LinkParserState({
    this.input = '',
    this.uri,
    this.selectedPlatform = MediaPlatform.unknown,
    this.inputStatus = LinkParsingStatus.idle,
    this.parserStatus = ParserExecutionStatus.waitingForInput,
    this.videoInfo,
    this.mediaContent,
    this.errorMessage,
  });

  final String input;
  final Uri? uri;
  final MediaPlatform selectedPlatform;
  final LinkParsingStatus inputStatus;
  final ParserExecutionStatus parserStatus;
  final VideoInfo? videoInfo;
  final MediaContent? mediaContent;
  final String? errorMessage;

  bool get hasInput => input.trim().isNotEmpty;
  bool get isReadyForParsing =>
      parserStatus == ParserExecutionStatus.readyToParse;
}
