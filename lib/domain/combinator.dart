class Combinator implements Comparable<Combinator> {
  const Combinator({required this.ignore, required this.show});

  final String? ignore;
  final String show;

  @override
  String toString() {
    return [if (ignore != null) ignore!, show].join('\n');
  }

  @override
  int compareTo(Combinator other) {
    return show.compareTo(other.show);
  }

  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Combinator && ignore == other.ignore && show == other.show;

  @override
  int get hashCode => ignore.hashCode ^ show.hashCode;
}
