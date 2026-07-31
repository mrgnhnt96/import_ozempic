import 'dart:io';
import 'dart:isolate';

import 'package:import_ozempic/domain/sdk_path.dart';
import 'package:import_ozempic/gen/version.dart';
import 'package:path/path.dart' as p;

const _runningAotEnv = 'IOZ_RUNNING_AOT';
const _disableAotEnv = 'IOZ_NO_AOT';
const recompileFlag = '--recompile';

/// If this process is running via the Dart VM, compile a native executable once
/// and re-exec it so subsequent (and this) runs avoid JIT warmup.
///
/// Pass [--recompile] to delete and rebuild the cached native binary.
/// Set `IOZ_NO_AOT=1` to skip. Already-compiled binaries are detected via
/// `IOZ_RUNNING_AOT` or a non-`dart` resolved executable.
Future<void> maybeReexecAsAot(List<String> arguments) async {
  if (Platform.environment.containsKey(_disableAotEnv)) {
    return;
  }

  final forceRecompile = arguments.contains(recompileFlag);
  final forwardedArgs = [
    for (final arg in arguments)
      if (arg != recompileFlag) arg,
  ];

  // Allow --recompile to run even from an existing AOT binary so we can
  // rebuild with `dart compile`. Otherwise bail when already native.
  if (!forceRecompile &&
      (Platform.environment.containsKey(_runningAotEnv) || _isCompiledExe())) {
    return;
  }

  final entrypoint = await _resolveEntrypoint();
  if (entrypoint == null) {
    if (forceRecompile) {
      stderr.writeln(
        'Could not resolve package entrypoint to recompile.',
      );
      exit(1);
    }
    return;
  }

  final cacheDir = _cacheDirectory();
  final output = p.join(cacheDir.path, 'import_ozempic-$version');
  final outputFile = File(output);

  _evictStaleAotBinaries(cacheDir, keep: output);

  final needsCompile =
      forceRecompile ||
      !outputFile.existsSync() ||
      _isStale(outputFile, entrypoint);

  if (needsCompile) {
    stdout.writeln(
      forceRecompile
          ? 'Recompiling native binary...'
          : 'Compiling native binary for faster runs (one-time)...',
    );
    cacheDir.createSync(recursive: true);

    if (forceRecompile && outputFile.existsSync()) {
      try {
        outputFile.deleteSync();
      } catch (_) {
        // Compile will overwrite when possible.
      }
    }

    final dartExecutable = _dartExecutableForCompile();
    final compileArgs = <String>[
      'compile',
      'exe',
      entrypoint,
      '-o',
      output,
      if (Platform.packageConfig case final String packages) ...[
        '--packages',
        Uri.parse(packages).toFilePath(),
      ],
    ];

    final result = await Process.run(
      dartExecutable,
      compileArgs,
      workingDirectory: p.dirname(p.dirname(entrypoint)),
    );

    if (result.exitCode != 0 || !outputFile.existsSync()) {
      if (forceRecompile) {
        stderr.writeln('Failed to recompile native binary.');
        if ((result.stderr as String).trim().isNotEmpty) {
          stderr.writeln(result.stderr);
        }
        exit(result.exitCode == 0 ? 1 : result.exitCode);
      }
      // Fall through to the VM — analysis still works, just without AOT.
      return;
    }
  }

  final sdkPath = resolveDartSdkPath(
    resolvedExecutable: _dartExecutableForCompile(),
    environment: Platform.environment,
  );

  final process = await Process.start(
    output,
    forwardedArgs,
    mode: ProcessStartMode.inheritStdio,
    environment: {
      ...Platform.environment,
      _runningAotEnv: '1',
      dartSdkEnv: sdkPath,
    },
  );

  exit(await process.exitCode);
}

bool _isCompiledExe() {
  final name = p.basename(Platform.resolvedExecutable).toLowerCase();
  return name != 'dart' && name != 'dart.exe';
}

String _dartExecutableForCompile() {
  final resolved = Platform.resolvedExecutable;
  final name = p.basename(resolved).toLowerCase();
  if (name == 'dart' || name == 'dart.exe') {
    return resolved;
  }

  final sdkPath = resolveDartSdkPath(
    resolvedExecutable: resolved,
    environment: Platform.environment,
  );
  final dartInSdk = p.join(
    sdkPath,
    'bin',
    Platform.isWindows ? 'dart.exe' : 'dart',
  );
  if (File(dartInSdk).existsSync()) {
    return dartInSdk;
  }

  throw StateError(
    'Could not find the dart executable to compile with. '
    'Set $dartSdkEnv or ensure `dart` is on PATH.',
  );
}

bool _isStale(File aotBinary, String entrypoint) {
  final aotModified = aotBinary.statSync().modified;
  final sources = [
    File(entrypoint),
    File(p.join(p.dirname(p.dirname(entrypoint)), 'pubspec.yaml')),
  ];

  for (final source in sources) {
    if (!source.existsSync()) continue;
    if (source.statSync().modified.isAfter(aotModified)) {
      return true;
    }
  }
  return false;
}

void _evictStaleAotBinaries(Directory cacheDir, {required String keep}) {
  if (!cacheDir.existsSync()) return;

  for (final entity in cacheDir.listSync()) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (!name.startsWith('import_ozempic-')) continue;
    if (entity.path == keep) continue;
    try {
      entity.deleteSync();
    } catch (_) {
      // Best-effort cleanup of older versioned binaries.
    }
  }
}

Future<String?> _resolveEntrypoint() async {
  final packageUri = await Isolate.resolvePackageUri(
    Uri.parse('package:import_ozempic/import_ozempic.dart'),
  );
  if (packageUri == null || packageUri.scheme != 'file') {
    return null;
  }

  final libFile = packageUri.toFilePath();
  final packageRoot = p.dirname(p.dirname(libFile));
  final entrypoint = p.join(packageRoot, 'bin', 'import_ozempic.dart');
  if (!File(entrypoint).existsSync()) {
    return null;
  }

  return entrypoint;
}

Directory _cacheDirectory() {
  final home =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.systemTemp.path;

  return Directory(p.join(home, '.import_ozempic', 'aot'));
}
