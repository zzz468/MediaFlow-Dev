import 'dart:convert';
import 'dart:io';
import 'package:feasibility/probe.dart';
import 'package:feasibility/youtube_watch_observation.dart';
Future<void> main() async {
  final rows = <Map<String,Object?>>[];
  for (final id in ['hLY9KMIU2BA','jNQXAC9IVRw']) {
    final events = <Map<String,Object?>>[];
    final client = ProbeClient(events, researchUserAgent: youtubeDesktopUserAgent);
    final row = <String,Object?>{'videoId':id, 'requests':events};
    rows.add(row);
    try {
      final response = await client.page(Uri.https('www.youtube.com','/watch',{'v':id}));
      row['httpStatus']=response.statusCode;
      row['status']='WATCH HTTP AVAILABLE';
    } catch (e) {
      row['status']= e is ProbeFailure && e.code=='networkFailure' ? 'BLOCKED BY ENVIRONMENT' : 'OTHER FAILURE';
      row['errorCategory']= e is ProbeFailure ? e.code : e.runtimeType.toString();
      row['reason']= e is ProbeFailure ? e.reason : 'raw exception omitted';
    } finally {client.close();}
  }
  final report={'platform':'windows','source':'existing ProbeClient; diagnostic-only; one watch request per sample; no production or Android logic changes','samples':rows};
  final text=const JsonEncoder.withIndent('  ').convert(report);
  await File('../../youtube-windows-environment-20261002.json').writeAsString(text);
  stdout.writeln(text);
}
