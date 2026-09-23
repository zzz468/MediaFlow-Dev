/// Browser infrastructure is independent of platform parsers and VideoInfo.
abstract interface class BrowserAdapter {
  Future<BrowserObservation> inspect(BrowserRequest request);
}

class BrowserRequest {
  BrowserRequest({required this.uri, required Set<String> allowedHosts})
    : allowedHosts = Set.unmodifiable(allowedHosts);
  final Uri uri;
  final Set<String> allowedHosts;
  bool get isAllowed =>
      uri.scheme == 'https' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      allowedHosts.contains(uri.host);
}

enum BrowserOutcome {
  loaded,
  noPublicMedia,
  browserVerification,
  loginRequired,
  regionRestricted,
  accessRestricted,
  navigationRejected,
  navigationFailed,
  runtimeUnavailable,
  readFailed,
  timeout,
  cancelled,
  invalidRequest,
  helperUnavailable,
}

class BrowserObservation {
  const BrowserObservation({
    required this.outcome,
    this.publicData = const {},
    this.profileCleaned = false,
    this.runtime,
  });
  final BrowserOutcome outcome;

  /// Only allowlisted public DOM metadata/resources, never Cookie/storage/HTML.
  final Map<String, Object?> publicData;
  final bool profileCleaned;
  final String? runtime;
}
