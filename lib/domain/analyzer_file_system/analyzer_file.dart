import 'dart:io' as io;
import 'dart:typed_data';

import 'package:analyzer/file_system/file_system.dart';
import 'package:file/file.dart' as f;
import 'package:file/file.dart' show FileSystem;
import 'package:import_cleaner/domain/analyzer_file_system/analyzer_folder.dart';
import 'package:import_cleaner/domain/analyzer_file_system/file_resource_provider.dart';

class AnalyzerFile implements File {
  AnalyzerFile({required this.file, required this.provider, required this.fs});

  @override
  final ResourceProvider provider;
  final f.File file;
  final FileSystem fs;

  FileSystem get fileSystem => file.fileSystem;

  @override
  File copyTo(Folder parentFolder) {
    final newPath = fs.path.join(parentFolder.path, fs.path.basename(path));
    final newFile = fileSystem.file(newPath);

    file.copySync(newPath);

    return AnalyzerFile(file: newFile, provider: provider, fs: fs);
  }

  @override
  bool isOrContains(String path) {
    return fs.path.isWithin(file.path, path);
  }

  @override
  int get modificationStamp => file.statSync().modified.millisecondsSinceEpoch;

  @override
  String get shortName => fs.path.basename(file.path);

  @override
  Uri toUri() => Uri.file(file.path);

  @override
  void delete() {
    file.deleteSync();
  }

  @override
  bool get exists => file.existsSync();

  @override
  int get lengthSync => file.statSync().size;

  @override
  Folder get parent => file.parent.toAnalyzerFolder(fileSystem);

  @override
  String get path => file.path;

  @override
  Uint8List readAsBytesSync() {
    return file.readAsBytesSync();
  }

  @override
  String readAsStringSync() {
    if (!file.existsSync()) {
      return '';
    }

    return file.readAsStringSync();
  }

  @override
  File renameSync(String newPath) {
    final newFile = fileSystem.file(newPath);

    file.renameSync(newPath);

    return AnalyzerFile(file: newFile, provider: provider, fs: fs);
  }

  @override
  Resource resolveSymbolicLinksSync() {
    final resolved = file.resolveSymbolicLinksSync();

    return fileSystem.file(resolved).toAnalyzerFile();
  }

  @override
  Never watch() {
    throw UnimplementedError();
  }

  @override
  void writeAsBytesSync(List<int> bytes) {
    file.writeAsBytesSync(bytes);
  }

  @override
  void writeAsStringSync(String content) {
    file.writeAsStringSync(content);
  }
}

extension FileX on f.File {
  AnalyzerFile toAnalyzerFile() => AnalyzerFile(
    file: this,
    provider: FileResourceProvider(fileSystem),
    fs: fileSystem,
  );
}

extension FileIOX on io.File {
  AnalyzerFile toAnalyzerFile(FileSystem fs) => AnalyzerFile(
    file: fs.file(path),
    provider: FileResourceProvider(fs),
    fs: fs,
  );
}
