List<int> computeEffectiveTimes(List<int> orig, Map<int, int> anchors) {
  final n = orig.length;
  final idx = anchors.keys.where((i) => i >= 0 && i < n).toList()..sort();
  if (idx.isEmpty) return orig;

  int target(int i) => anchors[i]!;
  final firstShift = target(idx.first) - orig[idx.first];
  final lastShift = target(idx.last) - orig[idx.last];

  final out = List<int>.filled(n, 0);
  var k = 0;
  var prev = 0;
  for (var i = 0; i < n; i++) {
    int v;
    if (i <= idx.first) {
      v = orig[i] + firstShift;
    } else if (i >= idx.last) {
      v = orig[i] + lastShift;
    } else {
      while (idx[k + 1] <= i) {
        k++;
      }
      final a = idx[k], b = idx[k + 1];
      final span = orig[b] - orig[a];
      final ta = target(a), tb = target(b);
      v = span <= 0
          ? ta
          : ta + ((orig[i] - orig[a]) * (tb - ta) / span).round();
    }
    if (v < 0) v = 0;
    if (v < prev) v = prev;
    out[i] = v;
    prev = v;
  }
  return out;
}

int indexForTime(List<int> times, int ms) {
  var lo = 0, hi = times.length - 1, ans = -1;
  while (lo <= hi) {
    final mid = (lo + hi) ~/ 2;
    if (times[mid] <= ms) {
      ans = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return ans;
}