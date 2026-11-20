import 'new_order_sound.dart';

/// Off the web (tests, VM) there is no audio: both players are silent.
AlertPlayer chimePlayer(String url) => const _SilentPlayer();

AlertPlayer tonePlayer() => const _SilentPlayer();

class _SilentPlayer implements AlertPlayer {
  const _SilentPlayer();

  @override
  void prime() {}

  @override
  Future<void> play() async {}
}
