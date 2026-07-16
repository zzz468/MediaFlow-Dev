import '../../../../core/models/media_link.dart';
import '../../domain/parser_interface.dart';
import '../../domain/parser_result.dart';

class DouyinParser implements ParserInterface {
  const DouyinParser();

  @override
  MediaPlatform get platform => MediaPlatform.douyin;

  @override
  Future<ParserResult> parse(MediaLink link) async {
    return const ParserFailure(
      code: 'not_implemented',
      message: 'Douyin parsing is not implemented yet.',
    );
  }

  @override
  bool supports(MediaLink link) => link.platform == platform;
}
