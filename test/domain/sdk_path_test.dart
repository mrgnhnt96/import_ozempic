import 'dart:io';

import 'package:import_ozempic/domain/sdk_path.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final dartExecutable = Platform.resolvedExecutable;
  final sdkFromDart = p.normalize(
    p.dirname(p.dirname(dartExecutable)),
  );

  group('resolveDartSdkPath', () {
    test('uses DART_SDK when it looks like an SDK', () {
      final resolved = resolveDartSdkPath(
        resolvedExecutable: '/tmp/not-dart/import_ozempic',
        environment: {dartSdkEnv: sdkFromDart},
        which: (_) => null,
      );

      expect(resolved, sdkFromDart);
    });

    test('derives SDK from dart executable', () {
      final resolved = resolveDartSdkPath(
        resolvedExecutable: dartExecutable,
        environment: const {},
        which: (_) => null,
      );

      expect(resolved, sdkFromDart);
    });

    test('falls back to dart on PATH for AOT binaries', () {
      final resolved = resolveDartSdkPath(
        resolvedExecutable:
            '/Users/me/.import_ozempic/aot/import_ozempic-0.0.20',
        environment: const {},
        which: (exe) => exe == 'dart' ? dartExecutable : null,
      );

      expect(resolved, sdkFromDart);
    });

    test('throws when SDK cannot be found', () {
      expect(
        () => resolveDartSdkPath(
          resolvedExecutable: '/tmp/import_ozempic',
          environment: const {},
          which: (_) => null,
        ),
        throwsStateError,
      );
    });
  });
}
