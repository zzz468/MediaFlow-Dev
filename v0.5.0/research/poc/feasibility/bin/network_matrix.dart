import 'dart:convert';
import 'dart:io';
import 'package:feasibility/probe.dart';

Future<void> main() async {
  final results = <Map<String, Object?>>[];
  for (final sample in [samples[0], samples[3]]) {
    final url = Uri.parse(sample['url'] as String);
    final result = <String, Object?>{
      'sample': sample['key'],
      'host': url.host,
      'os': Platform.operatingSystem,
      'resolver': 'system',
      'proxy': 'DIRECT',
    };
    try {
      result['phase'] = 'dns';
      result['dns'] = (await InternetAddress.lookup(url.host).timeout(
        const Duration(seconds: 6),
      )).map((a) => {'address': a.address, 'family': a.type.name}).toList();
      result['phase'] = 'tcp';
      final tcp = await Socket.connect(
        url.host,
        443,
        timeout: const Duration(seconds: 6),
      );
      result['tcpRemote'] = tcp.remoteAddress.address;
      tcp.destroy();
      result['phase'] = 'tls';
      final tls = await SecureSocket.connect(
        url.host,
        443,
        timeout: const Duration(seconds: 8),
      );
      result['certificateValidated'] = true;
      tls.destroy();
      result['phase'] = 'http';
      final events = <Map<String, Object?>>[];
      final client = ProbeClient(events);
      result['events'] = events;
      try {
        final page = await client.page(url);
        result['http'] = page.statusCode;
        result['bodyBytes'] = page.bodyBytes.length;
        result['finalUrlRedacted'] = redacted(page.request!.url);
        result['status'] = 'HTTP REACHED';
      } finally {
        client.close();
      }
    } catch (error) {
      result['status'] = 'STOPPED';
      result['failure'] = error is ProbeFailure
          ? error.code
          : 'networkFailure.${result['phase']}';
      result['errorType'] = error.runtimeType.toString();
      if (error is SocketException) {
        result['osError'] = error.osError?.errorCode;
      }
    }
    results.add(result);
  }
  await File(
    '../windows-dart-network-matrix-resume.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
  stdout.writeln(jsonEncode(results));
}
