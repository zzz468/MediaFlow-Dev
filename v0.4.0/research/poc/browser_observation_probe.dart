import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'douyin_gallery_probe.dart' as gallery;

Future<void> main(List<String> args) async {
  if (args.length != 2 ||
      !{
        'normal',
        'failure',
        'cancel',
        'target',
        'share',
        'shareFixture',
        'shareStopFixture',
        'rejectFixture',
      }.contains(args[1])) {
    throw ArgumentError('helper executable and scenario required');
  }
  const id = '7690029886242009957'; // Single authorized research fixture.
  final scenario = args[1];
  final share = scenario.startsWith('share');
  final p = await Process.start(args[0], ['douyinPublicObservation']);
  Map<String, dynamic>? finalFrame;
  String? profile;
  List<Uri> images = [];
  var exact = false;
  final watchdog = Timer(const Duration(seconds: 40), () {
    p.stdin.writeln(jsonEncode({'command': 'stop'}));
  });
  final killGuard = Timer(const Duration(seconds: 55), () => p.kill());
  final errors = p.stderr.drain<void>(); // Never export native raw diagnostics.
  p.stdin.writeln(
    jsonEncode({
      'enabled': true,
      'registered': true,
      'scenario': scenario,
      'navigation': scenario == 'failure'
          ? 'https://localhost/'
          : share
          ? 'https://www.iesdouyin.com/share/note/$id/'
          : 'https://www.douyin.com/note/$id',
      'hosts': [
        scenario == 'failure'
            ? 'localhost'
            : share
            ? 'www.iesdouyin.com'
            : 'www.douyin.com',
      ],
      'paths': [
        '/aweme/v1/web/aweme/detail/',
        '/aweme/v1/web/aweme/slidesinfo/',
      ],
      'maxBodyBytes': 1048576,
      'maxTotalBytes': 2097152,
      'maxCandidates': 8,
      'maxConsumerCalls': 8,
      'durationMs': 20000,
    }),
  );
  try {
    await for (final line
        in p.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      final frame = jsonDecode(line) as Map<String, dynamic>;
      if (frame['kind'] == 'hydration') {
        final data = frame.remove('data') as Map<String, dynamic>;
        final summaries = <Map<String, dynamic>>[];
        for (final work in data['works'] as List) {
          final parsed = gallery.parseStructured(
            jsonEncode(work),
            'application/json',
            id,
          );
          final fields = (work as Map)['fields'] as List;
          final structured =
              parsed.target != null &&
              fields.isNotEmpty &&
              parsed.images.isNotEmpty;
          summaries.add({
            'exactTarget': parsed.target != null,
            'sourceFields': fields,
            'awemeType': parsed.awemeType,
            'imageCount': parsed.images.length,
            'distinctUrls': parsed.images.toSet().length,
            'structured': structured,
          });
          if (structured) {
            exact = true;
            images = parsed.images;
          }
        }
        print(
          jsonEncode({
            'scenario': scenario,
            ...frame,
            'roots': data['roots'],
            'documentReady': data['documentReady'],
            'visits': data['visits'],
            'works': summaries,
          }),
        );
      } else if (frame['kind'] == 'candidate') {
        final bytes = base64Decode(frame.remove('body') as String);
        final parsed = gallery.parseStructured(
          utf8.decode(bytes, allowMalformed: true),
          'application/json',
          id,
        );
        print(
          jsonEncode({
            'scenario': scenario,
            'candidate': frame,
            'exactTarget': parsed.target != null,
            'awemeType': parsed.awemeType,
            'imageField': parsed.field,
            'imageCount': parsed.images.length,
            'distinctUrls': parsed.images.toSet().length,
          }),
        );
        bytes.fillRange(0, bytes.length, 0);
        if (parsed.target != null &&
            parsed.images.toSet().length >= 2 &&
            parsed.field != null) {
          exact = true;
          images = parsed.images;
        }
        p.stdin.writeln(jsonEncode({'command': exact ? 'found' : 'continue'}));
      } else {
        if (frame['kind'] == 'profile') profile = frame['profile'] as String;
        if (frame['kind'] == 'final') finalFrame = frame;
        print(jsonEncode({'scenario': scenario, ...frame}));
      }
    }
    final code = await p.exitCode;
    await errors;
    final remaining = profile == null
        ? null
        : await Directory(profile).exists();
    print(
      jsonEncode({
        'scenario': scenario,
        'processExit': code,
        'finalReceived': finalFrame != null,
        'directoryRemaining': remaining,
        'targetStructure': exact,
        'imageUrls': images.length,
      }),
    );
    final expectedOutcome = switch (scenario) {
      'normal' => 'completed',
      'failure' => 'navigationFailed',
      'cancel' => 'cancelled',
      'shareFixture' => 'completed',
      'shareStopFixture' => 'browserVerification',
      'rejectFixture' => 'navigationRejected',
      _ => finalFrame?['outcome'],
    };
    if (finalFrame?['profileCleaned'] != true ||
        remaining != false ||
        code != 0 ||
        finalFrame?['outcome'] != expectedOutcome ||
        finalFrame?['initialCookies'] != 0 ||
        finalFrame?['initialDirectoryAbsent'] != true) {
      exitCode = 2;
      return;
    }
    if (scenario == 'shareFixture' && !exact ||
        scenario == 'shareStopFixture' && exact) {
      exitCode = 3;
      return;
    }
    if (exact && !share) {
      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      try {
        final a = await gallery.validateImage(client, images.first, 1);
        final b = await gallery.validateImage(
          client,
          images.firstWhere((u) => u != images.first),
          2,
        );
        print(
          'IMAGES distinctContent=${a != null && b != null && !gallery.sameBytes(a, b)}',
        );
      } finally {
        client.close(force: true);
      }
    }
  } finally {
    watchdog.cancel();
    killGuard.cancel();
    await p.stdin.close();
  }
}
