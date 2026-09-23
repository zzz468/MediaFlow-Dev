import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/browser/observation/browser_network_observation.dart';
import 'package:mediaflow/features/parser/data/douyin/observation/douyin_browser_observation_result.dart';
import 'package:mediaflow/features/parser/data/douyin/observation/douyin_network_observation_consumer.dart';

void main() {
  test(
    'diagnostic consumer calls existing decoder and stops on exact target',
    () {
      final consumer = DouyinNetworkObservationConsumer(
        targetWorkId: '1000000000000000001',
      );
      final bytes = File(
        'test/features/parser/douyin/observation/fixtures/aweme_detail.redacted.json',
      ).readAsBytesSync();
      final response = BorrowedJsonResponse(
        Uint8List.fromList(bytes),
        JsonResponseProvenance(
          responseHost: 'www.douyin.com',
          resourceType: JsonResponseResourceType.xhr,
          httpStatus: 200,
          mimeType: 'application/json',
          responseBytes: bytes.length,
          observedAt: DateTime.utc(2026, 9, 18),
        ),
      );
      expect(consumer.consume(response), JsonConsumerDecision.found);
      response.dispose();
      expect(consumer.result!.outcome, DouyinBrowserObservationOutcome.found);
      expect(consumer.result!.provenance.objectPath, r'$.aweme_detail');
      expect(consumer.result!.work!.mediaVariants, isNotEmpty);
      consumer.reset();
      expect(consumer.result, isNull);
    },
  );
}
