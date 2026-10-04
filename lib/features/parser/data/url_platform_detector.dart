import '../../../core/models/media_link.dart';
import '../domain/platform_detector.dart';
import 'youtube/youtube_url.dart';
import 'instagram/instagram_url.dart';
import 'x/x_url.dart';

class UrlPlatformDetector implements PlatformDetector {
  const UrlPlatformDetector();

  static const _douyinHosts = {'douyin.com', 'iesdouyin.com'};
  static const _bilibiliHosts = {'bilibili.com', 'b23.tv', 'bili2233.cn'};
  static const _xiaohongshuHosts = {
    'xiaohongshu.com',
    'xhslink.cn',
    'xhslink.com',
  };

  @override
  MediaPlatform detect(Uri uri) {
    final host = uri.host.toLowerCase();

    if (_matchesHost(host, _douyinHosts)) {
      return MediaPlatform.douyin;
    }
    if (_matchesHost(host, _bilibiliHosts)) {
      return MediaPlatform.bilibili;
    }
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.userInfo.isEmpty &&
        _matchesHost(host, _xiaohongshuHosts)) {
      return MediaPlatform.xiaohongshu;
    }
    if (YoutubeUrl.id(uri) != null) return MediaPlatform.youtube;
    if (InstagramUrl.normalize(uri) != null) return MediaPlatform.instagram;
    if (XUrl.normalize(uri) != null) return MediaPlatform.x;
    return MediaPlatform.unknown;
  }

  bool _matchesHost(String host, Set<String> candidates) {
    return candidates.any(
      (candidate) => host == candidate || host.endsWith('.$candidate'),
    );
  }
}
