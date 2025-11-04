import 'package:analyzer/dart/element/element.dart';
import 'package:import_ozempic/domain/import.dart';
import 'package:import_ozempic/domain/multi_reference.dart';
import 'package:import_ozempic/domain/resolved_references.dart';
import 'package:import_ozempic/domain/shared_reference.dart';

class Reference with SharedReference {
  const Reference({
    required this.lib,
    required Element this.associatedElement,
    this.prefix,
  }) : optional = false,
       hide = false;

  const Reference.optional({
    required this.lib,
    this.prefix,
    this.hide = false,
    this.associatedElement,
  }) : optional = true;

  final LibraryElement lib;
  final String? prefix;
  final bool optional;
  final Element? associatedElement;

  /// Whether to hide the reference from the import statement
  final bool hide;

  bool canInclude(ResolvedReferences import) {
    if (associatedElement case Element(:final displayName)) {
      if (displayName.startsWith('_')) {
        return false;
      }
    }

    if (lib.isDartCore) {
      return false;
    }

    if (import.path == lib.firstFragment.source.fullName) {
      return false;
    }

    return true;
  }

  Import get import => Import(lib.uri.toString());

  @override
  String toString() {
    return [
      '$associatedElement',
      if (hide)
        if (optional) '(hide?)' else '(hide)',
      '${lib.uri.toString()}',
      if (prefix case final String prefix) 'as $prefix',
    ].join(', ');
  }

  Reference join(Reference ref) {
    if (!canJoin(ref)) {
      throw Exception('Reference ($this) cannot be joined with ($ref)');
    }

    return MultiReference(references: [this, ref]);
  }

  @override
  List<String>? get ignores {
    final element = associatedElement;
    if (element case null) return null;

    final ignores = <String>{};

    if (element.metadata.annotations.any(
      (annotation) => annotation.isDeprecated,
    )) {
      ignores.add('deprecated_member_use');
    }

    return ignores.toList();
  }
}
