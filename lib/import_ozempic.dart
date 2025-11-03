import 'package:import_ozempic/commands/fix_command.dart';
import 'package:import_ozempic/domain/args.dart';

class ImportOzempic {
  const ImportOzempic();

  Future<int> run(Args args) async {
    switch (args.path) {
      case ['fix', ...final files]:
        return FixCommand(args: args).run(files);
    }

    return 0;
  }
}
