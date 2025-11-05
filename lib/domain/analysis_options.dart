import 'package:import_ozempic/deps/fs.dart';

class AnalysisOptions {
  const AnalysisOptions({required this.path});

  static const name = 'analysis_options.yaml';
  static const temporaryName = '$name.tmp';

  final String path;

  String get temporaryPath => '$path.tmp';

  // Moves the analysis options file to a temporary location
  // to prevent any paths from being excluded from analysis
  void makeTemporary() {
    fs.file(path).copySync(temporaryPath);
    fs.file(path).deleteSync();
  }

  void restore() {
    fs.file(temporaryPath).copySync(path);
    fs.file(temporaryPath).deleteSync();
  }
}
