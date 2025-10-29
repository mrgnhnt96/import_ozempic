import 'package:scoped_deps/scoped_deps.dart';

typedef Logger = void Function(Object?);

final logProvider = create<Logger>(() => print);

Logger get log => read(logProvider);
