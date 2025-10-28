import 'dart:io' as io;

import 'package:analyzer/file_system/file_system.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:import_cleaner/domain/analyzer_file_system/analyzer_file.dart';
import 'package:import_cleaner/domain/analyzer_file_system/analyzer_folder.dart';

class FileResourceProvider extends ResourceProvider {
  FileResourceProvider(this.fs);

  final FileSystem fs;

  @override
  File getFile(String path) {
    final file = fs.file(path);

    return file.toAnalyzerFile();
  }

  @override
  Folder getFolder(String path) {
    final folder = fs.directory(path);

    return folder.toAnalyzerFolder(fs);
  }

  @override
  Resource getResource(String path) {
    final file = fs.file(path);

    if (file.existsSync()) {
      return file.toAnalyzerFile();
    }

    final directory = fs.directory(path);

    return directory.toAnalyzerFolder(fs);
  }

  @override
  Folder? getStateLocation(String pluginId) {
    final path = fs.path.join(io.Directory.systemTemp.path, pluginId);

    return fs.directory(path).toAnalyzerFolder(fs);
  }

  @override
  Never get pathContext {
    throw UnimplementedError();
  }

  @override
  Never getLink(String path) {
    throw UnimplementedError();
  }
}
