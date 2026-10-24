import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Short two-tone alert generated in the browser. TEMP until the owner's
/// `sfx_new_order.mp3` (ASSETS.md 4.5) is delivered.
void playNewOrderSound() {
  try {
    final ctx = web.AudioContext();
    final now = ctx.currentTime;
    for (final (i, freq) in [880.0, 1175.0].indexed) {
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();
      osc.frequency.value = freq;
      final start = now + i * 0.18;
      gain.gain.setValueAtTime(0.0001, start);
      gain.gain.exponentialRampToValueAtTime(0.3, start + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.16);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(start);
      osc.stop(start + 0.17);
    }
    // Release the context once the tones finish.
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      ctx.close().toDart.ignore();
    });
  } on Object {
    // Sound is best effort; the card highlight still shows the new order.
  }
}
