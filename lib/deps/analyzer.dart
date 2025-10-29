import 'package:import_cleaner/domain/analyzer.dart';
import 'package:scoped_deps/scoped_deps.dart';

final analyzerProvider = create<Analyzer>(Analyzer.new);

Analyzer get analyzer => read(analyzerProvider);
