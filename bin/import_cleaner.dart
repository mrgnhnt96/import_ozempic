import 'dart:io';

import 'package:import_cleaner/deps/analyzer.dart';
import 'package:import_cleaner/deps/find.dart';
import 'package:import_cleaner/deps/fs.dart';
import 'package:import_cleaner/deps/log.dart';
import 'package:import_cleaner/deps/platform.dart';
import 'package:import_cleaner/deps/process.dart';
import 'package:import_cleaner/domain/args.dart';
import 'package:import_cleaner/import_cleaner.dart';
import 'package:scoped_deps/scoped_deps.dart';

void main(List<String> arguments) async {
  // run(arguments);
  Directory.current =
      '/Users/morgan/Documents/develop.nosync/couchsurfing/pillows/apps/mobile';

  run(['fix', 'packages/ui', '--config', 'import_cleaner.yaml']);
}

void run(List<String> arguments) async {
  final args = Args.parse(arguments);

  exitCode = await runScoped(
    () => ImportCleaner().run(args),
    values: {
      fsProvider,
      platformProvider,
      logProvider,
      processProvider,
      findProvider,
      analyzerProvider,
    },
  );
}
