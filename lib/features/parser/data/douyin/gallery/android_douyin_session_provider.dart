import 'package:flutter/services.dart';

import 'douyin_gallery_backend.dart';
import 'douyin_gallery_capabilities.dart';
import 'f2_gallery_signer.dart';

/// Private platform bridge, never a content observation/parser route.
final class AndroidDouyinSessionProvider implements DouyinSessionProvider {
  AndroidDouyinSessionProvider({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.mediaflow.mediaflow/douyin_session');
  final MethodChannel _channel;
  DouyinSessionContext? _current;
  bool _blocked = false;
  bool _unsupported = false;
  bool _stateRead = false;
  int _epoch = 0;
  Future<DouyinSessionContext?>? _pending;

  Future<DouyinSessionContext?> _load(String command) async {
    if (_blocked) return null;
    if (_pending != null) return _pending;
    final operation = _read(command);
    _pending = operation;
    try {
      return await operation;
    } finally {
      _pending = null;
    }
  }

  Future<DouyinSessionContext?> _read(String command) async {
    final epoch = _epoch;
    Map<Object?, Object?>? data;
    try {
      data = await _channel.invokeMethod<Map<Object?, Object?>>(command);
      _unsupported = data?['status'] == 'unsupported';
      _stateRead = true;
      if (data?['status'] != 'ready' || epoch != _epoch) return null;
      final cookies = Map<String, String>.from(data!['cookies'] as Map);
      try {
        final context = DouyinSessionContext(
          userAgent: data['ua'] as String,
          browserPlatform: data['platform'] as String,
          browserMetrics: (data['metrics'] as List).cast<int>(),
          runtimeQuery: Map<String, String>.from(data['query'] as Map),
          sessionid: cookies['sessionid'],
          sessionidSs: cookies['sessionid_ss'],
          ttwid: cookies['ttwid'],
          msToken: cookies['msToken'],
        );
        _current?.invalidate();
        _current = context;
        return context.usable ? context : null;
      } finally {
        cookies.clear();
      }
    } catch (_) {
      return null;
    } finally {
      data?.remove('cookies');
    }
  }

  @override
  Future<DouyinSessionHandle?> getExistingSession() async {
    if (_blocked) return null;
    if (_current != null) return _current!.usable ? _current : null;
    return _load('restore');
  }

  @override
  Future<DouyinSessionHandle?> establishWithUserInteraction() =>
      _load('establish');
  @override
  Future<DouyinSessionState> getState() async {
    if (_current != null) {
      return _current!.usable
          ? DouyinSessionState.ready
          : DouyinSessionState.expired;
    }
    if (!_stateRead && await getExistingSession() != null) {
      return DouyinSessionState.ready;
    }
    return _unsupported
        ? DouyinSessionState.unsupported
        : DouyinSessionState.unavailable;
  }

  @override
  Future<bool> clear() async {
    _blocked = true;
    _epoch++;
    _current?.invalidate();
    _current = null;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'clear',
      );
      _blocked = result?['status'] != 'cleared';
      return !_blocked;
    } catch (_) {
      return false;
    }
  }
}

DouyinGalleryBackend createAndroidDouyinGalleryBackend({
  AndroidDouyinSessionProvider? sessions,
  DouyinDetailTransport? transport,
  bool argusCompatibilityHeader = true,
}) => DouyinGalleryBackend(
  sessions: sessions ?? AndroidDouyinSessionProvider(),
  client: F2DouyinGalleryDetailClient(
    signer: F2GallerySigner(),
    transport: transport ?? DirectDouyinDetailTransport(),
    argusCompatibilityHeader: argusCompatibilityHeader,
  ),
);
