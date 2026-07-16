enum DownloadFailureCode {
  networkError,
  invalidResponse,
  fileSystemError,
  cancelled,
  singleTaskLimit,
}

class DownloadException implements Exception {
  const DownloadException({
    required this.code,
    required this.message,
    this.cause,
  });

  final DownloadFailureCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'DownloadException(${code.name}): $message';
}
