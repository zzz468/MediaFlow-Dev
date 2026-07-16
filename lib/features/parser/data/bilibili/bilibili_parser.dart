import 'dart:async';
import 'dart:convert';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/models/media_link.dart';
import '../../../../core/network/network_client.dart';
import '../../domain/parser_interface.dart';
import '../../domain/parser_result.dart';
import '../../domain/video_info.dart';

class BilibiliParser implements ParserInterface {
  factory BilibiliParser({required NetworkClient networkClient}) {
    return BilibiliParser._(networkClient);
  }

  BilibiliParser._(this._networkClient);

  static const _headers = <String, String>{
    'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
    'Referer': 'https://www.bilibili.com/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
  };

  final NetworkClient _networkClient;

  @override
  MediaPlatform get platform => MediaPlatform.bilibili;

  @override
  Future<ParserResult> parse(MediaLink link) async {
    try {
      final sourceUri = await _resolveShortLink(link.normalizedUri);
      final videoId =
          _extractVideoId(sourceUri) ?? _extractVideoId(link.normalizedUri);
      if (videoId == null) {
        return const ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: '无法从 Bilibili 链接中识别视频编号。',
        );
      }

      final query = videoId.startsWith('BV')
          ? <String, String>{'bvid': videoId}
          : <String, String>{'aid': videoId.substring(2)};
      final response = await _networkClient.get(
        Uri.https('api.bilibili.com', '/x/web-interface/view', query),
        headers: _headers,
      );
      final statusFailure = _failureForStatus(response.statusCode);
      if (statusFailure != null) {
        return statusFailure;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return const ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: 'Bilibili 返回了无法识别的数据格式。',
        );
      }

      final code = _asInt(payload['code']);
      if (code != 0) {
        if (code == -404 || code == 62002) {
          return const ParserFailure(
            code: ParserFailureCode.linkExpired,
            message: '该 Bilibili 视频不存在、已失效或无权访问。',
          );
        }
        return ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: _asString(payload['message']) ?? 'Bilibili 视频信息解析失败。',
        );
      }

      final data = payload['data'];
      if (data is! Map<String, dynamic>) {
        return const ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: 'Bilibili 视频信息为空。',
        );
      }

      final title = _asString(data['title']);
      final bvid = _asString(data['bvid']);
      final aid = _asInt(data['aid']);
      if (title == null || (bvid == null && aid == null)) {
        return const ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: 'Bilibili 视频信息缺少必要字段。',
        );
      }

      final owner = data['owner'] is Map<String, dynamic>
          ? data['owner'] as Map<String, dynamic>
          : const <String, dynamic>{};
      final canonicalId = bvid ?? 'av$aid';
      final coverUrl = _parseWebUri(_asString(data['pic']));
      final downloadInfo = await _loadDownloadInfo(
        videoId: canonicalId,
        cid: _asInt(data['cid']),
      );

      return ParserSuccess(
        VideoInfo(
          id: canonicalId,
          title: title,
          author: _asString(owner['name']),
          authorId: owner['mid']?.toString(),
          coverUrl: coverUrl,
          videoUrl:
              downloadInfo?.url ??
              Uri.https('www.bilibili.com', '/video/$canonicalId'),
          platform: platform,
          duration: _durationFromSeconds(data['duration']),
          description: _asString(data['desc']),
          metadata: <String, Object?>{
            'sourceUrl': link.originalUrl,
            'mediaUrlAvailable': downloadInfo != null,
            'downloadHeaders': downloadInfo == null
                ? const <String, String>{}
                : const <String, String>{
                    'Referer': 'https://www.bilibili.com/',
                    'User-Agent':
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                        'AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
                  },
            'downloadSize': downloadInfo?.size,
            'downloadQuality': downloadInfo?.quality,
            'aid': aid,
            'bvid': bvid,
            'cid': _asInt(data['cid']),
            'pages': data['pages'],
            'stat': data['stat'],
          },
        ),
      );
    } on _BilibiliResponseException catch (error) {
      return error.failure;
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.error(
        'Bilibili request timed out',
        error: error,
        stackTrace: stackTrace,
      );
      return ParserFailure(
        code: ParserFailureCode.networkError,
        message: '连接 Bilibili 超时，请稍后重试。',
        cause: error,
      );
    } on NetworkRequestException catch (error, stackTrace) {
      AppLogger.error(
        'Bilibili network request failed',
        error: error,
        stackTrace: stackTrace,
      );
      return ParserFailure(
        code: ParserFailureCode.networkError,
        message: '无法连接 Bilibili，请检查网络后重试。',
        cause: error,
      );
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(
        'Bilibili response decoding failed',
        error: error,
        stackTrace: stackTrace,
      );
      return ParserFailure(
        code: ParserFailureCode.parseFailed,
        message: 'Bilibili 返回数据解析失败。',
        cause: error,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Bilibili parsing failed',
        error: error,
        stackTrace: stackTrace,
      );
      return ParserFailure(
        code: ParserFailureCode.parseFailed,
        message: 'Bilibili 视频信息解析失败。',
        cause: error,
      );
    }
  }

  @override
  bool supports(MediaLink link) => link.platform == platform;

  Future<_BilibiliDownloadInfo?> _loadDownloadInfo({
    required String videoId,
    required int? cid,
  }) async {
    if (cid == null) {
      return null;
    }

    try {
      final idQuery = videoId.startsWith('BV')
          ? <String, String>{'bvid': videoId}
          : <String, String>{'avid': videoId.substring(2)};
      final response = await _networkClient.get(
        Uri.https('api.bilibili.com', '/x/player/playurl', <String, String>{
          ...idQuery,
          'cid': cid.toString(),
          'qn': '64',
          'fnval': '0',
          'fourk': '0',
        }),
        headers: _headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic> || _asInt(payload['code']) != 0) {
        return null;
      }
      final data = payload['data'];
      if (data is! Map<String, dynamic>) {
        return null;
      }
      final durl = data['durl'];
      if (durl is! List || durl.isEmpty || durl.first is! Map) {
        return null;
      }
      final item = Map<String, dynamic>.from(durl.first as Map);
      final url = _parseWebUri(_asString(item['url']));
      if (url == null) {
        return null;
      }
      return _BilibiliDownloadInfo(
        url: url,
        size: _asInt(item['size']),
        quality: _asInt(data['quality']),
      );
    } catch (error) {
      AppLogger.info('Bilibili download option is temporarily unavailable.');
      return null;
    }
  }

  Future<Uri> _resolveShortLink(Uri uri) async {
    if (uri.host != 'b23.tv' && uri.host != 'bili2233.cn') {
      return uri;
    }

    final response = await _networkClient.get(uri, headers: _headers);
    final failure = _failureForStatus(response.statusCode);
    if (failure != null) {
      throw _BilibiliResponseException(failure);
    }
    return response.finalUri;
  }

  String? _extractVideoId(Uri uri) {
    final pathMatch = RegExp(
      r'/video/(BV[0-9A-Za-z]+|av\d+)',
      caseSensitive: false,
    ).firstMatch(uri.path);
    final value = pathMatch?.group(1) ?? uri.queryParameters['bvid'];
    if (value == null) {
      return null;
    }
    if (value.toLowerCase().startsWith('av')) {
      return 'av${value.substring(2)}';
    }
    return 'BV${value.substring(2)}';
  }

  ParserFailure? _failureForStatus(int statusCode) {
    if (statusCode == 404 || statusCode == 410) {
      return const ParserFailure(
        code: ParserFailureCode.linkExpired,
        message: '该 Bilibili 链接已失效。',
      );
    }
    if (statusCode < 200 || statusCode >= 300) {
      return ParserFailure(
        code: ParserFailureCode.networkError,
        message: 'Bilibili 服务请求失败（HTTP $statusCode）。',
      );
    }
    return null;
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String? _asString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Duration? _durationFromSeconds(Object? value) {
    final seconds = _asInt(value);
    return seconds == null ? null : Duration(seconds: seconds);
  }

  Uri? _parseWebUri(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.startsWith('//') ? 'https:$value' : value;
    final uri = Uri.tryParse(normalized);
    return uri != null && uri.hasScheme ? uri : null;
  }
}

class _BilibiliDownloadInfo {
  const _BilibiliDownloadInfo({
    required this.url,
    required this.size,
    required this.quality,
  });

  final Uri url;
  final int? size;
  final int? quality;
}

class _BilibiliResponseException implements Exception {
  const _BilibiliResponseException(this.failure);

  final ParserFailure failure;
}
