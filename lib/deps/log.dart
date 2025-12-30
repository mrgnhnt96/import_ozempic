import 'package:import_ozempic/deps/args.dart';
import 'package:mason_logger/mason_logger.dart' as m;
import 'package:scoped_deps/scoped_deps.dart';

final logProvider = create<Logger>(Logger.new);

Logger get log => read(logProvider);

class Logger {
  const Logger();

  void call(Object? message) {
    print(message);
  }

  void debug(Object? message) {
    if (args['loud'] case true) {
      print(m.darkGray.wrap('$message'));
    }
  }

  void debugError(Object? message) {
    debug(m.red.wrap('$message'));
  }

  void error(Object? message) {
    print(m.red.wrap('$message'));
  }

  void info(Object? message) {
    print(m.lightYellow.wrap('$message'));
  }
}
