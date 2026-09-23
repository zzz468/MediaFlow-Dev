import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/parser/data/douyin/observation/douyin_browser_observation_result.dart';
import 'package:mediaflow/features/parser/data/douyin/observation/douyin_observation_decoder.dart';
import 'package:mediaflow/features/parser/data/douyin/observation/douyin_observation_limits.dart';
import 'package:mediaflow/features/parser/data/douyin/observation/ephemeral_media_location.dart';

const targetId = '1000000000000000001';
const metadata = DouyinResponseMetadata(
  responseHost: 'www.douyin.com',
  redactedPathCategory: DouyinResponsePathCategory.contentApi,
  resourceType: DouyinResponseResourceType.xhr,
  httpStatus: 200,
  mimeType: 'application/json',
  anonymous: true,
  loginPromptVisible: false,
);
final observedAt = DateTime.utc(2026, 9, 17, 1, 2, 3);

void main() {
  late String fixture;
  setUpAll(() {
    fixture = File(
      'test/features/parser/douyin/observation/fixtures/'
      'aweme_detail.redacted.json',
    ).readAsStringSync();
  });

  group('DouyinObservationDecoder', () {
    test('minimal controlled handoff needs no media URL or real user data', () {
      final body = File(
        'test/features/parser/douyin/observation/fixtures/controlled_handoff.synthetic.json',
      ).readAsStringSync();
      final result = decode(body);
      expect(result.outcome, DouyinBrowserObservationOutcome.found);
      expect(result.work!.workId, targetId);
      expect(result.work!.duration, const Duration(milliseconds: 1));
      expect(result.work!.mediaVariants, isEmpty);
      expect(result.work!.covers, isEmpty);
      expect(result.provenance.responseBytes, utf8.encode(body).length);
    });
    test(r'projects the redacted $.aweme_detail fixture', () {
      final result = decode(fixture);
      expect(result.outcome, DouyinBrowserObservationOutcome.found);
      expect(result.provenance.objectPath, r'$.aweme_detail');
      expect(result.provenance.responseBytes, utf8.encode(fixture).length);
      expect(result.work!.workId, targetId);
      expect(result.work!.description, 'Synthetic public work description');
      expect(result.work!.author!.nickname, 'Fixture author');
      expect(result.work!.duration, const Duration(milliseconds: 20000));
      expect(result.work!.width, 1920);
      expect(result.work!.height, 1080);
      expect(result.work!.publishedAt, isNotNull);
      expect(result.work!.statistics!.diggCount, isNotNull);
      expect(result.work!.covers, isNotEmpty);
      expect(result.work!.mediaVariants.length, greaterThan(15));
      expect(
        result.work!.mediaVariants.every((item) => item.locations.isNotEmpty),
        isTrue,
      );
    });

    test('matches target exactly and ignores other recommendation objects', () {
      final result = decode(
        jsonEncode({
          'feed': [work('200'), work(targetId), work('300')],
        }),
      );
      expect(result.outcome, DouyinBrowserObservationOutcome.found);
      expect(result.work!.workId, targetId);
      expect(result.provenance.objectPath, r'$.feed[1]');
    });

    test('only non-target works is noMatchingContent', () {
      final result = decode(
        jsonEncode({
          'feed': [work('200'), work('300')],
        }),
      );
      expect(result.outcome, DouyinBrowserObservationOutcome.noMatchingContent);
      expect(result.work, isNull);
    });

    test('matching id with changed work schema is structureChanged', () {
      final result = decode(
        jsonEncode({
          'aweme_detail': {
            'aweme_id': targetId,
            'desc': 'description',
            'author': {},
            'video': {'replacement_media': {}},
          },
        }),
      );
      expect(result.outcome, DouyinBrowserObservationOutcome.structureChanged);
      expect(
        result.redactedDiagnostics,
        contains(DouyinObservationDiagnostic.targetStructureChanged),
      );
    });

    test('response over one MiB is budgetExceeded', () {
      final result = decode(' ' * (1024 * 1024 + 1));
      expect(result.outcome, DouyinBrowserObservationOutcome.budgetExceeded);
      expect(
        result.redactedDiagnostics,
        contains(DouyinObservationDiagnostic.responseTooLarge),
      );
    });

    test('depth over the configured budget stops before decoding', () {
      var nested = 'null';
      for (var i = 0; i < 16; i++) {
        nested = '[$nested]';
      }
      final result = decode(nested);
      expect(result.outcome, DouyinBrowserObservationOutcome.budgetExceeded);
      expect(
        result.redactedDiagnostics,
        contains(DouyinObservationDiagnostic.depthLimit),
      );
    });

    test('node count over 12000 stops traversal', () {
      final result = decode(jsonEncode(List<int>.filled(12001, 0)));
      expect(result.outcome, DouyinBrowserObservationOutcome.budgetExceeded);
      expect(
        result.redactedDiagnostics,
        contains(DouyinObservationDiagnostic.nodeLimit),
      );
    });

    test('malformed JSON is readFailed without retaining input', () {
      final result = decode('{"secret":"https://secret.invalid/?token=value"');
      expect(result.outcome, DouyinBrowserObservationOutcome.readFailed);
      expect(result.redactedDiagnostics, [
        DouyinObservationDiagnostic.invalidJson,
      ]);
      expect(result.toString(), isNot(contains('secret.invalid')));
    });

    test('invalid UTF-8 and an extreme string fail safely', () {
      final invalidUtf8 = const DouyinObservationDecoder().decode(
        targetWorkId: targetId,
        response: metadata,
        bodyBytes: [0xff],
        observedAt: observedAt,
      );
      expect(invalidUtf8.outcome, DouyinBrowserObservationOutcome.readFailed);
      expect(invalidUtf8.redactedDiagnostics, [
        DouyinObservationDiagnostic.invalidUtf8,
      ]);
      final longString =
          DouyinObservationDecoder(
            limits: const DouyinObservationLimits(maxStringCharacters: 8),
          ).decodeString(
            targetWorkId: targetId,
            response: metadata,
            body: jsonEncode({'value': '123456789'}),
            observedAt: observedAt,
          );
      expect(
        longString.outcome,
        DouyinBrowserObservationOutcome.budgetExceeded,
      );
      expect(longString.redactedDiagnostics, [
        DouyinObservationDiagnostic.stringLimit,
      ]);
    });

    test('partial author and statistics fields remain nullable', () {
      final value = work(targetId)
        ..['author'] = {'nickname': 'Only nickname'}
        ..['statistics'] = {'comment_count': 3};
      final result = decode(jsonEncode({'aweme_detail': value}));
      expect(result.work!.author!.nickname, 'Only nickname');
      expect(result.work!.author!.secUid, isNull);
      expect(result.work!.statistics!.commentCount, 3);
      expect(result.work!.statistics!.diggCount, isNull);
    });

    test('projects multiple variants without choosing or ranking one', () {
      final value = work(targetId);
      (value['video'] as Map<String, Object?>)['bit_rate'] = [
        quality(
          'low',
          100,
          'https://media.example.invalid/low?sign=opaque-low',
        ),
        quality(
          'high',
          900,
          'https://media.example.invalid/high?sign=opaque-high',
        ),
      ];
      final result = decode(jsonEncode({'aweme_detail': value}));
      final variants = result.work!.mediaVariants;
      expect(
        variants.map((item) => item.gearName),
        containsAll(['low', 'high']),
      );
      expect(variants.map((item) => item.bitrate), containsAll([100, 900]));
      expect(
        variants
            .where((item) => item.gearName != null)
            .every((item) => item.codec == 'fixture-codec'),
        isTrue,
      );
      expect(
        variants
            .where((item) => item.gearName == 'low')
            .single
            .locations
            .single
            .uri
            .queryParameters['sign'],
        'opaque-low',
      );
    });

    test('location and result debug output redact URL and query values', () {
      final secret = 'DO_NOT_PRINT_QUERY_VALUE';
      final location = EphemeralMediaLocation(
        uri: Uri.parse(
          'https://media.example.invalid/video/path?signature=$secret',
        ),
        observedAt: observedAt,
        category: ObservedLocationCategory.media,
      );
      expect(location.queryKeyNames, ['signature']);
      expect(location.toString(), isNot(contains(secret)));
      expect(location.toString(), isNot(contains('/video/path')));
      final result = decode(
        jsonEncode({
          'aweme_detail': work(
            targetId,
            url: 'https://media.example.invalid/path?signature=$secret',
          ),
        }),
      );
      expect(result.toString(), isNot(contains(secret)));
      expect(result.work.toString(), isNot(contains(secret)));
      expect(
        result.work!.mediaVariants.single.toString(),
        isNot(contains(secret)),
      );
    });

    test(
      'does not preserve unknown raw fields or offer default JSON output',
      () {
        final value = work(targetId)
          ..['unknown_private_field'] = {'raw': 'DO_NOT_KEEP'};
        final result = decode(jsonEncode({'aweme_detail': value}));
        expect(result.toString(), isNot(contains('DO_NOT_KEEP')));
        expect(
          () => jsonEncode(result.work),
          throwsA(isA<JsonUnsupportedObjectError>()),
        );
        expect(
          () =>
              result.work!.mediaVariants.add(result.work!.mediaVariants.first),
          throwsUnsupportedError,
        );
      },
    );

    test('target id in an unrelated string is not a match', () {
      final result = decode(
        jsonEncode({
          'message': 'text mentioning $targetId',
          'aweme_detail': work('200'),
        }),
      );
      expect(result.outcome, DouyinBrowserObservationOutcome.noMatchingContent);
    });

    test('work id type and content must be valid and exact', () {
      for (final invalidId in [true, 1.5, -1, 9007199254740992, '01', '1x']) {
        final result = decode(
          jsonEncode({
            'aweme_detail': work(targetId)..['aweme_id'] = invalidId,
          }),
        );
        expect(
          result.outcome,
          DouyinBrowserObservationOutcome.noMatchingContent,
          reason: '$invalidId',
        );
      }
      final numeric = const DouyinObservationDecoder().decodeString(
        targetWorkId: '123',
        response: metadata,
        body: jsonEncode({'aweme_detail': work('123')..['aweme_id'] = 123}),
        observedAt: observedAt,
      );
      expect(numeric.outcome, DouyinBrowserObservationOutcome.found);
    });

    test(
      'opaque URL is retained but signature semantics are not interpreted',
      () {
        const opaque = 'not-a-real-signature';
        final result = decode(
          jsonEncode({
            'aweme_detail': work(
              targetId,
              url: 'https://media.example.invalid/video?sign=$opaque&expires=',
            ),
          }),
        );
        final location = result.work!.mediaVariants.single.locations.single;
        expect(location.uri.queryParameters['sign'], opaque);
        expect(location.expiry, ObservedLocationExpiry.unknown);
        expect(location.sessionRequirement, ObservedSessionRequirement.unknown);
        expect(location.toString(), isNot(contains(opaque)));
      },
    );

    test('handles empty and array-root JSON safely', () {
      expect(
        decode('{}').outcome,
        DouyinBrowserObservationOutcome.noMatchingContent,
      );
      expect(
        decode('[]').outcome,
        DouyinBrowserObservationOutcome.noMatchingContent,
      );
      expect(
        decode('null').outcome,
        DouyinBrowserObservationOutcome.noMatchingContent,
      );
      expect(
        decode(jsonEncode([work(targetId)])).outcome,
        DouyinBrowserObservationOutcome.found,
      );
    });
  });
}

DouyinBrowserObservationResult decode(String body) =>
    const DouyinObservationDecoder().decodeString(
      targetWorkId: targetId,
      response: metadata,
      body: body,
      observedAt: observedAt,
    );

Map<String, Object?> work(String id, {String? url}) => {
  'aweme_id': id,
  'desc': 'description',
  'author': {'nickname': 'author'},
  'video': {
    'duration': 1,
    'play_addr': {
      'url_list': [url ?? 'https://media.example.invalid/video'],
    },
  },
};

Map<String, Object?> quality(String name, int bitrate, String url) => {
  'gear_name': name,
  'quality_type': bitrate,
  'codec': 'fixture-codec',
  'bit_rate': bitrate,
  'width': 1280,
  'height': 720,
  'play_addr': {
    'url_list': [url],
  },
};
