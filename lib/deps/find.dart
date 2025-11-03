import 'package:import_ozempic/domain/find.dart';
import 'package:scoped_deps/scoped_deps.dart';

final findProvider = create<Find>(Find.new);

Find get find => read(findProvider);
