import 'dart:io' as io;

import 'package:analyzer/file_system/file_system.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:import_cleaner/domain/analyzer_file_system/analyzer_file.dart';
import 'package:import_cleaner/domain/analyzer_file_system/file_resource_provider.dart';

class AnalyzerFolder implements Folder {
  AnalyzerFolder({
    required this.directory,
    required this.provider,
    required this.fs,
  });

  final io.Directory directory;

  final FileSystem fs;

  @override
  String canonicalizePath(String path) {
    return fs.path.canonicalize(path);
  }

  @override
  bool contains(String path) {
    return fs.path.isWithin(directory.path, path);
  }

  @override
  Folder copyTo(Folder parentFolder) {
    final files = directory.listSync(recursive: true);
    final newPath = fs.path.join(parentFolder.path, fs.path.basename(path));
    final newFolder = fs.directory(newPath);

    for (final file in files) {
      if (file is! io.File) {
        continue;
      }

      final newPath = fs.path.join(newFolder.path, fs.path.basename(file.path));
      file.copySync(newPath);
    }

    return AnalyzerFolder(fs: fs, directory: newFolder, provider: provider);
  }

  @override
  Resource getChild(String relPath) {
    final path = fs.path.join(directory.path, relPath);
    final child = fs.file(path);

    if (child.existsSync()) {
      return child.toAnalyzerFile();
    }

    return fs.directory(path).toAnalyzerFolder(fs);
  }

  @override
  File getChildAssumingFile(String relPath) {
    final path = fs.path.join(directory.path, relPath);
    final child = fs.file(path);

    return child.toAnalyzerFile();
  }

  @override
  Folder getChildAssumingFolder(String relPath) {
    final path = fs.path.join(directory.path, relPath);
    final child = fs.directory(path);

    return child.toAnalyzerFolder(fs);
  }

  @override
  List<Resource> getChildren() {
    Iterable<Resource> children() sync* {
      for (final entity in directory.listSync()) {
        if (entity is io.File) {
          yield entity.toAnalyzerFile(fs);
        } else if (entity is io.Directory) {
          yield entity.toAnalyzerFolder(fs);
        }
      }
    }

    return children().toList();
  }

  @override
  bool isOrContains(String path) {
    return fs.path.isWithin(directory.path, path);
  }

  @override
  bool get isRoot => directory.path == '/';

  @override
  final ResourceProvider provider;

  @override
  String get shortName => fs.path.basename(directory.path);

  @override
  Uri toUri() {
    return Uri.file(directory.path);
  }

  @override
  void create() {
    directory.createSync(recursive: true);
  }

  @override
  void delete() => directory.deleteSync(recursive: true);

  @override
  bool get exists => directory.existsSync();

  @override
  Folder get parent => directory.parent.toAnalyzerFolder(fs);

  @override
  String get path => directory.path;

  @override
  Resource resolveSymbolicLinksSync() {
    final resolved = directory.resolveSymbolicLinksSync();

    return fs.directory(resolved).toAnalyzerFolder(fs);
  }

  @override
  Never watch() {
    throw UnimplementedError();
  }
}

extension DirectoryIOX on io.Directory {
  AnalyzerFolder toAnalyzerFolder(FileSystem fs) => AnalyzerFolder(
    fs: fs,
    directory: fs.directory(path),
    provider: FileResourceProvider(fs),
  );
}
