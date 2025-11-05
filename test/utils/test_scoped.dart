import 'package:file/file.dart';
import 'package:import_ozempic/deps/analyzer.dart';
import 'package:import_ozempic/deps/find.dart';
import 'package:import_ozempic/deps/fs.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:import_ozempic/deps/platform.dart';
import 'package:import_ozempic/deps/process.dart';
import 'package:meta/meta.dart';
import 'package:scoped_deps/scoped_deps.dart';
import 'package:test/test.dart';

@isTest
void testScoped(
  String description,
  void Function() fn, {
  FileSystem Function()? fileSystem,
  String Function()? cwd,
  bool initializeAnalyzer = false,
}) {
  test(description, () async {
    final testProviders = {
      analyzerProvider,
      if (fileSystem?.call() case final FileSystem fs)
        fsProvider.overrideWith(() => fs)
      else
        fsProvider,
      findProvider,
      logProvider,
      platformProvider,
      processProvider,
    };

    await runScoped(values: testProviders, () async {
      if (initializeAnalyzer) {
        await analyzer.initialize(
          root: cwd?.call() ?? fs.currentDirectory.path,
        );
      }

      fn();
    });
  });
}
