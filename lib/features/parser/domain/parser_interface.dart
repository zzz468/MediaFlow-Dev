import '../../../core/models/media_link.dart';
import 'parser_result.dart';

abstract interface class ParserInterface {
  MediaPlatform get platform;

  bool supports(MediaLink link);

  Future<ParserResult> parse(MediaLink link);
}
