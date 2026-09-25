import 'media_content.dart';
import 'video_info.dart';

abstract final class ParserFailureCode {
  static const networkError = 'network_error';
  static const linkExpired = 'link_expired';
  static const unsupportedPlatform = 'unsupported_platform';
  static const parseFailed = 'parse_failed';
}

sealed class ParserResult {
  const ParserResult();

  bool get isSuccess => this is ParserSuccess || this is ParserContentSuccess;
  bool get isFailure => this is ParserFailure;
}

final class ParserSuccess extends ParserResult {
  const ParserSuccess(this.videoInfo);

  final VideoInfo videoInfo;
}

/// Transitional result for works that cannot be represented as VideoInfo.
/// Existing video callers keep the non-null ParserSuccess.videoInfo contract.
final class ParserContentSuccess extends ParserResult {
  const ParserContentSuccess(this.mediaContent);

  final MediaContent mediaContent;
}

final class ParserFailure extends ParserResult {
  const ParserFailure({required this.code, required this.message, this.cause});

  final String code;
  final String message;
  final Object? cause;
}
