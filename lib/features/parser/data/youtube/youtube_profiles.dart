// Android protocol profiles are based on youtube_explode_dart 3.1.0
// (BSD-3-Clause). See third_party/youtube_protocol/NOTICE.md and LICENSE.
// VISIONOS preserves the protocol profile validated in MediaFlow research.
final class YoutubeProfile {
  const YoutubeProfile(this.name, this.number, this.context);
  final String name;
  final int number;
  final Map<String, Object?> context;
  static const sdkless = YoutubeProfile('ANDROID_SDKLESS', 3, {
    'clientName': 'ANDROID',
    'clientVersion': '20.10.38',
    'userAgent':
        'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
    'hl': 'en',
    'timeZone': 'UTC',
    'utcOffsetMinutes': 0,
    'osName': 'Android',
    'osVersion': '11',
  });
  static final android = YoutubeProfile('ANDROID', 3, {
    ...sdkless.context,
    'androidSdkVersion': 30,
  });
  static const vision = YoutubeProfile('VISIONOS', 101, {
    'clientName': 'VISIONOS',
    'clientVersion': '1.02',
    'deviceMake': 'Apple',
    'deviceModel': 'RealityDevice17,1',
    'osName': 'visionOS',
    'osVersion': '26.5.23O471',
    'userAgent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15',
    'hl': 'en',
    'utcOffsetMinutes': 0,
  });
}
