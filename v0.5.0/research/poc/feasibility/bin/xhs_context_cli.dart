import 'dart:convert';
import 'dart:io';
import 'package:feasibility/probe.dart';

const mobileLayoutAgent =
    'MediaFlowResearch/0.5.0 (windows; Android-compatible layout)';

Future<void> main(List<String> args) async {
  final mode = args.first;
  final keys = args.skip(1).toSet();
  final results = <Map<String, Object?>>[];
  final output = File('../windows-xhs-$mode-context-results.json');
  if (await output.exists()) {
    throw StateError('Preserve saved operation; choose a new operation name');
  }
  for (final sample in samples.where(
    (s) => s['platform'] == 'xiaohongshu' && keys.contains(s['key']),
  )) {
    final events = <Map<String, Object?>>[];
    final client = ProbeClient(
      events,
      researchUserAgent: mode.startsWith('mobile') ? mobileLayoutAgent : null,
    );
    final out = <String, Object?>{
      'sample': sample['key'],
      'platform': 'xiaohongshu',
      'os': Platform.operatingSystem,
      'atUtc': DateTime.now().toUtc().toIso8601String(),
      'events': events,
      'originalUrl': sample['url'],
      'contextMode': mode,
      'anonymousSession': false,
      'cookiesPersisted': false,
      'a1Sent': false,
      'webSessionSent': false,
      'homeInitialization': false,
      'status': 'RUNNING',
    };
    try {
      await xhs(
        client,
        out,
        Uri.parse(sample['url'] as String),
        Directory('../downloads/windows-xhs-$mode'),
        sample,
      );
      out['status'] = 'DATA_AND_DOWNLOAD_OBTAINED; systemOpen pending';
    } on ProbeFailure catch (e) {
      out.addAll({'status': 'STOPPED', 'failure': e.code, 'reason': e.reason});
    } catch (e) {
      out.addAll({
        'status': 'STOPPED',
        'failure': 'unknown',
        'reason': e.runtimeType.toString(),
      });
    } finally {
      client.close();
    }
    results.add(out);
    await output.writeAsString(
      const JsonEncoder.withIndent('  ').convert(results),
    );
    stdout.writeln(
      jsonEncode({
        'sample': out['sample'],
        'mode': mode,
        'status': out['status'],
        'failure': out['failure'],
        'metadata': out['metadata'],
        'downloads': out['downloads'],
      }),
    );
    if (out['failure'] == 'securityChallenge' ||
        out['failure'] == 'resourceForbidden') {
      break;
    }
  }
}
