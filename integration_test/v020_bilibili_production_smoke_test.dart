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
    'production Bilibili parser resolves three public works',
    (tester) async {
      final flutterErrors = FlutterError.onError;
      final platformErrors = PlatformDispatcher.instance.onError;
      app.main();
      FlutterError.onError = flutterErrors;
      PlatformDispatcher.instance.onError = platformErrors;
      await tester.pump(const Duration(seconds: 1));

      final service = createDefaultParserService();
      const ids = ['BV1uzez6UEoP', 'BV14yhr6GEbH', 'BV1kceH6DEzQ'];
      try {
        for (final id in ids) {
          final result = await service
              .parseUri(Uri.https('www.bilibili.com', '/video/$id'))
              .timeout(const Duration(seconds: 90));
          final evidence = <String, Object?>{
            'platform': Platform.operatingSystem,
            'id': id,
            'result': result is ParserSuccess ? 'success' : 'failure',
            if (result is ParserFailure) 'failureCode': result.code,
            if (result is ParserSuccess) ...{
              'idMatched': result.videoInfo.id == id,
              'titlePresent': result.videoInfo.title.trim().isNotEmpty,
              'authorPresent':
                  result.videoInfo.author?.trim().isNotEmpty == true,
              'mediaUrlAvailable':
                  result.videoInfo.metadata['mediaUrlAvailable'] == true,
              'qualityCount': result.videoInfo.qualityOptions.length,
            },
          };
          stdout.writeln('mediaflowBilibiliSmoke=${jsonEncode(evidence)}');
          expect(result, isA<ParserSuccess>(), reason: jsonEncode(evidence));
          final info = (result as ParserSuccess).videoInfo;
          expect(info.id, id);
          expect(info.title, isNotEmpty);
          expect(info.metadata['mediaUrlAvailable'], true);
          expect(info.qualityOptions, isNotEmpty);
        }
      } finally {
        service.close();
      }
    },
    skip: !Platform.isAndroid && !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
