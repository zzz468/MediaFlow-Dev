import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import '../../domain/processing.dart';
import '../local_output.dart';

// Narrow filesystem interop only; no FFmpeg FFI/bindings or new package.
// CREATE_NEW and MoveFileExW without REPLACE_EXISTING close overwrite races.
class WindowsOutputStorage implements LocalOutputStorage {
  WindowsOutputStorage() {
    _error();
  } // Resolve GetLastError before any failing call.
  static final _dll = DynamicLibrary.open('kernel32.dll');
  static final _heap = _dll
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'GetProcessHeap',
      )();
  static final _alloc = _dll
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Uint32, UintPtr),
        Pointer<Void> Function(Pointer<Void>, int, int)
      >('HeapAlloc');
  static final _free = _dll
      .lookupFunction<
        Int32 Function(Pointer<Void>, Uint32, Pointer<Void>),
        int Function(Pointer<Void>, int, Pointer<Void>)
      >('HeapFree');
  static final _error = _dll.lookupFunction<Uint32 Function(), int Function()>(
    'GetLastError',
  );
  static final _create = _dll
      .lookupFunction<
        IntPtr Function(
          Pointer<Uint16>,
          Uint32,
          Uint32,
          Pointer<Void>,
          Uint32,
          Uint32,
          IntPtr,
        ),
        int Function(Pointer<Uint16>, int, int, Pointer<Void>, int, int, int)
      >('CreateFileW');
  static final _close = _dll
      .lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');
  static final _move = _dll
      .lookupFunction<
        Int32 Function(Pointer<Uint16>, Pointer<Uint16>, Uint32),
        int Function(Pointer<Uint16>, Pointer<Uint16>, int)
      >('MoveFileExW');
  static final _space = _dll
      .lookupFunction<
        Int32 Function(
          Pointer<Uint16>,
          Pointer<Uint64>,
          Pointer<Uint64>,
          Pointer<Uint64>,
        ),
        int Function(
          Pointer<Uint16>,
          Pointer<Uint64>,
          Pointer<Uint64>,
          Pointer<Uint64>,
        )
      >('GetDiskFreeSpaceExW');
  static Pointer<Uint16> _wide(String s) {
    final p = _alloc(_heap, 8, (s.length + 1) * 2).cast<Uint16>();
    if (p == nullptr) {
      throw ProcessingFailure(
        ProcessingErrorCode.unknown,
        'Unable to allocate storage query.',
      );
    }
    p.asTypedList(s.length + 1).setAll(0, s.codeUnits);
    return p;
  }

  static String partialPath(String output, String id, String nonce) =>
      '$output.${id.substring(0, id.length.clamp(0, 8))}.$nonce.partial';
  static Never _fail(int error) => throw fileFailure(
    FileSystemException(
      'Storage operation failed',
      '',
      OSError('Windows error $error', error),
    ),
  );
  @override
  int? freeBytes(String directory) {
    final path = _wide(directory);
    final data = _alloc(_heap, 8, 24).cast<Uint64>();
    if (data == nullptr) {
      _free(_heap, 0, path.cast());
      return null;
    }
    try {
      return _space(path, data, data + 1, data + 2) == 0 ? null : data.value;
    } finally {
      _free(_heap, 0, path.cast());
      _free(_heap, 0, data.cast());
    }
  }

  @override
  Future<PreparedOutput> prepare(ProcessingRequest r) async {
    if (!File(r.output).isAbsolute ||
        r.inputs.any((p) => !File(p).isAbsolute)) {
      throw ProcessingFailure(
        ProcessingErrorCode.invalidInput,
        'Use absolute local file paths.',
      );
    }
    try {
      final parent = await File(r.output).parent.resolveSymbolicLinks();
      final target = File('$parent/${File(r.output).uri.pathSegments.last}');
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw ProcessingFailure(
          ProcessingErrorCode.outputConflict,
          'Output already exists.',
        );
      }
      var inputBytes = 0;
      for (final path in r.inputs) {
        if (!await File(path).exists()) {
          throw ProcessingFailure(
            ProcessingErrorCode.inputMissing,
            'Input file is missing.',
          );
        }
        if ((await File(path).resolveSymbolicLinks()).toLowerCase() ==
            target.path.toLowerCase()) {
          throw ProcessingFailure(
            ProcessingErrorCode.outputConflict,
            'Input and output must differ.',
          );
        }
        inputBytes += await File(path).length();
      }
      final available = freeBytes(parent);
      final estimate = r.type == ProcessingType.extractFrame
          ? 4 * 1024 * 1024
          : inputBytes + 4 * 1024 * 1024;
      if (available != null && available < estimate) {
        throw ProcessingFailure(
          ProcessingErrorCode.insufficientStorage,
          'Insufficient output storage reserve.',
        );
      }
      final nonce =
          Random.secure().nextInt(1 << 32).toRadixString(16) +
          Random.secure().nextInt(1 << 32).toRadixString(16);
      final partial = File(partialPath(target.path, r.id, nonce));
      final wide = _wide(partial.path);
      try {
        final handle = _create(wide, 0x40000000, 0, nullptr, 1, 0x80, 0);
        if (handle == -1) _fail(_error());
        _close(handle);
      } finally {
        _free(_heap, 0, wide.cast());
      }
      return PreparedOutput(target, partial);
    } on FileSystemException catch (e) {
      throw fileFailure(e);
    }
  }

  @override
  void publish(PreparedOutput output) {
    final source = _wide(output.partial.path),
        target = _wide(output.target.path);
    try {
      if (_move(source, target, 8) == 0) _fail(_error());
    } finally {
      _free(_heap, 0, source.cast());
      _free(_heap, 0, target.cast());
    }
  }

  @override
  Future<void> cleanup(PreparedOutput output) async {
    if (await output.partial.exists()) await output.partial.delete();
  }
}
