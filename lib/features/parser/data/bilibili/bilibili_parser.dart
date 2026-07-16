import '../../../../core/models/media_link.dart';
import '../../domain/parser_interface.dart';
import '../../domain/parser_result.dart';
import '../../domain/video_info.dart';

class BilibiliParser implements ParserInterface {
  const BilibiliParser();

  @override
  MediaPlatform get platform => MediaPlatform.bilibili;

  @override
  Future<ParserResult> parse(MediaLink link) async {
    return ParserSuccess(
      VideoInfo(
        id: 'bilibili-demo',
        title: '测试视频',
        author: 'MediaFlow Demo',
        authorId: 'mediaflow-demo',
        platform: platform,
        coverUrl: Uri.parse(
          'https://example.test/mediaflow/bilibili-cover.jpg',
        ),
        videoUrl: Uri.parse('https://example.test/mediaflow/bilibili-demo.mp4'),
        duration: const Duration(minutes: 3, seconds: 20),
        description: '用于验证 MediaFlow 解析架构的 Bilibili 模拟数据。',
      ),
    );
  }

  @override
  bool supports(MediaLink link) => link.platform == platform;
}
