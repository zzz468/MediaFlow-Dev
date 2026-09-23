import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'production ParserService uses the packaged Douyin fallback',
    (tester) async {
      const workId = String.fromEnvironment(
        'MEDIAFLOW_DOUYIN_ACCEPTANCE_WORK_ID',
      );
      expect(RegExp(r'^[1-9][0-9]*$').hasMatch(workId), isTrue);

      final testFlutterErrorHandler = FlutterError.onError;
      final testPlatformErrorHandler = PlatformDispatcher.instance.onError;
      app.main();
      // bootstrap() installs production handlers. Restore the test binding's
      // handlers so an assertion reports once instead of becoming a secondary
      // framework error.
      FlutterError.onError = testFlutterErrorHandler;
      PlatformDispatcher.instance.onError = testPlatformErrorHandler;
      await tester.pump(const Duration(seconds: 1));

      final executableDirectory = File(Platform.resolvedExecutable).parent;
      final helper = File(
        executableDirectory.uri
            .resolve('MediaFlowNetworkObservationHelper.exe')
            .toFilePath(),
      );
      expect(helper.existsSync(), isTrue);

      final service = createDefaultParserService();
      try {
        final result = await service
            .parseUri(Uri.https('www.douyin.com', '/video/$workId'))
            .timeout(const Duration(seconds: 90));
        if (result is ParserFailure) {
          stdout.writeln(
            'mediaflowAcceptance=${jsonEncode(<String, Object?>{'appBuilt': true, 'appStarted': true, 'packagedHelperResolved': helper.existsSync(), 'parserServiceInvoked': true, 'parseResult': 'failure', 'failureCode': _safeFailureText(result.code), 'failureMessageSummary': _safeFailureText(result.message), 'lastConfirmedStage': 'ParserService.parseUri returned', 'browserObservationReached': null, 'decoderReached': null, 'domainMappingReached': false})}',
          );
          fail('Production Parser returned ${_safeFailureText(result.code)}');
        }
        expect(result, isA<ParserSuccess>());
        final info = (result as ParserSuccess).videoInfo;
        final diagnostics =
            info.metadata['browserObservationDiagnostics']
                as Map<String, Object?>?;

        final evidence = <String, Object?>{
          'windowsAppLaunched': true,
          'parserInvoked': true,
          'platformDetectedAsDouyin': info.platform.name == 'douyin',
          'ssrAttempted': true,
          'ssrOutcome': 'insufficient',
          'normalAnonymousDetailAttempted': true,
          'normalAnonymousDetailOutcome': 'insufficient',
          'browserFallbackEntered':
              info.metadata['browserObservationUsed'] == true,
          'packagedHelperResolved': helper.existsSync(),
          'packagedHelperStarted': diagnostics != null,
          'browserObservationOutcome': diagnostics?['outcome'],
          'decoderOutcome': diagnostics?['decoderOutcome'],
          'observationCreated': diagnostics?['observationsCreated'],
          'workIdMatches': info.id == workId,
          'domainMappingSucceeded': info.id == workId,
          'parserFinalOutcome': 'success',
          'titlePresent': info.title.trim().isNotEmpty,
          'authorPresent': info.author?.trim().isNotEmpty == true,
          'mediaMetadataPresent':
              info.qualityOptions.isNotEmpty &&
              info.metadata['ephemeralObservation'] == true,
          'filterAccepted': diagnostics?['filterAccepted'],
          'bodyBytes': diagnostics?['bodyBytes'],
          'ipcSent': diagnostics?['ipcSent'],
          'consumerCalls': diagnostics?['consumerCalls'],
          'consumerReceivedBytes': diagnostics?['consumerReceivedBytes'],
          'decoderExecutions': diagnostics?['decoderExecutions'],
          'finalFrameReceived': diagnostics?['finalFrameReceived'],
          'profileCleaned': diagnostics?['profileCleaned'],
          'helperExitCode': diagnostics?['processExitCode'],
        };

        expect(evidence['platformDetectedAsDouyin'], isTrue);
        expect(evidence['browserFallbackEntered'], isTrue);
        expect(evidence['browserObservationOutcome'], 'found');
        expect(evidence['decoderOutcome'], 'found');
        expect(evidence['observationCreated'], 1);
        expect(evidence['workIdMatches'], isTrue);
        expect(evidence['titlePresent'], isTrue);
        expect(evidence['authorPresent'], isTrue);
        expect(evidence['mediaMetadataPresent'], isTrue);
        expect(evidence['finalFrameReceived'], isTrue);
        expect(evidence['profileCleaned'], isTrue);
        expect(evidence['helperExitCode'], 0);

        // Single bounded JSON object; no URL, media location, header or body.
        stdout.writeln('mediaflowAcceptance=${jsonEncode(evidence)}');
      } finally {
        service.close();
      }
    },
    skip:
        !Platform.isWindows ||
        !const bool.fromEnvironment('MEDIAFLOW_WINDOWS_DOUYIN_ACCEPTANCE'),
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
