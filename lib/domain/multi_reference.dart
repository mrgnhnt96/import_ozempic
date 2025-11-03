import 'package:analyzer/dart/element/element.dart';
import 'package:import_ozempic/commands/fix_command.dart';
import 'package:import_ozempic/domain/reference.dart';
import 'package:import_ozempic/domain/shared_reference.dart';

class MultiReference with SharedReference implements Reference {
  MultiReference({required this.references});

  final List<Reference> references;

  @override
  Element? get associatedElement => null;

  @override
  bool canInclude(ResolvedImport import) {
    return references.any((ref) => ref.canInclude(import));
  }

  @override
  bool get hide => references.any((ref) => ref.hide);

  @override
  bool get show => references.any((ref) => ref.show);

  String? get hideCombinator {
    if (!hide) return null;

    final names = {
      for (final ref in references)
        if (ref case Reference(
          hide: true,
          associatedElement: Element(:final displayName),
        ))
          displayName,
    }.join(', ');

    if (names.isEmpty) return null;

    return 'hide $names';
  }

  String? get showCombinator {
    if (!show) return null;

    final names = {
      for (final ref in references)
        if (ref case Reference(
          show: true,
          associatedElement: Element(:final displayName),
        ))
          displayName,
    }.join(', ');

    if (names.isEmpty) return null;

    return 'show $names';
  }

  @override
  Import get import {
    final og = references.first.import;
    if (references.every((ref) => ref.import.resolved('') == og.resolved(''))) {
      return og;
    }

    throw Exception('MultiReference cannot have multiple imports');
  }

  @override
  Reference join(Reference ref) {
    if (!canJoin(ref)) {
      throw Exception('Reference ($this) cannot be joined with ($ref)');
    }

    return MultiReference(references: [...references, ref]);
  }

  @override
  LibraryElement get lib {
    final lib = references.first.lib;
    final og = lib.uri.toString();

    if (references.every((ref) => ref.lib.uri.toString() == og)) {
      return lib;
    }

    throw Exception('MultiReference cannot have multiple libraries');
  }

  @override
  bool get optional {
    if (references.every((ref) => ref.optional)) {
      return true;
    }

    return false;
  }

  @override
  String? get prefix {
    if (references.every((ref) => ref.prefix == null)) {
      return null;
    }

    final prefix = references.firstWhere((r) => r.prefix != null).prefix;

    if (references.every(
      (ref) => switch (ref.prefix) {
        null => true,
        final p when p == prefix => true,
        _ => false,
      },
    )) {
      return prefix;
    }

    throw Exception('MultiReference cannot have multiple prefixes');
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

  @override
  String toString() {
    return [
      if (hide)
        if (optional) '(hide?)' else '(hide)',
      '${lib.uri.toString()}',
      if (prefix case final String prefix) 'as $prefix',
    ].join(', ');
  }
}
