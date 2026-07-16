import 'video_info.dart';

abstract final class ParserFailureCode {
  static const networkError = 'network_error';
  static const linkExpired = 'link_expired';
  static const unsupportedPlatform = 'unsupported_platform';
  static const parseFailed = 'parse_failed';
}

sealed class ParserResult {
  const ParserResult();

  bool get isSuccess => this is ParserSuccess;
  bool get isFailure => this is ParserFailure;
}

final class ParserSuccess extends ParserResult {
  const ParserSuccess(this.videoInfo);

  final VideoInfo videoInfo;
}

final class ParserFailure extends ParserResult {
  const ParserFailure({required this.code, required this.message, this.cause});

  final String code;
  final String message;
  final Object? cause;
}
