import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:import_ozempic/domain/barrel_import.dart';
import 'package:import_ozempic/domain/reference.dart';
import 'package:meta/meta.dart';
import 'package:package_config/package_config.dart';

typedef _LookupKey = (String packageUri, String elementName);

/// Resolves granular package imports to barrel exports that re-export the
/// referenced element.
class BarrelImportCache {
  const BarrelImportCache._(this._lookup);

  const BarrelImportCache.empty() : _lookup = const {};

  @visibleForTesting
  const BarrelImportCache({Map<(String packageUri, String elementName), String>? lookup})
    : _lookup = lookup ?? const {};

  final Map<_LookupKey, String> _lookup;

  String? resolve(String packageUri, Element? element) {
    if (element case Element(:final displayName)) {
      if (displayName.isEmpty || displayName.startsWith('_')) {
        return null;
      }

      return _lookup[(packageUri, displayName)];
    }

    return null;
  }

  static Future<BarrelImportCache> build({
    required Iterable<Reference> references,
    required PackageConfig? packageConfig,
    required AnalysisSession session,
  }) async {
    if (packageConfig == null) {
      return const BarrelImportCache.empty();
    }

    final lookup = <_LookupKey, String>{};
    final elements = <_LookupKey, Element>{};
    final exportChecks = <String, Future<LibraryElement?>>{};

    Future<LibraryElement?> libraryFor(String uri) {
      return exportChecks.putIfAbsent(uri, () async {
        final result = await session.getLibraryByUri(uri);
        return switch (result) {
          LibraryElementResult(:final element) => element,
          _ => null,
        };
      });
    }

    for (final ref in references) {
      if (ref.optional) {
        continue;
      }

      final packageUri = ref.lib.uri.toString();
      if (!packageUri.startsWith('package:')) {
        continue;
      }

      final element = ref.associatedElement;
      if (element case null) {
        continue;
      }

      final name = element.displayName;
      if (name.isEmpty || name.startsWith('_')) {
        continue;
      }

      final key = (packageUri, name);
      if (lookup.containsKey(key)) {
        continue;
      }

      for (final candidate in BarrelImport.candidates(packageUri, packageConfig)) {
        final barrel = await libraryFor(candidate);
        if (barrel != null && exportsElement(barrel, element, name)) {
          lookup[key] = candidate;
          elements[key] = element;
          break;
        }
      }
    }

    await _consolidatePackageBarrels(
      lookup: lookup,
      elements: elements,
      packageConfig: packageConfig,
      libraryFor: libraryFor,
    );

    await _preferCrossPackageBarrels(
      lookup: lookup,
      elements: elements,
      libraryFor: libraryFor,
    );

    return BarrelImportCache._(lookup);
  }

  /// Collapses multiple barrels from the same package into one when a single
  /// barrel re-exports every referenced element.
  static Future<void> _consolidatePackageBarrels({
    required Map<_LookupKey, String> lookup,
    required Map<_LookupKey, Element> elements,
    required PackageConfig packageConfig,
    required Future<LibraryElement?> Function(String uri) libraryFor,
  }) async {
    final byPackage = <String, Set<_LookupKey>>{};
    for (final key in lookup.keys) {
      byPackage.putIfAbsent(_packageName(key.$1), () => {}).add(key);
    }

    for (final keys in byPackage.values) {
      final barrelsUsed = keys.map((key) => lookup[key]).toSet();
      if (barrelsUsed.length <= 1) {
        continue;
      }

      final orderedCandidates = <String>[];
      for (final key in keys) {
        for (final candidate in BarrelImport.candidates(key.$1, packageConfig)) {
          if (!orderedCandidates.contains(candidate)) {
            orderedCandidates.add(candidate);
          }
        }
      }

      for (final candidate in orderedCandidates) {
        final barrel = await libraryFor(candidate);
        if (barrel == null) {
          continue;
        }

        final coversAll = keys.every(
          (key) => exportsElement(barrel, elements[key]!, key.$2),
        );

        if (coversAll) {
          for (final key in keys) {
            lookup[key] = candidate;
          }
          break;
        }
      }
    }
  }

  /// Reassigns symbols to barrels from other packages when those barrels
  /// already re-export the referenced element.
  static Future<void> _preferCrossPackageBarrels({
    required Map<_LookupKey, String> lookup,
    required Map<_LookupKey, Element> elements,
    required Future<LibraryElement?> Function(String uri) libraryFor,
  }) async {
    final barrels = lookup.values.toSet();

    for (final key in lookup.keys) {
      final element = elements[key]!;
      final name = key.$2;
      final assigned = lookup[key]!;
      final assignedPackage = _packageName(assigned);

      for (final barrelUri in barrels) {
        if (_packageName(barrelUri) == assignedPackage) {
          continue;
        }

        final barrel = await libraryFor(barrelUri);
        if (barrel != null && exportsElement(barrel, element, name)) {
          lookup[key] = barrelUri;
          break;
        }
      }
    }
  }

  static String _packageName(String packageUri) {
    return packageUri.substring('package:'.length).split('/').first;
  }

  /// Whether [barrel] re-exports [element] under [name].
  static bool exportsElement(
    LibraryElement barrel,
    Element element,
    String name,
  ) {
    final exported = barrel.exportNamespace.get2(name);
    if (exported == null) {
      return false;
    }

    return _isSameElement(exported, element);
  }

  static bool _isSameElement(Element exported, Element target) {
    if (exported == target) {
      return true;
    }

    if (exported.library != target.library) {
      return false;
    }

    return exported.displayName == target.displayName;
  }
}
