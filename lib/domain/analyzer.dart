import 'dart:io' as io;

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/src/dart/analysis/byte_store.dart';
import 'package:analyzer/src/dart/analysis/file_byte_store.dart';
import 'package:analyzer/src/dart/analysis/file_content_cache.dart';
import 'package:import_ozempic/deps/find.dart';
import 'package:import_ozempic/deps/fs.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:import_ozempic/deps/platform.dart';
import 'package:import_ozempic/domain/analysis_options.dart';
import 'package:import_ozempic/domain/sdk_path.dart';
import 'package:import_ozempic/domain/units.dart';
import 'package:import_ozempic/gen/version.dart';

typedef AnalyzeFileResult = (
  ParsedUnitResult,
  Future<ResolvedUnitResult> Function(),
);

/// ~256 MiB on disk — same order of magnitude as analysis_server's cache.
const _byteStoreMaxSizeBytes = 256 * 1024 * 1024;

/// ~64 MiB in-process LRU in front of the on-disk store.
const _memoryCacheMaxSizeBytes = 64 * 1024 * 1024;

class Analyzer {
  Analyzer() : _provider = OverlayResourceProvider(PhysicalResourceProvider());

  final OverlayResourceProvider _provider;
  AnalysisContextCollection? _analysisCollection;
  AnalysisContextCollection get analysisCollection {
    if (_analysisCollection case final collection?) {
      return collection;
    }

    throw UnimplementedError('No analysis collection has not been initialized');
  }

  String get sdkPath => resolveDartSdkPath(
    resolvedExecutable: platform.resolvedExecutable,
    environment: platform.environment,
    pathContext: fs.path,
  );

  Future<void> initialize({required String root}) async {
    final path = switch (fs.path.isAbsolute(root)) {
      true => root,
      false => fs.file(root).absolute.path,
    };

    await _overlayClearedAnalysisOptions(path);

    final cachePath = _ensureCacheDirectory(path);

    try {
      _analysisCollection = AnalysisContextCollectionImpl(
        includedPaths: [path],
        resourceProvider: _provider,
        sdkPath: sdkPath,
        byteStore: MemoryCachingByteStore(
          EvictingFileByteStore(cachePath, _byteStoreMaxSizeBytes),
          _memoryCacheMaxSizeBytes,
        ),
        fileContentCache: FileContentCache(_provider),
      );
    } catch (e) {
      log('Error initializing analyzer: $e');

      rethrow;
    }
  }

  /// Clears `analyzer.exclude` via overlays so generated/barrel files stay
  /// resolvable, without moving `analysis_options.yaml` on disk.
  Future<void> _overlayClearedAnalysisOptions(String root) async {
    final searchRoots = <String>{
      root,
      fs.currentDirectory.path,
    };

    final seen = <String>{};
    for (final searchRoot in searchRoots) {
      final optionsPaths = await find.file(
        AnalysisOptions.name,
        workingDirectory: searchRoot,
      );

      for (final optionsPath in optionsPaths) {
        final normalized = fs.path.normalize(optionsPath);
        if (!seen.add(normalized)) {
          continue;
        }

        final file = fs.file(normalized);
        if (!file.existsSync()) {
          continue;
        }

        final cleared = AnalysisOptions.clearExcludes(file.readAsStringSync());
        _provider.setOverlay(
          normalized,
          content: cleared,
          modificationStamp: file.lastModifiedSync().millisecondsSinceEpoch,
        );
      }
    }
  }

  Future<void> dispose() async {
    await _analysisCollection?.dispose();
    _analysisCollection = null;
  }

  /// Analyzes the given path and returns the resolved unit results.
  ///
  /// If the path is a file, it will be analyzed as a single file.
  /// If the path is a directory, it will be analyzed as a directory.
  ///
  /// [skipInDirectory] is only applied when walking directories — explicit
  /// file paths (including `part` files) are always analyzed.
  Future<List<AnalyzeFileResult>> analyze(
    List<String> paths, {
    bool Function(String path)? skipInDirectory,
  }) async {
    final analyzed = <AnalyzeFileResult>[];

    for (final p in paths) {
      final path = switch (fs.path.isAbsolute(p)) {
        true => p,
        false => fs.path.canonicalize(
          fs.path.join(fs.currentDirectory.path, p),
        ),
      };

      try {
        if (fs.isDirectorySync(path)) {
          final results = await _analyzeDirectory(
            path,
            skip: skipInDirectory,
          );
          analyzed.addAll(results);
        } else if (fs.isFileSync(path)) {
          if (await _analyzeFile(path) case final result?) {
            analyzed.add(result);
          } else {
            log.error('Could not analyze file: $path');
            log.info(
              'Make sure that your current directory is the root of your project',
            );
            continue;
          }
        } else {
          log.error('Invalid path: $path');
          continue;
        }
      } catch (e) {
        log.debugError('Error analyzing path: $path');
        log.debugError('  ---  ');
        log.debugError(e);
        continue;
      }
    }

    return analyzed;
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

  Future<List<AnalyzeFileResult>> _analyzeDirectory(
    String path, {
    bool Function(String path)? skip,
  }) async {
    final results = <AnalyzeFileResult>[];
    final files = await find.file('*.dart', workingDirectory: path);

    log.debug('  - Found ${files.length} files to analyze');

    AnalysisContext context;
    for (final file in files) {
      if (skip?.call(file) ?? false) {
        continue;
      }

      try {
        context = analysisCollection.contextFor(file);
      } catch (e) {
        log.debugError('Could not analyze file: $file');
        log.debugError('  ---  ');
        log.debugError(e);
        continue;
      }

      final units = Units(context: context, path: file);

      results.add((units.parsed, units.resolved));
    }

    return results;
  }

  /// Versioned so upgrades don't reuse incompatible analyzer cache entries.
  String _ensureCacheDirectory(String root) {
    final cacheRoot = fs.path.join(
      root,
      '.dart_tool',
      'import_ozempic',
      'analysis-cache',
    );
    final cachePath = fs.path.join(cacheRoot, version);

    final rootDir = io.Directory(cacheRoot);
    if (rootDir.existsSync()) {
      for (final entity in rootDir.listSync()) {
        if (entity is! io.Directory) continue;
        if (fs.path.basename(entity.path) == version) continue;
        try {
          entity.deleteSync(recursive: true);
        } catch (_) {
          // Best-effort eviction of stale version caches.
        }
      }
    }

    io.Directory(cachePath).createSync(recursive: true);
    return cachePath;
  }
}
