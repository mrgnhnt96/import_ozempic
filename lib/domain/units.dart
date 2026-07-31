import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';

class Units {
  Units({required AnalysisContext context, required String path})
    : _context = context,
      _path = path,
      _parsed = context.currentSession.getParsedUnit(path);

  final AnalysisContext _context;
  final String _path;
  final SomeParsedUnitResult _parsed;

  /// Lazily started so callers can filter with parse-only results first.
  Future<SomeResolvedUnitResult>? _resolvedFuture;

  ParsedUnitResult get parsed {
    if (_parsed case final ParsedUnitResult parsed) {
      return parsed;
    }

    throw UnimplementedError('No parsed unit found');
  }

  ResolvedUnitResult? __resolved;
  Future<ResolvedUnitResult> resolved() async {
    if (__resolved case final ResolvedUnitResult resolved) {
      return resolved;
    }

    _resolvedFuture ??= _context.currentSession.getResolvedUnit(_path);
    final result = await _resolvedFuture!;

    if (result is! ResolvedUnitResult) {
      throw ArgumentError('Could not resolve unit: $result');
    }

    return __resolved = result;
  }
}
