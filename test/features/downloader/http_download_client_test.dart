import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/downloader/data/http_download_client.dart';

void main() {
  test(
    'HttpDownloadClient streams bytes from a real local HTTP server',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) {
        expect(request.headers.value('referer'), 'https://example.test/');
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('video', 'mp4')
          ..headers.contentLength = 4
          ..add(const [1, 2, 3, 4]);
        request.response.close();
      });
      final client = HttpDownloadClient();
      addTearDown(client.close);

      final response = await client.open(
        Uri.parse('http://${server.address.address}:${server.port}/video.mp4'),
        headers: const {'Referer': 'https://example.test/'},
      );
      final bytes = await response.stream.expand((chunk) => chunk).toList();

      expect(response.statusCode, HttpStatus.ok);
      expect(response.contentLength, 4);
      expect(response.headers['content-type'], startsWith('video/mp4'));
      expect(bytes, <int>[1, 2, 3, 4]);
    },
  );
}
