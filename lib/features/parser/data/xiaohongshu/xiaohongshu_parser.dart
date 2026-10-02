import 'dart:async';
import '../../../../core/models/media_link.dart';
import '../../../../core/network/network_client.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/parser_interface.dart';
import '../../domain/parser_result.dart';
import 'xiaohongshu_decoder.dart';
import 'xiaohongshu_failure.dart';
import 'xiaohongshu_resource_mapper.dart';
import 'xiaohongshu_url.dart';
import 'xiaohongshu_http_client.dart';

final class XiaohongshuParser implements ParserInterface {
  const XiaohongshuParser({required this.networkClient});
  final NetworkClient networkClient;
  @override
  MediaPlatform get platform => MediaPlatform.xiaohongshu;
  @override
  bool supports(MediaLink link) => link.platform == platform;

  @override
  Future<ParserResult> parse(MediaLink link) async {
    final uri = XiaohongshuUrl.input(link.normalizedUri);
    if (uri == null) {
      return const XiaohongshuFailure(ParserFailureCode.unsupportedUrl).result;
    }
    try {
      final response = await networkClient.get(uri);
      if (!XiaohongshuUrl.isPage(response.finalUri)) {
        throw const XiaohongshuFailure(ParserFailureCode.unsupportedUrl);
      }
      final rejection = XiaohongshuFailure.rejection(
        response.statusCode,
        response.finalUri,
      );
      if (rejection != null) throw XiaohongshuFailure(rejection);
      final id = XiaohongshuUrl.noteId(response.finalUri);
      if (response.statusCode != 200 ||
          id == null ||
          response.bodyBytes.length > XiaohongshuHttpClient.maxPageBytes) {
        throw const XiaohongshuFailure(ParserFailureCode.parseNoMatch);
      }
      final requestedId = XiaohongshuUrl.noteId(uri);
      if (requestedId != null && requestedId != id) {
        throw const XiaohongshuFailure(ParserFailureCode.parseNoMatch);
      }
      final note = const XiaohongshuDecoder().decode(response.body, id);
      final content = const XiaohongshuResourceMapper().map(note, id);
      AppLogger.info(
        'XHS note=$id type=${content.type.name} resources=${content.resources.length}',
        category: LogCategory.parser,
      );
      return ParserContentSuccess(content);
    } on XiaohongshuFailure catch (failure) {
      AppLogger.info(
        'XHS category=${failure.code}',
        category: LogCategory.parser,
      );
      return failure.result;
    } on NetworkRequestException {
      return const XiaohongshuFailure(ParserFailureCode.networkFailure).result;
    } on TimeoutException {
      return const XiaohongshuFailure(ParserFailureCode.networkFailure).result;
    } on FormatException {
      return const XiaohongshuFailure(ParserFailureCode.parseNoMatch).result;
    } on TypeError {
      return const XiaohongshuFailure(ParserFailureCode.parseNoMatch).result;
    } catch (_) {
      return const XiaohongshuFailure(ParserFailureCode.unknown).result;
    }
  }
}
