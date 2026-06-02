import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:file/memory.dart';
import 'package:import_ozempic/commands/sober_command.dart';
import 'package:import_ozempic/deps/analyzer.dart';
import 'package:import_ozempic/deps/fs.dart';
import 'package:import_ozempic/domain/args.dart';
import 'package:import_ozempic/domain/barrel_import_cache.dart';
import 'package:import_ozempic/domain/import_type_collector.dart';
import 'package:import_ozempic/domain/reference.dart';
import 'package:import_ozempic/domain/resolved_references.dart';
import 'package:package_config/package_config.dart';
import 'package:test/fake.dart';
import 'package:test/test.dart';

import '../utils/test_scoped.dart';

void main() {
  group(SoberCommand, () {
    late SoberCommand command;
    late MemoryFileSystem memoryFs;

    const path = 'lib/main.dart';

    setUp(() {
      command = SoberCommand(args: Args());
      memoryFs = MemoryFileSystem.test();
    });

    void write(String content) {
      memoryFs.file(path).createSync(recursive: true);
      memoryFs.file(path).writeAsStringSync(content);
    }

    testScoped(
      'collapses imports from the same package into a barrel export',
      fileSystem: () => memoryFs,
      cwd: () => memoryFs.currentDirectory.path,
      () async {
        write('''
import 'package:my_app/src/a.dart' show Foo;
import 'package:my_app/src/b.dart' show Bar;

void main() {}
''');

        final references = ResolvedReferences(
          path: path,
          references: [
            Reference(
              lib: _FakeLibrary(uri: 'package:my_app/src/a.dart'),
              associatedElement: _FakeElement(displayName: 'Foo'),
            ),
            Reference(
              lib: _FakeLibrary(uri: 'package:my_app/src/b.dart'),
              associatedElement: _FakeElement(displayName: 'Bar'),
            ),
          ],
        );

        await command.updateImportStatements(
          references,
          barrelCache: BarrelImportCache(
            lookup: {
              ('package:my_app/src/a.dart', 'Foo'):
                  'package:my_app/my_app.dart',
              ('package:my_app/src/b.dart', 'Bar'):
                  'package:my_app/my_app.dart',
            },
          ),
        );

        expect(fs.file(path).readAsStringSync(), '''
// dart format off
import 'package:my_app/my_app.dart';
// dart format on

void main() {}
''');
      },
    );

    testScoped(
      'keeps granular imports when no barrel exports the type',
      fileSystem: () => memoryFs,
      cwd: () => memoryFs.currentDirectory.path,
      () async {
        write('''
import 'package:my_app/src/a.dart' show Foo;

void main() {}
''');

        final references = ResolvedReferences(
          path: path,
          references: [
            Reference(
              lib: _FakeLibrary(uri: 'package:my_app/src/a.dart'),
              associatedElement: _FakeElement(displayName: 'Foo'),
            ),
          ],
        );

        await command.updateImportStatements(
          references,
          barrelCache: const BarrelImportCache.empty(),
        );

        expect(fs.file(path).readAsStringSync(), '''
// dart format off
import 'package:my_app/src/a.dart' show Foo;
// dart format on

void main() {}
''');
      },
    );

    String fixturesRoot() =>
        fs.directory(fs.path.joinAll(['test', 'fixtures'])).path;

    testScoped(
      'consolidates to package barrel when it re-exports all referenced types',
      cwd: () => fixturesRoot(),
      initializeAnalyzer: true,
      () async {
        final inputPath = fs.path.join(
          fixturesRoot(),
          'lib',
          'inputs',
          'bloc.dart',
        );
        final inputFile = fs.file(inputPath);
        final originalContent = inputFile.readAsStringSync();
        try {
          final results = await analyzer.analyze([inputPath]);
          final (parsed, resolved) = results.single;
          final library = await resolved();

          final collector = ImportTypeCollector();
          library.unit.accept(collector);

          final references = ResolvedReferences(path: parsed.path)
            ..addAll(collector.references);

          final packageConfig = await findPackageConfig(
            Directory(fixturesRoot()),
          );

          final barrelCache = await BarrelImportCache.build(
            references: references.references,
            packageConfig: packageConfig,
            session: library.session,
          );

          await command.updateImportStatements(
            references,
            barrelCache: barrelCache,
          );

          final content = fs.file(inputPath).readAsStringSync();

          expect(
            content,
            contains("import 'package:_extensions/_extensions.dart';"),
          );
          expect(content, isNot(contains('widgets.dart')));
          expect(content, isNot(contains(' show ')));
        } finally {
          File(inputFile.path).writeAsStringSync(originalContent);
        }
      },
    );

    testScoped(
      'consolidates overlapping barrels from the same package',
      cwd: () => fixturesRoot(),
      initializeAnalyzer: true,
      () async {
        final inputPath = fs.path.join(
          fixturesRoot(),
          'lib',
          'inputs',
          'multi_barrel.dart',
        );
        final inputFile = fs.file(inputPath);
        final originalContent = inputFile.readAsStringSync();
        try {
          final results = await analyzer.analyze([inputPath]);
          final (parsed, resolved) = results.single;
          final library = await resolved();

          final collector = ImportTypeCollector();
          library.unit.accept(collector);

          final references = ResolvedReferences(path: parsed.path)
            ..addAll(collector.references);

          final packageConfig = await findPackageConfig(
            Directory(fixturesRoot()),
          );

          final barrelCache = await BarrelImportCache.build(
            references: references.references,
            packageConfig: packageConfig,
            session: library.session,
          );

          await command.updateImportStatements(
            references,
            barrelCache: barrelCache,
          );

          final content = fs.file(inputPath).readAsStringSync();

          expect(content, contains("import 'package:_extensions/widgets.dart';"));
          expect(content, contains("import 'package:_extensions/theme.dart';"));
          expect(content, isNot(contains('foundation.dart')));
          expect(content, isNot(contains('theme_only.dart')));
          expect(content, isNot(contains(' show ')));
        } finally {
          File(inputFile.path).writeAsStringSync(originalContent);
        }
      },
    );
  });
}

class _FakeElement extends Fake implements Element {
  _FakeElement({required String displayName}) : _displayName = displayName;

  final String _displayName;

  @override
  Metadata get metadata => _FakeMetadata();

  @override
  String get displayName => _displayName;
}

class _FakeLibrary extends Fake implements LibraryElement {
  _FakeLibrary({required String uri}) : _uri = uri;

  final String _uri;

  @override
  Uri get uri => Uri.parse(_uri);
}

class _FakeMetadata extends Fake implements Metadata {
  @override
  List<ElementAnnotation> get annotations => [];
}
