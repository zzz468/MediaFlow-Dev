import 'dart:io';
import 'android_douyin_session_provider.dart';
import 'windows_douyin_session_provider.dart';
import 'douyin_gallery_backend.dart';
import 'f2_gallery_signer.dart';

DouyinGalleryBackend? installedDouyinGalleryBackend() {
  if (Platform.isAndroid) return createAndroidDouyinGalleryBackend();
  if (!Platform.isWindows) return null;
  final directory = File(Platform.resolvedExecutable).parent.path;
  return DouyinGalleryBackend(
    sessions: WindowsDouyinSessionProvider(
      executable:
          '$directory${Platform.pathSeparator}MediaFlowDouyinSession.exe',
    ),
    client: F2DouyinGalleryDetailClient(
      signer: F2GallerySigner(),
      transport: DirectDouyinDetailTransport(),
      argusCompatibilityHeader: true,
    ),
  );
}
