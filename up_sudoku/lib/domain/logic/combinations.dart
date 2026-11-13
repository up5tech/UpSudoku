/// Combination helper shared by the subset and fish techniques.
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

/// Every k-element combination of [items], in lexicographic order.
List<List<int>> combinations(List<int> items, int k) {
  final result = <List<int>>[];
  if (k <= 0 || k > items.length) return result;

  void walk(int start, List<int> current) {
    if (current.length == k) {
      result.add(List<int>.of(current));
      return;
    }
    for (var i = start; i < items.length; i++) {
      current.add(items[i]);
      walk(i + 1, current);
      current.removeLast();
    }
  }

  walk(0, <int>[]);
  return result;
}
