import 'package:_extensions/domain/handle_type_arg.dart';

class Bloc {
  const Bloc();
}

extension BlocX on Bloc {
  _Events get events => const _Events();
}

class _Events {
  const _Events();

  void init() {}

  void handle({required HandleTypeArg value}) {}
}
