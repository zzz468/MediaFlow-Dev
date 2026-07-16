import '../../../../core/models/media_link.dart';
import '../../domain/parser_interface.dart';
import '../../domain/parser_result.dart';
import '../../domain/video_info.dart';

class DouyinParser implements ParserInterface {
  const DouyinParser();

  @override
  MediaPlatform get platform => MediaPlatform.douyin;

  @override
  Future<ParserResult> parse(MediaLink link) async {
    return ParserSuccess(
      VideoInfo(
        id: 'douyin-demo',
        title: '测试视频',
        author: 'MediaFlow Demo',
        authorId: 'mediaflow-demo',
        platform: platform,
        coverUrl: Uri.parse('https://example.test/mediaflow/douyin-cover.jpg'),
        videoUrl: Uri.parse('https://example.test/mediaflow/douyin-demo.mp4'),
        duration: const Duration(minutes: 1, seconds: 45),
        description: '用于验证 MediaFlow 解析架构的抖音模拟数据。',
      ),
    );
  }

  @override
  bool supports(MediaLink link) => link.platform == platform;
}
