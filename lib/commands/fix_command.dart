import 'package:analyzer/dart/analysis/results.dart';
import 'package:import_cleaner/deps/analyzer.dart';
import 'package:import_cleaner/deps/fs.dart';
import 'package:import_cleaner/deps/log.dart';
import 'package:import_cleaner/domain/args.dart';
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

    analyzer.initialize(root: files.first);

    final results = await analyzer.analyze(files);

    final resultsByLibrary =
        <
          String,
          List<(ParsedUnitResult, Future<ResolvedUnitResult> Function())>
        >{};

    for (final result in results) {
      final (parsed, resolved) = result;

      final segments = fs.path.split(parsed.path);
      if (segments.contains('test')) continue;

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
            .first;

        final basename = fs.path.basename(partOfPath);

        (resultsByLibrary[basename] ??= []).add(result);
        continue;
      }

      final basename = fs.path.basename(parsed.path);

      (resultsByLibrary[basename] ??= []).add(result);
    }

    final resolvedImports = <ResolvedImport>[];

    log('Resolving imports:');
    for (final results in resultsByLibrary.values) {
      final collector = ImportTypeCollector();
      final resolvedImport = ResolvedImport();

      for (final result in results) {
        final (parsed, resolved) = result;
        log('  ${fs.path.relative(parsed.path)}');

        if (parsed.isLibrary) {
          resolvedImport.path = parsed.path;
        }

        final library = await resolved();

        library.unit.accept(collector);
      }

      resolvedImport.addAll([
        for (final type in collector.referencedTypes)
          type.element.library.uri.toString(),
        for (final extension in collector.extensions)
          extension.library.uri.toString(),
      ]);

      resolvedImports.add(resolvedImport);
    }

    for (final import in resolvedImports) {
      final ResolvedImport(:path, :imports, :hasImports) = import;

      if (path == null) continue;
      if (!hasImports) continue;

      final lines = fs.file(path).readAsLinesSync();

      int? importStart;
      int? importEnd;
      int? commentStart;

      for (final (index, line) in lines.indexed) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.startsWith('//')) {
          commentStart ??= index;
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

      String toStatement(String path) {
        return "import '$path';";
      }

      final content = [
        contentStart.trim(),
        if (dart.isNotEmpty) ...[...dart.map(toStatement), ''],
        if (package.isNotEmpty) ...[...package.map(toStatement), ''],
        if (relative.isNotEmpty) ...[...relative.map(toStatement), ''],
        contentEnd.trim(),
        '',
      ].join('\n');

      fs.file(path).writeAsStringSync(content.trimLeft());
    }

    return 0;
  }
}

class ResolvedImport {
  ResolvedImport() : _imports = {};

  String? path;
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

    if (isPackage) {
      final srcPath = _path.split(RegExp(r'package:\w+/')).last;

      if (root.endsWith(srcPath)) {
        return null;
      }
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
