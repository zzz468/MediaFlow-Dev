import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/network/network_client.dart';

import '../helpers/fake_http_client.dart';

void main() {
  test('preserves the final URL after redirects', () async {
    final originalUri = Uri.parse('https://short.example.test/share');
    final redirectedUri = Uri.parse(
      'https://www.example.test/video/1234567890',
    );
    final httpClient = ScriptedHttpClient((request) async {
      expect(request.followRedirects, isFalse);
      expect(request.headers['x-mediaflow-test'], 'redirect');
      if (request.url == originalUri) {
        return streamedResponse(
          '',
          request: request,
          statusCode: 302,
          headers: <String, String>{'location': redirectedUri.toString()},
        );
      }
      expect(request.url, redirectedUri);
      return streamedResponse(
        '<html>redirected response</html>',
        request: request,
        headers: const <String, String>{'content-type': 'text/html'},
      );
    });
    final client = HttpNetworkClient(client: httpClient);
    addTearDown(client.close);

    final response = await client.get(
      originalUri,
      headers: const <String, String>{'x-mediaflow-test': 'redirect'},
    );

    expect(response.statusCode, 200);
    expect(response.body, '<html>redirected response</html>');
    expect(response.finalUri, redirectedUri);
    expect(response.headers['content-type'], 'text/html');
    expect(httpClient.requests, <Uri>[originalUri, redirectedUri]);
  });
}
