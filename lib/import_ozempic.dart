import 'package:import_ozempic/commands/fix_command.dart';
import 'package:import_ozempic/commands/restore_command.dart';
import 'package:import_ozempic/commands/update_command.dart';
import 'package:import_ozempic/deps/analyzer.dart';
import 'package:import_ozempic/deps/args.dart';
import 'package:import_ozempic/deps/is_up_to_date.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:import_ozempic/gen/version.dart';

const _usage = '''
Usage: import_ozempic <command> <arguments>

Commands:
  fix <files...>   Fix the imports in the given files
  update           Update the package to the latest version
  restore          Restore the analysis options files to their original location


Flags:
  --version        Print the version of the package
''';

class ImportOzempic {
  const ImportOzempic();

  Future<int> run() async {
    int exitCode = 0;

    try {
      if (args['version'] case true) {
        log(version);
      } else {
        try {
          switch (args.path) {
            case ['fix', ...final files]:
              exitCode = await FixCommand(args: args).run(files);
            case ['update']:
              exitCode = await UpdateCommand(args: args).run();
            case ['restore']:
              exitCode = await RestoreCommand(args: args).run();
            default:
              log(_usage);
              exitCode = 1;
          }
        } catch (e) {
          log('Error running command: $e');
          exitCode = 1;
        }
      }
    } finally {
      await analyzer.dispose();
    }

    if (!await isUpToDate.check()) {
      final latestVersion = await isUpToDate.latestVersion();
      log(
        'A new version is available ($latestVersion). Run `import_ozempic update` to update.',
      );
    }

    return exitCode;
  }
}
