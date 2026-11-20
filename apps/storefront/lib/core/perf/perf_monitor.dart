import 'dart:async';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'frame_bursts.dart';

/// Whether the hidden frame-timing overlay is on. main.dart sets it from
/// `?perf` once at startup, so it lasts the session even though in-app
/// navigation drops the query (like `?semantics`). Off by default.
final perfModeProvider = Provider<bool>((ref) => false);

/// Feeds real frames into a [FrameBurstRecorder] and tells the overlay
/// when to repaint, without making the overlay itself look like app frames.
class PerfMonitor extends ChangeNotifier {
  PerfMonitor({SchedulerBinding? binding})
    : _binding = binding ?? SchedulerBinding.instance {
    _binding.addPersistentFrameCallback(_onFrame);
    _binding.addTimingsCallback(_onTimings);
  }

  final SchedulerBinding _binding;
  final recorder = FrameBurstRecorder();

  /// Whether the renderer reported any `FrameTiming` (it does on the web).
  bool timingsSeen = false;

  static const _liveEvery = Duration(milliseconds: 500);

  bool _active = true;
  Timer? _idle;
  Duration? _lastLive;
  bool _livePending = false;

  /// Set when an idle repaint of the overlay itself scheduled the next
  /// frame; that frame is not the page's and is not recorded.
  final _selfFrame = Stopwatch();

  /// Running for a moment after the overlay's own buttons are used, so
  /// their press feedback is not recorded as a burst.
  final _muted = Stopwatch();
  static const _muteFor = Duration(milliseconds: 400);

  void _onFrame(Duration _) {
    // Persistent callbacks cannot be removed; this one just goes quiet.
    if (!_active) return;
    if (_muted.isRunning) {
      if (_muted.elapsed < _muteFor) return;
      _muted.stop();
    }
    if (_selfFrame.isRunning) {
      final ours = _selfFrame.elapsedMilliseconds < 200;
      _selfFrame
        ..stop()
        ..reset();
      if (ours && !recorder.isRunning) return;
    }
    final t = _binding.currentSystemFrameTimeStamp;
    if (recorder.addFrame(t) != null) _repaint();
    _idle?.cancel();
    _idle = Timer(recorder.idleGap, _onIdle);
    // Live numbers ride on frames the page draws anyway; never more often.
    final last = _lastLive;
    if (!_livePending && (last == null || t - last >= _liveEvery)) {
      _lastLive = t;
      _livePending = true;
      _binding.addPostFrameCallback((_) {
        _livePending = false;
        if (_active) notifyListeners();
      });
    }
  }

  void _onIdle() {
    if (!_active) return;
    recorder.close();
    _lastLive = null;
    _repaint();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_active) return;
    timingsSeen = true;
    var matched = false;
    for (final t in timings) {
      matched |= recorder.addTiming(
        vsync: Duration(
          microseconds: t.timestampInMicroseconds(FramePhase.vsyncStart),
        ),
        build: t.buildDuration,
        raster: t.rasterDuration,
      );
    }
    // The tail of a burst is reported after the burst ended.
    if (matched && !recorder.isRunning) _repaint();
  }

  /// Repaints the overlay while the page is idle, marking the frame that
  /// this causes as ours.
  void _repaint() {
    if (!_active) return;
    if (hasListeners && !_binding.hasScheduledFrame) {
      _selfFrame
        ..reset()
        ..start();
    }
    notifyListeners();
  }

  /// Stops recording briefly while the overlay's own button reacts.
  void muteOwnTap() {
    _muted
      ..reset()
      ..start();
  }

  void reset() {
    muteOwnTap();
    recorder.reset();
    _idle?.cancel();
    _lastLive = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _active = false;
    _idle?.cancel();
    _binding.removeTimingsCallback(_onTimings);
    super.dispose();
  }
}
