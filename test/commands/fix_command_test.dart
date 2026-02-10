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
            config: Config(format: true),
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
            config: Config(format: true),
          );

          final content = memoryFs.file(path).readAsStringSync();

          expect(content, '''
import 'package:test/test.dart' show Test;

void main() {}
''');
        },
      );

      testScoped(
        'should detect white space between format comments',
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

          command.updateImportStatements(reference, config: Config());

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
        'should parse multi-line show clauses until semicolon',
        fileSystem: () => memoryFs,
        cwd: () => memoryFs.currentDirectory.path,
        () {
          write('''
import 'package:couchsurfing_application/blocs/community_bloc.dart'
    show
        \$CommunityBlocEventsX,
        \$CommunityStateTypingX,
        CommunityBloc,
        CommunityState;
import 'package:couchsurfing_application/blocs/post_bloc.dart'
    show \$PostBlocEventsX, \$PostStateTypingX, PostBloc, PostState;

void main() {}
''');

          final reference = ResolvedReferences(
            path: path,
            references: [
              Reference(
                lib: _FakeLibrary(uri: 'package:couchsurfing_application/blocs/community_bloc.dart'),
                associatedElement: _FakeElement(displayName: 'CommunityBloc'),
              ),
              Reference(
                lib: _FakeLibrary(uri: 'package:couchsurfing_application/blocs/post_bloc.dart'),
                associatedElement: _FakeElement(displayName: 'PostBloc'),
              ),
            ],
          );

          command.updateImportStatements(
            reference,
            config: Config(format: true),
          );

          final content = memoryFs.file(path).readAsStringSync();

          expect(content, '''
import 'package:couchsurfing_application/blocs/community_bloc.dart' show CommunityBloc;
import 'package:couchsurfing_application/blocs/post_bloc.dart' show PostBloc;

void main() {}
''');
        },
      );

      testScoped(
        'should parse multi-line show with comment after semicolon',
        fileSystem: () => memoryFs,
        cwd: () => memoryFs.currentDirectory.path,
        () {
          write('''
import 'package:foo/bar.dart'
    show
        Foo,
        Bar; // ignore: depend_on_referenced_packages

void main() {}
''');

          final reference = ResolvedReferences(
            path: path,
            references: [
              Reference(
                lib: _FakeLibrary(uri: 'package:foo/bar.dart'),
                associatedElement: _FakeElement(displayName: 'Foo'),
              ),
            ],
          );

          command.updateImportStatements(
            reference,
            config: Config(format: true),
          );

          final content = memoryFs.file(path).readAsStringSync();

          expect(content, '''
import 'package:foo/bar.dart' show Foo;

void main() {}
''');
        },
      );

      testScoped(
        'keep library name when present',
        fileSystem: () => memoryFs,
        cwd: () => memoryFs.currentDirectory.path,
        () {
          write('''
/// some library comment
library file;

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

          command.updateImportStatements(reference, config: Config());

          final content = memoryFs.file(path).readAsStringSync();

          expect(content, '''
/// some library comment
library file;

// dart format off
import 'package:test/test.dart' show Test;
// dart format on

void main() {}
''');
        },
      );
      testScoped(
        'should keep top level comments',
        fileSystem: () => memoryFs,
        cwd: () => memoryFs.currentDirectory.path,
        () {
          write('''
// ignore_for_file: avoid_dynamic_calls, inference_failure_on_untyped_parameter
// ignore_for_file: avoid_redundant_argument_values
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

          command.updateImportStatements(reference, config: Config());

          final content = memoryFs.file(path).readAsStringSync();

          expect(content, '''
// ignore_for_file: avoid_dynamic_calls, inference_failure_on_untyped_parameter
// ignore_for_file: avoid_redundant_argument_values

// dart format off
import 'package:test/test.dart' show Test;
// dart format on

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
