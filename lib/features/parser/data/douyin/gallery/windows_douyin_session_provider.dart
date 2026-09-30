import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'douyin_gallery_backend.dart';
import 'douyin_gallery_capabilities.dart';
import 'f2_gallery_signer.dart';

typedef WindowsSessionBridge =
    Future<Map<String, dynamic>> Function(String command);

/// Windows-only private infrastructure. Redirected IPC is consumed here only,
/// never forwarded to UI/logging/history or persisted as a secret file.
final class WindowsDouyinSessionProvider implements DouyinSessionProvider {
  WindowsDouyinSessionProvider({
    required String executable,
    WindowsSessionBridge? bridge,
  }) : _bridge = bridge ?? ((command) => _run(executable, command));
  final WindowsSessionBridge _bridge;
  DouyinSessionContext? _current;
  Future<Map<String, dynamic>>? _pending;
  Future<DouyinSessionContext?>? _loading;
  bool _unsupported = false;
  bool _stateRead = false;
  bool _cleanupFailed = false;
  int _epoch = 0;
  static Future<Map<String, dynamic>> _run(
    String executable,
    String command,
  ) async {
    if (!Platform.isWindows) {
      return {'status': 'unsupported'};
    }
    Process? process;
    try {
      process = await Process.start(
        executable,
        const [],
        mode: ProcessStartMode.normal,
      );
      final stderr = process.stderr.drain<void>();
      final output = (() async {
        final bytes = <int>[];
        await for (final chunk in process!.stdout) {
          if (bytes.length + chunk.length > 16384) {
            throw const FormatException('Session IPC exceeded limit.');
          }
          bytes.addAll(chunk);
        }
        return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      })();
      process.stdin.writeln(jsonEncode({'command': command}));
      await process.stdin.close();
      final result = await output.timeout(
        Duration(minutes: command == 'establish' ? 10 : 1),
      );
      final exit = await process.exitCode.timeout(const Duration(seconds: 15));
      await stderr;
      if (exit != 0) {
        return {'status': 'unavailable'};
      }
      return result;
    } catch (_) {
      process?.kill();
      return {'status': 'unavailable'};
    }
  }

  Future<DouyinSessionContext?> _load(String command) async {
    if (_cleanupFailed) return null;
    if (_loading != null) return _loading!;
    final loading = _loadOwned(command);
    _loading = loading;
    try {
      return await loading;
    } finally {
      _loading = null;
    }
  }

  Future<DouyinSessionContext?> _loadOwned(String command) async {
    final epoch = _epoch;
    _pending ??= _bridge(command);
    Map<String, dynamic> data;
    try {
      data = await _pending!;
    } finally {
      _pending = null;
    }
    _unsupported = data['status'] == 'unsupported';
    _stateRead = true;
    if (epoch != _epoch || data['status'] != 'ready') {
      data.remove('cookies');
      return null;
    }
    final cookies = data.remove('cookies');
    if (cookies is! Map) {
      return null;
    }
    DouyinSessionContext context;
    try {
      context = DouyinSessionContext(
        userAgent: data['ua'] as String,
        browserMetrics: (data['metrics'] as List).cast<int>(),
        runtimeQuery: (data['query'] as Map).cast<String, String>(),
        sessionid: cookies['sessionid'] as String?,
        sessionidSs: cookies['sessionid_ss'] as String?,
        ttwid: cookies['ttwid'] as String?,
        msToken: cookies['msToken'] as String?,
        expiresAt: data['expiresAt'] is String
            ? DateTime.parse(data['expiresAt'] as String)
            : null,
      );
    } catch (_) {
      return null;
    } finally {
      cookies.clear();
    }
    _current?.invalidate();
    _current = context;
    return context.usable ? context : null;
  }

  @override
  Future<DouyinSessionState> getState() async {
    if (_current != null) {
      return _current!.usable
          ? DouyinSessionState.ready
          : DouyinSessionState.expired;
    }
    if (!_stateRead && await _load('restore') != null) {
      return DouyinSessionState.ready;
    }
    return _unsupported
        ? DouyinSessionState.unsupported
        : DouyinSessionState.unavailable;
  }

  @override
  Future<DouyinSessionHandle?> getExistingSession() async {
    if (_cleanupFailed) return null;
    // Do not silently re-admit persisted Cookies after server rejection.
    if (_current != null) return _current!.usable ? _current : null;
    return await _load('restore');
  }

  @override
  Future<DouyinSessionHandle?> establishWithUserInteraction() async =>
      _load('establish');
  @override
  Future<bool> clear() async {
    _cleanupFailed = true;
    _epoch++;
    _current?.invalidate();
    _current = null;
    final pending = _pending;
    if (pending != null) {
      await pending;
    }
    final result = await _bridge('clear');
    _cleanupFailed = result['status'] != 'cleared';
    return !_cleanupFailed;
  }
}

/// Candidate factory only. Main parser/UI registration intentionally absent.
DouyinGalleryBackend createWindowsDouyinGalleryBackend({
  required String sessionExecutable,
  bool argusCompatibilityHeader = false,
  DouyinDetailTransport? transport,
}) => DouyinGalleryBackend(
  sessions: WindowsDouyinSessionProvider(executable: sessionExecutable),
  client: F2DouyinGalleryDetailClient(
    signer: F2GallerySigner(),
    transport: transport ?? DirectDouyinDetailTransport(),
    argusCompatibilityHeader: argusCompatibilityHeader,
  ),
);
