class ResolvedImport implements Comparable<ResolvedImport> {
  const ResolvedImport({
    required this.import,
    required this.trailComments,
    this.ignoreComments,
  });

  final String import;
  final List<String>? ignoreComments;

  /// Whether the [ignoreComments] should be appended to the [import] statement.
  ///
  /// if `false`, the [ignoreComments] will be prepended with a line break
  final bool trailComments;

  @override
  String toString() {
    final comment = switch (ignoreComments) {
      null || [] => null,
      final comments => '// ignore: ${comments.join(', ')}',
    };

    if (trailComments && comment != null) {
      return '$import $comment';
    }

    return import;
  }

  @override
  int compareTo(ResolvedImport other) {
    return import.compareTo(other.import);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedImport &&
          import == other.import &&
          ignoreComments == other.ignoreComments &&
          trailComments == other.trailComments;

  @override
  int get hashCode =>
      import.hashCode ^ ignoreComments.hashCode ^ trailComments.hashCode;
}
