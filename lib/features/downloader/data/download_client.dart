class DownloadStreamResponse {
  const DownloadStreamResponse({
    required this.statusCode,
    required this.stream,
    required this.finalUri,
    this.contentLength,
    this.headers = const {},
  });

  final int statusCode;
  final Stream<List<int>> stream;
  final Uri finalUri;
  final int? contentLength;
  final Map<String, String> headers;
}

abstract interface class DownloadClient {
  Future<DownloadStreamResponse> open(
    Uri uri, {
    Map<String, String> headers = const {},
  });

  void close();
}
