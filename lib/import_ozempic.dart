import 'package:import_ozempic/commands/fix_command.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:import_ozempic/domain/args.dart';

const _usage = '''
Usage: import_ozempic <command> <arguments>

Commands:
  fix <files...>  Fix the imports in the given files
''';

class ImportOzempic {
  const ImportOzempic();

  Future<int> run(Args args) async {
    switch (args.path) {
      case ['fix', ...final files]:
        return FixCommand(args: args).run(files);
      default:
        log(_usage);
    }

    return 0;
  }
}
