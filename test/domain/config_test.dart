import 'package:import_ozempic/domain/config.dart';
import 'package:test/test.dart';

void main() {
  group('Config', () {
    test('defaults to generated-file excludes', () {
      final config = Config();

      expect(config.exclude, Config.defaultExclude);
      expect(config.shouldExclude('/project/lib/foo.g.dart'), isTrue);
      expect(config.shouldExclude('/project/lib/foo.freezed.dart'), isTrue);
      expect(config.shouldExclude('/project/lib/foo.mocks.dart'), isTrue);
      expect(config.shouldExclude('/project/lib/foo.config.dart'), isTrue);
      expect(config.shouldExclude('/project/lib/foo.dart'), isFalse);
    });

    test('explicit empty exclude list disables defaults', () {
      final config = Config(exclude: []);

      expect(config.exclude, isEmpty);
      expect(config.shouldExclude('/project/lib/foo.g.dart'), isFalse);
    });
  });
}
