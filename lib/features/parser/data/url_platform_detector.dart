import '../../../core/models/media_link.dart';
import '../domain/platform_detector.dart';

class UrlPlatformDetector implements PlatformDetector {
  const UrlPlatformDetector();

  static const _douyinHosts = {'douyin.com', 'iesdouyin.com'};
  static const _bilibiliHosts = {'bilibili.com', 'b23.tv', 'bili2233.cn'};

  @override
  MediaPlatform detect(Uri uri) {
    final host = uri.host.toLowerCase();

    if (_matchesHost(host, _douyinHosts)) {
      return MediaPlatform.douyin;
    }
    if (_matchesHost(host, _bilibiliHosts)) {
      return MediaPlatform.bilibili;
    }
    return MediaPlatform.unknown;
  }

  bool _matchesHost(String host, Set<String> candidates) {
    return candidates.any(
      (candidate) => host == candidate || host.endsWith('.$candidate'),
    );
  }
}
