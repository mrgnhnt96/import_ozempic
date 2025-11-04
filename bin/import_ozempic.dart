import 'dart:io';

import 'package:import_ozempic/deps/analyzer.dart';
import 'package:import_ozempic/deps/find.dart';
import 'package:import_ozempic/deps/fs.dart';
import 'package:import_ozempic/deps/is_up_to_date.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:import_ozempic/deps/platform.dart';
import 'package:import_ozempic/deps/process.dart';
import 'package:import_ozempic/deps/pub_updater.dart';
import 'package:import_ozempic/domain/args.dart';
import 'package:import_ozempic/import_ozempic.dart';
import 'package:scoped_deps/scoped_deps.dart';

void main(List<String> arguments) async {
  run(arguments);
}

void run(List<String> arguments) async {
  final args = Args.parse(arguments);

  exitCode = await runScoped(
    () => ImportOzempic().run(args),
    values: {
      fsProvider,
      platformProvider,
      logProvider,
      processProvider,
      findProvider,
      analyzerProvider,
      pubUpdaterProvider,
      isUpToDateProvider,
    },
  );
}
