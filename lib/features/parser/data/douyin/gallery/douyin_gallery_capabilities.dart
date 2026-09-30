/// Shared capability contracts for the ordinary Douyin Gallery URL flow.
/// Implementations belong to the Douyin infrastructure boundary.
enum DouyinSessionState { unavailable, ready, expired, unsupported }

/// Opaque platform-owned capability. No Cookie/token getters or serialization.
abstract interface class DouyinSessionHandle {}

abstract interface class DouyinSessionProvider {
  Future<DouyinSessionState> getState();

  /// Opens the App-owned normal interaction surface only after user intent.
  /// A challenge pauses automatic consumption until the user finishes it.
  Future<DouyinSessionHandle?> establishWithUserInteraction();

  /// Returns an existing local capability without opening UI or logging in.
  Future<DouyinSessionHandle?> getExistingSession();

  /// Invalidates handles, cancels work and removes all owned platform state.
  /// False means cleanup could not be verified, and must be visible to the user.
  Future<bool> clear();
}

abstract interface class DouyinGalleryDetailClient {
  /// One bounded request; no security retries, other endpoints or identity
  /// escalation. Returns only allowlisted content fields, never credentials.
  Future<Map<String, Object?>> fetchDetail({
    required String awemeId,
    required DouyinSessionHandle session,
  });
}
