import 'dart:io' as io;

import 'package:import_ozempic/deps/fs.dart';
import 'package:import_ozempic/domain/process_details.dart';
import 'package:scoped_deps/scoped_deps.dart';

typedef Process =
    Future<ProcessDetails> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment,
      bool runInShell,
      io.ProcessStartMode mode,
    });

final processProvider = create<Process>(() {
  return (
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    io.ProcessStartMode mode = io.ProcessStartMode.normal,
  }) async {
    final process = await io.Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory ?? fs.currentDirectory.path,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      mode: mode,
    );

    return ProcessDetails(
      stdout: process.stdout,
      stderr: process.stderr,
      pid: process.pid,
      exitCode: process.exitCode,
    );
  };
});

Process get process => read(processProvider);
