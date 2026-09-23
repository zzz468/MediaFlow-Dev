import 'dart:async';
import 'dart:convert';

import '../../../../core/network/network_client.dart';

enum DouyinMobileFeedFailure {
  invalidWorkId,
  timeout,
  network,
  unexpectedOrigin,
  httpStatus,
  contentType,
  responseTooLarge,
  invalidJson,
  missingList,
  targetMissing,
  duplicateTarget,
  missingDescription,
  missingAuthor,
  missingVideo,
  missingPlayAddress,
  missingDownloadAddress,
}

final class DouyinMobileFeedAttempt {
  const DouyinMobileFeedAttempt({this.work, this.failure, this.statusCode});

  final Map<String, dynamic>? work;
  final DouyinMobileFeedFailure? failure;
  final int? statusCode;
}

/// Anonymous, bounded Douyin-only feed request. Each production attempt owns a
/// fresh HttpNetworkClient with redirects disabled and no Cookie header.
final class DouyinMobileFeedSession {
  const DouyinMobileFeedSession({this.client});

  final NetworkClient? client;

  static const _host = 'api5-normal-c-hl.amemv.com';
  static const _path = '/aweme/v1/feed/';
  static const _timeout = Duration(seconds: 15);
  static const _maxBodyBytes = 2 * 1024 * 1024;
  static const _headers = <String, String>{
    'Accept': 'application/json',
    'User-Agent': 'MediaFlow/0.2.0 (anonymous local HTTP client)',
  };

  Future<DouyinMobileFeedAttempt> fetch(String workId) async {
    if (!RegExp(r'^[1-9][0-9]{4,24}$').hasMatch(workId)) {
      return const DouyinMobileFeedAttempt(
        failure: DouyinMobileFeedFailure.invalidWorkId,
      );
    }
    final ownedClient = client == null
        ? HttpNetworkClient(maxRedirects: 0)
        : null;
    final requestClient = client ?? ownedClient!;
    try {
      final uri = Uri.https(_host, _path, {'aweme_id': workId, 'aid': '1128'});
      final response = await requestClient
          .get(uri, headers: _headers)
          .timeout(_timeout);
      if (response.finalUri.scheme != 'https' ||
          response.finalUri.host != _host ||
          response.finalUri.port != 443 ||
          response.finalUri.path != _path) {
        return DouyinMobileFeedAttempt(
          failure: DouyinMobileFeedFailure.unexpectedOrigin,
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode != 200) {
        return DouyinMobileFeedAttempt(
          failure: DouyinMobileFeedFailure.httpStatus,
          statusCode: response.statusCode,
        );
      }
      final contentType = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (contentType != 'application/json') {
        return const DouyinMobileFeedAttempt(
          failure: DouyinMobileFeedFailure.contentType,
        );
      }
      if (response.bodyBytes.length > _maxBodyBytes) {
        return const DouyinMobileFeedAttempt(
          failure: DouyinMobileFeedFailure.responseTooLarge,
        );
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        return const DouyinMobileFeedAttempt(
          failure: DouyinMobileFeedFailure.invalidJson,
        );
      }
      if (decoded is! Map<String, dynamic> || decoded['aweme_list'] is! List) {
        return const DouyinMobileFeedAttempt(
          failure: DouyinMobileFeedFailure.missingList,
        );
      }
      final matches = <Map<String, dynamic>>[];
      for (final item in decoded['aweme_list'] as List) {
        if (item is Map<String, dynamic> &&
            item['aweme_id']?.toString() == workId) {
          matches.add(item);
        }
      }
      if (matches.isEmpty) {
        return const DouyinMobileFeedAttempt(
          failure: DouyinMobileFeedFailure.targetMissing,
        );
      }
      if (matches.length != 1) {
        return const DouyinMobileFeedAttempt(
          failure: DouyinMobileFeedFailure.duplicateTarget,
        );
      }
      final work = matches.single;
      if (!_nonEmpty(work['desc']) && !_nonEmpty(work['title'])) {
        return const DouyinMobileFeedAttempt(
          failure: DouyinMobileFeedFailure.missingDescription,
        );
      }
      final author = work['author'];
      if (author is! Map || !_nonEmpty(author['nickname'])) {
        return const DouyinMobileFeedAttempt(
          failure: DouyinMobileFeedFailure.missingAuthor,
        );
      }
      final video = work['video'];
      if (video is! Map) {
        return const DouyinMobileFeedAttempt(
          failure: DouyinMobileFeedFailure.missingVideo,
        );
      }
      if (!_hasUsableUrl(video['play_addr'])) {
        return const DouyinMobileFeedAttempt(
          failure: DouyinMobileFeedFailure.missingPlayAddress,
        );
      }
      if (!_hasUsableUrl(video['download_addr'])) {
        return const DouyinMobileFeedAttempt(
          failure: DouyinMobileFeedFailure.missingDownloadAddress,
        );
      }
      return DouyinMobileFeedAttempt(
        work: work,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return const DouyinMobileFeedAttempt(
        failure: DouyinMobileFeedFailure.timeout,
      );
    } catch (_) {
      // Do not log exception messages: a client can include the request URL.
      return const DouyinMobileFeedAttempt(
        failure: DouyinMobileFeedFailure.network,
      );
    } finally {
      ownedClient?.close();
    }
  }

  static bool _nonEmpty(Object? value) =>
      value is String && value.trim().isNotEmpty;

  static bool _hasUsableUrl(Object? value) {
    if (value is! Map || value['url_list'] is! List) return false;
    for (final raw in value['url_list'] as List) {
      if (raw is! String) continue;
      final uri = Uri.tryParse(raw);
      if (uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.hasAuthority &&
          uri.userInfo.isEmpty) {
        return true;
      }
    }
    return false;
  }
}
