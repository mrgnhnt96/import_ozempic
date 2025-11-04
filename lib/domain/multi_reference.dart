import 'package:analyzer/dart/element/element.dart';
import 'package:import_ozempic/domain/combinator.dart';
import 'package:import_ozempic/domain/import.dart';
import 'package:import_ozempic/domain/reference.dart';
import 'package:import_ozempic/domain/resolved_references.dart';
import 'package:import_ozempic/domain/shared_reference.dart';

class MultiReference with SharedReference implements Reference {
  MultiReference({required this.references});

  final List<Reference> references;

  @override
  Element? get associatedElement => null;

  @override
  bool canInclude(ResolvedReferences import) {
    return references.any((ref) => ref.canInclude(import));
  }

  @override
  bool get hide => references.any((ref) => ref.hide);

  @override
  String? get hideCombinator {
    if (!hide) return null;

    final names = {
      for (final ref in references)
        if (ref case Reference(
          hide: true,
          associatedElement: Element(:final displayName),
        ))
          if (displayName.trim() case final String name when name.isNotEmpty)
            name,
    };

    if (names.isEmpty) return null;

    final sorted = names.toList()..sort();
    final joined = sorted.join(', ');

    return 'hide $joined';
  }

  Combinator? _showCombinator(Reference ref, {bool includeIgnores = false}) {
    final combinator = ref.showCombinator(includeIgnores: includeIgnores);
    if (combinator == null) return null;

    final parts = combinator.split('\n');
    if (parts case [final show]) {
      return Combinator(
        ignore: null,
        show: show.replaceFirst(RegExp(r'^show\s+'), '').trim(),
      );
    }

    final [ignore, show] = parts;

    return Combinator(ignore: ignore, show: show.replaceAll('show', '').trim());
  }

  @override
  String? showCombinator({bool includeIgnores = false}) {
    final names = {
      for (final ref in references)
        if (_showCombinator(ref, includeIgnores: includeIgnores)
            case final Combinator combinator)
          combinator,
    };

    if (names.isEmpty) return null;

    final sorted = names.toList()..sort();
    final joined = sorted.join(', ');

    return 'show $joined';
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
    String? p;

    for (final Reference(:prefix) in references) {
      if (prefix == null) continue;

      p ??= prefix;

      if (p != prefix) {
        throw Exception('MultiReference cannot have multiple prefixes');
      }
    }

    return p;
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
          hide == other.hide &&
          ignores == other.ignores;

  @override
  String toString() {
    if (importStatement('') case final String import) {
      return import;
    }

    return '~~$import~~';
  }

  @override
  List<String>? get ignores {
    final ignores = <String>{};

    for (final ref in references) {
      final element = ref.associatedElement;
      if (element case null) continue;

      if (element.metadata.annotations.any(
        (annotation) => annotation.isDeprecated,
      )) {
        ignores.add('deprecated_member_use');
      }
    }

    return ignores.toList();
  }
}
