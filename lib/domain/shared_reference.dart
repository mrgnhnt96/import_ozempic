import 'package:analyzer/dart/element/element.dart';
import 'package:import_ozempic/domain/barrel_import_cache.dart';
import 'package:import_ozempic/domain/import.dart';
import 'package:import_ozempic/domain/import_style.dart';
import 'package:import_ozempic/domain/reference.dart';

mixin SharedReference {
  LibraryElement get lib;
  String? get prefix;
  bool get optional;
  Element? get associatedElement;
  bool get hide;
  Import get import;

  String? get hideCombinator {
    if (!hide) return null;

    if (associatedElement case Element(:final displayName)) {
      return 'hide $displayName';
    }

    return null;
  }

  String? showCombinator({bool includeIgnores = false}) {
    if (associatedElement case Element(
      :final displayName,
      metadata: Metadata(:final annotations),
    )) {
      final ignores = <String>{};
      if (includeIgnores) {
        for (final annotation in annotations) {
          if (annotation.isDeprecated) {
            ignores.add('deprecated_member_use');
          }
        }
      }

      if (ignores.isNotEmpty) {
        return [
          'show',
          '// ignore: ${ignores.join(', ')}',
          '$displayName',
        ].join('\n');
      }

      return 'show $displayName';
    }

    return null;
  }

  /// [includeIgnores] will add any ignore comments to above any `show` combinator
  String? importStatement(
    String path, {
    bool includeIgnores = false,
    ImportStyle style = ImportStyle.granular,
    BarrelImportCache barrelCache = const BarrelImportCache.empty(),
  }) {
    if (optional) {
      return null;
    }

    var import = this.import.resolved(path);
    if (import == null) {
      return null;
    }

    var usesBarrel = false;
    if (style == ImportStyle.barrel && Import(import).isPackage) {
      final barrel = barrelCache.resolve(import, associatedElement);
      if (barrel != null) {
        import = barrel;
        usesBarrel = true;
      }
    }

    final show = usesBarrel
        ? null
        : showCombinator(includeIgnores: includeIgnores);

    final statement = [
      'import',
      "'$import'",
      if (prefix case final String prefix) 'as $prefix',
      if (show case final String combinator) combinator,
    ].join(' ').trim();

    return '$statement;';
  }

  /// Resolves the import URI used for grouping and writing import statements.
  String? resolvedImportUri(
    String path, {
    ImportStyle style = ImportStyle.granular,
    BarrelImportCache barrelCache = const BarrelImportCache.empty(),
  }) {
    final import = this.import.resolved(path);
    if (import == null) {
      return null;
    }

    return switch (style) {
      ImportStyle.granular => import,
      ImportStyle.barrel =>
        barrelCache.resolve(import, associatedElement) ?? import,
    };
  }

  List<String>? get ignores;

  bool canJoin(Reference other) {
    // prefixes cannot be joined if they are:
    // - different
    // - one is null and the other is not
    return switch ((prefix, other.prefix)) {
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
