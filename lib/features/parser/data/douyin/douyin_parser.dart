import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../../core/browser/observation/browser_network_observation.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/models/media_link.dart';
import '../../../../core/network/network_client.dart';
import '../../domain/parser_interface.dart';
import '../../domain/parser_result.dart';
import '../../domain/video_info.dart';

import 'douyin_detail_session.dart';
import 'douyin_mobile_feed_session.dart';
import 'observation/douyin_browser_observation.dart';
import 'observation/douyin_browser_observation_result.dart';
import 'observation/douyin_observed_work.dart';

class DouyinParser implements ParserInterface {
  factory DouyinParser({
    required NetworkClient networkClient,
    NetworkClient? detailNetworkClient,
    NetworkClient? mobileFeedNetworkClient,
    DateTime Function()? now,
    DouyinBrowserObservationCapability? browserObservation,
  }) {
    return DouyinParser._(
      networkClient,
      DouyinDetailSession(client: detailNetworkClient, now: now),
      DouyinMobileFeedSession(client: mobileFeedNetworkClient),
      browserObservation,
    );
  }

  DouyinParser._(
    this._networkClient,
    this._detailSession,
    this._mobileFeedSession,
    this._browserObservation,
  );

  final DouyinDetailSession _detailSession;
  final DouyinMobileFeedSession _mobileFeedSession;
  final DouyinBrowserObservationCapability? _browserObservation;

  static const _headers = <String, String>{
    'Accept':
        'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Mobile) '
        'AppleWebKit/537.36 Chrome/124.0 Mobile Safari/537.36',
  };

  final NetworkClient _networkClient;

  @override
  MediaPlatform get platform => MediaPlatform.douyin;

  @override
  Future<ParserResult> parse(MediaLink link) async {
    try {
      var response = await _networkClient.get(
        link.normalizedUri,
        headers: _headers,
      );
      var statusFailure = _failureForStatus(response.statusCode);
      if (statusFailure != null &&
          (response.statusCode == 404 ||
              response.statusCode == 410 ||
              (_extractVideoId(response.finalUri) == null &&
                  _extractVideoId(link.normalizedUri) == null))) {
        return statusFailure;
      }

      var page = _parsePage(response);
      if (page.isExpired) {
        return _expiredFailure();
      }

      var resolvedUri = response.finalUri;
      var videoId =
          page.data?.id ??
          _extractVideoId(resolvedUri) ??
          _extractVideoId(link.normalizedUri);

      if (!_isComplete(page.data) &&
          videoId != null &&
          resolvedUri.host != 'www.iesdouyin.com') {
        final shareUri = Uri.https(
          'www.iesdouyin.com',
          '/share/video/$videoId/',
        );
        response = await _networkClient.get(shareUri, headers: _headers);
        statusFailure = _failureForStatus(response.statusCode);
        if (response.statusCode == 404 || response.statusCode == 410) {
          return statusFailure!;
        }

        final sharePage = statusFailure == null
            ? _parsePage(response)
            : const _DouyinPageData(data: null, isExpired: false);
        if (sharePage.isExpired) {
          return _expiredFailure();
        }
        page = _DouyinPageData(
          data: page.data?.merge(sharePage.data) ?? sharePage.data,
          isExpired: false,
        );
        resolvedUri = response.finalUri;
      }

      var metadata = page.data;
      var usedDetail = false;
      var usedMobileFeed = false;
      var detailMedia = false;
      var mobileFeedMedia = false;
      var browserMedia = false;
      var browserObservationUsed = false;
      DouyinBrowserObservationAttempt? browserAttempt;
      if (!_isComplete(metadata) && videoId != null) {
        final feed = await _mobileFeedSession.fetch(videoId);
        final work = feed.work;
        if (work != null) {
          final data = _dataFromAwemeMap(work);
          if (_isComplete(data) &&
              data.id == videoId &&
              data.videoUrl!.hasAuthority &&
              const ['http', 'https'].contains(data.videoUrl!.scheme) &&
              data.qualityOptions.every(
                (option) =>
                    option.url.hasAuthority &&
                    const ['http', 'https'].contains(option.url.scheme),
              )) {
            mobileFeedMedia = metadata?.videoUrl == null;
            metadata = metadata?.merge(data, preserveMedia: true) ?? data;
            usedMobileFeed = true;
          }
        }
      }
      if (!_isComplete(metadata) && videoId != null) {
        final detail = await _detailSession.fetch(videoId);
        if (detail != null) {
          final candidate = _findAwemeMap(detail);
          if (candidate != null) {
            final data = _dataFromAwemeMap(candidate);
            if (_isComplete(data) &&
                data.videoUrl!.hasAuthority &&
                const ['http', 'https'].contains(data.videoUrl!.scheme) &&
                data.qualityOptions.every(
                  (option) =>
                      option.url.hasAuthority &&
                      const ['http', 'https'].contains(option.url.scheme),
                )) {
              detailMedia = metadata?.videoUrl == null;
              metadata = metadata?.merge(data, preserveMedia: true) ?? data;
              usedDetail = true;
            }
          }
        }
      }
      if (!_isComplete(metadata) &&
          videoId != null &&
          _browserObservation != null) {
        browserAttempt = await _browserObservation.observe(
          navigationUri: Uri.https('www.douyin.com', '/video/$videoId'),
          targetWorkId: videoId,
        );
        final observation = browserAttempt.result;
        if (observation?.outcome == DouyinBrowserObservationOutcome.found &&
            observation?.work?.workId == videoId) {
          final observed = _dataFromObservedWork(observation!.work!);
          if (_isComplete(observed)) {
            browserObservationUsed = true;
            browserMedia = metadata?.videoUrl == null;
            metadata =
                metadata?.merge(observed, preserveMedia: true) ?? observed;
          }
        }
      }
      if (!_isComplete(metadata) &&
          (_detailSession.wasRestricted || browserAttempt != null) &&
          (metadata?.title == null || metadata?.videoUrl == null)) {
        return ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: _browserFailureMessage(browserAttempt),
        );
      }
      if (metadata == null || metadata.title == null) {
        return const ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: '未能从抖音页面中提取视频信息，页面结构可能已更新。',
        );
      }
      if (metadata.videoUrl == null) {
        return const ParserFailure(
          code: ParserFailureCode.parseFailed,
          message: '已获取抖音视频信息，但未找到可下载的真实媒体地址。',
        );
      }

      final id =
          metadata.id ??
          videoId ??
          _extractVideoId(resolvedUri) ??
          resolvedUri.toString().hashCode.abs().toString();

      final qualityOptions = metadata.qualityOptions.isEmpty
          ? <MediaQualityOption>[
              MediaQualityOption(
                id: 'douyin-default',
                label: '默认清晰度',
                url: metadata.videoUrl!,
                isRecommended: true,
                isWatermarkFree: metadata.isWatermarkFree,
                metadata: <String, Object?>{
                  'mediaSource': metadata.mediaSource,
                },
              ),
            ]
          : metadata.qualityOptions;
      final mediaHeaders = <String, String>{
        'Referer': detailMedia || mobileFeedMedia || browserMedia
            ? 'https://www.douyin.com/video/$videoId'
            : resolvedUri.origin,
        'User-Agent': detailMedia || mobileFeedMedia || browserMedia
            ? DouyinDetailSession.userAgent
            : _headers['User-Agent']!,
      };
      final optionsWithHeaders = <MediaQualityOption>[
        for (final option in qualityOptions)
          MediaQualityOption(
            id: option.id,
            label: option.label,
            url: option.url,
            isRecommended: option.isRecommended,
            isWatermarkFree: option.isWatermarkFree,
            sizeBytes: option.sizeBytes,
            width: option.width,
            height: option.height,
            bitrate: option.bitrate,
            requestHeaders: mediaHeaders,
            metadata: option.metadata,
          ),
      ];
      final recommendedOption = _recommendedOption(optionsWithHeaders);

      return ParserSuccess(
        VideoInfo(
          id: id,
          title: metadata.title!,
          author: metadata.author,
          authorId: metadata.authorId,
          coverUrl: metadata.coverUrl,
          videoUrl: recommendedOption?.url ?? metadata.videoUrl!,
          platform: platform,
          duration: metadata.duration,
          description: metadata.description,
          qualityOptions: optionsWithHeaders,
          metadata: <String, Object?>{
            'sourceUrl': link.originalUrl,
            'resolvedUrl': resolvedUri.toString(),
            // Observed locations are session-ephemeral. Keeping the existing
            // download entry disabled prevents persistence in DownloadTask.
            'mediaUrlAvailable': !browserMedia,
            'ephemeralObservation': browserMedia,
            'watermarkFree':
                recommendedOption?.isWatermarkFree ?? metadata.isWatermarkFree,
            'mediaSource':
                recommendedOption?.metadata['mediaSource'] ??
                metadata.mediaSource,
            'downloadHeaders': mediaHeaders,
            'detailFallbackUsed': usedDetail,
            'mobileFeedUsed': usedMobileFeed,
            'browserObservationUsed': browserObservationUsed,
            if (browserAttempt != null)
              'browserObservationDiagnostics': <String, Object?>{
                'outcome': browserAttempt.summary.outcome.name,
                'navigationSucceeded':
                    browserAttempt.summary.navigationSucceeded,
                'filterAccepted':
                    browserAttempt.summary.filterCounts[NetworkFilterReason
                        .filterAccepted] ??
                    0,
                'bodyBytes':
                    browserAttempt.summary.filterCounts[NetworkFilterReason
                        .bodyBytes] ??
                    0,
                'ipcSent':
                    browserAttempt.summary.filterCounts[NetworkFilterReason
                        .ipcSent] ??
                    0,
                'consumerCalls': browserAttempt.consumerCalls,
                'consumerReceivedBytes': browserAttempt.consumerReceivedBytes,
                'decoderExecutions': browserAttempt.decoderExecutions,
                'decoderOutcome': browserAttempt.result?.outcome.name,
                'observationsCreated': browserAttempt.observationsCreated,
                'finalFrameReceived': browserAttempt.summary.finalFrameReceived,
                'profileCleaned': browserAttempt.summary.profileCleaned,
                'processExitCode': browserAttempt.summary.processExitCode,
              },
          },
        ),
      );
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.networkError(
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
      AppLogger.networkError(
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
      AppLogger.parserError(
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
      AppLogger.parserError(
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

  bool _isComplete(_DouyinVideoData? data) =>
      data?.title != null &&
      data?.title != 'Douyin Video' &&
      data?.author != null &&
      data?.videoUrl != null;

  _DouyinVideoData _dataFromObservedWork(DouyinObservedWork work) {
    final options = <MediaQualityOption>[];
    final seen = <String>{};
    for (final variant in work.mediaVariants) {
      for (final location in variant.locations) {
        if (!seen.add(location.uri.toString())) continue;
        options.add(
          MediaQualityOption(
            id: 'douyin-observed-${options.length}',
            label: _douyinQualityLabel(
              uri: location.uri,
              gearName: variant.gearName,
              height: variant.height,
              bitrate: variant.bitrate,
              index: options.length,
            ),
            url: location.uri,
            isWatermarkFree: _isWatermarkFreeResource(
              location.uri,
              source: variant.sourceField.split('.').last,
            ),
            width: variant.width,
            height: variant.height,
            bitrate: variant.bitrate,
            metadata: <String, Object?>{
              'mediaSource': variant.sourceField,
              'ephemeralObservation': true,
            },
          ),
        );
      }
    }
    final finalized = _finalizeQualityOptions(
      options,
      fallbackResource: null,
      width: work.width,
      height: work.height,
    );
    final media = _recommendedOption(finalized);
    return _DouyinVideoData(
      id: work.workId,
      title: work.description,
      description: work.description,
      author: work.author?.nickname,
      authorId: work.author?.uniqueId ?? work.author?.uid,
      coverUrl: work.covers.isEmpty ? null : work.covers.first.uri,
      videoUrl: media?.url,
      isWatermarkFree: media?.isWatermarkFree ?? false,
      mediaSource: media?.metadata['mediaSource'] as String?,
      qualityOptions: finalized,
      duration: work.duration,
    );
  }

  String _browserFailureMessage(DouyinBrowserObservationAttempt? attempt) {
    final outcome =
        attempt?.result?.outcome.name ?? attempt?.summary.outcome.name;
    return switch (outcome) {
      'loginRequired' => '抖音公开页面要求登录；MediaFlow 不会导入账号状态。',
      'browserVerification' => '抖音公开页面要求安全验证；MediaFlow 不会绕过验证。',
      'regionRestricted' => '该抖音公开内容存在地区限制。',
      'accessRestricted' => '该抖音公开内容存在访问权限限制。',
      'timeout' => '抖音匿名浏览器解析超时，请稍后重试。',
      'runtimeUnavailable' || 'unsupportedCapability' => '当前设备的匿名浏览器解析能力不可用。',
      _ => '抖音未返回可下载的真实媒体地址；匿名公开页面解析失败，请稍后重试。',
    };
  }

  _DouyinPageData _parsePage(NetworkResponse response) {
    final document = html_parser.parse(response.body);
    if (_looksExpired(document)) {
      return const _DouyinPageData(data: null, isExpired: true);
    }

    final routerData = _extractRouterDataVideo(document);
    final embedded = _extractEmbeddedVideo(document);
    final structured = _extractStructuredVideo(document);
    final openGraph = _extractOpenGraph(document);
    final data =
        routerData?.merge(embedded).merge(structured).merge(openGraph) ??
        embedded?.merge(structured).merge(openGraph) ??
        structured?.merge(openGraph) ??
        openGraph;
    return _DouyinPageData(data: data, isExpired: false);
  }

  ParserFailure _expiredFailure() {
    return const ParserFailure(
      code: ParserFailureCode.linkExpired,
      message: '该抖音作品不存在、已删除、不可见或暂时无法访问。',
    );
  }

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
    final text = '${document.body?.text ?? ''}\n${document.outerHtml}';
    return text.contains('视频不存在') ||
        text.contains('作品不存在') ||
        text.contains('作品已删除') ||
        text.contains('作品不见了') ||
        text.contains('无法观看') ||
        text.contains('内容暂时无法查看');
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
      final mediaResource =
          _mediaResource(
            videoObject['contentUrl'],
            source: 'json_ld_content_url',
          ) ??
          _mediaResource(videoObject['embedUrl'], source: 'json_ld_embed_url');
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
        videoUrl: mediaResource?.url,
        isWatermarkFree: mediaResource?.isWatermarkFree ?? false,
        mediaSource: mediaResource?.source,
        duration: _parseIsoDuration(_stringValue(videoObject['duration'])),
        description: _stringValue(videoObject['description']),
      );
    }
    return null;
  }

  _DouyinVideoData? _extractRouterDataVideo(Document document) {
    for (final script in document.querySelectorAll('script')) {
      if (!script.text.contains('_ROUTER_DATA')) {
        continue;
      }
      final jsonText = _extractAssignedJson(script.text, '_ROUTER_DATA');
      if (jsonText == null) {
        continue;
      }
      final candidate = _findAwemeMap(_tryDecodeJson(jsonText));
      if (candidate != null) {
        return _dataFromAwemeMap(candidate);
      }
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
    final mediaResource = _mediaResource(
      _metaContent(document, property: 'og:video'),
      source: 'open_graph_video',
    );
    return _DouyinVideoData(
      title: title,
      author: _metaContent(document, name: 'author'),
      coverUrl: _uriFromValue(_metaContent(document, property: 'og:image')),
      videoUrl: mediaResource?.url,
      isWatermarkFree: mediaResource?.isWatermarkFree ?? false,
      mediaSource: mediaResource?.source,
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

  String? _extractAssignedJson(String script, String marker) {
    final markerIndex = script.indexOf(marker);
    if (markerIndex < 0) {
      return null;
    }
    final start = script.indexOf('{', markerIndex + marker.length);
    if (start < 0) {
      return null;
    }

    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var index = start; index < script.length; index += 1) {
      final character = script[index];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (character == '\\') {
          escaped = true;
        } else if (character == '"') {
          inString = false;
        }
        continue;
      }
      if (character == '"') {
        inString = true;
      } else if (character == '{') {
        depth += 1;
      } else if (character == '}') {
        depth -= 1;
        if (depth == 0) {
          return script.substring(start, index + 1);
        }
      }
    }
    return null;
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
    final id =
        _stringValue(map['aweme_id']) ??
        _stringValue(map['id']) ??
        _stringValue(map['itemId']);
    final authorName =
        _stringValue(author['nickname']) ?? _stringValue(author['name']);
    final fallbackResource = _preferredMediaResourceFromMap(video);
    final qualityOptions = _finalizeQualityOptions(
      _qualityOptionsFromBitRate(video['bit_rate'] ?? video['bitRate']),
      fallbackResource: fallbackResource,
      width: _intValue(video['width']),
      height: _intValue(video['height']),
    );
    final recommendedOption = _recommendedOption(qualityOptions);
    final videoUrl = recommendedOption?.url ?? fallbackResource?.url;
    return _DouyinVideoData(
      id: id,
      title:
          _stringValue(map['desc']) ??
          _stringValue(map['title']) ??
          'Douyin Video',
      author: authorName,
      authorId:
          _stringValue(author['unique_id']) ??
          _stringValue(author['sec_uid']) ??
          _stringValue(author['uid']),
      coverUrl:
          _uriFromUrlContainer(video['cover']) ??
          _uriFromUrlContainer(video['origin_cover']) ??
          _uriFromUrlContainer(video['dynamic_cover']),
      videoUrl: videoUrl,
      isWatermarkFree:
          recommendedOption?.isWatermarkFree ??
          fallbackResource?.isWatermarkFree ??
          false,
      mediaSource:
          recommendedOption?.metadata['mediaSource'] as String? ??
          fallbackResource?.source,
      qualityOptions: qualityOptions,
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

  Uri? _normalizePlaybackUri(Uri? uri) {
    if (uri == null ||
        uri.host != 'aweme.snssdk.com' ||
        uri.path != '/aweme/v1/playwm/') {
      return uri;
    }
    return uri.replace(
      queryParameters: <String, String>{...uri.queryParameters, 'line': '1'},
    );
  }

  _DouyinMediaResource? _mediaResource(
    Object? value, {
    required String source,
  }) {
    final uri = _normalizePlaybackUri(_uriFromUrlContainer(value));
    if (uri == null) {
      return null;
    }
    return _DouyinMediaResource(
      url: uri,
      source: source,
      isWatermarkFree: _isWatermarkFreeResource(uri, source: source),
    );
  }

  _DouyinMediaResource? _preferredMediaResourceFromMap(
    Map<String, dynamic> map,
  ) {
    return _preferredMediaResource(<_DouyinMediaResource?>[
      _mediaResource(map['play_addr_h264'], source: 'play_addr_h264'),
      _mediaResource(map['playAddrH264'], source: 'play_addr_h264'),
      _mediaResource(map['play_addr'], source: 'play_addr'),
      _mediaResource(map['playAddr'], source: 'play_addr'),
      _mediaResource(map['download_addr'], source: 'download_addr'),
      _mediaResource(map['downloadAddr'], source: 'download_addr'),
      _mediaResource(map['play_addr_265'], source: 'play_addr_265'),
      _mediaResource(map['playAddr265'], source: 'play_addr_265'),
    ]);
  }

  _DouyinMediaResource? _preferredMediaResource(
    Iterable<_DouyinMediaResource?> candidates,
  ) {
    final resources = <_DouyinMediaResource>[];
    for (final candidate in candidates) {
      if (candidate != null) {
        resources.add(candidate);
      }
    }
    if (resources.isEmpty) {
      return null;
    }

    for (final resource in resources) {
      if (resource.isWatermarkFree && !_isH265Source(resource.source)) {
        return resource;
      }
    }
    for (final resource in resources) {
      if (!_isH265Source(resource.source)) {
        return resource;
      }
    }
    for (final resource in resources) {
      if (resource.isWatermarkFree) {
        return resource;
      }
    }
    return resources.first;
  }

  bool _isWatermarkFreeResource(Uri uri, {required String source}) {
    final path = uri.path.toLowerCase();
    final explicitlyWatermarked =
        path.contains('/playwm/') ||
        path.endsWith('/playwm') ||
        uri.queryParameters['watermark'] == '1';
    if (explicitlyWatermarked || source == 'download_addr') {
      return false;
    }
    return source.startsWith('play_addr') || path.contains('/play/');
  }

  bool _isH265Source(String source) => source.contains('265');

  List<MediaQualityOption> _qualityOptionsFromBitRate(Object? value) {
    if (value is! List) {
      return const <MediaQualityOption>[];
    }

    final options = <MediaQualityOption>[];
    final seenUrls = <String>{};
    for (final item in value) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final resource = _preferredMediaResourceFromMap(map);
      final uri = resource?.url;
      if (resource == null || uri == null || !seenUrls.add(uri.toString())) {
        continue;
      }

      final height =
          _intValue(map['height']) ??
          _intValue(_mapValue(map['play_addr'], 'height')) ??
          _intValue(_mapValue(map['playAddr'], 'height'));
      final width =
          _intValue(map['width']) ??
          _intValue(_mapValue(map['play_addr'], 'width')) ??
          _intValue(_mapValue(map['playAddr'], 'width'));
      final bitrate = _intValue(map['bit_rate']) ?? _intValue(map['bitRate']);
      final qualityType =
          _intValue(map['quality_type']) ?? _intValue(map['qualityType']);
      final gearName =
          _stringValue(map['gear_name']) ?? _stringValue(map['gearName']);
      final label = _douyinQualityLabel(
        uri: uri,
        gearName: gearName,
        height: height,
        bitrate: bitrate,
        index: options.length,
      );
      options.add(
        MediaQualityOption(
          id: 'douyin-${qualityType ?? gearName ?? height ?? bitrate ?? 'quality'}-${options.length}',
          label: label,
          url: uri,
          isWatermarkFree: resource.isWatermarkFree,
          width: width,
          height: height,
          bitrate: bitrate,
          metadata: <String, Object?>{
            'qualityType': qualityType,
            'gearName': gearName,
            'mediaSource': resource.source,
          },
        ),
      );
    }
    return options;
  }

  List<MediaQualityOption> _finalizeQualityOptions(
    List<MediaQualityOption> options, {
    required _DouyinMediaResource? fallbackResource,
    required int? width,
    required int? height,
  }) {
    final combined = <MediaQualityOption>[...options];
    if (fallbackResource != null &&
        fallbackResource.isWatermarkFree &&
        !combined.any((option) => option.url == fallbackResource.url)) {
      final fallbackResolution = _shortSide(width: width, height: height);
      final matchingIndex = fallbackResolution == null
          ? -1
          : combined.indexWhere(
              (option) =>
                  _shortSide(width: option.width, height: option.height) ==
                  fallbackResolution,
            );
      if (matchingIndex >= 0) {
        final matching = combined[matchingIndex];
        combined[matchingIndex] = _copyQualityOption(
          matching,
          isRecommended: false,
          url: fallbackResource.url,
          isWatermarkFree: true,
          metadata: <String, Object?>{
            ...matching.metadata,
            'mediaSource': fallbackResource.source,
          },
        );
      } else {
        combined.insert(
          0,
          MediaQualityOption(
            id: 'douyin-watermark-free',
            label: _resolutionLabel(width: width, height: height),
            url: fallbackResource.url,
            isWatermarkFree: true,
            width: width,
            height: height,
            metadata: <String, Object?>{'mediaSource': fallbackResource.source},
          ),
        );
      }
    }
    if (combined.isEmpty) {
      return combined;
    }

    var recommendedIndex = combined.indexWhere(
      (option) => option.isWatermarkFree,
    );
    if (recommendedIndex < 0) {
      recommendedIndex = 0;
    }
    return <MediaQualityOption>[
      for (var index = 0; index < combined.length; index += 1)
        _copyQualityOption(
          combined[index],
          isRecommended: index == recommendedIndex,
        ),
    ];
  }

  MediaQualityOption _copyQualityOption(
    MediaQualityOption option, {
    required bool isRecommended,
    Uri? url,
    bool? isWatermarkFree,
    Map<String, Object?>? metadata,
  }) {
    return MediaQualityOption(
      id: option.id,
      label: option.label,
      url: url ?? option.url,
      isRecommended: isRecommended,
      isWatermarkFree: isWatermarkFree ?? option.isWatermarkFree,
      sizeBytes: option.sizeBytes,
      width: option.width,
      height: option.height,
      bitrate: option.bitrate,
      requestHeaders: option.requestHeaders,
      metadata: metadata ?? option.metadata,
    );
  }

  int? _shortSide({required int? width, required int? height}) {
    return switch ((width, height)) {
      (final width?, final height?) => width < height ? width : height,
      (final width?, null) => width,
      (null, final height?) => height,
      _ => null,
    };
  }

  String _resolutionLabel({required int? width, required int? height}) {
    final shortSide = _shortSide(width: width, height: height);
    return shortSide == null || shortSide <= 0
        ? '\u9ed8\u8ba4\u6e05\u6670\u5ea6'
        : '${shortSide}P';
  }

  MediaQualityOption? _recommendedOption(List<MediaQualityOption> options) {
    for (final option in options) {
      if (option.isRecommended) {
        return option;
      }
    }
    return options.isEmpty ? null : options.first;
  }

  String _douyinQualityLabel({
    required Uri uri,
    required String? gearName,
    required int? height,
    required int? bitrate,
    required int index,
  }) {
    final ratio = uri.queryParameters['ratio'];
    final ratioMatch = RegExp(
      r'(\d{3,4})p',
      caseSensitive: false,
    ).firstMatch(ratio ?? gearName ?? '');
    if (ratioMatch != null) {
      return '${ratioMatch.group(1)}P';
    }
    if (height != null && height > 0) {
      return '${height}P';
    }
    if (gearName != null) {
      return gearName;
    }
    if (bitrate != null && bitrate > 0) {
      final megabits = bitrate / 1000000;
      return '${megabits.toStringAsFixed(megabits >= 10 ? 0 : 1)} Mbps';
    }
    return '清晰度 ${index + 1}';
  }

  Object? _mapValue(Object? value, String key) {
    return value is Map ? value[key] : null;
  }

  int? _intValue(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
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

class _DouyinPageData {
  const _DouyinPageData({required this.data, required this.isExpired});

  final _DouyinVideoData? data;
  final bool isExpired;
}

class _DouyinVideoData {
  const _DouyinVideoData({
    this.id,
    this.title,
    this.author,
    this.authorId,
    this.coverUrl,
    this.videoUrl,
    this.isWatermarkFree = false,
    this.mediaSource,
    this.qualityOptions = const [],
    this.duration,
    this.description,
  });

  _DouyinVideoData merge(
    _DouyinVideoData? fallback, {
    bool preserveMedia = false,
  }) {
    if (fallback == null) {
      return this;
    }
    return _DouyinVideoData(
      id: id ?? fallback.id,
      title: preserveMedia && title == 'Douyin Video'
          ? fallback.title ?? title
          : title ?? fallback.title,
      author: author ?? fallback.author,
      authorId: authorId ?? fallback.authorId,
      coverUrl: coverUrl ?? fallback.coverUrl,
      videoUrl: videoUrl ?? fallback.videoUrl,
      isWatermarkFree: videoUrl != null
          ? isWatermarkFree
          : fallback.isWatermarkFree,
      mediaSource: videoUrl != null ? mediaSource : fallback.mediaSource,
      qualityOptions: preserveMedia && videoUrl != null
          ? qualityOptions
          : qualityOptions.isNotEmpty
          ? qualityOptions
          : fallback.qualityOptions,
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
  final bool isWatermarkFree;
  final String? mediaSource;
  final List<MediaQualityOption> qualityOptions;
  final Duration? duration;
  final String? description;
}

class _DouyinMediaResource {
  const _DouyinMediaResource({
    required this.url,
    required this.source,
    required this.isWatermarkFree,
  });

  final Uri url;
  final String source;
  final bool isWatermarkFree;
}
