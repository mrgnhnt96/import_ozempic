import 'package:file/memory.dart';
import 'package:import_ozempic/domain/barrel_import.dart';
import 'package:import_ozempic/deps/fs.dart';
import 'package:test/test.dart';

import '../utils/package_config.dart';
import '../utils/test_scoped.dart';

void main() {
  group(BarrelImport, () {
    test('uriFor returns conventional barrel path', () {
      expect(
        BarrelImport.uriFor('package:my_app/src/foo.dart'),
        'package:my_app/my_app.dart',
      );
    });

    test('uriFor returns null for non-package imports', () {
      expect(BarrelImport.uriFor('dart:async'), isNull);
      expect(BarrelImport.uriFor('../foo.dart'), isNull);
    });

    test('isBarrel identifies barrel URIs', () {
      expect(BarrelImport.isBarrel('package:my_app/my_app.dart'), isTrue);
      expect(BarrelImport.isBarrel('package:my_app/src/foo.dart'), isFalse);
    });

    testScoped(
      'candidates prioritizes parent segment barrels',
      fileSystem: () {
        final memoryFs = MemoryFileSystem.test();
        memoryFs
            .file('lib/widgets.dart')
            .createSync(recursive: true);
        memoryFs
            .file('lib/flutter.dart')
            .createSync(recursive: true);
        return memoryFs;
      },
      cwd: () => fs.currentDirectory.path,
      () {
        final config = testPackageConfig(packageName: 'flutter');

        expect(
          BarrelImport.candidates(
            'package:flutter/src/widgets/basic.dart',
            config,
          ),
          [
            'package:flutter/widgets.dart',
            'package:flutter/flutter.dart',
          ],
        );
      },
    );

    testScoped(
      'candidates includes conventional package barrel',
      fileSystem: () {
        final memoryFs = MemoryFileSystem.test();
        memoryFs
            .file('lib/my_app.dart')
            .createSync(recursive: true);
        return memoryFs;
      },
      cwd: () => fs.currentDirectory.path,
      () {
        final config = testPackageConfig(packageName: 'my_app');

        expect(
          BarrelImport.candidates(
            'package:my_app/src/domain/user.dart',
            config,
          ),
          ['package:my_app/my_app.dart'],
        );
      },
    );

    testScoped(
      'candidates returns empty when no barrels exist',
      fileSystem: () => MemoryFileSystem.test(),
      cwd: () => fs.currentDirectory.path,
      () {
        final config = testPackageConfig(packageName: 'my_app');

        expect(
          BarrelImport.candidates(
            'package:my_app/src/domain/user.dart',
            config,
          ),
          isEmpty,
        );
      },
    );
  });
}
