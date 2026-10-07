import 'dart:io';

abstract interface class ProcessingChild {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;
  bool kill();
}

abstract interface class ProcessingProcessRunner {
  Future<ProcessingChild> start(
    String executable,
    List<String> arguments,
    String workingDirectory,
  );
}

class IoProcessingProcessRunner implements ProcessingProcessRunner {
  @override
  Future<ProcessingChild> start(
    String executable,
    List<String> arguments,
    String workingDirectory,
  ) async => _IoChild(
    await Process.start(
      executable,
      arguments,
      runInShell: false,
      workingDirectory: workingDirectory,
      environment: {'PATH': '${Platform.environment['SystemRoot']}\\System32'},
    ),
  );
}

class _IoChild implements ProcessingChild {
  final Process process;
  _IoChild(this.process);
  @override
  Stream<List<int>> get stdout => process.stdout;
  @override
  Stream<List<int>> get stderr => process.stderr;
  @override
  Future<int> get exitCode => process.exitCode;
  @override
  bool kill() => process.kill();
}
