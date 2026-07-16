import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../../core/logging/app_logger.dart';
import '../../../../core/models/media_link.dart';
import '../../../../core/network/network_client.dart';
import '../../domain/parser_interface.dart';
import '../../domain/parser_result.dart';
import '../../domain/video_info.dart';

class DouyinParser implements ParserInterface {
  factory DouyinParser({required NetworkClient networkClient}) {
    return DouyinParser._(networkClient);
  }

  DouyinParser._(this._networkClient);

  static const _headers = <String, String>{
    'Accept':
        'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
  };

  final NetworkClient _networkClient;

  @override
  MediaPlatform get platform => MediaPlatform.douyin;

  @override
  Future<ParserResult> parse(MediaLink link) async {
    try {
      final response = await _networkClient.get(
        link.normalizedUri,
        headers: _headers,
      );
      final statusFailure = _failureForStatus(response.statusCode);
      if (statusFailure != null) {
        return statusFailure;
      }

      final document = html_parser.parse(response.body);
      if (_looksExpired(document)) {
        return const ParserFailure(
          code: ParserFailureCode.linkExpired,
          message: '该抖音作品不存在、已删除或暂时无法访问。',
        );
      }

      final structured = _extractStructuredVideo(document);
      final embedded = _extractEmbeddedVideo(document);
      final openGraph = _extractOpenGraph(document);
      final metadata = _mergeVideoData(embedded, structured, openGraph);
      if (metadata == null || metadata.title == null) {
        return const ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: '未能从抖音页面中提取视频信息，页面结构可能已更新。',
        );
      }

      final resolvedUri = response.finalUri;
      final id =
          metadata.id ??
          _extractVideoId(resolvedUri) ??
          _extractVideoId(link.normalizedUri) ??
          resolvedUri.toString().hashCode.abs().toString();

      return ParserSuccess(
        VideoInfo(
          id: id,
          title: metadata.title!,
          author: metadata.author,
          authorId: metadata.authorId,
          coverUrl: metadata.coverUrl,
          videoUrl: metadata.videoUrl ?? resolvedUri,
          platform: platform,
          duration: metadata.duration,
          description: metadata.description,
          metadata: <String, Object?>{
            'sourceUrl': link.originalUrl,
            'resolvedUrl': resolvedUri.toString(),
            'mediaUrlAvailable': metadata.videoUrl != null,
            'downloadHeaders': <String, String>{
              'Referer': resolvedUri.origin,
              'User-Agent': _headers['User-Agent']!,
            },
          },
        ),
      );
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.error(
        'Douyin request timed out',
        error: error,
        stackTrace: stackTrace,
      );
      return ParserFailure(
        code: ParserFailureCode.networkError,
        message: '连接抖音超时，请稍后重试。',
        cause: error,
      );
    } on NetworkRequestException catch (error, stackTrace) {
      AppLogger.error(
        'Douyin network request failed',
        error: error,
        stackTrace: stackTrace,
      );
      return ParserFailure(
        code: ParserFailureCode.networkError,
        message: '无法连接抖音，请检查网络后重试。',
        cause: error,
      );
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(
        'Douyin response decoding failed',
        error: error,
        stackTrace: stackTrace,
      );
      return ParserFailure(
        code: ParserFailureCode.parseFailed,
        message: '抖音页面数据解析失败。',
        cause: error,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Douyin parsing failed',
        error: error,
        stackTrace: stackTrace,
      );
      return ParserFailure(
        code: ParserFailureCode.parseFailed,
        message: '抖音视频信息解析失败。',
        cause: error,
      );
    }
  }

  @override
  bool supports(MediaLink link) => link.platform == platform;

  ParserFailure? _failureForStatus(int statusCode) {
    if (statusCode == 404 || statusCode == 410) {
      return const ParserFailure(
        code: ParserFailureCode.linkExpired,
        message: '该抖音链接已失效。',
      );
    }
    if (statusCode < 200 || statusCode >= 300) {
      return ParserFailure(
        code: ParserFailureCode.networkError,
        message: '抖音服务请求失败（HTTP $statusCode）。',
      );
    }
    return null;
  }

  bool _looksExpired(Document document) {
    final text = document.body?.text ?? '';
    return text.contains('视频不存在') ||
        text.contains('作品不存在') ||
        text.contains('作品已删除') ||
        text.contains('内容暂时无法查看');
  }

  _DouyinVideoData? _mergeVideoData(
    _DouyinVideoData? primary,
    _DouyinVideoData? secondary,
    _DouyinVideoData? fallback,
  ) {
    return primary?.merge(secondary).merge(fallback) ??
        secondary?.merge(fallback) ??
        fallback;
  }

  _DouyinVideoData? _extractStructuredVideo(Document document) {
    for (final script in document.querySelectorAll(
      'script[type="application/ld+json"]',
    )) {
      final decoded = _tryDecodeJson(script.text);
      final videoObject = _findJsonLdVideo(decoded);
      if (videoObject == null) {
        continue;
      }

      final author = videoObject['author'];
      final authorMap = author is Map<String, dynamic> ? author : null;
      return _DouyinVideoData(
        id: _stringValue(videoObject['identifier']),
        title:
            _stringValue(videoObject['name']) ??
            _stringValue(videoObject['headline']),
        author: authorMap == null
            ? _stringValue(author)
            : _stringValue(authorMap['name']),
        authorId: authorMap == null
            ? null
            : _stringValue(authorMap['identifier']),
        coverUrl: _uriFromValue(videoObject['thumbnailUrl']),
        videoUrl:
            _uriFromValue(videoObject['contentUrl']) ??
            _uriFromValue(videoObject['embedUrl']),
        duration: _parseIsoDuration(_stringValue(videoObject['duration'])),
        description: _stringValue(videoObject['description']),
      );
    }
    return null;
  }

  _DouyinVideoData? _extractEmbeddedVideo(Document document) {
    for (final script in document.querySelectorAll('script')) {
      final id = script.id.toLowerCase();
      if (!id.contains('render_data') &&
          !id.contains('universal_data') &&
          !script.text.contains('aweme')) {
        continue;
      }

      final decoded = _tryDecodeJson(script.text);
      final candidate = _findAwemeMap(decoded);
      if (candidate != null) {
        return _dataFromAwemeMap(candidate);
      }
    }
    return null;
  }

  _DouyinVideoData? _extractOpenGraph(Document document) {
    final title = _metaContent(document, property: 'og:title');
    if (title == null) {
      return null;
    }
    return _DouyinVideoData(
      title: title,
      author: _metaContent(document, name: 'author'),
      coverUrl: _uriFromValue(_metaContent(document, property: 'og:image')),
      videoUrl: _uriFromValue(_metaContent(document, property: 'og:video')),
      duration: _durationFromSeconds(
        _metaContent(document, property: 'video:duration'),
      ),
      description: _metaContent(document, property: 'og:description'),
    );
  }

  Object? _tryDecodeJson(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(text);
    } on FormatException {
      if (!text.contains('%')) {
        return null;
      }
    }

    try {
      return jsonDecode(Uri.decodeComponent(text));
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  Map<String, dynamic>? _findJsonLdVideo(Object? value) {
    if (value is List) {
      for (final child in value) {
        final result = _findJsonLdVideo(child);
        if (result != null) {
          return result;
        }
      }
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final type = map['@type'];
      if (type == 'VideoObject' ||
          (type is List && type.contains('VideoObject'))) {
        return map;
      }
      for (final child in map.values) {
        final result = _findJsonLdVideo(child);
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? _findAwemeMap(Object? value) {
    if (value is List) {
      for (final child in value) {
        final result = _findAwemeMap(child);
        if (result != null) {
          return result;
        }
      }
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final video = map['video'];
      final author = map['author'];
      if (video is Map &&
          author is Map &&
          (map.containsKey('desc') || map.containsKey('title'))) {
        return map;
      }
      for (final child in map.values) {
        final result = _findAwemeMap(child);
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }

  _DouyinVideoData _dataFromAwemeMap(Map<String, dynamic> map) {
    final author = Map<String, dynamic>.from(map['author'] as Map);
    final video = Map<String, dynamic>.from(map['video'] as Map);
    return _DouyinVideoData(
      id:
          _stringValue(map['aweme_id']) ??
          _stringValue(map['id']) ??
          _stringValue(map['itemId']),
      title: _stringValue(map['desc']) ?? _stringValue(map['title']),
      author: _stringValue(author['nickname']) ?? _stringValue(author['name']),
      authorId:
          _stringValue(author['unique_id']) ??
          _stringValue(author['sec_uid']) ??
          _stringValue(author['uid']),
      coverUrl:
          _uriFromUrlContainer(video['cover']) ??
          _uriFromUrlContainer(video['origin_cover']) ??
          _uriFromUrlContainer(video['dynamic_cover']),
      videoUrl:
          _uriFromUrlContainer(video['play_addr']) ??
          _uriFromUrlContainer(video['playAddr']),
      duration: _durationFromMilliseconds(video['duration']),
      description: _stringValue(map['desc']),
    );
  }

  String? _metaContent(Document document, {String? property, String? name}) {
    for (final element in document.querySelectorAll('meta')) {
      if ((property != null && element.attributes['property'] == property) ||
          (name != null && element.attributes['name'] == name)) {
        return _stringValue(element.attributes['content']);
      }
    }
    return null;
  }

  String? _extractVideoId(Uri uri) {
    final pathMatch = RegExp(r'/video/(\d+)').firstMatch(uri.path);
    return pathMatch?.group(1) ?? uri.queryParameters['modal_id'];
  }

  String? _stringValue(Object? value) {
    if (value is List && value.isNotEmpty) {
      return _stringValue(value.first);
    }
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Uri? _uriFromValue(Object? value) {
    final text = _stringValue(value);
    if (text == null) {
      return null;
    }
    final normalized = text.startsWith('//') ? 'https:$text' : text;
    final uri = Uri.tryParse(normalized);
    return uri != null && uri.hasScheme ? uri : null;
  }

  Uri? _uriFromUrlContainer(Object? value) {
    if (value is String || value is List) {
      return _uriFromValue(value);
    }
    if (value is Map) {
      return _uriFromValue(value['url_list']) ??
          _uriFromValue(value['urlList']) ??
          _uriFromValue(value['url']);
    }
    return null;
  }

  Duration? _durationFromSeconds(Object? value) {
    final seconds = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  Duration? _durationFromMilliseconds(Object? value) {
    final milliseconds = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    if (milliseconds == null) {
      return null;
    }
    return Duration(milliseconds: milliseconds);
  }

  Duration? _parseIsoDuration(String? value) {
    if (value == null) {
      return null;
    }
    final match = RegExp(
      r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?$',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = double.tryParse(match.group(3) ?? '') ?? 0;
    return Duration(
      hours: hours,
      minutes: minutes,
      milliseconds: (seconds * 1000).round(),
    );
  }
}

class _DouyinVideoData {
  const _DouyinVideoData({
    this.id,
    this.title,
    this.author,
    this.authorId,
    this.coverUrl,
    this.videoUrl,
    this.duration,
    this.description,
  });

  _DouyinVideoData merge(_DouyinVideoData? fallback) {
    if (fallback == null) {
      return this;
    }
    return _DouyinVideoData(
      id: id ?? fallback.id,
      title: title ?? fallback.title,
      author: author ?? fallback.author,
      authorId: authorId ?? fallback.authorId,
      coverUrl: coverUrl ?? fallback.coverUrl,
      videoUrl: videoUrl ?? fallback.videoUrl,
      duration: duration ?? fallback.duration,
      description: description ?? fallback.description,
    );
  }

  final String? id;
  final String? title;
  final String? author;
  final String? authorId;
  final Uri? coverUrl;
  final Uri? videoUrl;
  final Duration? duration;
  final String? description;
}
