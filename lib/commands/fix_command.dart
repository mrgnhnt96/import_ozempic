import 'dart:convert';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:import_ozempic/deps/analyzer.dart';
import 'package:import_ozempic/deps/fs.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:import_ozempic/deps/process.dart';
import 'package:import_ozempic/domain/args.dart';
import 'package:import_ozempic/domain/config.dart';
import 'package:import_ozempic/domain/import_type_collector.dart';
import 'package:import_ozempic/domain/resolved_references.dart';
import 'package:meta/meta.dart';

const _usage = '''
Usage: import_ozempic fix <files...> [--config <path>]

Formats and fixes import statements in the specified Dart file(s), removing unused imports and normalizing import order and style.
''';

class FixCommand {
  const FixCommand({required this.args});

  final Args args;

  Config get config =>
      switch (args.getOrNull('config') ?? args.getOrNull('c')) {
        final String path => Config.load(path),
        _ => Config(),
      };

  Future<int> run(List<String> files) async {
    if (args['help'] case true) {
      log(_usage);
      return 0;
    }

    if (files.isEmpty) {
      log('No files were provided');
      log(_usage);
      return 1;
    }

    if (await _fixImports(files) case final int exitCode) {
      return exitCode;
    }

    if (config.format) {
      log('');
      if (await _format(files) case final int exitCode) {
        return exitCode;
      }
    }

    return 0;
  }

  Future<int?> _format(List<String> files) async {
    log('Formatting files');

    final result = await process('dart', ['format', ...files]);

    if (await result.exitCode != 0) {
      log('Failed to format files');
      await for (final line in result.stderr.transform(utf8.decoder)) {
        log(line);
      }
      return result.exitCode;
    }

    await for (final line in result.stdout.transform(utf8.decoder)) {
      log(line);
    }

    return null;
  }

  Future<int?> _fixImports(List<String> files) async {
    final config = switch (args.getOrNull('config')) {
      final String path => Config.load(path),
      _ => Config(),
    };

    log.debug('Config: $config');

    final cleanedFiles = [
      for (final file in files)
        if (file == '.') fs.currentDirectory.path else file,
    ];

    log.debug('Cleaned files: $cleanedFiles');

    final root = _findCommonRoot(cleanedFiles);
    log.debug('Using root: $root');

    await analyzer.initialize(root: root);

    final results = await analyzer.analyze(cleanedFiles);
    log.debug('Analyzed (${results.length} results)');

    final libraries =
        <(ParsedUnitResult, Future<ResolvedUnitResult> Function())>[];

    for (final result in results) {
      final (parsed, resolved) = result;

      if (config.shouldExclude(parsed.path)) {
        continue;
      }

      if (!parsed.isLibrary) {
        // We _could_ resolve the library here and add it to the list..
        // But it would be more expensive than to just "teach" the user to
        // provide libraries (as opposed to parts)
        continue;
      }

      libraries.add(result);
    }

    if (libraries.isEmpty) {
      log.debug("Didn't find any libraries..");
      log.error('No files were found to fix');

      if (files.isNotEmpty) {
        log.debug('Found ${files.length} files');
        for (final file in files) {
          log.debug('  - $file');
        }

        log.info('Provide files that do not contain `part of` directives');
      }
      return 0;
    }

    log('Resolving imports:');
    for (final lib in libraries) {
      await updateImportStatements(
        await _resolveReferences(lib),
        config: config,
      );
    }

    return null;
  }

  @visibleForTesting
  Future<void> updateImportStatements(
    ResolvedReferences import, {
    Config? config,
  }) async {
    final _config = config ?? Config();
    final ResolvedReferences(:path, :imports, :hasImports) = import;

    if (path == null) return;
    if (!hasImports) return;

    final lines = fs.file(path).readAsLinesSync();

    int? importStart;
    int? importEnd;
    int? commentStart;

    final skippable = [
      'library',
      'as',
      'hide',
      'show',
      'export',
      RegExp(r'^\w+[,;]$'),
    ];

    var inShowOrHide = false;

    bool endsWithSemicolon(String line) {
      final withoutComment = line.contains('//')
          ? line.substring(0, line.indexOf('//')).trimRight()
          : line;
      return withoutComment.endsWith(';');
    }

    for (final (index, line) in lines.indexed) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('//')) {
        if (trimmed != '// dart format on') {
          commentStart ??= index;
        }

        continue;
      }

      // When inside a multi-line show/hide clause, continue until we find
      // the terminating semicolon (ignoring any trailing comment).
      if (inShowOrHide) {
        if (endsWithSemicolon(trimmed)) {
          inShowOrHide = false;
        }
        continue;
      }

      // A line starting with show/hide may span multiple lines until `;`.
      if (trimmed.startsWith('show') || trimmed.startsWith('hide')) {
        inShowOrHide = !endsWithSemicolon(trimmed);
        continue;
      }

      if (skippable.any(trimmed.startsWith)) {
        continue;
      }

      if (trimmed.startsWith('import ')) {
        importStart ??= index;
        commentStart = null;
        continue;
      }

      importEnd = commentStart ?? index;
      break;
    }

    if (importStart == null) {
      if (importEnd != null) {
        importStart = importEnd;
      } else {
        log('No import start found for ${fs.path.relative(path)}');
        return;
      }
    }

    if (importEnd == null) {
      log('No import end found for ${fs.path.relative(path)}');
      return;
    }

    final contentStart = lines.take(importStart).join('\n');
    final contentEnd = lines.sublist(importEnd).join('\n');

    final (:dart, :relative, :package) = imports(
      trailComments: !_config.format,
    );

    final importStatements = [
      if (dart.isNotEmpty) ...dart.map((e) => '$e').followedBy(['']),
      if (package.isNotEmpty) ...package.map((e) => '$e').followedBy(['']),
      if (relative.isNotEmpty) ...relative.map((e) => '$e').followedBy(['']),
    ];

    if (_config case Config(format: false) when importStatements.isNotEmpty) {
      importStatements.insert(0, '// dart format off');
      // leave the last line empty
      importStatements.insert(importStatements.length - 1, '// dart format on');
    }

    String? startContent = null;

    if (contentStart.trim() case final String start when start.isNotEmpty) {
      final lines = start.split('\n');
      for (final (index, line) in lines.reversed.indexed) {
        if (line.trim().isEmpty) {
          continue;
        }

        if (line.trim() == '// dart format off') {
          continue;
        }

        final reversedIndex = lines.length - index;

        startContent = lines.sublist(0, reversedIndex).join('\n');
        break;
      }
    }

    var content = [
      if (startContent?.trim() case final String start when start.isNotEmpty)
        '$start\n',
      ...importStatements,
      contentEnd.trim(),
      '',
    ].join('\n');

    fs.file(path).writeAsStringSync(content.trimLeft());
  }

  Future<ResolvedReferences> _resolveReferences(
    (ParsedUnitResult, Future<ResolvedUnitResult> Function()) lib,
  ) async {
    final collector = ImportTypeCollector();
    final resolvedImport = ResolvedReferences();

    final (parsed, resolved) = lib;

    log('  ${fs.path.relative(parsed.path)}');

    if (parsed.isLibrary) {
      resolvedImport.path = parsed.path;
    }

    final parts = await analyzer.analyze(getParts(parsed));

    for (final part in [lib].followedBy(parts)) {
      final (_, resolved) = part;

      final library = await resolved();

      if (library.path case final String path
          when path != resolvedImport.path) {
        resolvedImport.parts.add(path);
      }

      library.unit.accept(collector);
    }

    return resolvedImport..addAll(collector.references);
  }

  /// Finds the common root directory that contains all the provided paths.
  ///
  /// For files, uses their parent directory. For directories, uses the directory itself.
  /// Returns the current directory if no valid paths are provided.
  String _findCommonRoot(List<String> paths) {
    if (paths.isEmpty) {
      return fs.currentDirectory.path;
    }

    final absolutePaths = <String>[];
    for (final path in paths) {
      final absolutePath = switch (fs.path.isAbsolute(path)) {
        true => path,
        false => fs.path.canonicalize(
          fs.path.join(fs.currentDirectory.path, path),
        ),
      };

      // For files, use their parent directory
      if (fs.isFileSync(absolutePath)) {
        absolutePaths.add(fs.path.dirname(absolutePath));
      } else if (fs.isDirectorySync(absolutePath)) {
        absolutePaths.add(absolutePath);
      }
    }

    if (absolutePaths.isEmpty) {
      return fs.currentDirectory.path;
    }

    // Normalize all paths
    final normalizedPaths = absolutePaths
        .map((p) => fs.path.normalize(p))
        .toList();

    // Use the first path as a starting point
    var candidate = normalizedPaths.first;

    // Walk up the directory tree from the first path
    while (true) {
      // Check if all paths are within or equal to the candidate
      final allContained = normalizedPaths.every((path) {
        // Check if path equals candidate or is a subdirectory
        if (path == candidate) return true;
        // Check if path starts with candidate + separator
        final relative = fs.path.relative(path, from: candidate);
        return !relative.startsWith('..') && !fs.path.isAbsolute(relative);
      });

      if (allContained) {
        return candidate;
      }

      // Move up one directory level
      final parent = fs.path.dirname(candidate);
      if (parent == candidate) {
        // Reached root, can't go higher
        break;
      }
      candidate = parent;
    }

    // Fallback: if we can't find a common root, use current directory
    // This handles edge cases like paths on different drives (Windows)
    return fs.currentDirectory.path;
  }

  @visibleForTesting
  List<String> getParts(ParsedUnitResult parsed) {
    Iterable<String> parts() sync* {
      final lines = parsed.content.split('\n');

      const avoid = ['export', 'import', 'library', 'as', 'show', 'hide', '//'];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (avoid.any(trimmed.startsWith)) continue;

        if (!trimmed.startsWith('part')) {
          break;
        }

        if (trimmed.split("'") case [_, final String part, ...]) {
          yield fs.path.normalize(
            fs.path.join(fs.path.dirname(parsed.path), part),
          );
        }
      }
    }

    return parts().toList();
  }
}
