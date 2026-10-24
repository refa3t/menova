import 'dart:math';

import 'package:flutter/animation.dart';

import 'placement.dart';

/// How an ingredient's pieces enter when added (ANIMATIONS.md 2). Values are
/// proposals calibrated against the approved reference (AC-11, AC-12).
class EnterProfile {
  const EnterProfile({
    required this.fromYPct,
    required this.fromScale,
    required this.spinDeg,
    required this.curve,
    required this.durMs,
    required this.staggerMs,
    required this.jitterMs,
    required this.capMs,
    this.fadePortion = 0.35,
    this.swayPct = 0,
    this.arcPct = 0,
    this.spreadPct = 8,
  });

  /// Start offset above the final spot, as % of the product diameter.
  final double fromYPct;
  final double fromScale;

  /// Random start rotation within ±spinDeg, settling to the final angle.
  final double spinDeg;
  final Curve curve;
  final int durMs;
  final int staggerMs;
  final int jitterMs;

  /// Upper bound for the whole group; stagger is compressed to fit.
  final int capMs;

  /// Share of the duration spent fading in.
  final double fadePortion;

  /// Horizontal sine sway while falling (float), % of diameter.
  final double swayPct;

  /// Arc height of the path (toss), % of diameter.
  final double arcPct;

  /// Random horizontal start offset, % of diameter.
  final double spreadPct;
}

/// How pieces leave when removed (ANIMATIONS.md 3), last in first out.
class ExitProfile {
  const ExitProfile({
    required this.durMs,
    required this.staggerMs,
    required this.capMs,
    required this.toScale,
    this.liftPct = 0,
    this.spinDeg = 0,
    this.curve = Curves.easeIn,
  });

  final int durMs;
  final int staggerMs;
  final int capMs;
  final double toScale;
  final double liftPct;
  final double spinDeg;
  final Curve curve;
}

/// Registered enter profiles (extension point, ARC-08).
const enterProfiles = <String, EnterProfile>{
  'drop': EnterProfile(
    fromYPct: -18,
    fromScale: 1.25,
    spinDeg: 20,
    curve: Curves.easeOutBack,
    durMs: 380,
    staggerMs: 35,
    jitterMs: 60,
    capMs: 900,
  ),
  'shower': EnterProfile(
    fromYPct: -22,
    fromScale: 0.6,
    spinDeg: 10,
    curve: Curves.easeOut,
    durMs: 520,
    staggerMs: 18,
    jitterMs: 30,
    capMs: 800,
    fadePortion: 0.4,
    spreadPct: 12,
  ),
  'sprinkle': EnterProfile(
    fromYPct: -28,
    fromScale: 0.8,
    spinDeg: 90,
    curve: Curves.easeOutQuad,
    durMs: 650,
    staggerMs: 12,
    jitterMs: 20,
    capMs: 800,
    fadePortion: 0.25,
    spreadPct: 6,
  ),
  'float': EnterProfile(
    fromYPct: -20,
    fromScale: 0.8,
    spinDeg: 30,
    curve: Curves.easeInOutCubic,
    durMs: 700,
    staggerMs: 70,
    jitterMs: 40,
    capMs: 1000,
    fadePortion: 0.3,
    swayPct: 3,
  ),
  'toss': EnterProfile(
    fromYPct: -15,
    fromScale: 1.1,
    spinDeg: 45,
    curve: Curves.easeOutCubic,
    durMs: 480,
    staggerMs: 45,
    jitterMs: 40,
    capMs: 900,
    fadePortion: 0.3,
    arcPct: 8,
  ),
};

/// Registered exit profiles (extension point, ARC-08).
const exitProfiles = <String, ExitProfile>{
  'liftFade': ExitProfile(
    durMs: 220,
    staggerMs: 12,
    capMs: 400,
    toScale: 0.7,
    liftPct: -6,
    spinDeg: 10,
  ),
  'dissolve': ExitProfile(
    durMs: 180,
    staggerMs: 8,
    capMs: 300,
    toScale: 0.85,
    curve: Curves.easeOut,
  ),
};

const defaultEnterProfile = 'drop';
const defaultExitProfile = 'liftFade';

/// Per-piece timing for a group of [count] pieces, compressing the stagger
/// so the group never exceeds the profile cap. Deterministic per seed.
List<Duration> staggerDelays({
  required int count,
  required int staggerMs,
  required int jitterMs,
  required int durMs,
  required int capMs,
  required String seed,
}) {
  if (count <= 0) return const [];
  final rnd = StableRandom(stableSeed(seed));
  final raw = [
    for (var i = 0; i < count; i++)
      i * staggerMs + (jitterMs == 0 ? 0 : rnd.nextInt(jitterMs + 1)),
  ];
  final last = raw.reduce(max);
  final budget = max(0, capMs - durMs);
  final factor = last == 0 || last <= budget ? 1.0 : budget / last;
  return [for (final r in raw) Duration(milliseconds: (r * factor).round())];
}
