import 'package:_extensions/domain/bloc.dart';
import 'package:_extensions/domain/context.dart';
import 'package:_extensions/ext/context_x.dart';

void main() {
  final context = Context();

  context.read<Bloc>().events.init();
}
