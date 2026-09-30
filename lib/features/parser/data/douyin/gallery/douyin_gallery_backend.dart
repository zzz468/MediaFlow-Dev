import 'dart:convert';
import 'dart:io';

import '../../../domain/media_content.dart';
import 'douyin_gallery_adapter.dart';
import 'douyin_gallery_capabilities.dart';
import 'f2_gallery_signer.dart';

enum DouyinDetailFailure {
  noSession,
  sessionExpired,
  securityGate,
  signatureRejected,
  httpError,
  invalidJson,
  missingAwemeDetail,
  invalidGallery,
  unavailable,
}

final class DouyinDetailException implements Exception {
  const DouyinDetailException(
    this.failure, {
    this.httpStatus,
    this.platformMarker,
  });
  final DouyinDetailFailure failure;
  final int? httpStatus;
  final String? platformMarker;
  @override
  String toString() => 'Douyin detail: ${failure.name} (values redacted)';
}

/// Private infrastructure input. Values have no getters or JSON serializer.
/// Construct only from an owned profile (synthetic values in offline tests).
final class DouyinSessionContext implements DouyinSessionHandle {
  DouyinSessionContext({
    required this.userAgent,
    required List<int> browserMetrics,
    required Map<String, String> runtimeQuery,
    this.browserPlatform = 'Win32',
    String? sessionid,
    String? sessionidSs,
    String? ttwid,
    String? msToken,
    this.expiresAt,
  }) : _metrics = List.unmodifiable(browserMetrics),
       _runtime = Map.unmodifiable(runtimeQuery),
       _cookies = {
         'sessionid': ?sessionid,
         'sessionid_ss': ?sessionidSs,
         'ttwid': ?ttwid,
       },
       _msToken = msToken {
    const runtimeKeys = {
      'screen_width',
      'screen_height',
      'browser_language',
      'browser_platform',
      'browser_name',
      'browser_version',
      'browser_online',
      'engine_name',
      'engine_version',
      'os_name',
      'os_version',
      'cpu_core_num',
      'device_memory',
      'downlink',
      'effective_type',
      'round_trip_time',
    };
    if (_runtime.keys.any((key) => !runtimeKeys.contains(key))) {
      throw const FormatException('Unrecognized runtime query field.');
    }
    for (final value in [..._cookies.values, ?msToken]) {
      if (value.isEmpty ||
          value.codeUnits.any((c) => c < 33 || c > 126 || c == 59)) {
        throw const FormatException('Invalid owned session material.');
      }
    }
  }
  final String userAgent, browserPlatform;
  final DateTime? expiresAt;
  final List<int> _metrics;
  final Map<String, String> _runtime, _cookies;
  String? _msToken;
  bool _revoked = false;
  bool get usable =>
      !_revoked &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now())) &&
      (_cookies.containsKey('sessionid') ||
          _cookies.containsKey('sessionid_ss'));
  void invalidate() {
    _revoked = true;
    _cookies.clear();
    _msToken = null;
  }

  @override
  String toString() => 'DouyinSessionContext(redacted)';
}

final class DouyinDetailResponse {
  const DouyinDetailResponse(this.status, this.body);
  final int status;
  final String body;
  @override
  String toString() => 'DouyinDetailResponse(redacted)';
}

abstract interface class DouyinDetailTransport {
  Future<DouyinDetailResponse> get(Uri uri, Map<String, String> headers);
}

/// Direct, bounded transport. No proxy, redirect or retry policy.
final class DirectDouyinDetailTransport implements DouyinDetailTransport {
  @override
  Future<DouyinDetailResponse> get(Uri uri, Map<String, String> headers) async {
    if (uri.scheme != 'https' ||
        uri.host != 'www.douyin.com' ||
        uri.path != '/aweme/v1/web/aweme/detail/' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty) {
      throw const DouyinDetailException(DouyinDetailFailure.httpError);
    }
    final client = HttpClient();
    client.findProxy = (_) => 'DIRECT';
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      return await (() async {
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        headers.forEach(request.headers.set);
        final response = await request.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          if (bytes.length + chunk.length > 2 * 1024 * 1024) {
            throw const DouyinDetailException(DouyinDetailFailure.httpError);
          }
          bytes.addAll(chunk);
        }
        return DouyinDetailResponse(
          response.statusCode,
          utf8.decode(bytes, allowMalformed: true),
        );
      })().timeout(const Duration(seconds: 25));
    } on DouyinDetailException {
      rethrow;
    } catch (_) {
      throw const DouyinDetailException(DouyinDetailFailure.httpError);
    } finally {
      client.close(force: true);
    }
  }
}

String douyinCanonicalQuery(Map<String, String> fields) => fields.entries
    .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
    .join('&');

/// F2 behavior reference: BaseRequestModel/PostDetail, fetch_post_detail,
/// ABogusManager and GatewayHeaderManager at pinned commit in NOTICE.
final class F2DouyinGalleryDetailClient implements DouyinGalleryDetailClient {
  F2DouyinGalleryDetailClient({
    required this.signer,
    required this.transport,
    this.argusCompatibilityHeader = false,
  });
  final F2GallerySigner signer;
  final DouyinDetailTransport transport;
  final bool argusCompatibilityHeader;
  @override
  Future<Map<String, Object?>> fetchDetail({
    required String awemeId,
    required DouyinSessionHandle session,
    Uri? sourceUrl,
  }) async {
    if (session is! DouyinSessionContext || !session.usable) {
      throw DouyinDetailException(
        session is DouyinSessionContext
            ? DouyinDetailFailure.sessionExpired
            : DouyinDetailFailure.noSession,
      );
    }
    if (!RegExp(r'^\d+$').hasMatch(awemeId)) {
      throw const DouyinDetailException(DouyinDetailFailure.missingAwemeDetail);
    }
    final note = Uri.https('www.douyin.com', '/note/$awemeId');
    if (sourceUrl != null && sourceUrl != note) {
      throw const DouyinDetailException(DouyinDetailFailure.missingAwemeDetail);
    }
    // Keep upstream order; replace identity declarations by actual profile
    // measurements. No random device parameters or fake msToken fallback.
    final fields = <String, String>{
      'device_platform': 'webapp',
      'aid': '6383',
      'channel': 'channel_pc_web',
      'pc_client_type': '1',
      'publish_video_strategy_type': '2',
      'pc_libra_divert': 'Windows',
      'version_code': '290100',
      'version_name': '29.1.0',
      'cookie_enabled': 'true',
      ...session._runtime,
      'platform': 'PC',
      'msToken': ?session._msToken,
      'aweme_id': awemeId,
    };
    final query = douyinCanonicalQuery(fields);
    final signature = signer.sign(
      query,
      userAgent: session.userAgent,
      browserMetrics: session._metrics,
      browserPlatform: session.browserPlatform,
    );
    final uri = Uri.parse(
      'https://www.douyin.com/aweme/v1/web/aweme/detail/?$query&a_bogus=${Uri.encodeComponent(signature)}',
    );
    final headers = <String, String>{
      'User-Agent': session.userAgent,
      'Referer': note.toString(),
      'Origin': 'https://www.douyin.com',
      'Accept': 'application/json',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'Cookie': session._cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; '),
      if (argusCompatibilityHeader) 'x-tt-argus': '1',
    };
    final response = await transport.get(uri, headers);
    if (!session.usable) {
      throw const DouyinDetailException(DouyinDetailFailure.sessionExpired);
    }
    final body = response.body.toLowerCase();
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      /* Classify below. */
    }
    final business =
        decoded is Map<String, dynamic> && decoded['status_code'] == 0;
    Never fail(DouyinDetailFailure f) {
      final marker = f == DouyinDetailFailure.securityGate
          ? (body.contains('uifid not found')
                ? 'argusUifidMissing'
                : body.contains('argussecurityplugin')
                ? 'argusGate'
                : 'securityGate')
          : null;
      throw DouyinDetailException(
        f,
        httpStatus: response.status,
        platformMarker: marker,
      );
    }

    if (response.status == 401) {
      session.invalidate();
      fail(DouyinDetailFailure.sessionExpired);
    }
    if (response.status == 403 ||
        response.status == 429 ||
        (!business &&
            (body.contains('uifid not found') ||
                body.contains('argussecurityplugin')))) {
      fail(DouyinDetailFailure.securityGate);
    }
    if (!business &&
        (body.contains('invalid signature') ||
            body.contains('signature rejected'))) {
      fail(DouyinDetailFailure.signatureRejected);
    }
    if (response.status != 200) {
      fail(DouyinDetailFailure.httpError);
    }
    if (decoded is! Map<String, dynamic>) {
      fail(DouyinDetailFailure.invalidJson);
    }
    if (decoded['status_code'] == 401) {
      session.invalidate();
      fail(DouyinDetailFailure.sessionExpired);
    }
    final detail = decoded['aweme_detail'];
    if (detail is! Map || detail['aweme_id'] != awemeId) {
      fail(DouyinDetailFailure.missingAwemeDetail);
    }
    if (decoded['status_code'] != 0) {
      fail(DouyinDetailFailure.httpError);
    }
    final raw = <String, Object?>{
      'status_code': 0,
      'aweme_detail': {
        'aweme_id': detail['aweme_id'],
        'aweme_type': detail['aweme_type'],
        'desc': detail['desc'],
        'images': detail['images'] is List
            ? [
                for (final image in detail['images'] as List)
                  if (image is Map) {'url_list': image['url_list']} else null,
              ]
            : null,
      },
    };
    try {
      const DouyinGalleryAdapter().adapt(raw, expectedAwemeId: awemeId);
    } on FormatException {
      fail(DouyinDetailFailure.invalidGallery);
    }
    return raw;
  }
}

final class DouyinGalleryBackend {
  const DouyinGalleryBackend({required this.sessions, required this.client});
  final DouyinSessionProvider sessions;
  final DouyinGalleryDetailClient client;
  Future<MediaContent> parse(
    String awemeId, {
    bool establishSession = false,
  }) async {
    var session = await sessions.getExistingSession();
    if (session == null && establishSession) {
      session = await sessions.establishWithUserInteraction();
    }
    if (session == null) {
      if (await sessions.getState() == DouyinSessionState.expired) {
        throw const DouyinDetailException(DouyinDetailFailure.sessionExpired);
      }
      throw const DouyinDetailException(DouyinDetailFailure.noSession);
    }
    final raw = await client.fetchDetail(awemeId: awemeId, session: session);
    return const DouyinGalleryAdapter().adapt(raw, expectedAwemeId: awemeId);
  }
}
