import 'package:import_ozempic/deps/is_up_to_date.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:import_ozempic/domain/args.dart';
import 'package:import_ozempic/gen/pkg.dart';
import 'package:import_ozempic/gen/version.dart';

const _usage = '''
Usage: import_ozempic update

Updates the package to the latest version.

Flags:
  --help     Print this help message
''';

class UpdateCommand {
  const UpdateCommand({required this.args});

  final Args args;

  Future<int> run() async {
    if (args['help'] case true) {
      log(_usage);
      return 0;
    }

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
