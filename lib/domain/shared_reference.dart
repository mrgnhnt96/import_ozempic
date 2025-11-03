import 'package:analyzer/dart/element/element.dart';
import 'package:import_ozempic/commands/fix_command.dart';
import 'package:import_ozempic/domain/reference.dart';

mixin SharedReference {
  LibraryElement get lib;
  String? get prefix;
  bool get optional;
  Element? get associatedElement;
  bool get hide;
  bool get show;
  Import get import;

  String? get hideCombinator {
    if (!hide) return null;

    if (associatedElement case Element(:final displayName)) {
      return 'hide $displayName';
    }

    return null;
  }

  String? get showCombinator {
    if (!show) return null;

    if (associatedElement case Element(:final displayName)) {
      return 'show $displayName';
    }

    return null;
  }

  String? importStatement(String path) {
    if (optional) {
      return null;
    }

    final import = this.import.resolved(path);
    if (import == null) {
      return null;
    }

    final statement = [
      'import',
      "'$import'",
      if (hideCombinator case final String combinator) combinator,
      if (showCombinator case final String combinator) combinator,
      if (prefix case final String prefix) 'as $prefix',
    ].join(' ').trim();

    return '$statement;';
  }

  bool canJoin(Reference other) {
    // prefixes cannot be joined if they are:
    // - different
    // - one is null and the other is not
    final canMergePrefix = switch ((prefix, other.prefix)) {
      (null, null) => true,
      (null, String()) || (String(), null) => switch ((
        associatedElement,
        other.associatedElement,
      )) {
        // If one is an import statement, then we can join them
        (PrefixElement(), _) || (PrefixElement(), _) => true,
        _ => false,
      },
      (final String p1, final String p2) => p1 == p2,
    };

    if (!canMergePrefix) {
      return false;
    }

    final canMergeShow = switch ((show, other.show)) {
      (true, true) => true,
      (false, false) => true,
      _ => false,
    };

    if (!canMergeShow) {
      return false;
    }

    return true;
  }

  @override
  int get hashCode =>
      Object.hash(lib, associatedElement, prefix, optional, hide);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reference &&
          lib == other.lib &&
          associatedElement == other.associatedElement &&
          prefix == other.prefix &&
          optional == other.optional &&
          hide == other.hide;
}
