import 'dart:async';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:import_cleaner/deps/find.dart';
import 'package:import_cleaner/deps/fs.dart';
import 'package:import_cleaner/deps/log.dart';
import 'package:import_cleaner/deps/platform.dart';
import 'package:import_cleaner/domain/units.dart';

typedef AnalyzeFileResult = (
  ParsedUnitResult,
  Future<ResolvedUnitResult> Function(),
);

class Analyzer {
  Analyzer() : _provider = PhysicalResourceProvider();

  ResourceProvider _provider;
  AnalysisContextCollection? _analysisCollection;
  AnalysisContextCollection get analysisCollection {
    if (_analysisCollection case final collection?) {
      return collection;
    }

    throw UnimplementedError('No analysis collection has not been initialized');
  }

  String get sdkPath => fs.file(platform.resolvedExecutable).parent.parent.path;

  void initialize({required String root}) {
    try {
      _analysisCollection = AnalysisContextCollection(
        includedPaths: [root],
        resourceProvider: _provider,
        sdkPath: sdkPath,
      );
    } catch (e) {
      log('Error initializing analyzer: $e');

      rethrow;
    }
  }

  /// Analyzes the given path and returns the resolved unit results.
  ///
  /// If the path is a file, it will be analyzed as a single file.
  /// If the path is a directory, it will be analyzed as a directory.
  Future<List<AnalyzeFileResult>> analyze(List<String> paths) async {
    final result = <AnalyzeFileResult>[];

    for (final path in paths) {
      if (fs.isDirectorySync(path)) {
        result.addAll(await _analyzeDirectory(path));
      } else if (fs.isFileSync(path)) {
        if (await _analyzeFile(path) case final resolved?) {
          result.add(resolved);
        }
      } else {
        log('Invalid path: $path');
        continue;
      }
    }

    return result;
  }

  Future<AnalyzeFileResult?> _analyzeFile(String path) async {
    AnalysisContext context;
    try {
      context = analysisCollection.contextFor(path);
    } catch (_) {
      return null;
    }

    final units = Units(context: context, path: path);

    return (units.parsed, units.resolved);
  }

  Future<List<AnalyzeFileResult>> _analyzeDirectory(String path) async {
    final results = <AnalyzeFileResult>[];
    final files = await find.file('*.dart', workingDirectory: path);

    AnalysisContext context;
    for (final file in files) {
      try {
        context = analysisCollection.contextFor(file);
      } catch (_) {
        continue;
      }

      final units = Units(context: context, path: file);

      results.add((units.parsed, units.resolved));
    }

    return results;
  }
}
