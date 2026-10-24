import 'package:core/core.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'anim_step.dart';

/// Lifecycle events of a sequence run (P1-G01).
enum AnimEvent { started, completed, cancelled, skipped }

/// A resolved step with its share of the total duration.
class PlannedStep {
  const PlannedStep(this.key, this.step, this.params, this.share);

  final String key;
  final AnimStep step;
  final Map<String, Object?> params;
  final double share;
}

/// Total duration of a sequence: the sum of each step's `durationMs`
/// param, or [fallback] when the definition gives none.
Duration sequenceDuration(StepSequence sequence, Duration fallback) {
  final ms = sequence.steps.fold<num>(
    0,
    (a, s) => a + ((s.params['durationMs'] as num?) ?? 0),
  );
  return ms > 0 ? Duration(milliseconds: ms.round()) : fallback;
}

/// Plans which steps run and for how long. Reduced motion keeps only the
/// listed steps and caps the total (ANIMATIONS.md 7: Swap then FlyToCart,
/// ≤ 600ms). Unregistered steps are skipped, never fatal (ARC-05).
({List<PlannedStep> steps, Duration total}) planSequence({
  required StepSequence sequence,
  required Map<String, AnimStep> registry,
  required Duration total,
  required bool reduceMotion,
  Set<String> reducedSteps = const {'Swap', 'FlyToCart'},
  Duration reducedMax = const Duration(milliseconds: 600),
}) {
  final specs = [
    for (final s in sequence.steps)
      if (registry.containsKey(s.step) &&
          (!reduceMotion || reducedSteps.contains(s.step)))
        s,
  ];
  final weight = specs.fold<double>(0, (a, s) => a + s.weight);
  final steps = [
    for (final s in specs)
      PlannedStep(
        s.step,
        registry[s.step]!,
        s.params,
        weight == 0 ? 0 : s.weight / weight,
      ),
  ];
  return (
    steps: steps,
    total: reduceMotion && total > reducedMax ? reducedMax : total,
  );
}

/// Plays planned steps in order as one overlay, driven by a single ticker.
/// Tapping skips to a short final step. Disposing cancels cleanly; the cart
/// item was committed before this started, so nothing here can lose or
/// duplicate it (ARC-07, AC-17, AC-30).
class StepRunner extends StatefulWidget {
  const StepRunner({
    super.key,
    required this.steps,
    required this.total,
    required this.input,
    this.skipDuration = const Duration(milliseconds: 300),
    this.onEvent,
  });

  final List<PlannedStep> steps;
  final Duration total;
  final AnimStepInput input;
  final Duration skipDuration;
  final ValueChanged<AnimEvent>? onEvent;

  @override
  State<StepRunner> createState() => _StepRunnerState();
}

class _StepRunnerState extends State<StepRunner>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  bool _done = false;

  /// After a skip: the last step plays alone from this moment.
  Duration? _skipAt;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    widget.onEvent?.call(AnimEvent.started);
  }

  void _tick(Duration elapsed) {
    setState(() => _elapsed = elapsed);
    final end = _skipAt == null ? widget.total : _skipAt! + widget.skipDuration;
    if (!_done && elapsed >= end) {
      _done = true;
      _ticker.stop();
      widget.onEvent?.call(AnimEvent.completed);
    }
  }

  void _skip() {
    if (_skipAt != null || _done || widget.steps.isEmpty) return;
    _skipAt = _elapsed;
    widget.onEvent?.call(AnimEvent.skipped);
  }

  @override
  void dispose() {
    if (!_done) widget.onEvent?.call(AnimEvent.cancelled);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();
    var step = widget.steps.last;
    var t = 1.0;
    var stepElapsed = Duration.zero;
    if (_skipAt != null) {
      final local = _elapsed - _skipAt!;
      t = (local.inMicroseconds / widget.skipDuration.inMicroseconds).clamp(
        0.0,
        1.0,
      );
      stepElapsed = local;
    } else {
      final total = widget.total.inMicroseconds;
      final now = _elapsed.inMicroseconds.clamp(0, total);
      var start = 0;
      for (final s in widget.steps) {
        final len = (s.share * total).round();
        if (now < start + len || identical(s, widget.steps.last)) {
          step = s;
          t = len == 0 ? 1 : ((now - start) / len).clamp(0.0, 1.0);
          stepElapsed = Duration(microseconds: now - start);
          break;
        }
        start += len;
      }
    }
    final input = AnimStepInput(
      product: widget.input.product,
      productRect: widget.input.productRect,
      cartTarget: widget.input.cartTarget,
      params: step.params,
      images: widget.input.images,
      reduceMotion: widget.input.reduceMotion,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: step.step.build(
        context,
        AnimFrame(t: t, elapsed: stepElapsed),
        input,
      ),
    );
  }
}
