import 'dart:convert';

import 'package:glob/glob.dart';
import 'package:import_cleaner/deps/fs.dart';
import 'package:import_cleaner/deps/log.dart';
import 'package:yaml/yaml.dart';

class Config {
  Config({this.exclude = const [], List<Alteration> alterations = const []})
    : alterations = Alterations(alterations);

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

    final alterations = switch (yaml['alterations']) {
      final List<dynamic> list =>
        list
            .map((e) => Alteration.fromJson(e as Map<dynamic, dynamic>))
            .toList(),
      _ => <Alteration>[],
    };

    return Config(exclude: exclude as List<String>, alterations: alterations);
  }

  final List<String> exclude;
  final Alterations alterations;

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

class Alterations {
  Alterations([this.alterations = const []])
    : _alterations = {
        for (final alteration in alterations)
          fs.path.relative(alteration.path): alteration,
      };

  final List<Alteration> alterations;

  final Map<String, Alteration> _alterations;

  Alteration? operator [](String path) {
    return _alterations[path] ?? _alterations[fs.path.relative(path)];
  }
}

class Alteration {
  const Alteration({
    required this.path,
    required this.import,
    this.hide = const [],
    this.show = const [],
  });

  factory Alteration.fromJson(Map<dynamic, dynamic> json) {
    return Alteration(
      path: json['path'] as String,
      import: json['import'] as String,
      hide: switch (json['hide']) {
        final String string => [string],
        final List<dynamic> list => list.map((e) => '$e').toList(),
        _ => [],
      },
      show: switch (json['show']) {
        final String string => [string],
        final List<dynamic> list => list.map((e) => '$e').toList(),
        _ => [],
      },
    );
  }

  final String path;
  final String import;
  final List<String> hide;
  final List<String> show;
}
