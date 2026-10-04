import 'dart:convert';
import 'dart:io';
import '../lib/social_probe.dart';

Future<void> main(List<String> args) async {
  final d = <String, Object?>{
    'os': Platform.operatingSystem,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
  };
  try {
    await SocialProbe().parse(
      args.first,
      d,
      instagramGraphql: args.contains('--graphql'),
      initializedContext: args.contains('--context'),
    );
  } catch (e) {
    d['errorCategory'] = categoryFor(e);
    d['summary'] = e is ProbeFailure ? e.reason : e.runtimeType.toString();
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(d));
}
