import 'dart:io';

import 'package:import_cleaner/commands/fix_command.dart';
import 'package:import_cleaner/deps/fs.dart';
import 'package:import_cleaner/domain/args.dart';
import 'package:scoped_deps/scoped_deps.dart';

void main(List<String> arguments) async {
  final args = Args.parse(arguments);

  exitCode = await runScoped(() => run(args), values: {fileSystem});
}

Future<int> run(Args args) async {
  switch (args.path) {
    case ['fix']:
      return FixCommand(args: args).run();
  }

  return 0;
}
