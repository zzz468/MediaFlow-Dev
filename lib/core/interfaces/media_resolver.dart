import '../models/media_info.dart';
import '../models/media_link.dart';

abstract interface class MediaResolver {
  String get id;

  bool supports(MediaLink link);

  Future<MediaInfo> resolve(MediaLink link);
}

abstract interface class MediaResolverRegistry {
  MediaResolver? findResolver(MediaLink link);
}
