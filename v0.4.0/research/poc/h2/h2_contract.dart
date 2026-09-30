// Research only: no production imports, network implementation, browser,
// persistence, logging, or third-party signer algorithm.
import 'dart:convert';

enum H2Failure {
  sessionRequired,
  sessionExpired,
  securityChallengeRequired,
  signatureRejected,
  contentUnavailable,
  unsupportedContent,
  networkFailure,
  parserSchemaChanged,
  signerUnavailable,
  requestRejected,
}

final class H2Exception implements Exception {
  const H2Exception(this.code);
  final H2Failure code;
  @override
  String toString() => 'H2Exception(${code.name})';
}

enum ContextState { absent, availableUnvalidated, expired, challenged, cleared }

enum ContextCapability { userAgent, uifid }

final class ContextHandle {
  const ContextHandle._(this._owner, this._epoch);
  final Object _owner;
  final int _epoch;
  @override
  String toString() => 'ContextHandle(redacted)';
}

// Adapter-internal values. Never passed to ParserService or public models.
final class _ContextMaterial {
  const _ContextMaterial(this.ua, this.uifid, this.expiresAt);
  final String ua;
  final String uifid;
  final DateTime expiresAt;
}

abstract class DouyinContextProvider {
  ContextState get state;
  Set<ContextCapability> get capabilities;
  ContextHandle acquire(DateTime now);
  _ContextMaterial _consume(ContextHandle handle, DateTime now);
  bool _isCurrent(ContextHandle handle);
  void invalidate(H2Failure reason);
  Future<void> clear();
  // Native establish/refresh is a separate user interaction port in the design.
}

/// Synthetic context ONLY; cannot create a real platform session.
final class FixtureContextProvider implements DouyinContextProvider {
  FixtureContextProvider({
    required String fixtureUa,
    required String fixtureUifid,
    required DateTime expiresAt,
  }) : _material = _ContextMaterial(fixtureUa, fixtureUifid, expiresAt),
       _state = fixtureUa.trim().isEmpty
           ? ContextState.absent
           : ContextState.availableUnvalidated;
  final Object _owner = Object();
  _ContextMaterial? _material;
  ContextState _state;
  int _epoch = 0;
  bool _consumed = false;
  @override
  ContextState get state => _state;
  @override
  Set<ContextCapability> get capabilities => Set.unmodifiable({
    if (_material?.ua.trim().isNotEmpty ?? false) ContextCapability.userAgent,
    if (_material?.uifid.isNotEmpty ?? false) ContextCapability.uifid,
  });
  void _check(DateTime now) {
    if (_state == ContextState.challenged) {
      throw const H2Exception(H2Failure.securityChallengeRequired);
    }
    final material = _material;
    if (_state == ContextState.expired ||
        (material != null && !now.isBefore(material.expiresAt))) {
      invalidate(H2Failure.sessionExpired);
      throw const H2Exception(H2Failure.sessionExpired);
    }
    if (material == null || material.ua.trim().isEmpty || _consumed) {
      throw const H2Exception(H2Failure.sessionRequired);
    }
  }

  @override
  ContextHandle acquire(DateTime now) {
    _check(now);
    return ContextHandle._(_owner, _epoch);
  }

  @override
  _ContextMaterial _consume(ContextHandle handle, DateTime now) {
    _check(now);
    if (!identical(handle._owner, _owner) || handle._epoch != _epoch) {
      throw const H2Exception(H2Failure.sessionExpired);
    }
    _consumed = true;
    return _material!;
  }

  @override
  bool _isCurrent(ContextHandle handle) =>
      identical(handle._owner, _owner) &&
      handle._epoch == _epoch &&
      _state == ContextState.availableUnvalidated;

  @override
  void invalidate(H2Failure reason) {
    _epoch++;
    _material = null;
    _state = switch (reason) {
      H2Failure.securityChallengeRequired => ContextState.challenged,
      H2Failure.sessionExpired => ContextState.expired,
      _ => ContextState.absent,
    };
  }

  @override
  Future<void> clear() async {
    invalidate(H2Failure.sessionRequired);
    _state = ContextState.cleared;
  }
}

/// Order is explicit, duplicate keys rejected, values encoded once. This is
/// a contract convention; protocol correctness requires real signer vectors.
final class CanonicalRequest {
  CanonicalRequest({
    required List<MapEntry<String, String>> query,
    required this.userAgent,
    required this.timestamp,
  }) : query = List.unmodifiable(query) {
    final keys = <String>{};
    for (final pair in query) {
      if (pair.key.isEmpty ||
          !keys.add(pair.key) ||
          const {'a_bogus', 'X-Bogus'}.contains(pair.key)) {
        throw const H2Exception(H2Failure.requestRejected);
      }
    }
    if (userAgent.trim().isEmpty ||
        userAgent.contains(RegExp(r'[\r\n]')) ||
        timestamp.millisecondsSinceEpoch < 0) {
      throw const H2Exception(H2Failure.requestRejected);
    }
  }
  final List<MapEntry<String, String>> query;
  final String userAgent;
  final DateTime timestamp;
  String get encodedQuery => query
      .map(
        (pair) =>
            '${Uri.encodeComponent(pair.key)}=${Uri.encodeComponent(pair.value)}',
      )
      .join('&');
  @override
  String toString() => 'CanonicalRequest(redacted)';
}

final class SignaturePatch {
  SignaturePatch(String value) : _value = value {
    if (value.isEmpty ||
        value.length > 4096 ||
        value.contains(RegExp(r'[\s\x00-\x1f\x7f]'))) {
      throw const H2Exception(H2Failure.requestRejected);
    }
  }
  final String _value;
  @override
  String toString() => 'SignaturePatch(redacted)';
}

abstract interface class DouyinWebRequestSigner {
  // Pure computation. Same query / UA / time / algorithm entropy must match
  // a protocol vector. No browser, storage, logging or HTTP responsibility.
  SignaturePatch sign(CanonicalRequest request);
}

final class UnavailableSigner implements DouyinWebRequestSigner {
  const UnavailableSigner();
  @override
  SignaturePatch sign(CanonicalRequest request) =>
      throw const H2Exception(H2Failure.signerUnavailable);
}

enum H2Layer { p1ContextBaseline, p2ContextABogus }

/// Adapter-local: URL/header values may be sensitive; never log this envelope.
final class DetailRequest {
  const DetailRequest._(this.uri, this.headers);
  final Uri uri;
  final Map<String, String> headers;
  @override
  String toString() => 'DetailRequest(redacted)';
}

final class DetailResponse {
  const DetailResponse(this.status, this.body);
  final int status;
  final String body;
  @override
  String toString() => 'DetailResponse(redacted)';
}

abstract interface class DetailTransport {
  // Future live adapter: no redirects/proxy/retries; exact origin/path only;
  // cancellation, deadlines, 2 MiB byte cap. Only offline fake exists here.
  Future<DetailResponse> send(DetailRequest request);
}

final class DouyinWebDetailClient {
  const DouyinWebDetailClient(this.provider, this.transport, this.signer);
  final DouyinContextProvider provider;
  final DetailTransport transport;
  final DouyinWebRequestSigner signer;
  Future<Map<String, dynamic>> fetch({
    required String awemeId,
    required ContextHandle context,
    required DateTime now,
    required H2Layer layer,
    Set<ContextCapability> requiredCapabilities = const {
      ContextCapability.userAgent,
    },
  }) async {
    if (!RegExp(r'^\d{1,30}$').hasMatch(awemeId)) {
      throw const H2Exception(H2Failure.requestRejected);
    }
    if (!provider.capabilities.containsAll(requiredCapabilities)) {
      throw const H2Exception(H2Failure.sessionRequired);
    }
    final material = provider._consume(context, now);
    final canonical = CanonicalRequest(
      query: [
        const MapEntry('device_platform', 'webapp'),
        const MapEntry('aid', '6383'),
        const MapEntry('channel', 'channel_pc_web'),
        MapEntry('aweme_id', awemeId),
      ],
      userAgent: material.ua,
      timestamp: now,
    );
    var query = canonical.encodedQuery;
    if (layer == H2Layer.p2ContextABogus) {
      query += '&a_bogus=${Uri.encodeComponent(signer.sign(canonical)._value)}';
    }
    // UIFID alone is admitted in this research layer. No guessed tokens/jar.
    if (material.uifid.contains(RegExp(r'[\r\n]'))) {
      throw const H2Exception(H2Failure.requestRejected);
    }
    final response = await _send(
      DetailRequest._(
        Uri.parse('https://www.douyin.com/aweme/v1/web/aweme/detail/?$query'),
        Map.unmodifiable({
          'Accept': 'application/json',
          'User-Agent': material.ua,
          'Referer': 'https://www.douyin.com/note/$awemeId',
          if (material.uifid.isNotEmpty) 'uifid': material.uifid,
        }),
      ),
    );
    if (!provider._isCurrent(context)) {
      throw const H2Exception(H2Failure.sessionExpired);
    }
    final body = response.body;
    if (utf8.encode(body).length > 2 * 1024 * 1024) {
      throw const H2Exception(H2Failure.parserSchemaChanged);
    }
    // Fixture classifier, not an exhaustive production error catalogue.
    if (body.contains('ArgusSecurityPlugin') ||
        body.contains('lf-waf-js') ||
        body.contains('captcha')) {
      provider.invalidate(H2Failure.securityChallengeRequired);
      throw const H2Exception(H2Failure.securityChallengeRequired);
    }
    if (response.status == 404 || response.status == 410) {
      throw const H2Exception(H2Failure.contentUnavailable);
    }
    if (response.status != 200) {
      throw const H2Exception(H2Failure.requestRejected);
    }
    Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw const H2Exception(H2Failure.parserSchemaChanged);
    }
    if (json is! Map<String, dynamic> || json['status_code'] != 0) {
      throw const H2Exception(H2Failure.parserSchemaChanged);
    }
    final detail = json['aweme_detail'];
    if (detail is! Map<String, dynamic> || detail['aweme_id'] != awemeId) {
      throw const H2Exception(H2Failure.parserSchemaChanged);
    }
    return json; // Raw JSON; no model/download/history mapping.
  }

  Future<DetailResponse> _send(DetailRequest request) async {
    try {
      return await transport.send(request);
    } catch (_) {
      throw const H2Exception(H2Failure.networkFailure);
    }
  }
}
