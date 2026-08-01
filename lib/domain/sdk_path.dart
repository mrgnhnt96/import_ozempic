import 'dart:io';

import 'package:path/path.dart' as p;

const dartSdkEnv = 'DART_SDK';

/// Resolves the Dart SDK root even when [resolvedExecutable] is an AOT binary
/// rather than `dart` itself.
///
/// Prefer [dartSdkEnv] when set (the AOT launcher passes this through).
String resolveDartSdkPath({
  required String resolvedExecutable,
  required Map<String, String> environment,
  p.Context? pathContext,
  String? Function(String executable)? which,
}) {
  final path = pathContext ?? p.context;

  if (environment[dartSdkEnv] case final String sdk
      when sdk.isNotEmpty && _looksLikeSdk(sdk, path)) {
    return path.normalize(sdk);
  }

  final exeName = path.basename(resolvedExecutable).toLowerCase();
  if (exeName == 'dart' || exeName == 'dart.exe') {
    final sdk = path.normalize(
      path.dirname(path.dirname(resolvedExecutable)),
    );
    if (_looksLikeSdk(sdk, path)) {
      return sdk;
    }
  }

  final dartOnPath = (which ?? _whichSync).call('dart');
  if (dartOnPath != null) {
    final sdk = path.normalize(path.dirname(path.dirname(dartOnPath)));
    if (_looksLikeSdk(sdk, path)) {
      return sdk;
    }
  }

  throw StateError(
    'Could not locate the Dart SDK. '
    'Set the $dartSdkEnv environment variable to your SDK root.',
  );
}

bool _looksLikeSdk(String sdkPath, p.Context path) {
  final versionFile = path.join(sdkPath, 'version');
  return File(versionFile).existsSync();
}

String? _whichSync(String executable) {
  final command = Platform.isWindows ? 'where' : 'which';
  try {
    final result = Process.runSync(command, [executable]);
    if (result.exitCode != 0) {
      return null;
    }
    final stdout = (result.stdout as String).trim();
    if (stdout.isEmpty) {
      return null;
    }
    return stdout.split(RegExp(r'\r?\n')).first.trim();
  } catch (_) {
    return null;
  }
}
