import 'package:import_ozempic/deps/is_up_to_date.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:import_ozempic/gen/pkg.dart';
import 'package:import_ozempic/gen/version.dart';

class UpdateCommand {
  const UpdateCommand();

  Future<int> run() async {
    final isUpdated = await isUpToDate.check();

    if (isUpdated) {
      log('You are using the latest version of $pkg (${version})');
      return 0;
    }

    final success = await isUpToDate.update();

    final latestVersion = await isUpToDate.latestVersion();

    if (success) {
      log('Updated $pkg to $latestVersion (from $version)');
      return 0;
    }

    log('Failed to update $pkg. Please try again later.');
    return 1;
  }
}
