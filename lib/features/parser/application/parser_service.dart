import '../../../core/models/media_link.dart';
import '../../../core/network/network_client.dart';
import '../data/bilibili/bilibili_parser.dart';
import '../data/douyin/douyin_parser.dart';
import '../data/url_platform_detector.dart';
import '../domain/parser_interface.dart';
import '../domain/parser_result.dart';
import '../domain/platform_detector.dart';

class ParserService {
  const ParserService({
    required this.platformDetector,
    required this.parsers,
    this.onClose,
  });

  final PlatformDetector platformDetector;
  final List<ParserInterface> parsers;
  final void Function()? onClose;

  MediaPlatform detectPlatform(Uri uri) => platformDetector.detect(uri);

  Future<ParserResult> parseUri(Uri uri) async {
    final platform = detectPlatform(uri);
    final link = MediaLink(
      originalUrl: uri.toString(),
      normalizedUri: uri,
      platform: platform,
    );
    final parser = _findParser(link);

    if (parser == null) {
      return ParserFailure(
        code: ParserFailureCode.unsupportedPlatform,
        message: '暂不支持 ${platform.displayName} 平台。',
      );
    }

    return parser.parse(link);
  }

  void close() => onClose?.call();

  ParserInterface? _findParser(MediaLink link) {
    for (final parser in parsers) {
      if (parser.supports(link)) {
        return parser;
      }
    }
    return null;
  }
}

ParserService createDefaultParserService() {
  final networkClient = HttpNetworkClient();
  return ParserService(
    platformDetector: const UrlPlatformDetector(),
    parsers: [
      BilibiliParser(networkClient: networkClient),
      DouyinParser(networkClient: networkClient),
    ],
    onClose: networkClient.close,
  );
}
