import 'package:import_ozempic/domain/args.dart';
import 'package:scoped_deps/scoped_deps.dart';

final argsProvider = create<Args>(Args.new);

Args get args => read(argsProvider);
