import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../core/models/media_link.dart';
import '../../domain/parser_interface.dart';
import '../../domain/parser_result.dart';
import 'x_failure.dart';
import 'x_resource_mapper.dart';
import 'x_syndication_token.dart';
import 'x_url.dart';

final class XParser implements ParserInterface {
  XParser({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;
  final http.Client Function() _clientFactory;
  @override
  MediaPlatform get platform => MediaPlatform.x;
  @override
  bool supports(MediaLink link) => link.platform == platform;
  @override
  Future<ParserResult> parse(MediaLink link) async {
    final source = XUrl.normalize(link.normalizedUri);
    if (source == null) {
      return const XFailure(ParserFailureCode.unsupportedUrl).result;
    }
    final client = _clientFactory();
    try {
      final id = source.pathSegments.last;
      final request = http.Request(
        'GET',
        Uri.https('cdn.syndication.twimg.com', '/tweet-result', {
          'id': id,
          'lang': 'en',
          'token': syndicationToken(id),
        }),
      )..followRedirects = false;
      request.headers['User-Agent'] = 'MediaFlow-Research/0.6.0';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      final code = switch (response.statusCode) {
        200 => null,
        401 => ParserFailureCode.loginRequired,
        403 => ParserFailureCode.resourceForbidden,
        429 => ParserFailureCode.rateLimited,
        404 || 410 => ParserFailureCode.notFound,
        >= 300 && < 400 => _redirectCode(response.headers['location']),
        _ => ParserFailureCode.networkFailure,
      };
      if (code != null) throw XFailure(code);
      const maxBytes = 8 * 1024 * 1024;
      if ((response.contentLength ?? 0) > maxBytes) {
        throw const XFailure(ParserFailureCode.parseNoMatch);
      }
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const XFailure(ParserFailureCode.parseNoMatch);
        }
        bytes.addAll(chunk);
      }
      return ParserContentSuccess(
        mapXContent(jsonDecode(utf8.decode(bytes)), source, id),
      );
    } on XFailure catch (failure) {
      return failure.result;
    } on TimeoutException {
      return const XFailure(ParserFailureCode.networkFailure).result;
    } on SocketException {
      return const XFailure(ParserFailureCode.networkFailure).result;
    } on HandshakeException {
      return const XFailure(ParserFailureCode.networkFailure).result;
    } on http.ClientException {
      return const XFailure(ParserFailureCode.networkFailure).result;
    } catch (_) {
      return const XFailure(ParserFailureCode.parseNoMatch).result;
    } finally {
      client.close();
    }
  }

  String _redirectCode(String? location) {
    final path = Uri.tryParse(location ?? '')?.path ?? '';
    if (path.contains('login')) return ParserFailureCode.loginRequired;
    if (path.contains('challenge') || path.contains('checkpoint')) {
      return ParserFailureCode.securityChallenge;
    }
    return ParserFailureCode.resourceForbidden;
  }
}
