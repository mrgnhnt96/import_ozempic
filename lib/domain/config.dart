import 'dart:convert';

import 'package:glob/glob.dart';
import 'package:import_ozempic/deps/fs.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:yaml/yaml.dart';

class Config {
  Config({this.exclude = const [], this.format = false});

  factory Config.load(String path) {
    final file = fs.file(path);

    if (!file.existsSync()) {
      log('Config file not found at $path');
      return Config();
    }

    final content = file.readAsStringSync();

    final yaml =
        jsonDecode(jsonEncode(loadYaml(content))) as Map<String, dynamic>;

    final exclude = switch (yaml['exclude']) {
      final String string => [string],
      final List<dynamic> list => list.map((e) => '$e').toList(),
      _ => [],
    };

    final format = switch (yaml['format']) {
      final bool v => v,
      'true' => true,
      'false' => false,
      _ => false,
    };

    return Config(exclude: exclude as List<String>, format: format);
  }

  final List<String> exclude;

  /// When `false`, the import statements will not be formatted,
  /// leaving 1 import statement per line.
  ///
  /// Defaults to `false`.
  final bool format;

  bool shouldExclude(String path) {
    for (final exclude in exclude) {
      if (path == exclude) {
        return true;
      }

      if (path.endsWith(exclude)) {
        return true;
      }

      if (Glob(exclude).matches(path)) {
        return true;
      }

      if (Glob('/$exclude').matches(path)) {
        return true;
      }
    }

    return false;
  }
}
