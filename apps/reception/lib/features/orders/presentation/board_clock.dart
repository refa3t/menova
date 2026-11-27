import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/order_timing.dart';

/// The wall clock the board reads; overridden in tests.
final boardNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The board's one periodic timer: every [OrderTiming.tick] it publishes the
/// current time, and only the widgets listening to it (the timer badges and
/// the late count) rebuild. Cards do not run timers of their own.
class BoardClock extends ValueNotifier<DateTime> {
  BoardClock({DateTime Function()? now, Duration every = OrderTiming.tick})
    : this._(now ?? DateTime.now, every);

  BoardClock._(this._now, Duration every) : super(_now()) {
    _timer = Timer.periodic(every, (_) => value = _now());
  }

  final DateTime Function() _now;
  late final Timer _timer;

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
