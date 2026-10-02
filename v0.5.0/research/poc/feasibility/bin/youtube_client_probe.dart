import 'dart:convert';
import 'dart:io';
import 'package:feasibility/youtube_client_evaluation.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('public URL and local output path required');
  }
  final report = await evaluateClients(
    args[0],
    (report) => File(args[1])
        .writeAsString(
          const JsonEncoder.withIndent(
            '  ',
          ).convert({...report, 'platform': Platform.operatingSystem}),
        )
        .then((_) {}),
  );
  stdout.writeln(report['state']);
}
