import '../../../../../core/models/media_link.dart';
import '../../../../../core/network/network_client.dart';
import '../../../domain/parser_interface.dart';
import '../../../domain/parser_result.dart';
import 'douyin_gallery_backend.dart';

/// Platform-local dispatch. Unknown/video links never acquire a session merely
/// because the anonymous video parser failed.
final class DouyinContentParser implements ParserInterface {
  const DouyinContentParser({
    required this.video,
    required this.gallery,
    required this.network,
  });
  final ParserInterface video;
  final DouyinGalleryBackend? gallery;
  final NetworkClient network;
  @override
  MediaPlatform get platform => MediaPlatform.douyin;
  @override
  bool supports(MediaLink link) => video.supports(link);

  static String? noteId(Uri uri) {
    if (!(uri.host == 'douyin.com' || uri.host.endsWith('.douyin.com'))) {
      return null;
    }
    return RegExp(r'^/note/(\d+)(?:/|$)').firstMatch(uri.path)?.group(1);
  }

  @override
  Future<ParserResult> parse(MediaLink link) async {
    var uri = link.normalizedUri;
    var id = noteId(uri);
    if (id == null && uri.host == 'v.douyin.com') {
      try {
        final response = await network.get(uri);
        if (response.statusCode == 200) {
          uri = response.finalUri;
          id = noteId(uri);
        }
      } catch (_) {
        return const ParserFailure(
          code: ParserFailureCode.networkError,
          message: '网络连接失败，请稍后重试。',
        );
      }
    }
    if (id == null) return video.parse(link);
    if (gallery == null) {
      return const ParserFailure(
        code: ParserFailureCode.unsupportedPlatform,
        message: '当前系统暂不支持抖音图文解析。',
      );
    }
    try {
      return ParserContentSuccess(await gallery!.parse(id));
    } on DouyinDetailException catch (error) {
      return switch (error.failure) {
        DouyinDetailFailure.noSession => const ParserFailure(
          code: ParserFailureCode.sessionRequired,
          message: '首次解析抖音图文可能需要完成一次抖音登录或安全验证。登录状态保存在本机，后续通常可直接解析。',
        ),
        DouyinDetailFailure.sessionExpired => const ParserFailure(
          code: ParserFailureCode.sessionExpired,
          message: '抖音登录状态已失效，请重新登录。',
        ),
        _ => const ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: '暂时无法解析此抖音图文，请稍后再试。',
        ),
      };
    } catch (_) {
      return const ParserFailure(
        code: ParserFailureCode.parseFailed,
        message: '暂时无法解析此抖音图文，请稍后再试。',
      );
    }
  }
}
