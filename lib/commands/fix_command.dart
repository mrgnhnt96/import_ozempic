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
Usage: import_ozempic fix <files...>

Formats and fixes import statements in the specified Dart file(s), removing unused imports and normalizing import order and style.
''';

class FixCommand {
  const FixCommand({required this.args});

  final Args args;

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

    log('');
    log('Fixing unused imports in files');

    final result = await process('dart', [
      'fix',
      ...files,
      '--apply',
      '--code',
      'unused_import',
      '--code',
      'unnecessary_import',
      '--code',
      'unused_shown_name',
    ]);

    if (result.exitCode != 0) {
      log('Failed to fix analysis errors in files');
      log(result.stderr);
      return result.exitCode;
    }

    log('Analysis errors fixed in files');
    log(result.stdout);

    return 0;
  }

  Future<int?> _fixImports(List<String> files) async {
    final config = switch (args.getOrNull('config')) {
      final String path => Config.load(path),
      _ => Config(),
    };

    analyzer.initialize(root: fs.currentDirectory.path);

    final cleanedFiles = [
      for (final file in files)
        if (file == '.') fs.currentDirectory.path else file,
    ];

    final results = await analyzer.analyze(cleanedFiles);

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
      log('No files were found to fix');
      if (files.isNotEmpty) {
        log('Provide files that do not contain `part of` directives');
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

    final skippable = ['as', 'hide', 'show', 'export', RegExp(r'^\w+[,;]$')];

    for (final (index, line) in lines.indexed) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('//')) {
        commentStart ??= index;
        continue;
      }

      if (skippable.any(trimmed.startsWith)) {
        continue;
      }

      if (trimmed.startsWith('import ')) {
        if (index > 0 && lines[index - 1].startsWith('// dart format off')) {
          importStart ??= index - 1;
        }

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
    final contentEnd = switch (lines.sublist(importEnd)) {
      ['// dart format on', ...final lines] => lines.join('\n'),
      final lines => lines.join('\n'),
    };

    final (:dart, :relative, :package) = imports;

    final importStatements = [
      if (dart.isNotEmpty) ...dart.followedBy(['']),
      if (package.isNotEmpty) ...package.followedBy(['']),
      if (relative.isNotEmpty) ...relative.followedBy(['']),
    ];

    if (_config case Config(
      formatImports: false,
    ) when importStatements.isNotEmpty) {
      importStatements.insert(0, '// dart format off');
      // leave the last line empty
      importStatements.insert(importStatements.length - 1, '// dart format on');
    }

    var content = [
      if (contentStart.trim() case final String start when start.isNotEmpty)
        start,
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

    final parts = await analyzer.analyze(_getParts(parsed));

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

  List<String> _getParts(ParsedUnitResult parsed) {
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
