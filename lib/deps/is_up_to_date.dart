import 'package:import_ozempic/domain/is_up_to_date.dart';
import 'package:scoped_deps/scoped_deps.dart';

final isUpToDateProvider = create<IsUpToDate>(IsUpToDate.new);

IsUpToDate get isUpToDate => read(isUpToDateProvider);
