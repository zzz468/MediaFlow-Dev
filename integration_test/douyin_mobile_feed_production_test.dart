import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/main.dart' as app;

import '../tools/douyin_http_probe/probe.dart' as probe;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'production ParserService resolves two public works',
    (tester) async {
      final flutterErrors = FlutterError.onError;
      final platformErrors = PlatformDispatcher.instance.onError;
      app.main();
      FlutterError.onError = flutterErrors;
      PlatformDispatcher.instance.onError = platformErrors;
      await tester.pump(const Duration(seconds: 1));

      final service = createDefaultParserService();
      const workIds = ['7682375032253180345', '7660061608801996068'];
      try {
        for (final workId in workIds) {
          final result = await service
              .parseUri(Uri.https('www.douyin.com', '/video/$workId'))
              .timeout(const Duration(seconds: 90));
          if (result is ParserFailure) {
            stdout.writeln(
              jsonEncode({
                'platform': Platform.operatingSystem,
                'workId': workId,
                'productionParser': 'failure',
                'failureCode': result.code,
              }),
            );
            fail('Production parser returned ${result.code} for $workId');
          }
          final info = (result as ParserSuccess).videoInfo;
          final evidence = <String, Object?>{
            'platform': Platform.operatingSystem,
            'workId': workId,
            'productionParser': 'success',
            'targetIdMatched': info.id == workId,
            'titlePresent': info.title.trim().isNotEmpty,
            'authorPresent': info.author?.trim().isNotEmpty == true,
            'mediaUrlPresent': info.videoUrl.hasAuthority,
            'qualityCount': info.qualityOptions.length,
            'mobileFeedUsed': info.metadata['mobileFeedUsed'] == true,
            'browserObservationUsed':
                info.metadata['browserObservationUsed'] == true,
          };
          stdout.writeln('mediaflowProductionFeed=${jsonEncode(evidence)}');
          expect(evidence['targetIdMatched'], isTrue);
          expect(evidence['titlePresent'], isTrue);
          expect(evidence['authorPresent'], isTrue);
          expect(evidence['mediaUrlPresent'], isTrue);
          expect(evidence['qualityCount'], greaterThan(0));
          expect(evidence['mobileFeedUsed'], isTrue);
          expect(evidence['browserObservationUsed'], isFalse);

          final selected = await probe.probeMediaLocation(
            info.videoUrl,
            'production_selected',
          );
          stdout.writeln(
            'mediaflowProductionMedia=${jsonEncode({'platform': Platform.operatingSystem, 'workId': workId, ...selected})}',
          );
          expect(selected['statusCode'], 206);
          expect(selected['contentType'], 'video/mp4');
          expect(selected['mp4HeaderFound'], isTrue);

          for (final media in await probe.probeMedia(workId)) {
            stdout.writeln(
              'mediaflowProductionMedia=${jsonEncode({'platform': Platform.operatingSystem, 'workId': workId, ...media})}',
            );
            expect(media['statusCode'], 206);
            expect(media['contentType'], 'video/mp4');
            expect(media['mp4HeaderFound'], isTrue);
          }
        }
      } finally {
        service.close();
      }
    },
    skip: !Platform.isAndroid && !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
