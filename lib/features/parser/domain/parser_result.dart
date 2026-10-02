import 'media_content.dart';
import 'video_info.dart';

abstract final class ParserFailureCode {
  static const sessionRequired = 'session_required';
  static const sessionExpired = 'session_expired';
  static const userCancelledLogin = 'user_cancelled_login';
  static const networkError = 'network_error';
  static const linkExpired = 'link_expired';
  static const unsupportedPlatform = 'unsupported_platform';
  static const parseFailed = 'parse_failed';
  static const unsupportedUrl = 'unsupported_url';
  static const notFound = 'not_found';
  static const privateOrRestricted = 'private_or_restricted';
  static const loginRequired = 'login_required';
  static const securityChallenge = 'security_challenge';
  static const rateLimited = 'rate_limited';
  static const networkFailure = 'network_failure';
  static const parseNoMatch = 'parse_no_match';
  static const resourceForbidden = 'resource_forbidden';
  static const unknown = 'unknown';
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
