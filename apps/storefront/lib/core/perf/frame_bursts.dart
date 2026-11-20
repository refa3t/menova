/// Pure frame-burst statistics for the hidden `?perf` overlay.
///
/// Frames that follow each other closely form a burst (an animation, a
/// scroll); a pause longer than [FrameBurstRecorder.idleGap] ends it. No
/// Flutter imports, so it can be unit tested with plain timestamps.
library;

/// One finished (or in-progress) burst of frames.
class BurstSummary {
  const BurstSummary({
    required this.startMicros,
    required this.endMicros,
    required this.frames,
    required this.intervalsMicros,
    this.buildMicros = const [],
    this.rasterMicros = const [],
  });

  /// Timestamp of the first and last frame (frame clock, microseconds).
  final int startMicros;
  final int endMicros;

  /// Number of frames in the burst.
  final int frames;

  /// Frame-to-frame intervals, in frame order (`frames - 1` of them).
  final List<int> intervalsMicros;

  /// Engine build and raster durations of the frames, when the renderer
  /// reports `FrameTiming` (it does on the web).
  final List<int> buildMicros;
  final List<int> rasterMicros;

  double get durationMs => (endMicros - startMicros) / 1000;

  /// Frames per second over the burst: intervals per elapsed second.
  double get averageFps => endMicros > startMicros
      ? intervalsMicros.length * 1e6 / (endMicros - startMicros)
      : 0;

  double get p50Ms => percentile(intervalsMicros, 50) / 1000;
  double get p95Ms => percentile(intervalsMicros, 95) / 1000;
  double get maxMs => percentile(intervalsMicros, 100) / 1000;

  /// Frames that came more than 17 ms (a missed 60 Hz frame) or more than
  /// 34 ms (visible stutter) after the previous one.
  int get over17 => intervalsMicros.where((i) => i > 17000).length;
  int get over34 => intervalsMicros.where((i) => i > 34000).length;

  bool get hasTimings => buildMicros.isNotEmpty;
  double get buildP95Ms => percentile(buildMicros, 95) / 1000;
  double get buildMaxMs => percentile(buildMicros, 100) / 1000;
  double get rasterP95Ms => percentile(rasterMicros, 95) / 1000;
  double get rasterMaxMs => percentile(rasterMicros, 100) / 1000;
}

/// Nearest-rank percentile ([p] in 0..100) of [values]; 0 when empty.
int percentile(List<int> values, double p) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final rank = (p / 100 * sorted.length).ceil();
  return sorted[(rank - 1).clamp(0, sorted.length - 1)];
}

class _Burst {
  _Burst(this.start) : last = start;

  final int start;
  int last;
  int frames = 1;
  final intervals = <int>[];
  final build = <int>[];
  final raster = <int>[];

  BurstSummary summary() => BurstSummary(
    startMicros: start,
    endMicros: last,
    frames: frames,
    intervalsMicros: List.unmodifiable(intervals),
    buildMicros: List.unmodifiable(build),
    rasterMicros: List.unmodifiable(raster),
  );
}

/// Groups frame timestamps into bursts and keeps their statistics.
class FrameBurstRecorder {
  FrameBurstRecorder({
    this.idleGap = const Duration(milliseconds: 500),
    this.maxBursts = 50,
  });

  /// A pause longer than this ends the current burst.
  final Duration idleGap;

  /// How many finished bursts are kept (oldest dropped first).
  final int maxBursts;

  /// Slack when matching a `FrameTiming` to a burst: the engine stamps its
  /// vsync a little after the frame timestamp.
  static const _matchSlackMicros = 20000;

  _Burst? _open;
  final _done = <_Burst>[];

  /// Records a frame produced at [timestamp]. Returns the burst that a long
  /// pause before this frame closed, if any.
  BurstSummary? addFrame(Duration timestamp) {
    final t = timestamp.inMicroseconds;
    final open = _open;
    if (open != null && t - open.last <= idleGap.inMicroseconds) {
      open.intervals.add(t - open.last);
      open.last = t;
      open.frames++;
      return null;
    }
    final closed = close();
    _open = _Burst(t);
    return closed;
  }

  /// Ends the current burst. Returns its summary, or null when there was
  /// none or it was a lone frame (no interval to measure).
  BurstSummary? close() {
    final open = _open;
    _open = null;
    if (open == null || open.frames < 2) return null;
    _done.add(open);
    if (_done.length > maxBursts) _done.removeAt(0);
    return open.summary();
  }

  /// Attaches one engine timing to the burst whose frames span [vsync].
  /// Returns false when no burst matches (an idle or ignored frame).
  bool addTiming({
    required Duration vsync,
    required Duration build,
    required Duration raster,
  }) {
    final v = vsync.inMicroseconds;
    for (final b in [?_open, ..._done.reversed]) {
      if (v >= b.start - _matchSlackMicros && v <= b.last + _matchSlackMicros) {
        b.build.add(build.inMicroseconds);
        b.raster.add(raster.inMicroseconds);
        return true;
      }
    }
    return false;
  }

  /// Whether a burst is in progress.
  bool get isRunning => _open != null;

  /// The burst in progress, if any.
  BurstSummary? get current => _open?.summary();

  /// Finished bursts, newest first.
  List<BurstSummary> get bursts => [
    for (final b in _done.reversed) b.summary(),
  ];

  /// Frame rate over the last [window] of the current burst; null when idle
  /// or too few frames.
  double? liveFps({Duration window = const Duration(milliseconds: 500)}) {
    final open = _open;
    if (open == null || open.intervals.isEmpty) return null;
    var spent = 0;
    var count = 0;
    for (final i in open.intervals.reversed) {
      spent += i;
      count++;
      if (spent >= window.inMicroseconds) break;
    }
    return count * 1e6 / spent;
  }

  void reset() {
    _open = null;
    _done.clear();
  }
}
