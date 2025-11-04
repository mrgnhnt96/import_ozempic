import 'package:file/file.dart';
import 'package:import_ozempic/deps/analyzer.dart';
import 'package:import_ozempic/deps/find.dart';
import 'package:import_ozempic/deps/fs.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:import_ozempic/deps/platform.dart';
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
  test(description, () {
    final testProviders = {
      analyzerProvider,
      if (fileSystem?.call() case final FileSystem fs)
        fsProvider.overrideWith(() => fs)
      else
        fsProvider,
      findProvider,
      logProvider,
      platformProvider,
    };

    runScoped(values: testProviders, () {
      if (initializeAnalyzer) {
        analyzer.initialize(root: cwd?.call() ?? fs.currentDirectory.path);
      }

      fn();
    });
  });
}
