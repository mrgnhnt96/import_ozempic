// Uses type alias for static method call (e.g. DioMediaType.parse() not MediaType.parse()).
// Should import DioMediaType from media_type_alias, NOT MediaType from media_type.dart.
import 'package:_extensions/ext/media_type_alias.dart';

void main() {
  // ignore: unused_local_variable
  final x = DioMediaType.parse('text/plain');
}
