import 'package:import_ozempic/domain/import.dart';
import 'package:import_ozempic/domain/reference.dart';

class ResolvedReferences {
  ResolvedReferences() : parts = {}, references = {};

  String? path;
  final Set<String> parts;
  final Set<Reference> references;

  bool get hasImports => references.isNotEmpty;

  ({List<String> dart, List<String> relative, List<String> package})
  get imports {
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

    final dart = <String>{};
    final relative = <String>{};
    final package = <String>{};

    for (final ref in imports.values) {
      final resolved = ref.importStatement(path);
      if (resolved == null) continue;

      switch (ref.import) {
        case Import(isDart: true):
          dart.add(resolved);
        case Import(isRelative: true):
          relative.add(resolved);
        case Import(isPackage: true):
          package.add(resolved);
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
