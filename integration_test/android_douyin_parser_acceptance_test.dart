import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/data/douyin/observation/douyin_browser_observation.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android production ParserService uses System WebView observation',
    (tester) async {
      const workId = String.fromEnvironment(
        'MEDIAFLOW_DOUYIN_ACCEPTANCE_WORK_ID',
      );
      expect(RegExp(r'^[1-9][0-9]*$').hasMatch(workId), isTrue);

      final testFlutterErrorHandler = FlutterError.onError;
      final testPlatformErrorHandler = PlatformDispatcher.instance.onError;
      app.main();
      FlutterError.onError = testFlutterErrorHandler;
      PlatformDispatcher.instance.onError = testPlatformErrorHandler;
      await tester.pump(const Duration(seconds: 1));

      final service = createDefaultParserService();
      try {
        final result = await service
            .parseUri(Uri.https('www.douyin.com', '/video/$workId'))
            .timeout(const Duration(seconds: 90));
        if (result is ParserFailure) {
          final direct =
              AndroidDouyinBrowserObservation.takeAcceptanceSnapshot();
          if (direct == null) {
            fail('Production Parser failed before Android Browser Observation');
          }
          final diagnostic = <String, Object?>{
            'outcome': direct.summary.outcome.name,
            'navigationSucceeded': direct.summary.navigationSucceeded,
            'responses': direct.summary.responses,
            'candidates': direct.summary.candidates,
            'consumerCalls': direct.consumerCalls,
            'decoderExecutions': direct.decoderExecutions,
            'decoderOutcome': direct.decoderOutcome,
            'observationsCreated': direct.observationsCreated,
            'profileCleaned': direct.summary.profileCleaned,
            'finalFrameReceived': direct.summary.finalFrameReceived,
            'filterCounts': <String, int>{
              for (final entry in direct.summary.filterCounts.entries)
                entry.key.name: entry.value,
            },
            'rejectedHosts': direct.summary.rejectedHosts,
            'transportDiagnostics': direct.summary.transportDiagnostics,
          };
          stdout.writeln(
            'mediaflowAndroidAcceptance=${jsonEncode(<String, Object?>{'appStarted': true, 'parserServiceInvoked': true, 'platformDetected': 'douyin', 'ssrAttempted': true, 'parseResult': 'failure', 'failureCode': _safeFailureText(result.code), 'failureMessageSummary': _safeFailureText(result.message), 'browserDiagnostic': diagnostic})}',
          );
          fail(
            'Production Parser returned ${_safeFailureText(result.code)}: '
            '${_safeFailureText(result.message)}; '
            'browserDiagnostic=${jsonEncode(diagnostic)}',
          );
        }

        final info = (result as ParserSuccess).videoInfo;
        final diagnostics =
            info.metadata['browserObservationDiagnostics']
                as Map<String, Object?>?;
        final evidence = <String, Object?>{
          'appStarted': true,
          'parserServiceInvoked': true,
          'platformDetected': info.platform.name,
          'ssrAttempted': true,
          'browserObservationReached': diagnostics != null,
          'decoderReached':
              (diagnostics?['decoderExecutions'] as int? ?? 0) > 0,
          'decoderOutcome': diagnostics?['decoderOutcome'],
          'observationCreated': diagnostics?['observationsCreated'],
          'domainMappingReached': info.id == workId,
          'parseResult': 'success',
          'cleanupCompleted': diagnostics?['profileCleaned'],
          'browserObservationOutcome': diagnostics?['outcome'],
          'consumerCalls': diagnostics?['consumerCalls'],
          'consumerReceivedBytes': diagnostics?['consumerReceivedBytes'],
          'finalFrameReceived': diagnostics?['finalFrameReceived'],
          'titlePresent': info.title.trim().isNotEmpty,
          'authorPresent': info.author?.trim().isNotEmpty == true,
          'ephemeralObservation': info.metadata['ephemeralObservation'] == true,
        };

        expect(evidence['platformDetected'], 'douyin');
        expect(evidence['browserObservationReached'], isTrue);
        expect(evidence['decoderReached'], isTrue);
        expect(evidence['decoderOutcome'], 'found');
        expect(evidence['observationCreated'], 1);
        expect(evidence['domainMappingReached'], isTrue);
        expect(evidence['cleanupCompleted'], isTrue);
        expect(evidence['browserObservationOutcome'], 'found');
        expect(evidence['finalFrameReceived'], isTrue);
        expect(evidence['titlePresent'], isTrue);
        expect(evidence['authorPresent'], isTrue);
        expect(evidence['ephemeralObservation'], isTrue);

        // Bounded diagnostics only: no URL, media location, body, or headers.
        stdout.writeln('mediaflowAndroidAcceptance=${jsonEncode(evidence)}');
      } finally {
        service.close();
      }
    },
    skip:
        !Platform.isAndroid ||
        !const bool.fromEnvironment('MEDIAFLOW_ANDROID_DOUYIN_ACCEPTANCE'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

String _safeFailureText(String value) {
  final redacted = value
      .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '[url]')
      .replaceAll(
        RegExp(
          r'\b(cookie|authorization|token|mstoken|ttwid)\s*[:=]\s*\S+',
          caseSensitive: false,
        ),
        '[credential]',
      )
      .replaceAll(RegExp(r'[\r\n]+'), ' ');
  return redacted.length <= 256 ? redacted : redacted.substring(0, 256);
}
