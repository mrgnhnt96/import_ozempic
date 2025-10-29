import 'package:import_cleaner/commands/fix_command.dart';
import 'package:import_cleaner/domain/args.dart';

class ImportCleaner {
  const ImportCleaner();

  Future<int> run(Args args) async {
    switch (args.path) {
      case ['fix', ...final files]:
        return FixCommand(args: args).run(files);
    }

    return 0;
  }
}
