// Minimal Route B feasibility probe, not a native processing binding.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

typedef AllocNative = Pointer<Void> Function(IntPtr);
typedef FreeNative = Void Function(Pointer<Void>);
typedef OpenNative =
    Int32 Function(
      Pointer<Pointer<Void>>,
      Pointer<Uint8>,
      Pointer<Void>,
      Pointer<Void>,
    );
typedef InfoNative = Int32 Function(Pointer<Void>, Pointer<Void>);
typedef CloseNative = Void Function(Pointer<Pointer<Void>>);

void main(List<String> args) {
  if (args.length != 2) {
    throw ArgumentError('FFmpeg bin directory and local input');
  }
  final crt = DynamicLibrary.open('ucrtbase.dll');
  final alloc = crt.lookupFunction<AllocNative, Pointer<Void> Function(int)>(
    'malloc',
  );
  final free = crt.lookupFunction<FreeNative, void Function(Pointer<Void>)>(
    'free',
  );
  final kernel = DynamicLibrary.open('kernel32.dll');
  final setDirectory = kernel
      .lookupFunction<
        Int32 Function(Pointer<Uint16>),
        int Function(Pointer<Uint16>)
      >('SetDllDirectoryW');
  final directory = alloc((args[0].codeUnits.length + 1) * 2).cast<Uint16>();
  directory.asTypedList(args[0].codeUnits.length + 1).setAll(0, [
    ...args[0].codeUnits,
    0,
  ]);
  try {
    if (setDirectory(directory) == 0) throw StateError('DLL directory failed');
    final format = DynamicLibrary.open('${args[0]}/avformat-62.dll');
    final util = DynamicLibrary.open('${args[0]}/avutil-60.dll');
    final version = util
        .lookupFunction<Pointer<Uint8> Function(), Pointer<Uint8> Function()>(
          'av_version_info',
        )();
    String cString(Pointer<Uint8> ptr) {
      final bytes = <int>[];
      for (var i = 0; ptr[i] != 0 && i < 8192; i++) {
        bytes.add(ptr[i]);
      }
      return utf8.decode(bytes);
    }

    final config = format
        .lookupFunction<Pointer<Uint8> Function(), Pointer<Uint8> Function()>(
          'avformat_configuration',
        )();
    final inputBytes = [...utf8.encode(File(args[1]).absolute.path), 0];
    final input = alloc(inputBytes.length).cast<Uint8>();
    final context = alloc(sizeOf<Pointer<Void>>()).cast<Pointer<Void>>();
    context.value = nullptr;
    try {
      input.asTypedList(inputBytes.length).setAll(0, inputBytes);
      final open = format
          .lookupFunction<
            OpenNative,
            int Function(
              Pointer<Pointer<Void>>,
              Pointer<Uint8>,
              Pointer<Void>,
              Pointer<Void>,
            )
          >('avformat_open_input');
      final info = format
          .lookupFunction<
            InfoNative,
            int Function(Pointer<Void>, Pointer<Void>)
          >('avformat_find_stream_info');
      final close = format
          .lookupFunction<CloseNative, void Function(Pointer<Pointer<Void>>)>(
            'avformat_close_input',
          );
      final code = open(context, input, nullptr, nullptr);
      try {
        final result = code == 0 ? info(context.value, nullptr) : code;
        stdout.writeln(
          jsonEncode({
            'version': cString(version),
            'configuration': cString(config),
            'openInput': code,
            'findStreamInfo': result,
            'path': args[1],
          }),
        );
        if (code != 0 || result < 0) exitCode = 1;
      } finally {
        close(context);
      }
    } finally {
      free(input.cast());
      free(context.cast());
    }
  } finally {
    setDirectory(nullptr);
    free(directory.cast());
  }
}
