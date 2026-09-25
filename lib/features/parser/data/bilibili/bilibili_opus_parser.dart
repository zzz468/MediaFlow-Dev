import 'dart:async';
import 'dart:convert';

import '../../../../core/models/media_link.dart';
import '../../../../core/network/network_client.dart';
import '../../domain/media_content.dart';
import '../../domain/parser_interface.dart';
import '../../domain/parser_result.dart';

/// Reads public opus page data. Video URLs remain with BilibiliParser.
final class BilibiliOpusParser implements ParserInterface {
  BilibiliOpusParser({required NetworkClient networkClient})
    : this._(networkClient);

  BilibiliOpusParser._(this._networkClient);

  final NetworkClient _networkClient;

  static const _pageHeaders = <String, String>{
    'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
    'Referer': 'https://www.bilibili.com/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
  };
  static const _resourceHeaders = <String, String>{
    'Referer': 'https://www.bilibili.com/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
  };

  @override
  MediaPlatform get platform => MediaPlatform.bilibili;

  @override
  bool supports(MediaLink link) =>
      link.platform == platform && _opusId(link.normalizedUri) != null;

  @override
  Future<ParserResult> parse(MediaLink link) async {
    final id = _opusId(link.normalizedUri);
    if (link.platform != platform || id == null) {
      return const ParserFailure(
        code: ParserFailureCode.parseFailed,
        message: '不是有效的 Bilibili 图文作品链接。',
      );
    }
    final sourceUrl = Uri.https('www.bilibili.com', '/opus/$id');
    try {
      final response = await _networkClient.get(
        sourceUrl,
        headers: _pageHeaders,
      );
      if (response.statusCode == 404 || response.statusCode == 410) {
        return const ParserFailure(
          code: ParserFailureCode.linkExpired,
          message: '该 Bilibili 图文作品不存在或无法公开访问。',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ParserFailure(
          code: ParserFailureCode.networkError,
          message: 'Bilibili 图文页面请求失败（HTTP ${response.statusCode}）。',
        );
      }
      if (response.finalUri.host != sourceUrl.host ||
          response.finalUri.path != sourceUrl.path) {
        return const ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: 'Bilibili 图文页面跳转到其他地址，无法安全解析。',
        );
      }
      final html = response.body;
      if (html.contains('验证码_哔哩哔哩')) {
        return const ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: 'Bilibili 要求安全验证，已停止图文解析。',
        );
      }
      final state = _embeddedState(html);
      if (state == null) {
        return const ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: 'Bilibili 图文页面缺少可识别的公开作品数据。',
        );
      }
      final opus = state['opus'];
      final detail = state['detail'] ?? (opus is Map ? opus['detail'] : null);
      if (detail is! Map || detail['id_str']?.toString() != id) {
        return const ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: 'Bilibili 图文作品数据结构或作品编号无法确认。',
        );
      }
      final content = _contentFromDetail(detail, id, sourceUrl);
      return content == null
          ? const ParserFailure(
              code: ParserFailureCode.parseFailed,
              message: 'Bilibili 图文作品没有可识别的图片资源。',
            )
          : ParserContentSuccess(content);
    } on TimeoutException {
      return const ParserFailure(
        code: ParserFailureCode.networkError,
        message: '连接 Bilibili 图文页面超时。',
      );
    } on NetworkRequestException {
      return const ParserFailure(
        code: ParserFailureCode.networkError,
        message: '无法连接 Bilibili 图文页面。',
      );
    } on FormatException {
      return const ParserFailure(
        code: ParserFailureCode.parseFailed,
        message: 'Bilibili 图文作品数据不是有效 JSON。',
      );
    } on ArgumentError {
      return const ParserFailure(
        code: ParserFailureCode.parseFailed,
        message: 'Bilibili 图文作品包含无效资源地址。',
      );
    }
  }

  static String? _opusId(Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    final host = uri.host.toLowerCase();
    if (host != 'bilibili.com' &&
        host != 'www.bilibili.com' &&
        host != 'm.bilibili.com') {
      return null;
    }
    final match = RegExp(r'^/opus/(\d+)/?$').firstMatch(uri.path);
    return match?.group(1);
  }

  static Map<String, dynamic>? _embeddedState(String html) {
    const marker = 'window.__INITIAL_STATE__=';
    final markerStart = html.indexOf(marker);
    if (markerStart < 0) return null;
    final start = markerStart + marker.length;
    if (start >= html.length || html[start] != '{') return null;
    var depth = 0;
    var quoted = false;
    var escaped = false;
    for (var index = start; index < html.length; index++) {
      final char = html[index];
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          quoted = false;
        }
      } else if (char == '"') {
        quoted = true;
      } else if (char == '{') {
        depth += 1;
      } else if (char == '}') {
        depth -= 1;
        if (depth == 0) {
          final value = jsonDecode(html.substring(start, index + 1));
          return value is Map<String, dynamic> ? value : null;
        }
      }
    }
    return null;
  }

  static MediaContent? _contentFromDetail(Map detail, String id, Uri source) {
    final modules = detail['modules'];
    if (modules is! List) return null;
    String? title = _text(
      (detail['basic'] is Map) ? (detail['basic'] as Map)['title'] : null,
    );
    String? author;
    final body = StringBuffer();
    final resources = <MediaResource>[];
    for (final module in modules.whereType<Map>()) {
      switch (module['module_type']) {
        case 'MODULE_TYPE_TITLE':
          title ??= _text(
            (module['module_title'] is Map)
                ? (module['module_title'] as Map)['text']
                : null,
          );
        case 'MODULE_TYPE_AUTHOR':
          author ??= _text(
            (module['module_author'] is Map)
                ? (module['module_author'] as Map)['name']
                : null,
          );
        case 'MODULE_TYPE_CONTENT':
          final content = module['module_content'];
          final paragraphs = content is Map ? content['paragraphs'] : null;
          if (paragraphs is! List) continue;
          for (final paragraph in paragraphs.whereType<Map>()) {
            if (paragraph['para_type'] == 1) {
              final rawText = paragraph['text'];
              final nodes = rawText is Map ? rawText['nodes'] : null;
              if (nodes is List) {
                for (final node in nodes.whereType<Map>()) {
                  final word = node['word'];
                  final text = word is Map ? _text(word['words']) : null;
                  if (text != null) body.write(text);
                }
              }
            } else if (paragraph['para_type'] == 2) {
              final rawPic = paragraph['pic'];
              final pics = rawPic is Map ? rawPic['pics'] : null;
              if (pics is! List) continue;
              for (final pic in pics.whereType<Map>()) {
                final rawUrl = _text(pic['url']);
                if (rawUrl == null) return null;
                final uri = Uri.tryParse(
                  rawUrl.startsWith('//') ? 'https:$rawUrl' : rawUrl,
                );
                if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
                  return null;
                }
                final index = resources.length + 1;
                final sequence = index.toString().padLeft(3, '0');
                final extension = uri.path.toLowerCase().split('.').last;
                final mime = switch (extension) {
                  'jpg' || 'jpeg' => 'image/jpeg',
                  'png' => 'image/png',
                  'webp' => 'image/webp',
                  'gif' => 'image/gif',
                  _ => null,
                };
                resources.add(
                  MediaResource(
                    id: 'image-$sequence',
                    type: MediaResourceType.image,
                    url: uri,
                    requestHeaders: _resourceHeaders,
                    mimeType: mime,
                    suggestedFileName: 'bilibili-opus-$id',
                  ),
                );
              }
            }
          }
      }
    }
    if (resources.isEmpty) return null;
    return MediaContent(
      id: id,
      platform: MediaPlatform.bilibili,
      title: title ?? 'Bilibili 图文 $id',
      sourceUrl: source,
      type: resources.length == 1
          ? MediaContentType.image
          : MediaContentType.imageGallery,
      author: author,
      description: _text(body.toString()),
      resources: resources,
    );
  }

  static String? _text(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }
}
