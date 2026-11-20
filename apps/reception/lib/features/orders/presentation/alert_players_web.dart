import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'new_order_sound.dart';

AlertPlayer chimePlayer(String url) => _ChimeFilePlayer(url);

AlertPlayer tonePlayer() => _TonePlayer();

/// Plays the chime file through one `<audio>` element, reused so that the
/// unlock from the staff's tap carries over to later alerts.
class _ChimeFilePlayer implements AlertPlayer {
  _ChimeFilePlayer(this._url);

  final String _url;
  web.HTMLAudioElement? _audio;

  web.HTMLAudioElement get _element => _audio ??= web.HTMLAudioElement()
    ..preload = 'auto'
    ..src = _url;

  @override
  void prime() => _element;

  @override
  Future<void> play() async {
    final audio = _element;
    if (audio.error != null) throw StateError('chime failed to load');
    audio.currentTime = 0;
    await audio.play().toDart;
  }
}

/// The generated two-tone alert, kept as the fallback when the chime file
/// cannot load or play. One context, created in the staff's tap.
class _TonePlayer implements AlertPlayer {
  web.AudioContext? _ctx;

  @override
  void prime() {
    final ctx = _ctx ??= web.AudioContext();
    if (ctx.state == 'suspended') ctx.resume().toDart.ignore();
  }

  @override
  Future<void> play() async {
    final ctx = _ctx ??= web.AudioContext();
    if (ctx.state != 'running') await ctx.resume().toDart;
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
  }
}
