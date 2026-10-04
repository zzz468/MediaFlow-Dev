import 'dart:convert';
import 'dart:io';
import '../lib/social_probe.dart';

Future<void> main(List<String> args) async {
  final n = normalize(args.first);
  final root = Directory(args[1])..createSync(recursive: true);
  final d = <String, Object?>{
    'os': Platform.operatingSystem,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
  };
  try {
    final content = await SocialProbe().parse(
      args.first,
      d,
      instagramGraphql: args.contains('--context'),
      initializedContext: args.contains('--context'),
    );
    for (var i = 0; i < content.resources.length; i++) {
      final r = content.resources[i];
      final item = (d['orderedResources'] as List)[i] as Map;
      final dd = <String, Object?>{};
      item['download'] = dd;
      final part = File('${root.path}/${n.id}-${i + 1}.part');
      final sink = part.openWrite();
      try {
        final response = await ProbeHttp().fetch(
          r.url,
          n.platform,
          dd,
          sink: sink,
          budget: 512 * 1024 * 1024,
        );
        await sink.flush();
        await sink.close();
        final ext = response.mime == 'image/png'
            ? 'png'
            : response.mime == 'image/webp'
            ? 'webp'
            : r.type == MediaResourceType.video
            ? 'mp4'
            : 'jpg';
        final file = await part.rename('${root.path}/${n.id}-${i + 1}.$ext');
        dd['fileBytes'] = await file.length();
        dd['savePath'] = file.absolute.path;
        dd['completeDownload'] = true;
      } catch (e) {
        dd['errorCategory'] = categoryFor(e);
        dd['summary'] = e is ProbeFailure ? e.reason : e.runtimeType.toString();
      } finally {
        await sink.close();
      }
    }
  } catch (e) {
    d['errorCategory'] = categoryFor(e);
    d['summary'] = e is ProbeFailure ? e.reason : e.runtimeType.toString();
  }
  await File(
    '${root.path}/validation-${n.id}.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(d));
  print(const JsonEncoder.withIndent('  ').convert(d));
}
