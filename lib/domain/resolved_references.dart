import 'package:import_ozempic/domain/import.dart';
import 'package:import_ozempic/domain/reference.dart';
import 'package:import_ozempic/domain/resolved_import.dart';

class ResolvedReferences {
  ResolvedReferences({
    this.path,
    List<String>? parts,
    List<Reference>? references,
  }) : parts = {...?parts},
       references = {...?references};

  String? path;
  final Set<String> parts;
  final Set<Reference> references;

  bool get hasImports => references.isNotEmpty;

  ({
    List<ResolvedImport> dart,
    List<ResolvedImport> relative,
    List<ResolvedImport> package,
  })
  imports({bool trailComments = true}) {
    final path = this.path;

    if (path == null) {
      throw Exception('Path is missing, cannot resolve imports');
    }

    final imports = <String, Reference>{};

    for (final ref in references) {
      final import = ref.import.resolved(path);
      if (import == null) {
        continue;
      }

      final key = switch (ref) {
        Reference(prefix: null) => import,
        Reference(:final String prefix) => '$import as $prefix',
      };

      if (imports.remove(key) case final Reference existing) {
        if (existing.canJoin(ref)) {
          imports[key] = existing.join(ref);
        } else {
          final existingKey = switch (existing) {
            Reference(prefix: null) => import,
            Reference(:final String prefix) => '$import as $prefix',
          };

          if (existingKey == key) {
            throw Exception('Unexpected duplicate import: $key');
          }

          imports[existingKey] = existing;
          imports[key] = ref;
        }
        continue;
      }

      imports[key] = ref;
    }

    final dart = <ResolvedImport>{};
    final relative = <ResolvedImport>{};
    final package = <ResolvedImport>{};

    for (final ref in imports.values) {
      final resolved = ref.importStatement(
        path,
        includeIgnores: !trailComments,
      );
      if (resolved == null) continue;

      void addTo(Set<ResolvedImport> set) {
        set.add(
          ResolvedImport(
            import: resolved,
            trailComments: trailComments,
            ignoreComments: ref.ignores,
          ),
        );
      }

      switch (ref.import) {
        case Import(isDart: true):
          addTo(dart);
        case Import(isRelative: true):
          addTo(relative);
        case Import(isPackage: true):
          addTo(package);
      }
    }

    return (
      dart: dart.toList()..sort(),
      relative: relative.toList()..sort(),
      package: package.toList()..sort(),
    );
  }

  void add(Reference reference) {
    if (reference.canInclude(this)) {
      references.add(reference);
    }
  }

  void addAll(Iterable<Reference> references) {
    references.forEach(add);
  }
}
