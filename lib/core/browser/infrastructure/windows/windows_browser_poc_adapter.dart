import 'dart:convert';
import 'dart:io';

import '../../domain/browser_adapter.dart';

typedef BrowserHelperRunner =
    Future<ProcessResult> Function(String, List<String>);

/// Windows-only PoC infrastructure. Not registered with any production parser.
class WindowsBrowserPocAdapter implements BrowserAdapter {
  WindowsBrowserPocAdapter({
    required this.executable,
    BrowserHelperRunner? runner,
  }) : _runner = runner ?? ((exe, args) => Process.run(exe, args));
  final String executable;
  final BrowserHelperRunner _runner;

  @override
  Future<BrowserObservation> inspect(BrowserRequest request) async {
    if (!request.isAllowed) {
      return const BrowserObservation(outcome: BrowserOutcome.invalidRequest);
    }
    try {
      final result = await _runner(executable, [
        request.uri.toString(),
        request.allowedHosts.join(','),
      ]);
      if (result.exitCode != 0) {
        throw const FormatException();
      }
      final decoded = jsonDecode(result.stdout.toString().trim());
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final outcome = BrowserOutcome.values.firstWhere(
        (v) => v.name == decoded['status'],
        orElse: () => BrowserOutcome.readFailed,
      );
      return BrowserObservation(
        outcome: outcome,
        publicData: decoded['snapshot'] is Map<String, dynamic>
            ? Map<String, Object?>.unmodifiable(
                decoded['snapshot'] as Map<String, dynamic>,
              )
            : const {},
        profileCleaned: decoded['profileCleaned'] == true,
        runtime: decoded['runtime'] as String?,
      );
    } on ProcessException {
      return const BrowserObservation(
        outcome: BrowserOutcome.helperUnavailable,
      );
    } catch (_) {
      return const BrowserObservation(outcome: BrowserOutcome.readFailed);
    }
  }
}
