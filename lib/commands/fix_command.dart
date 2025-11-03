import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:import_ozempic/deps/analyzer.dart';
import 'package:import_ozempic/deps/fs.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:import_ozempic/domain/args.dart';
import 'package:import_ozempic/domain/config.dart';
import 'package:import_ozempic/domain/import_type_collector.dart';
import 'package:import_ozempic/domain/reference.dart';

const _usage = '''
Usage: import_ozempic fix <file>...

Fixes the imports in the given files.
''';

class FixCommand {
  const FixCommand({required this.args});

  final Args args;

  Future<int> run(List<String> files) async {
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

    final result = await Process.run('dart', [
      'fix',
      ...files,
      '--apply',
      '--code',
      'unused_import',
      '--code',
      'unnecessary_import',
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

    final futures = <Future<ResolvedImport>>[];

    log('Resolving imports:');
    for (final lib in libraries) {
      futures.add(_resolveImport(lib));
    }

    final resolvedImports = await Future.wait(futures);

    for (final import in resolvedImports) {
      final ResolvedImport(:path, :imports, :hasImports) = import;

      if (path == null) continue;
      if (!hasImports) continue;

      final lines = fs.file(path).readAsLinesSync();

      int? importStart;
      int? importEnd;
      int? commentStart;

      const skippable = ['as', 'hide', 'show', 'export'];

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
          continue;
        }
      }

      if (importEnd == null) {
        log('No import end found for ${fs.path.relative(path)}');
        continue;
      }

      final contentStart = lines.take(importStart).join('\n');
      final contentEnd = lines.sublist(importEnd).join('\n');

      final (:dart, :relative, :package) = imports;

      var content = [
        if (contentStart.trim() case final String start when start.isNotEmpty)
          start,
        if (dart.isNotEmpty) ...dart.followedBy(['']),
        if (package.isNotEmpty) ...package.followedBy(['']),
        if (relative.isNotEmpty) ...relative.followedBy(['']),
        contentEnd.trim(),
        '',
      ].join('\n');

      fs.file(path).writeAsStringSync(content.trimLeft());
    }

    return null;
  }

  Future<ResolvedImport> _resolveImport(
    (ParsedUnitResult, Future<ResolvedUnitResult> Function()) lib,
  ) async {
    final collector = ImportTypeCollector();
    final resolvedImport = ResolvedImport();

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

class ResolvedImport {
  ResolvedImport() : parts = {}, references = {};

  String? path;
  final Set<String> parts;
  final Set<Reference> references;

  bool get hasImports => references.isNotEmpty;

  ({List<String> dart, List<String> relative, List<String> package})
  get imports {
    final path = this.path;

    if (path == null) {
      throw Exception('Path is missing, cannot resolve imports');
    }

    final imports = <String, Reference>{};

    for (final ref in references) {
      final import = ref.import.resolved(path);
      if (import == null) {
        continue;
      }

      if (imports.remove(import) case final Reference existing) {
        if (existing.canJoin(ref)) {
          imports[import] = existing.join(ref);
        } else {
          final key = '$import (${ref.prefix})';

          if (imports.remove(key) case final Reference existing) {
            if (existing.canJoin(ref)) {
              imports[key] = existing.join(ref);
            } else {
              throw Exception('Unexpected duplicate import: $key');
            }
            continue;
          }

          imports[key] = ref;
        }
        continue;
      }

      imports[import] = ref;
    }

    final dart = <String>{};
    final relative = <String>{};
    final package = <String>{};

    for (final ref in imports.values) {
      final resolved = ref.importStatement(path);
      if (resolved == null) continue;

      switch (ref.import) {
        case Import(isDart: true):
          dart.add(resolved);
        case Import(isRelative: true):
          relative.add(resolved);
        case Import(isPackage: true):
          package.add(resolved);
      }
    }

    return (
      dart: dart.toList()..sort(),
      relative: relative.toList()..sort(),
      package: package.toList()..sort(),
    );
  }

  void add(Reference reference) {
    if (reference.canInclude(this)) {
      references.add(reference);
    }
  }

  void addAll(Iterable<Reference> references) {
    references.forEach(add);
  }
}

class HiddenType {
  const HiddenType({required this.type, required this.library});

  final String type;
  final Import library;
}

class Import {
  const Import(this._path);

  final String _path;

  String? resolved(String root) {
    if (_path.isEmpty) return null;

    if (_path.startsWith('file:')) {
      return fs.path.relative(
        _path.replaceFirst(RegExp('^file:'), ''),
        from: fs.path.dirname(root),
      );
    }

    if (_path == 'dart:_http') {
      return 'dart:io';
    }

    return _path;
  }

  bool get isDart => _path.startsWith('dart:');
  bool get isPackage => _path.startsWith('package:');
  bool get isRelative => !isDart && !isPackage;

  @override
  bool operator ==(Object other) {
    if (other is Import) {
      return _path == other._path;
    }

    return false;
  }

  @override
  int get hashCode => _path.hashCode;

  @override
  String toString() {
    return _path;
  }
}
