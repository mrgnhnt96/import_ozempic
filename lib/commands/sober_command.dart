import 'package:import_ozempic/commands/fix_command.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:import_ozempic/domain/import_style.dart';

const _usage = '''
Usage: import_ozempic sober <files...> [--config <path>]

Collapses granular package imports back to barrel exports
(`package:<name>/<name>.dart`) when the barrel file exists on disk.
Useful when updating dependencies—barrel exports stay stable even when
a package reorganizes its internal src paths.
Use `fix` for the inverse (granular source files with show combinators).
''';

class SoberCommand extends FixCommand {
  SoberCommand({required super.args}) : super(style: ImportStyle.barrel);

  @override
  Future<int> run(List<String> files) async {
    if (args['help'] case true) {
      log(_usage);
      return 0;
    }

    if (files.isEmpty) {
      log('No files were provided');
      log(_usage);
      return 1;
    }

    return super.run(files);
  }
}
