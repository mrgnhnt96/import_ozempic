import 'package:import_ozempic/domain/analysis_options.dart';
import 'package:test/test.dart';

void main() {
  group('AnalysisOptions.clearExcludes', () {
    test('empties analyzer.exclude while preserving other keys', () {
      const input = '''
analyzer:
  language:
    strict-casts: true
  exclude:
    - '**/*.g.dart'
    - packages/domain/lib/domain.dart
  errors:
    unused_import: ignore

linter:
  rules:
    - always_declare_return_types
''';

      final cleared = AnalysisOptions.clearExcludes(input);

      expect(cleared, contains('strict-casts: true'));
      expect(cleared, contains('unused_import: ignore'));
      expect(cleared, contains('always_declare_return_types'));
      expect(cleared, contains('exclude: []'));
      expect(cleared, isNot(contains('**/*.g.dart')));
      expect(cleared, isNot(contains('domain.dart')));
    });

    test('is a no-op when there is no exclude section', () {
      const input = '''
analyzer:
  language:
    strict-casts: true
''';

      expect(AnalysisOptions.clearExcludes(input), input);
    });

    test('handles pillows-style deep indentation', () {
      const input = '''
analyzer:
    language:
        strict-casts: true

    exclude:
        - '**/*.g.dart'
        - packages/domain/lib/domain.dart

linter:
    rules:
        - always_declare_return_types
''';

      final cleared = AnalysisOptions.clearExcludes(input);
      expect(cleared, contains('exclude: []'));
      expect(cleared, isNot(contains('**/*.g.dart')));
      expect(cleared, contains('strict-casts: true'));
      expect(cleared, contains('always_declare_return_types'));
    });
  });
}
