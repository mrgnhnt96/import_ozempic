import 'package:import_ozempic/deps/pub_updater.dart';
import 'package:import_ozempic/gen/pkg.dart' as pkg;
import 'package:import_ozempic/gen/version.dart' as pkg;

class IsUpToDate {
  const IsUpToDate();

  Future<bool> check() async {
    try {
      final version = await pubUpdater.getLatestVersion(pkg.pkg);

      return version == pkg.version;
    } catch (_) {
      return true;
    }
  }

  Future<String> latestVersion() async {
    try {
      return await pubUpdater.getLatestVersion(pkg.pkg);
    } catch (_) {
      return pkg.version;
    }
  }

  Future<bool> update() async {
    try {
      await pubUpdater.update(packageName: pkg.pkg);

      return true;
    } catch (_) {
      return false;
    }
  }
}
