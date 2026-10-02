import 'dart:convert';
import 'dart:io';
import 'package:feasibility/probe.dart';

Future<void> main(List<String> args) async {
  final file = File(args.isEmpty ? '../windows-real-results.json' : args.first);
  final results = <Map<String, Object?>>[];
  for (final sample in samples) {
    if (args.length > 1 && sample['key'] != args[1]) continue;
    final result = await runSample(sample, Directory('../downloads/windows'));
    results.add(result);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(results),
    );
    stdout.writeln(
      jsonEncode({
        'sample': result['sample'],
        'status': result['status'],
        'failure': result['failure'],
        'reason': result['reason'],
      }),
    );
  }
}
