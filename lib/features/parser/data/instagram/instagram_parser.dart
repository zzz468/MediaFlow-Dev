import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../core/models/media_link.dart';
import '../../domain/parser_interface.dart';
import '../../domain/parser_result.dart';
import 'instagram_url.dart';
import 'instagram_failure.dart';
import 'instagram_http_session.dart';
import 'instagram_resource_mapper.dart';

final class InstagramParser implements ParserInterface {
  InstagramParser({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;
  final http.Client Function() _clientFactory;
  @override
  MediaPlatform get platform => MediaPlatform.instagram;
  @override
  bool supports(MediaLink link) => link.platform == platform;
  @override
  Future<ParserResult> parse(MediaLink link) async {
    final source = InstagramUrl.normalize(link.normalizedUri);
    if (source == null) {
      return const InstagramFailure(ParserFailureCode.unsupportedUrl).result;
    }
    try {
      final id = source.pathSegments[1];
      final data = await InstagramHttpSession(_clientFactory()).load(id);
      return ParserContentSuccess(mapInstagramContent(data, source, id));
    } on InstagramFailure catch (failure) {
      return failure.result;
    } on TimeoutException {
      return const InstagramFailure(ParserFailureCode.networkFailure).result;
    } on SocketException {
      return const InstagramFailure(ParserFailureCode.networkFailure).result;
    } on HandshakeException {
      return const InstagramFailure(ParserFailureCode.networkFailure).result;
    } on http.ClientException {
      return const InstagramFailure(ParserFailureCode.networkFailure).result;
    } catch (_) {
      // Never attach raw responses, URLs or anonymous state to logging/cause.
      return const InstagramFailure(ParserFailureCode.parseNoMatch).result;
    }
  }
}
