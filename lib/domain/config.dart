import 'dart:convert';

import 'package:glob/glob.dart';
import 'package:import_cleaner/deps/fs.dart';
import 'package:import_cleaner/deps/log.dart';
import 'package:yaml/yaml.dart';

class Config {
  Config({this.exclude = const [], Alterations? alterations})
    : alterations = alterations ?? Alterations();

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

    return Config(
      exclude: exclude as List<String>,
      alterations: switch (yaml['alterations']) {
        final Map<dynamic, dynamic> map => Alterations.fromJson(map),
        _ => null,
      },
    );
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
  Alterations({this.paths = const [], this.imports = const []})
    : _paths = {
        for (final alteration in paths)
          if (alteration.path case final String path)
            fs.path.relative(path): alteration,
      },
      _imports = {
        for (final alteration in imports) alteration.import: alteration,
      };

  factory Alterations.fromJson(Map<dynamic, dynamic> json) {
    return Alterations(
      paths: switch (json['paths']) {
        final List<dynamic> list =>
          list
              .map((e) => Alteration.fromJson(e as Map<dynamic, dynamic>))
              .toList(),
        _ => [],
      },
      imports: switch (json['imports']) {
        final List<dynamic> list =>
          list
              .map((e) => Alteration.fromJson(e as Map<dynamic, dynamic>))
              .toList(),
        _ => [],
      },
    );
  }

  final List<Alteration> paths;
  final List<Alteration> imports;

  final Map<String, Alteration> _paths;
  final Map<String, Alteration> _imports;

  Alteration? forImport(String import) {
    return _imports[import];
  }

  Alteration? forPath(String path) {
    return _paths[path] ?? _paths[fs.path.relative(path)];
  }

  Alteration? forPathAndImport({required String path, required String import}) {
    final i = forImport(import);
    final p = switch (forPath(path)) {
      final Alteration alteration when alteration.import == import =>
        alteration,
      _ => null,
    };

    if (i == null && p == null) {
      return null;
    }

    return Alteration(
      path: p?.path ?? path,
      import: i?.import ?? import,
      hide: [...?p?.hide, ...?i?.hide],
      show: [...?p?.show, ...?i?.show],
    );
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
      path: json['path'] as String?,
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

  final String? path;
  final String import;
  final List<String> hide;
  final List<String> show;
}
