// Uses type alias in constructor call (e.g. SegmentTabController() not TabController).
// Should import HeroOfTime from user_type_alias, NOT User from user.dart.
import 'package:_extensions/ext/user_type_alias.dart';

void main() {
  // ignore: unused_local_variable
  final hero = HeroOfTime();
}
