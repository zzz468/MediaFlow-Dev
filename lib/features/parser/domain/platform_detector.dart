import '../../../core/models/media_link.dart';

abstract interface class PlatformDetector {
  MediaPlatform detect(Uri uri);
}
