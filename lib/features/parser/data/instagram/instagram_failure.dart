import '../../domain/parser_result.dart';

final class InstagramFailure implements Exception {
  const InstagramFailure(this.code);
  final String code;
  ParserFailure get result => ParserFailure(
    code: code,
    message: switch (code) {
      ParserFailureCode.unsupportedUrl => '请使用 Instagram 公开 Post 或 Reel 链接。',
      ParserFailureCode.loginRequired => 'Instagram 要求登录，本次匿名解析已停止。',
      ParserFailureCode.securityChallenge => 'Instagram 要求安全验证，本次解析已停止。',
      ParserFailureCode.privateOrRestricted => 'Instagram 作品不公开或访问受限。',
      ParserFailureCode.resourceForbidden => 'Instagram 拒绝访问，本次解析已停止。',
      ParserFailureCode.rateLimited => 'Instagram 请求过于频繁，请稍后再试。',
      ParserFailureCode.notFound => 'Instagram 作品不存在或已删除。',
      ParserFailureCode.networkFailure => '无法连接 Instagram，请检查网络后重试。',
      _ => '未找到完整的 Instagram 媒体数据，平台格式可能已变化。',
    },
  );
}
