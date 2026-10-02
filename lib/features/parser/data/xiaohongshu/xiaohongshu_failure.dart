import '../../domain/parser_result.dart';

final class XiaohongshuFailure implements Exception {
  const XiaohongshuFailure(this.code);
  final String code;

  ParserFailure get result => ParserFailure(
    code: code,
    message: switch (code) {
      ParserFailureCode.unsupportedUrl => '不支持此小红书链接。请使用作品或分享链接。',
      ParserFailureCode.notFound => '小红书作品不存在或分享链接已失效。',
      ParserFailureCode.privateOrRestricted => '该小红书作品不公开或访问受限。',
      ParserFailureCode.loginRequired => '小红书要求登录，本次匿名解析已停止。',
      ParserFailureCode.securityChallenge => '小红书要求安全验证，本次解析已停止。',
      ParserFailureCode.rateLimited => '小红书请求过于频繁，请稍后再试。',
      ParserFailureCode.networkFailure => '无法连接小红书，请检查网络后重试。',
      ParserFailureCode.parseNoMatch => '未找到可解析的小红书公开作品数据。',
      ParserFailureCode.resourceForbidden => '小红书拒绝访问此页面或媒体资源。',
      _ => '小红书解析发生未知错误。',
    },
  );

  static String? rejection(int status, Uri uri) {
    if (status == 429) return ParserFailureCode.rateLimited;
    if (status == 461 ||
        status == 471 ||
        uri.path.contains('/sorry') ||
        uri.path.toLowerCase().contains('captcha')) {
      return ParserFailureCode.securityChallenge;
    }
    if (status == 404 || status == 410) return ParserFailureCode.notFound;
    if (status == 401 ||
        uri.path.contains('website-login') ||
        uri.path == '/login') {
      return ParserFailureCode.loginRequired;
    }
    if (status == 403) return ParserFailureCode.resourceForbidden;
    if (status >= 400) return ParserFailureCode.unknown;
    return null;
  }
}
