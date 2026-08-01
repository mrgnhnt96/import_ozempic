import 'package:import_ozempic/deps/fs.dart';
import 'package:yaml/yaml.dart';

class AnalysisOptions {
  const AnalysisOptions({required this.path});

  static const name = 'analysis_options.yaml';
  static const temporaryName = '$name.tmp';

  final String path;

  String get temporaryPath => path.endsWith('.tmp') ? path : '$path.tmp';

  String get originalPath => path.endsWith('.tmp')
      ? path.substring(0, path.length - '.tmp'.length)
      : path;

  /// Restores a leftover `.tmp` from older versions that moved options on disk.
  void restore() {
    final tmp = fs.file(temporaryPath);
    if (!tmp.existsSync()) {
      return;
    }
    tmp.copySync(originalPath);
    tmp.deleteSync();
  }

  /// Returns [content] with `analyzer.exclude` emptied so excluded files
  /// (generated parts, barrels, etc.) remain resolvable via `contextFor`.
  ///
  /// Disk files are left untouched; callers should apply this via an overlay.
  static String clearExcludes(String content) {
    final dynamic loaded = loadYaml(content);
    if (loaded is! YamlMap) {
      return content;
    }

    final analyzer = loaded['analyzer'];
    if (analyzer is! YamlMap || !analyzer.containsKey('exclude')) {
      return content;
    }

    return _replaceExcludeList(content);
  }

  /// Replaces the `exclude:` list under `analyzer:` with `exclude: []`,
  /// preserving the rest of the file (comments, includes, lints, etc.).
  static String _replaceExcludeList(String content) {
    final lines = content.split('\n');
    final out = <String>[];
    var inAnalyzer = false;
    var analyzerIndent = 0;
    var inExclude = false;
    var excludeIndent = 0;

    for (final line in lines) {
      final trimmed = line.trimLeft();
      final indent = line.length - trimmed.length;

      if (!inAnalyzer) {
        if (RegExp(r'^analyzer\s*:').hasMatch(trimmed)) {
          inAnalyzer = true;
          analyzerIndent = indent;
        }
        out.add(line);
        continue;
      }

      // Left the analyzer: block.
      if (trimmed.isNotEmpty &&
          !trimmed.startsWith('#') &&
          indent <= analyzerIndent) {
        inAnalyzer = false;
        inExclude = false;
        out.add(line);
        continue;
      }

      if (!inExclude && RegExp(r'^exclude\s*:').hasMatch(trimmed)) {
        out.add('${' ' * indent}exclude: []');
        inExclude = true;
        excludeIndent = indent;
        continue;
      }

      if (inExclude) {
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }
        // Skip list items / nested content under exclude.
        if (indent > excludeIndent) {
          continue;
        }
        inExclude = false;
        // Fall through — this line belongs to the next analyzer key.
      }

      out.add(line);
    }

    return out.join('\n');
  }
}
