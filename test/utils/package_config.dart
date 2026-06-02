import 'package:import_ozempic/deps/fs.dart';
import 'package:package_config/package_config.dart';

PackageConfig testPackageConfig({required String packageName}) {
  final root = Uri.directory(fs.currentDirectory.path);

  return PackageConfig([
    Package(
      packageName,
      root,
      packageUriRoot: root.replace(path: '${root.path}lib/'),
    ),
  ]);
}
