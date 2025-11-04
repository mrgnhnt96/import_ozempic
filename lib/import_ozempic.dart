import 'package:import_ozempic/commands/fix_command.dart';
import 'package:import_ozempic/commands/update_command.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:import_ozempic/domain/args.dart';

const _usage = '''
Usage: import_ozempic <command> <arguments>

Commands:
  fix <files...>   Fix the imports in the given files
  update           Update the package to the latest version
''';

class ImportOzempic {
  const ImportOzempic();

  Future<int> run(Args args) async {
    int exitCode = 0;
    switch (args.path) {
      case ['fix', ...final files]:
        exitCode = await FixCommand(args: args).run(files);
      case ['update']:
        exitCode = await UpdateCommand().run();
      default:
        log(_usage);
        exitCode = 1;
    }

    return exitCode;
  }
}
