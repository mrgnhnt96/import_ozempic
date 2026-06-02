import 'package:import_ozempic/deps/fs.dart';
import 'package:package_config/package_config.dart';

/// Resolves package imports to barrel export URIs.
class BarrelImport {
  const BarrelImport._();

  /// Returns `package:<name>/<name>.dart` for a package URI, or `null` if
  /// [packageUri] is not a package import.
  static String? uriFor(String packageUri) {
    if (!packageUri.startsWith('package:')) {
      return null;
    }

    final packageName = packageUri.substring('package:'.length).split('/').first;
    if (packageName.isEmpty) {
      return null;
    }

    return 'package:$packageName/$packageName.dart';
  }

  /// Returns the barrel URI when [packageUri] already points at the barrel.
  static bool isBarrel(String packageUri) {
    final conventional = uriFor(packageUri);
    return conventional == packageUri;
  }

  /// Ordered barrel candidates for [packageUri], limited to files that exist.
  static List<String> candidates(
    String packageUri,
    PackageConfig? packageConfig,
  ) {
    if (!packageUri.startsWith('package:') || packageConfig == null) {
      return const [];
    }

    final withoutPackage = packageUri.substring('package:'.length);
    final parts = withoutPackage.split('/');
    final packageName = parts.first;
    if (parts.length < 2) {
      return const [];
    }

    final package = packageConfig[packageName];
    if (package == null) {
      return const [];
    }

    final libPath = parts.sublist(1).join('/');
    final segments = libPath.replaceAll('.dart', '').split('/');
    final ordered = <String>[];

    void add(String uri) {
      if (uri != packageUri &&
          !ordered.contains(uri) &&
          exists(uri, packageConfig)) {
        ordered.add(uri);
      }
    }

    if (segments.length >= 2) {
      final parentSegment = segments[segments.length - 2];
      if (!_isSkippedSegment(parentSegment)) {
        add('package:$packageName/$parentSegment.dart');
      }
    }

    for (var i = segments.length - 3; i >= 0; i--) {
      final segment = segments[i];
      if (_isSkippedSegment(segment)) {
        continue;
      }

      add('package:$packageName/$segment.dart');
    }

    add('package:$packageName/$packageName.dart');

    final libDir = fs.directory(
      fs.path.join(package.root.toFilePath(), 'lib'),
    );

    if (libDir.existsSync()) {
      final siblings = <String>[];
      for (final entity in libDir.listSync()) {
        if (!entity.path.endsWith('.dart')) {
          continue;
        }

        siblings.add(
          'package:$packageName/${fs.path.basename(entity.path)}',
        );
      }

      siblings.sort();
      for (final uri in siblings) {
        add(uri);
      }
    }

    return ordered;
  }

  /// Whether [barrelUri] exists on disk according to [packageConfig].
  static bool exists(String barrelUri, PackageConfig packageConfig) {
    final withoutPackage = barrelUri.substring('package:'.length);
    final parts = withoutPackage.split('/');
    final packageName = parts.first;
    final package = packageConfig[packageName];
    if (package == null || parts.length < 2) {
      return false;
    }

    final relativePath = parts.sublist(1).join('/');
    final barrelPath = fs.path.join(
      package.root.toFilePath(),
      'lib',
      relativePath,
    );

    return fs.file(barrelPath).existsSync();
  }

  static bool _isSkippedSegment(String segment) {
    return segment == 'src' || segment.startsWith('_');
  }
}
