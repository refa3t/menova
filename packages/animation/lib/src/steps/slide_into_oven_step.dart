import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../anim_step.dart';

/// Slide into oven (CLAUDE.md 5.5, OVEN.md 0 option b): an oven's front
/// wall with an arched opening comes down above the product, which slides
/// up into the glowing opening (smaller and tilted away, as seen through
/// it), bakes there among the flames (Cooked), and slides back out baked
/// and steaming, ready for Swap.
///
/// Drawn in code like the Oven's minimum (OVEN.md 7), in the same colours.
/// Optional image roles, shared with the Oven: `steam` over the product once
/// out, `embers` inside the opening. Params (all optional, clamped):
/// `scrimMaxPct` (35), `saturation` (1.45), `insideScale` (0.62) and `tilt`
/// (0.6: the product's height inside, of its width), `archWidth` (0.95, of
/// the product's width), `shrinkTo` (0.9: its scale once out, where Swap
/// takes over), `bubbles` (0: how many bubbles rise on it while it bakes,
/// within `bubbleArea` (0.7) of its radius).
class SlideIntoOvenStep implements AnimStep {
  const SlideIntoOvenStep();

  static const _scrimColor = Color(0xFF0B0705);

  // Phases, in fractions of the step.
  static const _inStart = 0.08, _inEnd = 0.3;
  static const _outStart = 0.72, _outEnd = 0.95;

  @override
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input) {
    final t = frame.t.isFinite ? frame.t.clamp(0.0, 1.0) : 1.0;
    final p = input.params;
    double param(String k, double d, double lo, double hi) {
      final v = p[k];
      return v is num && v.isFinite ? v.toDouble().clamp(lo, hi) : d;
    }

    final scrimMax = param('scrimMaxPct', 35, 0, 100) / 100;
    final saturation = param('saturation', 1.45, 0, 3);
    final insideScale = param('insideScale', 0.62, 0.2, 1);
    final tilt = param('tilt', 0.6, 0.2, 1);
    final archWidth = param('archWidth', 0.95, 0.5, 1.6);
    final shrinkTo = param('shrinkTo', 0.9, 0.2, 1);
    final bubbles = param('bubbles', 0, 0, 60).round();
    final bubbleArea = param('bubbleArea', 0.7, 0, 1);
    final still = input.reduceMotion;
    final ms = frame.elapsed.inMilliseconds;

    final rect = input.productRect;
    final r = rect.shortestSide / 2;
    final geo = _OvenFront(
      center: rect.center,
      radius: r,
      archWidth: archWidth,
    );

    // Curves.
    final scrim = interval(t, 0, 0.2) * scrimMax;
    final ovenIn = interval(t, 0, 0.18, Curves.easeOut);
    final oven = ovenIn * (1 - interval(t, 0.9, 1));
    final slideIn = interval(t, _inStart, _inEnd, Curves.easeInOut);
    final slideOut = interval(t, _outStart, _outEnd, Curves.easeInOut);
    final inside = slideIn - slideOut;
    final cook = interval(t, _inEnd, _outStart, Curves.easeInOut);
    final glow =
        interval(t, 0.05, 0.3) *
        (0.75 + (still ? 0 : 0.25 * sin(ms / 1000 * 2 * pi * 1.5)));
    final steam =
        interval(t, _outStart + 0.05, 0.85) * (1 - interval(t, 0.93, 1));
    final bubbling = t > _inEnd && !still ? (ms % 1400) / 1400 : 0.0;

    final outScale = lerpDouble(1, shrinkTo, slideOut)!;
    final scale = lerpDouble(outScale, insideScale, inside)!;
    final squash = lerpDouble(1, tilt, inside)!;
    final at = Offset.lerp(rect.center, geo.insideCenter, inside)!;
    // The front wall comes down from above as it appears.
    final drop = -r * 0.6 * (1 - ovenIn);

    String? first(String role) => input.images[role]?.firstOrNull;
    final steamUrl = first('steam');
    final embersUrl = first('embers');

    final product = Cooked(
      amount: cook,
      saturation: saturation,
      bubble: bubbling,
      child: Stack(
        fit: StackFit.expand,
        children: [
          input.product,
          if (bubbles > 0 && cook > 0)
            CustomPaint(
              painter: _BubblesPainter(
                count: bubbles,
                area: bubbleArea,
                phase: still ? 0 : ms / 1000,
                amount: cook * (1 - slideOut),
              ),
            ),
        ],
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: _scrimColor.withValues(alpha: scrim)),
        ),
        // Inside the opening: dark, glowing, with flames at the back.
        if (oven > 0)
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, drop),
              child: CustomPaint(
                painter: _OvenInsidePainter(
                  geo: geo,
                  opacity: oven,
                  glow: glow,
                  flicker: still ? 0 : ms / 1000,
                ),
              ),
            ),
          ),
        if (embersUrl != null && oven > 0)
          Positioned.fromRect(
            rect: geo.arch.shift(Offset(0, drop)),
            child: ClipPath(
              clipper: _ArchClip(geo.arch.size),
              child: Image.network(
                embersUrl,
                fit: BoxFit.cover,
                opacity: AlwaysStoppedAnimation((oven * glow).clamp(0.0, 1.0)),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        // The customer's product, sliding in and out.
        Positioned.fromRect(
          rect: Rect.fromCenter(
            center: at,
            width: rect.width,
            height: rect.height,
          ),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(scale, scale * squash, 1),
            child: product,
          ),
        ),
        // The front wall over it: the product goes in behind it.
        if (oven > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(0, drop),
                child: CustomPaint(
                  painter: _OvenWallPainter(
                    geo: geo,
                    opacity: oven,
                    glow: glow,
                  ),
                ),
              ),
            ),
          ),
        if (steamUrl != null && steam > 0)
          Positioned.fromRect(
            rect: rect.translate(0, -rect.height * 0.1 * steam),
            child: IgnorePointer(
              child: Image.network(
                steamUrl,
                fit: BoxFit.contain,
                opacity: AlwaysStoppedAnimation(steam.clamp(0.0, 1.0) * 0.8),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Where the oven's front wall and its arched opening sit, from the product
/// (centre and radius): the wall's bottom edge (the mouth) is the product's
/// top edge, the opening is centred above it.
@immutable
class _OvenFront {
  _OvenFront({
    required Offset center,
    required double radius,
    required double archWidth,
  }) : mouthY = center.dy - radius,
       arch = Rect.fromLTRB(
         center.dx - radius * archWidth,
         center.dy - radius - radius * archWidth * 1.6,
         center.dx + radius * archWidth,
         center.dy - radius,
       ),
       wall = Rect.fromLTRB(
         center.dx - radius * 1.7,
         center.dy - radius - radius * archWidth * 1.6 - radius * 0.55,
         center.dx + radius * 1.7,
         center.dy - radius,
       );

  final double mouthY;

  /// The opening's bounds: a round top over straight sides.
  final Rect arch;

  /// The front wall's bounds.
  final Rect wall;

  /// Where the product's centre rests inside, on the oven floor.
  Offset get insideCenter =>
      Offset(arch.center.dx, arch.bottom - arch.height * 0.36);

  /// The opening's outline.
  Path archPath() => _archPath(arch.size, arch.topLeft);
}

Path _archPath(Size size, [Offset at = Offset.zero]) {
  final w = size.width, h = size.height;
  final top = min(w / 2, h);
  return Path()
    ..moveTo(at.dx, at.dy + h)
    ..lineTo(at.dx, at.dy + top)
    ..arcToPoint(
      Offset(at.dx + w, at.dy + top),
      radius: Radius.elliptical(max(w / 2, 1e-3), max(top, 1e-3)),
    )
    ..lineTo(at.dx + w, at.dy + h)
    ..close();
}

class _ArchClip extends CustomClipper<Path> {
  const _ArchClip(this.size);

  final Size size;

  @override
  Path getClip(Size s) => _archPath(s);

  @override
  bool shouldReclip(_ArchClip oldClipper) => oldClipper.size != size;
}

Color _fade(Color c, double opacity) =>
    c.withValues(alpha: (c.a * opacity).clamp(0.0, 1.0));

/// The inside of the opening: a dark chamber, warmer at the floor, flames
/// along the back and a glow that breathes.
class _OvenInsidePainter extends CustomPainter {
  _OvenInsidePainter({
    required this.geo,
    required this.opacity,
    required this.glow,
    required this.flicker,
  });

  final _OvenFront geo;
  final double opacity;
  final double glow;
  final double flicker;

  @override
  void paint(Canvas canvas, Size size) {
    final arch = geo.arch;
    if (arch.isEmpty) return;
    final path = geo.archPath();
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      arch,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _fade(const Color(0xFF120906), opacity),
            _fade(const Color(0xFF3A1A0A), opacity),
          ],
        ).createShader(arch),
    );
    // Flames along the back (the upper part of the opening).
    final rng = Random(7);
    const n = 7;
    for (var i = 0; i < n; i++) {
      final x = arch.left + arch.width * (i + 0.5) / n;
      final h =
          arch.height *
          0.34 *
          (0.7 + 0.3 * sin(flicker * 2 * pi * (2.2 + rng.nextDouble()) + i));
      final w = arch.width / n * 1.1;
      final base = arch.top + arch.height * 0.62;
      final flame = Path()
        ..moveTo(x - w / 2, base)
        ..quadraticBezierTo(x - w / 2, base - h * 0.5, x, base - h)
        ..quadraticBezierTo(x + w / 2, base - h * 0.5, x + w / 2, base)
        ..close();
      canvas.drawPath(
        flame,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              _fade(const Color(0xFFFFD27A), opacity * glow),
              _fade(const Color(0xFFFF7A1A), opacity * glow),
              _fade(const Color(0x00FF3A00), opacity),
            ],
          ).createShader(Rect.fromLTWH(x - w / 2, base - h, w, max(h, 1e-3))),
      );
    }
    // The warm glow.
    canvas.drawRect(
      arch,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.3),
          radius: 0.9,
          colors: [
            _fade(const Color(0xFFFF7A1A), opacity * glow * 0.55),
            _fade(const Color(0x00FF7A1A), opacity),
          ],
        ).createShader(arch),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OvenInsidePainter old) =>
      old.geo.arch != geo.arch ||
      old.opacity != opacity ||
      old.glow != glow ||
      old.flicker != flicker;
}

/// The oven's front wall: brick, domed on top, with the arched opening cut
/// out, its stone arch lit by the fire inside.
class _OvenWallPainter extends CustomPainter {
  _OvenWallPainter({
    required this.geo,
    required this.opacity,
    required this.glow,
  });

  final _OvenFront geo;
  final double opacity;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final wall = geo.wall;
    if (wall.isEmpty) return;
    final dome = RRect.fromRectAndCorners(
      wall,
      topLeft: Radius.circular(wall.width * 0.45),
      topRight: Radius.circular(wall.width * 0.45),
    );
    final front = Path.combine(
      PathOperation.difference,
      Path()..addRRect(dome),
      geo.archPath(),
    );
    canvas.save();
    canvas.clipPath(front);
    canvas.drawRect(
      wall,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _fade(const Color(0xFF5A2A18), opacity),
            _fade(const Color(0xFF8A3E22), opacity),
          ],
        ).createShader(wall),
    );
    // Brick courses.
    final mortar = Paint()
      ..color = _fade(const Color(0xFF3A1C10), opacity)
      ..strokeWidth = max(1, wall.height / 90);
    final row = max(wall.height / 9, 2.0);
    final brick = row * 2.2;
    var k = 0;
    for (var y = wall.bottom; y > wall.top; y -= row, k++) {
      canvas.drawLine(Offset(wall.left, y), Offset(wall.right, y), mortar);
      for (
        var x = wall.left + (k.isOdd ? brick / 2 : 0);
        x < wall.right;
        x += brick
      ) {
        canvas.drawLine(Offset(x, y), Offset(x, y - row), mortar);
      }
    }
    // Firelight on the wall around the opening.
    canvas.drawRect(
      wall,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            0,
            ((geo.arch.center.dy - wall.center.dy) / (wall.height / 2)).clamp(
              -1.0,
              1.0,
            ),
          ),
          radius: 0.8,
          colors: [
            _fade(const Color(0xFFFF8A2A), opacity * glow * 0.35),
            _fade(const Color(0x00FF8A2A), opacity),
          ],
        ).createShader(wall),
    );
    canvas.restore();
    // The stone arch round the opening.
    canvas.drawPath(
      geo.archPath(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(geo.arch.width * 0.07, 1)
        ..color = _fade(const Color(0xFFB98A62), opacity),
    );
    // The mouth's lip, where the product slides in.
    canvas.drawLine(
      Offset(geo.arch.left, geo.mouthY),
      Offset(geo.arch.right, geo.mouthY),
      Paint()
        ..strokeWidth = max(geo.arch.width * 0.05, 1)
        ..color = _fade(const Color(0xFF6E5038), opacity),
    );
  }

  @override
  bool shouldRepaint(_OvenWallPainter old) =>
      old.geo.wall != geo.wall ||
      old.geo.arch != geo.arch ||
      old.opacity != opacity ||
      old.glow != glow;
}

/// Bubbles rising and popping on a baking product (melted cheese), spread
/// over [area] of its radius; deterministic, and still at phase 0.
class _BubblesPainter extends CustomPainter {
  _BubblesPainter({
    required this.count,
    required this.area,
    required this.phase,
    required this.amount,
  });

  final int count;
  final double area;
  final double phase;
  final double amount;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    if (r <= 0 || amount <= 0) return;
    final c = size.center(Offset.zero);
    final rng = Random(31);
    for (var i = 0; i < count; i++) {
      final d = sqrt(rng.nextDouble()) * area * r;
      final a = rng.nextDouble() * 2 * pi;
      final period = 0.8 + rng.nextDouble() * 0.9;
      final life = ((phase + rng.nextDouble() * period) % period) / period;
      // Grows, then pops.
      final grow = life < 0.8 ? life / 0.8 : 1 - (life - 0.8) / 0.2;
      final br = r * (0.025 + 0.035 * rng.nextDouble()) * grow;
      if (br <= 0.2) continue;
      final at = c + Offset(cos(a), sin(a)) * d;
      canvas.drawCircle(
        at,
        br,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(br * 0.35, 0.5)
          ..color = const Color(0xFF8A4A16).withValues(alpha: 0.35 * amount),
      );
      canvas.drawCircle(
        at - Offset(br * 0.3, br * 0.3),
        br * 0.35,
        Paint()
          ..color = const Color(0xFFFFF2C8).withValues(alpha: 0.6 * amount),
      );
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter old) =>
      old.count != count ||
      old.area != area ||
      old.phase != phase ||
      old.amount != amount;
}
