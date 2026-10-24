import 'package:flutter_test/flutter_test.dart';
import 'package:product_builder/product_builder.dart';

void main() {
  test('group delays respect the cap by compressing the stagger', () {
    final d = staggerDelays(
      count: 30,
      staggerMs: 35,
      jitterMs: 60,
      durMs: 380,
      capMs: 900,
      seed: 'corn#1',
    );
    final last = d.map((x) => x.inMilliseconds).reduce((a, b) => a > b ? a : b);
    expect(last + 380, lessThanOrEqualTo(900));
  });

  test('delays are deterministic per seed', () {
    List<int> run() => staggerDelays(
      count: 8,
      staggerMs: 35,
      jitterMs: 60,
      durMs: 380,
      capMs: 900,
      seed: 'olive#0',
    ).map((x) => x.inMilliseconds).toList();
    expect(run(), run());
  });

  test('ANIMATIONS.md profiles are registered', () {
    expect(
      enterProfiles.keys,
      containsAll(['drop', 'shower', 'sprinkle', 'float', 'toss']),
    );
    expect(exitProfiles.keys, containsAll(['liftFade', 'dissolve']));
  });
}
