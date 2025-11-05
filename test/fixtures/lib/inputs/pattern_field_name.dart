import 'package:_extensions/domain/user.dart';
import 'package:_extensions/ext/user_x.dart';

void main() {
  final user = User();

  final User(:name) = user;

  print(name);
}
