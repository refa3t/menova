import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reception/features/orders/presentation/new_order_sound.dart';

class FakePlayer implements AlertPlayer {
  FakePlayer(this.name, this.log, {this.fails = false});

  final String name;
  final List<String> log;
  final bool fails;

  @override
  void prime() => log.add('$name.prime');

  @override
  Future<void> play() async {
    log.add('$name.play');
    if (fails) throw StateError('$name cannot play');
  }
}

void main() {
  late List<String> log;
  NewOrderSound sound({bool chimeFails = false, bool toneFails = false}) =>
      NewOrderSound(
        chime: FakePlayer('chime', log, fails: chimeFails),
        fallback: FakePlayer('tone', log, fails: toneFails),
      );

  setUp(() => log = []);

  test('plays the chime file and not the tone when the file plays', () async {
    await sound().play();
    expect(log, ['chime.play']);
  });

  test('falls back to the generated tone when the file fails', () async {
    await sound(chimeFails: true).play();
    expect(log, ['chime.play', 'tone.play']);
  });

  test('never throws when both fail', () async {
    await expectLater(
      sound(chimeFails: true, toneFails: true).play(),
      completes,
    );
    expect(log, ['chime.play', 'tone.play']);
  });

  test(
    'enabling primes both players and starts the chime inside the tap',
    () async {
      final done = sound().enable();
      // Synchronous part only: still within the browser's user gesture.
      expect(log, ['chime.prime', 'tone.prime', 'chime.play']);
      await done;
    },
  );

  test('the chime is bundled as a small MP3 under web/', () {
    final file = File('web/$newOrderChimeUrl');
    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    expect(bytes.length, lessThan(100 * 1024));
    final id3 = String.fromCharCodes(bytes.take(3)) == 'ID3';
    final frameSync = bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0;
    expect(id3 || frameSync, isTrue, reason: 'MP3 header');
  });
}
