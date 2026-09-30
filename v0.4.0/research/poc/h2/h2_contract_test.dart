import 'dart:convert';
import 'dart:async';
import 'h2_contract.dart';

final now = DateTime.utc(2026, 9, 28);
const target = '7690029886242009957';
int checks = 0;
void check(bool value, String name) {
  if (!value) throw StateError(name);
  checks++;
}

Future<void> fails(Future<void> Function() action, H2Failure expected) async {
  try {
    await action();
  } on H2Exception catch (error) {
    check(error.code == expected, 'typed failure ${expected.name}');
    return;
  }
  throw StateError('Expected ${expected.name}');
}

FixtureContextProvider provider({
  String uifid = 'SYNTHETIC_ONLY',
  DateTime? expiresAt,
  String ua = 'Fixture/1',
}) => FixtureContextProvider(
  fixtureUa: ua,
  fixtureUifid: uifid,
  expiresAt: expiresAt ?? now.add(const Duration(minutes: 1)),
);

// NOT an A-Bogus algorithm, test vector, or usable platform signature.
final class RecordingFixtureSigner implements DouyinWebRequestSigner {
  CanonicalRequest? input;
  int calls = 0;
  @override
  SignaturePatch sign(CanonicalRequest request) {
    input = request;
    calls++;
    return SignaturePatch('MOCK+/=');
  }
}

final class FixtureTransport implements DetailTransport {
  FixtureTransport(this.response, {this.fail = false});
  final DetailResponse response;
  final bool fail;
  int calls = 0;
  DetailRequest? input;
  @override
  Future<DetailResponse> send(DetailRequest request) async {
    calls++;
    input = request;
    if (fail) throw StateError('SYNTHETIC_ONLY network secret');
    return response;
  }
}

final class DeferredTransport implements DetailTransport {
  final started = Completer<void>();
  final result = Completer<DetailResponse>();
  @override
  Future<DetailResponse> send(DetailRequest request) {
    started.complete();
    return result.future;
  }
}

Future<Map<String, dynamic>> fetch(
  FixtureContextProvider p,
  FixtureTransport t, {
  DouyinWebRequestSigner? signer,
  H2Layer layer = H2Layer.p1ContextBaseline,
  ContextHandle? handle,
  DateTime? at,
  String id = target,
  Set<ContextCapability> requiredCapabilities = const {
    ContextCapability.userAgent,
  },
}) => DouyinWebDetailClient(p, t, signer ?? const UnavailableSigner()).fetch(
  awemeId: id,
  context: handle ?? p.acquire(now),
  now: at ?? now,
  layer: layer,
  requiredCapabilities: requiredCapabilities,
);

Future<void> main() async {
  final delayedProvider = provider();
  final delayedTransport = DeferredTransport();
  final delayedFailure = fails(() async {
    await DouyinWebDetailClient(
      delayedProvider,
      delayedTransport,
      const UnavailableSigner(),
    ).fetch(
      awemeId: target,
      context: delayedProvider.acquire(now),
      now: now,
      layer: H2Layer.p1ContextBaseline,
    );
  }, H2Failure.sessionExpired);
  await delayedTransport.started.future;
  await delayedProvider.clear();
  delayedTransport.result.complete(
    const DetailResponse(
      200,
      '{"status_code":0,"aweme_detail":{"aweme_id":"7690029886242009957"}}',
    ),
  );
  await delayedFailure;
  final canonical = CanonicalRequest(
    query: const [MapEntry('b', '中 文+/%='), MapEntry('a', '1')],
    userAgent: 'Fixture/1',
    timestamp: now,
  );
  check(
    canonical.encodedQuery == 'b=%E4%B8%AD%20%E6%96%87%2B%2F%25%3D&a=1',
    'exact byte encoding/order',
  );
  check(canonical.encodedQuery == canonical.encodedQuery, 'stable encoding');
  await fails(() async {
    CanonicalRequest(
      query: const [MapEntry('a', '1'), MapEntry('a', '2')],
      userAgent: 'Fixture/1',
      timestamp: now,
    );
  }, H2Failure.requestRejected);
  await fails(() async {
    CanonicalRequest(
      query: const [MapEntry('a_bogus', 'x')],
      userAgent: 'Fixture/1',
      timestamp: now,
    );
  }, H2Failure.requestRejected);
  await fails(() async {
    CanonicalRequest(query: const [], userAgent: 'bad\r\nUA', timestamp: now);
  }, H2Failure.requestRejected);
  await fails(() async {
    CanonicalRequest(query: const [], userAgent: '', timestamp: now);
  }, H2Failure.requestRejected);
  await fails(() async {
    CanonicalRequest(
      query: const [],
      userAgent: 'Fixture/1',
      timestamp: DateTime.utc(1960),
    );
  }, H2Failure.requestRejected);
  await fails(() async {
    SignaturePatch('');
  }, H2Failure.requestRejected);
  await fails(() async {
    SignaturePatch('bad\nvalue');
  }, H2Failure.requestRejected);

  // URLs are synthetic fixtures; no media request can occur.
  final body = jsonEncode({
    'status_code': 0,
    'aweme_detail': {
      'aweme_id': target,
      'aweme_type': 68,
      'images': [
        {
          'url_list': ['https://example.invalid/2'],
        },
        {
          'url_list': ['https://example.invalid/1'],
        },
        {
          'url_list': ['https://example.invalid/2'],
        },
      ],
    },
  });
  final success = DetailResponse(200, body);
  final p = provider();
  final t = FixtureTransport(success);
  final raw = await fetch(p, t);
  check(raw['aweme_detail']['images'].length == 3, 'raw payload retained');
  check(
    jsonEncode(raw) == body,
    'array order and duplicate positions retained',
  );
  check(
    t.calls == 1 && t.input!.uri.queryParameters.length == 4,
    'baseline one call/minimal query',
  );
  check(
    t.input!.headers.keys.toSet().difference({
      'Accept',
      'User-Agent',
      'Referer',
      'uifid',
    }).isEmpty,
    'no jar or token',
  );
  await fails(() async {
    await fetch(p, t);
  }, H2Failure.sessionRequired);
  check(t.calls == 1, 'no automatic or manual same-context retry');

  final signingProvider = provider();
  final signedTransport = FixtureTransport(success);
  final signer = RecordingFixtureSigner();
  await fetch(
    signingProvider,
    signedTransport,
    signer: signer,
    layer: H2Layer.p2ContextABogus,
  );
  check(
    signer.calls == 1 &&
        signer.input!.userAgent == signedTransport.input!.headers['User-Agent'],
    'UA passed unchanged',
  );
  check(signer.input!.timestamp == now, 'time passed unchanged');
  check(
    signedTransport.input!.uri.query.endsWith('a_bogus=MOCK%2B%2F%3D'),
    'signature encoded once',
  );
  signer.sign(canonical);
  check(
    signer.input == canonical &&
        signer.calls == 2 &&
        signedTransport.calls == 1,
    'signer has no transport',
  );
  final unavailableTransport = FixtureTransport(success);
  await fails(() async {
    await fetch(
      provider(),
      unavailableTransport,
      layer: H2Layer.p2ContextABogus,
    );
  }, H2Failure.signerUnavailable);
  check(unavailableTransport.calls == 0, 'unavailable signer sends nothing');

  final emptyTransport = FixtureTransport(success);
  await fails(() async {
    await fetch(
      provider(uifid: ''),
      emptyTransport,
      requiredCapabilities: {
        ContextCapability.userAgent,
        ContextCapability.uifid,
      },
    );
  }, H2Failure.sessionRequired);
  check(emptyTransport.calls == 0, 'missing context sends nothing');
  final optionalContext = provider(uifid: '');
  final optionalTransport = FixtureTransport(success);
  await fetch(optionalContext, optionalTransport);
  check(
    optionalTransport.calls == 1 &&
        !optionalTransport.input!.headers.containsKey('uifid'),
    'default strategy works without UIFID and omits its header',
  );
  check(
    !optionalContext.capabilities.contains(ContextCapability.uifid),
    'capability metadata does not invent UIFID',
  );
  final expired = provider(expiresAt: now);
  await fails(() async {
    expired.acquire(now);
  }, H2Failure.sessionExpired);
  final expiring = provider();
  final lease = expiring.acquire(now);
  await fails(() async {
    await fetch(
      expiring,
      emptyTransport,
      handle: lease,
      at: now.add(const Duration(minutes: 1)),
    );
  }, H2Failure.sessionExpired);
  final other = provider();
  await fails(() async {
    await fetch(other, emptyTransport, handle: provider().acquire(now));
  }, H2Failure.sessionExpired);
  final cleared = provider();
  final stale = cleared.acquire(now);
  await cleared.clear();
  await fails(() async {
    await fetch(cleared, emptyTransport, handle: stale);
  }, H2Failure.sessionRequired);
  check(cleared.state == ContextState.cleared, 'clear revokes immediately');

  final challenged = provider();
  final denied = FixtureTransport(
    const DetailResponse(403, 'ArgusSecurityPlugin Uifid Not Found'),
  );
  await fails(() async {
    await fetch(challenged, denied);
  }, H2Failure.securityChallengeRequired);
  await fails(() async {
    challenged.acquire(now);
  }, H2Failure.securityChallengeRequired);
  check(
    denied.calls == 1 && challenged.state == ContextState.challenged,
    'challenge stops without retry or signature escalation',
  );
  await fails(() async {
    await fetch(
      provider(),
      FixtureTransport(const DetailResponse(403, 'unknown')),
    );
  }, H2Failure.requestRejected);
  for (final value in [
    '',
    '[]',
    '{"status_code":0}',
    '{"status_code":0,"aweme_detail":{"aweme_id":"other"}}',
  ]) {
    await fails(() async {
      await fetch(provider(), FixtureTransport(DetailResponse(200, value)));
    }, H2Failure.parserSchemaChanged);
  }
  await fails(() async {
    await fetch(provider(), FixtureTransport(const DetailResponse(410, '')));
  }, H2Failure.contentUnavailable);
  await fails(() async {
    await fetch(provider(), FixtureTransport(success, fail: true));
  }, H2Failure.networkFailure);
  await fails(() async {
    await fetch(provider(), emptyTransport, id: '../x');
  }, H2Failure.requestRejected);
  await fails(() async {
    await fetch(provider(uifid: 'x\r\ny'), emptyTransport);
  }, H2Failure.requestRejected);
  check(
    ![
      canonical,
      SignaturePatch('SYNTHETIC_ONLY'),
      lease,
      signedTransport.input!,
      success,
      const H2Exception(H2Failure.networkFailure),
    ].join().contains('SYNTHETIC_ONLY'),
    'default diagnostics redact values',
  );
  print(
    jsonEncode({
      'scope': 'OFFLINE_SYNTHETIC_CONTRACT_ONLY',
      'checks': checks,
      'passed': true,
      'platformRequests': 0,
      'realSignerVerified': false,
      'realGalleryVerified': false,
    }),
  );
}
