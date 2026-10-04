import '../../domain/parser_result.dart';

final class XFailure implements Exception {
  const XFailure(this.code);
  final String code;
  ParserFailure get result => ParserFailure(
    code: code,
    message: switch (code) {
      ParserFailureCode.unsupportedUrl => '请使用 X / Twitter 公开帖子链接。',
      ParserFailureCode.loginRequired => 'X 要求登录，本次匿名解析已停止。',
      ParserFailureCode.securityChallenge => 'X 要求安全验证，本次解析已停止。',
      ParserFailureCode.resourceForbidden => 'X 拒绝访问，本次解析已停止。',
      ParserFailureCode.rateLimited => 'X 请求过于频繁，请稍后再试。',
      ParserFailureCode.notFound => 'X 帖子不存在或已删除。',
      ParserFailureCode.networkFailure => '无法连接 X，请检查网络后重试。',
      _ => '未找到完整的 X 媒体数据，平台格式可能已变化。',
    },
  );
}
