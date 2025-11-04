import 'package:import_ozempic/deps/analyzer.dart';
import 'package:import_ozempic/deps/fs.dart';
import 'package:import_ozempic/domain/import.dart';
import 'package:import_ozempic/domain/import_type_collector.dart';
import 'package:test/test.dart';

import '../utils/test_scoped.dart';

void main() {
  group(ImportTypeCollector, () {
    late ImportTypeCollector collector;
    setUp(() {
      collector = ImportTypeCollector();
    });

    testScoped(
      'pattern field name',
      cwd: () => fs.directory(fs.path.joinAll(['test', 'fixtures'])).path,
      initializeAnalyzer: true,
      () async {
        final results = await analyzer.analyze([
          fs.path.join('lib', 'pattern_field_name.dart'),
        ]);

        final lib = await (results.single.$2)();

        lib.unit.accept(collector);

        final references = collector.references;

        expect(references, isNotEmpty);

        final [user, extension, core] = references
            .map((e) => e.import)
            .toList();

        expect(user, Import('package:_extensions/domain/user.dart'));
        expect(extension, Import('package:_extensions/ext/user_x.dart'));
        expect(core, Import('dart:core'));
      },
    );

    testScoped(
      'should ignore Future and Stream',
      cwd: () => fs.directory(fs.path.joinAll(['test', 'fixtures'])).path,
      initializeAnalyzer: true,
      () async {
        final results = await analyzer.analyze([
          fs.path.join('lib', 'named_type', 'future_and_stream.dart'),
        ]);

        final lib = await (results.single.$2)();

        lib.unit.accept(collector);

        final references = collector.references;

        expect(references, isEmpty);
      },
    );

    testScoped(
      'should resolve type aliases',
      cwd: () => fs.directory(fs.path.joinAll(['test', 'fixtures'])).path,
      initializeAnalyzer: true,
      () async {
        final results = await analyzer.analyze([
          fs.path.join('lib', 'named_type', 'type_aliases.dart'),
        ]);

        final lib = await (results.single.$2)();

        lib.unit.accept(collector);

        final references = collector.references;

        final [alias, user] = references.toList();

        expect(user.import, Import('package:_extensions/domain/user.dart'));
        expect(
          alias.import,
          Import('package:_extensions/ext/user_type_alias.dart'),
        );
        expect(user.prefix, isNull);
      },
    );

    testScoped(
      'should get general types',
      cwd: () => fs.directory(fs.path.joinAll(['test', 'fixtures'])).path,
      initializeAnalyzer: true,
      () async {
        final results = await analyzer.analyze([
          fs.path.join('lib', 'named_type', 'return_types.dart'),
        ]);

        final lib = await (results.single.$2)();

        lib.unit.accept(collector);

        final references = collector.references;

        final [user, user2] = references.toList();

        expect(user.import, Import('package:_extensions/domain/user.dart'));
        expect(user.prefix, isNull);

        expect(user2.import, Import('package:_extensions/domain/user.dart'));
        expect(user2.prefix, 'i1');
      },
    );

    testScoped(
      'should get top level getter & setter',
      cwd: () => fs.directory(fs.path.joinAll(['test', 'fixtures'])).path,
      initializeAnalyzer: true,
      () async {
        final results = await analyzer.analyze([
          fs.path.join('lib', 'simple_identifier', 'env_globals.dart'),
        ]);

        final lib = await (results.single.$2)();

        lib.unit.accept(collector);

        final references = collector.references;

        final [core, getter, setter] = references.toList();

        expect(core.import, Import('dart:core'));
        expect(
          getter.import,
          Import('package:_extensions/globals/global_env.dart'),
        );
        expect(
          setter.import,
          Import('package:_extensions/globals/global_env.dart'),
        );
      },
    );

    testScoped(
      'should get top level variable and method',
      cwd: () => fs.directory(fs.path.joinAll(['test', 'fixtures'])).path,
      initializeAnalyzer: true,
      () async {
        final results = await analyzer.analyze([
          fs.path.join('lib', 'simple_identifier', 'math_globals.dart'),
        ]);

        final lib = await (results.single.$2)();

        lib.unit.accept(collector);

        final references = collector.references;

        final [pi, max, mathPi, mathImport, mathMax] = references.toList();

        expect(
          pi.import,
          Import('package:_extensions/globals/global_math.dart'),
        );
        expect(pi.prefix, isNull);
        expect(
          max.import,
          Import('package:_extensions/globals/global_math.dart'),
        );
        expect(max.prefix, isNull);

        expect(
          mathPi.import,
          Import('package:_extensions/globals/global_math.dart'),
        );
        expect(mathPi.prefix, 'math');
        expect(
          mathMax.import,
          Import('package:_extensions/globals/global_math.dart'),
        );
        expect(mathMax.prefix, 'math');
      },
    );
  });
}
