import 'package:analyzer/dart/element/element.dart';
import 'package:file/memory.dart';
import 'package:import_ozempic/commands/fix_command.dart';
import 'package:import_ozempic/domain/args.dart';
import 'package:import_ozempic/domain/config.dart';
import 'package:import_ozempic/domain/reference.dart';
import 'package:import_ozempic/domain/resolved_references.dart';
import 'package:test/fake.dart';
import 'package:test/test.dart';

import '../utils/test_scoped.dart';

void main() {
  late FixCommand command;
  late MemoryFileSystem memoryFs;

  const path = 'file.dart';

  setUp(() {
    command = FixCommand(args: Args());
    memoryFs = MemoryFileSystem.test();
  });

  void write(String content) {
    memoryFs.file(path).writeAsStringSync(content);
  }

  group(FixCommand, () {
    group('#updateImportStatements', () {
      testScoped(
        'should include dart format comments if present',
        fileSystem: () => memoryFs,
        cwd: () => memoryFs.currentDirectory.path,
        () {
          write('''
// dart format off
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
// dart format on

void main() {}
''');

          final reference = ResolvedReferences(
            path: path,
            references: [
              Reference(
                lib: _FakeLibrary(uri: 'package:test/test.dart'),
                associatedElement: _FakeElement(displayName: 'Test'),
              ),
            ],
          );

          command.updateImportStatements(reference);

          final content = memoryFs.file(path).readAsStringSync();

          expect(content, '''
// dart format off
import 'package:test/test.dart' show Test;
// dart format on

void main() {}
''');
        },
      );

      testScoped(
        'should add import statements if not present',
        fileSystem: () => memoryFs,
        cwd: () => memoryFs.currentDirectory.path,
        () {
          write('''
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

void main() {}
''');

          final reference = ResolvedReferences(
            path: path,
            references: [
              Reference(
                lib: _FakeLibrary(uri: 'package:test/test.dart'),
                associatedElement: _FakeElement(displayName: 'Test'),
              ),
            ],
          );

          command.updateImportStatements(reference);

          final content = memoryFs.file(path).readAsStringSync();

          expect(content, '''
// dart format off
import 'package:test/test.dart' show Test;
// dart format on

void main() {}
''');
        },
      );

      testScoped(
        'should not include dart format comments if format imports is enabled',
        fileSystem: () => memoryFs,
        cwd: () => memoryFs.currentDirectory.path,
        () {
          write('''
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

void main() {}
''');

          final reference = ResolvedReferences(
            path: path,
            references: [
              Reference(
                lib: _FakeLibrary(uri: 'package:test/test.dart'),
                associatedElement: _FakeElement(displayName: 'Test'),
              ),
            ],
          );

          command.updateImportStatements(
            reference,
            config: Config(formatImports: true),
          );

          final content = memoryFs.file(path).readAsStringSync();

          expect(content, '''
import 'package:test/test.dart' show Test;

void main() {}
''');
        },
      );

      testScoped(
        'should remove dart format comments if format imports is enabled',
        fileSystem: () => memoryFs,
        cwd: () => memoryFs.currentDirectory.path,
        () {
          write('''
// dart format off
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
// dart format on

void main() {}
''');

          final reference = ResolvedReferences(
            path: path,
            references: [
              Reference(
                lib: _FakeLibrary(uri: 'package:test/test.dart'),
                associatedElement: _FakeElement(displayName: 'Test'),
              ),
            ],
          );

          command.updateImportStatements(
            reference,
            config: Config(formatImports: true),
          );

          final content = memoryFs.file(path).readAsStringSync();

          expect(content, '''
import 'package:test/test.dart' show Test;

void main() {}
''');
        },
      );
    });
  });
}

class _FakeElement extends Fake implements Element {
  _FakeElement({required String displayName}) : _displayName = displayName;

  final String _displayName;

  @override
  String get displayName => _displayName;
}

class _FakeLibrary extends Fake implements LibraryElement {
  _FakeLibrary({required String uri}) : _uri = uri;

  final String _uri;

  @override
  Uri get uri => Uri.parse(_uri);
}
