import '../../../../core/models/media_link.dart';
import '../../domain/parser_interface.dart';
import '../../domain/parser_result.dart';

class BilibiliParser implements ParserInterface {
  const BilibiliParser();

  @override
  MediaPlatform get platform => MediaPlatform.bilibili;

  @override
  Future<ParserResult> parse(MediaLink link) async {
    return const ParserFailure(
      code: 'not_implemented',
      message: 'Bilibili parsing is not implemented yet.',
    );
  }

  @override
  bool supports(MediaLink link) => link.platform == platform;
}
