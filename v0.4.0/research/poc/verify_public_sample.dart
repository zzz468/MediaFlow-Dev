// Isolated sample availability check; no parser, cookies, proxy, or saved body.
import 'dart:convert';
import 'dart:io';
import 'douyin_gallery_probe.dart' as probe;

Future<void> main(List<String> args) async {
  final ids = args
      .where((arg) => RegExp(r'^\d{15,22}$').hasMatch(arg))
      .toList();
  if (ids.length > 1) {
    stderr.writeln('Provide at most one publicly sourced numeric note ID.');
    exitCode = 2;
    return;
  }
  final expectedId = ids.isEmpty ? '7626598460468333858' : ids.single;
  final shareArgs = args.where((arg) => arg.startsWith('--share=')).toList();
  if (shareArgs.length > 1) {
    stderr.writeln('Provide at most one public share URL.');
    exitCode = 2;
    return;
  }
  Uri? share;
  if (shareArgs.isNotEmpty) {
    share = Uri.tryParse(shareArgs.single.substring('--share='.length));
    if (share == null ||
        share.scheme != 'https' ||
        share.host != 'v.douyin.com' ||
        share.userInfo.isNotEmpty ||
        share.hasQuery ||
        share.hasFragment) {
      stderr.writeln('Provide a plain public https://v.douyin.com/ share URL.');
      exitCode = 2;
      return;
    }
  }
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12)
    ..idleTimeout = const Duration(seconds: 12);
  client.findProxy = (_) => 'DIRECT';
  final samples = <Uri>[
    if (share != null) share,
    if (ids.isEmpty) Uri.parse('https://v.douyin.com/8SOAeTUxRo8/'),
    Uri.parse('https://www.iesdouyin.com/share/note/$expectedId/'),
    Uri.parse('https://www.douyin.com/note/$expectedId'),
  ];
  if (args.contains('--mobile-only')) {
    samples.removeWhere((url) => url.host != 'www.iesdouyin.com');
  }
  try {
    for (final original in samples) {
      var current = original;
      for (var hop = 0; hop < 4; hop++) {
        if (current.scheme != 'https' || !isDouyinHost(current.host)) {
          print('STOP disallowed redirect target');
          break;
        }
        try {
          final request = await client
              .getUrl(current)
              .timeout(const Duration(seconds: 15));
          request.followRedirects = false;
          request.headers.set(HttpHeaders.acceptHeader, 'text/html');
          request.headers.set(
            HttpHeaders.userAgentHeader,
            original.host == 'www.iesdouyin.com'
                ? 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36'
                : 'Mozilla/5.0 (compatible; MediaFlowResearch/0.4)',
          );
          request.headers.removeAll(HttpHeaders.cookieHeader);
          final response = await request.close().timeout(
            const Duration(seconds: 15),
          );
          final location = response.headers.value(HttpHeaders.locationHeader);
          print(
            'CHECK sourceHost=${original.host} host=${current.host} '
            'path=${current.path} status=${response.statusCode} '
            'type=${response.headers.contentType?.mimeType ?? 'absent'} '
            'setCookie=${response.headers[HttpHeaders.setCookieHeader]?.isNotEmpty ?? false} '
            'sentCookie=false redirect=${location != null}',
          );
          if (location != null && response.isRedirect) {
            current = current.resolve(location);
            await response.drain<void>().timeout(const Duration(seconds: 15));
            continue;
          }
          var bytes = 0;
          var targetIdInBody = false;
          final chunks = <int>[];
          await for (final chunk in response.timeout(
            const Duration(seconds: 20),
          )) {
            bytes += chunk.length;
            if (bytes > 512 * 1024)
              throw const FormatException('Body over cap');
            chunks.addAll(chunk);
          }
          targetIdInBody = String.fromCharCodes(chunks).contains(expectedId);
          final body = utf8.decode(chunks, allowMalformed: true);
          final parsed = probe.parseStructured(
            body,
            response.headers.contentType?.mimeType ?? 'text/html',
            expectedId,
          );
          final markers = <String>[
            for (final marker in [
              '_ROUTER_DATA',
              'RENDER_DATA',
              '__INITIAL_STATE__',
              'SIGI_STATE',
              'videoInfoRes',
              'item_list',
              'aweme_id',
              'image_post_info',
              'images_v2',
              'images',
              'url_list',
              'slides',
              'note',
            ])
              if (body.contains(marker)) marker,
          ];
          final scripts = RegExp(
            r'<script\b([^>]*)>([\s\S]*?)<\/script>',
            caseSensitive: false,
          ).allMatches(body).toList();
          final matchingScripts = scripts.where(
            (m) => m.group(2)!.contains(expectedId),
          );
          for (final script in matchingScripts) {
            final content = script.group(2)!.trim();
            final open = content.indexOf('{');
            final close = content.lastIndexOf('}');
            Object? root;
            if (open >= 0 && close > open) {
              try {
                root = jsonDecode(content.substring(open, close + 1));
              } catch (_) {
                /* non-JSON JS */
              }
            }
            final keys = root is Map
                ? root.keys.take(10).join(',')
                : 'unparsed';
            final idPaths = <String>[];
            void walk(Object? value, String path, int depth) {
              if (depth > 20 || idPaths.length >= 8) return;
              if (value is Map) {
                for (final entry in value.entries) {
                  final child = '$path.${entry.key}';
                  if (entry.value?.toString() == expectedId) idPaths.add(child);
                  walk(entry.value, child, depth + 1);
                }
              } else if (value is List) {
                for (var i = 0; i < value.length && i < 100; i++) {
                  walk(value[i], '$path[$i]', depth + 1);
                }
              }
            }

            walk(root, 'root', 0);
            print(
              'SCRIPT sourceHost=${original.host} chars=${content.length} '
              'jsonParsed=${root != null} rootKeys=$keys idPaths=${idPaths.join(',')}',
            );
          }
          print(
            'FINAL sourceHost=${original.host} host=${current.host} '
            'path=${current.path} bytes=$bytes targetIdInBody=$targetIdInBody '
            'noteDetail=${body.contains('note-detail')} '
            'imagePostInfo=${body.contains('image_post_info')} '
            'jsonLd=${body.contains('application/ld+json')} '
            'ogImage=${body.contains('og:image')} markers=${markers.join(',')} '
            'scriptCount=${scripts.length} matchingScripts=${matchingScripts.length} '
            'exactTarget=${parsed.target != null} imageField=${parsed.field ?? 'absent'} '
            'imageCount=${parsed.images.length} '
            'distinctCandidateUrls=${parsed.images.toSet().length}',
          );
          break;
        } catch (e) {
          print('ERROR sourceHost=${original.host} type=${e.runtimeType}');
          break;
        }
      }
    }
  } finally {
    client.close(force: true);
  }
}

bool isDouyinHost(String host) =>
    host == 'douyin.com' ||
    host.endsWith('.douyin.com') ||
    host == 'iesdouyin.com' ||
    host.endsWith('.iesdouyin.com');
