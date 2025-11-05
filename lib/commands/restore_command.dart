import 'package:import_ozempic/deps/find.dart';
import 'package:import_ozempic/deps/fs.dart';
import 'package:import_ozempic/deps/log.dart';
import 'package:import_ozempic/domain/analysis_options.dart';
import 'package:import_ozempic/domain/args.dart';

const _usage = '''
Usage: import_ozempic restore

Restores the analysis options files to their original location.

analysis_options.yaml.tmp files will be restored to their original location.

Flags:
  --help     Print this help message
''';

class RestoreCommand {
  const RestoreCommand({required this.args});

  final Args args;

  Future<int> run() async {
    if (args['help'] case true) {
      log(_usage);
      return 0;
    }

    final tmpOptions = await find.file(
      AnalysisOptions.temporaryName,
      workingDirectory: fs.currentDirectory.path,
    );

    for (final option in tmpOptions) {
      AnalysisOptions(path: option).restore();
    }

    return 0;
  }
}
