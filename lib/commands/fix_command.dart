import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:import_cleaner/deps/analyzer.dart';
import 'package:import_cleaner/deps/fs.dart';
import 'package:import_cleaner/deps/log.dart';
import 'package:import_cleaner/domain/args.dart';
import 'package:import_cleaner/domain/config.dart';
import 'package:import_cleaner/domain/import_type_collector.dart';

const _usage = '''
Usage: import_cleaner fix <file>...

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

    final results = await analyzer.analyze(files);

    final resultsByLibrary =
        <
          String,
          List<(ParsedUnitResult, Future<ResolvedUnitResult> Function())>
        >{};

    for (final result in results) {
      final (parsed, resolved) = result;

      if (config.shouldExclude(parsed.path)) {
        continue;
      }

      if (!parsed.isLibrary) {
        final partOfDirective = parsed.unit.directives
            .map((e) => e.toString())
            .firstWhere((e) => e.contains('part of'), orElse: () => '');

        if (partOfDirective.isEmpty) {
          log(
            'Skipping ${parsed.path} and it did not have a `part of` directive',
          );
          continue;
        }

        final partOfPath = partOfDirective
            .split(' ')
            .last
            .substring(1)
            .split("'")
            .first
            .split('/')
            .last;

        final basename = fs.path.basename(partOfPath);

        (resultsByLibrary[basename] ??= []).add(result);
        continue;
      }

      final basename = fs.path.basename(parsed.path);

      (resultsByLibrary[basename] ??= []).add(result);
    }

    if (resultsByLibrary.isEmpty) {
      log('No files were found to fix');
      return 0;
    }

    final resolvedImports = <ResolvedImport>[];

    log('Resolving imports:');
    for (final results in resultsByLibrary.values) {
      final collector = ImportTypeCollector();
      final resolvedImport = ResolvedImport();

      for (final result in results) {
        final (parsed, resolved) = result;
        resolvedImport.parts.add(parsed.path);
        log('  ${fs.path.relative(parsed.path)}');

        if (parsed.isLibrary) {
          resolvedImport.path = parsed.path;
        }

        final library = await resolved();

        library.unit.accept(collector);
      }

      resolvedImport
        ..addAll([
          for (final lib in collector.libraries)
            if (lib.firstFragment.source.fullName != resolvedImport.path)
              lib.uri.toString(),
        ])
        ..hiddenTypes.addAll(
          collector.hiddenTypes.map(
            (e) => HiddenType(
              type: e.element.displayName,
              library: Import(e.element.library.uri.toString()),
            ),
          ),
        )
        ..prefixedIdentifiers.addAll({
          for (final MapEntry(:key, :value)
              in collector.prefixedIdentifiers.entries)
            key: [for (final type in value) Import(type.uri.toString())],
        });

      resolvedImports.add(resolvedImport);
    }

    for (final import in resolvedImports) {
      final ResolvedImport(
        :path,
        :imports,
        :hasImports,
        :hiddenTypes,
        :prefixedIdentifiers,
      ) = import;

      final prefixByPath = <String, String>{
        for (final MapEntry(:key, :value) in prefixedIdentifiers.entries)
          for (final import in value)
            if (path != null)
              if (import.resolved(path) case final String resolved)
                resolved: key,
      };

      if (path == null) continue;
      if (!hasImports) continue;

      final lines = fs.file(path).readAsLinesSync();

      int? importStart;
      int? importEnd;
      int? commentStart;

      const skippable = ['show', 'hide', 'as'];

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

      String toStatement(String import) {
        final prefix = switch (prefixByPath[import]) {
          final String prefix => prefix,
          _ => null,
        };

        final asClause = switch (prefix) {
          final String prefix => 'as $prefix',
          _ => '',
        };

        final hidden = {
          if (prefix == null)
            for (final hiddenType in hiddenTypes)
              if (hiddenType.library.resolved(path) == import) hiddenType.type,
        };

        final alterations = config.alterations.forPathAndImport(
          path: fs.path.relative(path),
          import: import,
        );

        final shown = <String>{};

        if (alterations case Alteration(
          import: final i,
          :final hide,
          :final show,
        ) when i == import) {
          hidden.addAll(hide);
          shown.addAll(show);
        }

        final hide = switch (hidden.toList()) {
          [] => switch (shown.toList()) {
            [] => '',
            final list => 'show ${list.join(', ')}',
          },
          final list => 'hide ${list.join(', ')}',
        };

        final statement = "import '$import' $asClause $hide".trim();

        return '$statement;';
      }

      var content = [
        contentStart.trim(),
        if (dart.isNotEmpty) ...[...dart.map(toStatement), ''],
        if (package.isNotEmpty) ...[...package.map(toStatement), ''],
        if (relative.isNotEmpty) ...[...relative.map(toStatement), ''],
        contentEnd.trim(),
        '',
      ].join('\n');

      fs.file(path).writeAsStringSync(content.trimLeft());
    }

    return null;
  }
}

class ResolvedImport {
  ResolvedImport()
    : _imports = {},
      parts = {},
      hiddenTypes = {},
      prefixedIdentifiers = {};

  String? path;
  final Set<String> parts;
  final Set<HiddenType> hiddenTypes;
  // Example: 'math' -> [pi, max]
  final Map<String, List<Import>> prefixedIdentifiers;
  final Set<Import> _imports;

  bool get hasImports => _imports.isNotEmpty;

  ({List<String> dart, List<String> relative, List<String> package})
  get imports {
    final path = this.path;

    if (path == null) {
      throw Exception('Path is missing, cannot resolve imports');
    }

    final dart = <String>{};
    final relative = <String>{};
    final package = <String>{};

    for (final import in _imports) {
      final resolved = import.resolved(path);
      if (resolved == null) continue;

      switch (import) {
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

  void add(String path) {
    _imports.add(Import(path));
  }

  void addAll(Iterable<String> paths) {
    for (final path in paths) {
      add(path);
    }
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
}
