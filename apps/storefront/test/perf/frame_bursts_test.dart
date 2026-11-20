import 'package:flutter_test/flutter_test.dart';
import 'package:storefront/core/perf/frame_bursts.dart';

Duration ms(num v) => Duration(microseconds: (v * 1000).round());

/// Feeds frames at the given millisecond timestamps.
void feed(FrameBurstRecorder r, List<num> times) {
  for (final t in times) {
    r.addFrame(ms(t));
  }
}

void main() {
  test('frames close together form one burst with its statistics', () {
    final r = FrameBurstRecorder();
    // 10 intervals: eight of 16 ms, one of 20 ms, one of 50 ms.
    feed(r, [0, 16, 32, 48, 64, 80, 96, 112, 128, 148, 198]);
    expect(r.isRunning, isTrue);
    final b = r.close()!;
    expect(b.frames, 11);
    expect(b.intervalsMicros, hasLength(10));
    expect(b.durationMs, 198);
    expect(b.averageFps, closeTo(10 / 0.198, 1e-9));
    expect(b.p50Ms, 16);
    expect(b.p95Ms, 50);
    expect(b.maxMs, 50);
    expect(b.over17, 2);
    expect(b.over34, 1);
    expect(r.isRunning, isFalse);
    expect(r.bursts, hasLength(1));
  });

  test('a pause longer than the idle gap splits bursts, newest first', () {
    final r = FrameBurstRecorder();
    feed(r, [0, 16, 33]);
    // 600 ms of silence, then a second burst; exactly 500 ms still joins.
    final closed = r.addFrame(ms(633));
    expect(closed!.frames, 3);
    feed(r, [649, 1149, 1165]);
    r.close();
    final bursts = r.bursts;
    expect(bursts, hasLength(2));
    expect(bursts.first.frames, 4);
    expect(bursts.first.maxMs, 500);
    expect(bursts.last.frames, 3);
  });

  test('a lone frame is not a burst', () {
    final r = FrameBurstRecorder();
    r.addFrame(ms(0));
    expect(r.close(), isNull);
    r.addFrame(ms(1000));
    r.addFrame(ms(2000));
    expect(r.close(), isNull);
    expect(r.bursts, isEmpty);
  });

  test('percentile uses nearest rank', () {
    final values = [for (var i = 1; i <= 20; i++) i];
    expect(percentile(values, 50), 10);
    expect(percentile(values, 95), 19);
    expect(percentile(values, 100), 20);
    expect(percentile([7], 95), 7);
    expect(percentile(const [], 95), 0);
  });

  test('engine timings attach to the burst they fall in', () {
    final r = FrameBurstRecorder();
    feed(r, [1000, 1016, 1032]);
    r.close();
    expect(r.addTiming(vsync: ms(1018), build: ms(4), raster: ms(9)), isTrue);
    expect(r.addTiming(vsync: ms(1033), build: ms(30), raster: ms(2)), isTrue);
    // An idle frame long after the burst belongs to none.
    expect(r.addTiming(vsync: ms(1600), build: ms(1), raster: ms(1)), isFalse);
    final b = r.bursts.single;
    expect(b.hasTimings, isTrue);
    expect(b.buildMaxMs, 30);
    expect(b.rasterMaxMs, 9);
  });

  test('live fps covers the latest frames and is null when idle', () {
    final r = FrameBurstRecorder();
    expect(r.liveFps(), isNull);
    feed(r, [for (var i = 0; i <= 60; i++) i * 20]);
    expect(r.liveFps(), closeTo(50, 1e-9));
    r.close();
    expect(r.liveFps(), isNull);
  });

  test('only the newest bursts are kept, and reset clears all', () {
    final r = FrameBurstRecorder(maxBursts: 2);
    for (var i = 0; i < 3; i++) {
      feed(r, [i * 1000, i * 1000 + 16]);
    }
    r.close();
    expect(r.bursts, hasLength(2));
    expect(r.bursts.last.startMicros, 1000 * 1000);
    r.reset();
    expect(r.bursts, isEmpty);
    expect(r.isRunning, isFalse);
  });
}
