import 'dart:math';

/// Buckets keyed by deadline on-time percentage.
///
/// `noData` is used when there are no deadline-bearing completed tasks to
/// score from (we cannot earn any percentage, good or bad).
enum MotivationalBucket { noData, low, mid, high, top }

/// Map on-time % → bucket.
///
/// `pct` is on a 0..100 scale. `hasData` is false when there are no
/// completed-with-deadline tasks to score on (in which case the bucket is
/// always `noData` regardless of `pct`).
MotivationalBucket bucketForOnTime({
  required bool hasData,
  required int pct,
}) {
  if (!hasData) return MotivationalBucket.noData;
  if (pct < 40) return MotivationalBucket.low;
  if (pct < 70) return MotivationalBucket.mid;
  if (pct < 90) return MotivationalBucket.high;
  return MotivationalBucket.top;
}

const Map<MotivationalBucket, List<String>> motivationalPool = {
  MotivationalBucket.noData: [
    'Add a task and start your streak.',
    'A clear screen is a clean start.',
    'One task is enough to begin.',
    'Set a deadline — show up for it.',
  ],
  MotivationalBucket.low: [
    'Fresh start — one task at a time.',
    'Small wins compound. Try one today.',
    'Pick the easiest one and finish it.',
    'Progress beats perfection.',
  ],
  MotivationalBucket.mid: [
    'Steady work. Keep it moving.',
    'You\'re on the board — keep going.',
    'Halfway is a real place. Push on.',
    'Consistent beats clever.',
  ],
  MotivationalBucket.high: [
    'Strong week. Hold the line.',
    'You\'re close to clockwork.',
    'Most things, on time. Nice.',
    'Sharp follow-through.',
  ],
  MotivationalBucket.top: [
    'Crushing your deadlines.',
    'On-time, on-point.',
    'This is what reliable looks like.',
    'Untouchable week.',
  ],
};

/// Session-stable picker.
///
/// Picks one line per bucket the first time that bucket is requested, then
/// caches the choice for the lifetime of this process. New process = re-roll.
class MotivationalSession {
  MotivationalSession({Random? random}) : _random = random ?? Random();

  final Random _random;
  final Map<MotivationalBucket, String> _cache = {};

  String lineFor(MotivationalBucket bucket) {
    final cached = _cache[bucket];
    if (cached != null) return cached;
    final pool = motivationalPool[bucket]!;
    final pick = pool[_random.nextInt(pool.length)];
    _cache[bucket] = pick;
    return pick;
  }
}

/// Process-scoped instance. First access on Statistics rolls the line;
/// subsequent accesses within the same launch return the same line.
final MotivationalSession motivationalSession = MotivationalSession();
