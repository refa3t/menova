import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../anim_step.dart';

/// Slide into oven (CLAUDE.md 5.5, OVEN.md 0 option b): an oven's front
/// wall with an arched opening appears, placed so all of it is on screen;
/// the product moves in front of it, slides up into the glowing opening
/// (smaller and tilted away, as seen through it), bakes there among the
/// flames (Cooked) while its top melts (param `melt`, see [Melted]: the
/// surface softens and turns golden, the pieces sink into it), and slides
/// back out baked and steaming to its place, ready for the next step.
///
/// Drawn in code like the Oven's minimum (OVEN.md 7), in the same colours.
/// Optional image roles, shared with the Oven: `steam` over the product once
/// out, `embers` inside the opening. Params (all optional, clamped):
/// `scrimMaxPct` (35), `saturation` (1.45), `insideScale` (0.62) and `tilt`
/// (0.6: the product's height inside, of its width), `archWidth` (0.95, of
/// the product's width in front of the oven), `shrinkTo` (0.9: its scale
/// once back, where the next step takes over), `bubbles` (0: how many
/// bubbles rise on it while it bakes, within `bubbleArea` (0.7) of its
/// radius), `melt` (none).
///
/// With [AnimStepInput.lite] (a phone's GPU) it looks the same but costs
/// less a frame: the product crossfades to its baked (and melted) look
/// painted once ([LiteBaked]) instead of being baked, blurred and tinted
/// every frame, the front wall is painted once into an image and only
/// moved, the opening is cut by a rounded rectangle instead of a path, and
/// the melted top's shine does not drift.
class SlideIntoOvenStep implements AnimStep {
  const SlideIntoOvenStep();

  static const _scrimColor = Color(0xFF0B0705);

  /// Space kept between the oven and the screen's edges.
  static const _margin = 12.0;

  // Phases, in fractions of the step.
  static const _toFront = (0.03, 0.18), _in = (0.18, 0.32);
  static const _out = (0.7, 0.82), _back = (0.82, 0.97);

  @override
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input) =>
      LayoutBuilder(
        builder: (context, box) => _build(frame, input, box.biggest),
      );

  Widget _build(AnimFrame frame, AnimStepInput input, Size screen) {
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
    final melt = MeltSpec.from(p['melt']);
    final still = input.reduceMotion;
    final lite = input.lite;
    final ms = frame.elapsed.inMilliseconds;
    final baseScale = input.baseScale.isFinite
        ? input.baseScale.clamp(0.0, 1.0)
        : 1.0;

    final rect = input.productRect;
    final r = rect.shortestSide / 2;
    final place = _place(rect, screen, archWidth);
    final geo = place.oven;
    // The product's scale in front of the oven (inside: insideScale of it).
    final front = r > 0 ? place.radius / r : 1.0;

    // Curves.
    double phase((double, double) span) =>
        interval(t, span.$1, span.$2, Curves.easeInOut);
    final toFront = phase(_toFront), slideIn = phase(_in);
    final slideOut = phase(_out), back = phase(_back);
    final scrim = interval(t, 0, 0.15) * scrimMax;
    final ovenIn = interval(t, 0, 0.15, Curves.easeOut);
    final oven = ovenIn * (1 - interval(t, 0.85, 1));
    final cook = interval(t, _in.$2, _out.$1, Curves.easeInOut);
    final glow =
        interval(t, 0.05, 0.3) *
        (0.75 + (still ? 0 : 0.25 * sin(ms / 1000 * 2 * pi * 1.5)));
    final steam = interval(t, _out.$2, _back.$2) * (1 - interval(t, 0.95, 1));
    final bubbling = t > _in.$2 && !still ? (ms % 1400) / 1400 : 0.0;

    final stage = geo.frontCenter;
    final inside = geo.insideCenter;
    final (Offset at, double scale) = back > 0
        ? (
            Offset.lerp(stage, rect.center, back)!,
            lerpDouble(front, shrinkTo, back)!,
          )
        : slideOut > 0
        ? (
            Offset.lerp(inside, stage, slideOut)!,
            lerpDouble(front * insideScale, front, slideOut)!,
          )
        : slideIn > 0
        ? (
            Offset.lerp(stage, inside, slideIn)!,
            lerpDouble(front, front * insideScale, slideIn)!,
          )
        : (
            Offset.lerp(rect.center, stage, toFront)!,
            lerpDouble(1, front, toFront)!,
          );
    final squash = lerpDouble(1, tilt, slideIn - slideOut)!;
    // Behind the oven's front wall only while it goes in and comes out.
    final behindWall = slideIn > 0 && slideOut < 1;
    // The front wall comes down from above as it appears.
    final drop = -place.radius * 0.6 * (1 - ovenIn);

    String? first(String role) => input.images[role]?.firstOrNull;
    final steamUrl = first('steam');
    final embersUrl = first('embers');

    Widget product = lite
        ? _liteProduct(input, cook, saturation, melt, baseScale)
        : Cooked(
            amount: cook,
            saturation: saturation,
            bubble: bubbling,
            child: input.product,
          );
    if (melt != null && !lite) {
      product = Melted(
        amount: cook,
        spec: melt,
        baseScale: baseScale,
        gloss: still ? 0 : (ms % 3000) / 3000,
        contents: bakedContents(input),
        child: product,
      );
    }
    // On a phone always in the same place in the tree, so what is painted
    // once is kept.
    if (bubbles > 0 && (cook > 0 || lite)) {
      product = Stack(
        fit: StackFit.expand,
        children: [
          product,
          CustomPaint(
            painter: _BubblesPainter(
              count: bubbles,
              area: bubbleArea * baseScale,
              phase: still ? 0 : ms / 1000,
              amount: cook * (1 - slideOut),
            ),
          ),
        ],
      );
    }

    // Keyed (as the wall is) so moving behind or in front of the wall
    // keeps what is drawn, an image painted once among it.
    final moving = Positioned.fromRect(
      key: const ValueKey(_Part.product),
      rect: Rect.fromCenter(center: at, width: rect.width, height: rect.height),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(scale, scale * squash, 1),
        child: product,
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
              // Repainted every frame (the flames): kept apart.
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _OvenInsidePainter(
                    geo: geo,
                    opacity: oven,
                    glow: glow,
                    flicker: still ? 0 : ms / 1000,
                    lite: lite,
                  ),
                ),
              ),
            ),
          ),
        if (embersUrl != null && oven > 0 && !geo.arch.isEmpty)
          Positioned.fromRect(
            rect: geo.arch.shift(Offset(0, drop)),
            child: _clipArch(
              lite,
              geo.arch.size,
              Image.network(
                embersUrl,
                fit: BoxFit.cover,
                opacity: AlwaysStoppedAnimation((oven * glow).clamp(0.0, 1.0)),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        if (behindWall) moving,
        // The front wall: over the product while it is in the oven.
        if (oven > 0 && lite && !geo.wall.isEmpty) _liteWall(geo, oven, drop),
        if (oven > 0 && !lite)
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(0, drop),
                // Painted once it has faded in, then only moved (its
                // firelight is steady, not breathing, for that reason).
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _OvenWallPainter(
                      geo: geo,
                      opacity: oven,
                      glow: 0.75,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (!behindWall) moving,
        if (steamUrl != null && steam > 0)
          Positioned.fromRect(
            rect: Rect.fromCenter(
              center: at,
              width: rect.width * scale,
              height: rect.height * scale,
            ).translate(0, -rect.height * 0.1 * steam),
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

  /// The product baking, for a phone: its baked look painted once into an
  /// image, faded in over the raw product as it cooks (by the image itself,
  /// no layer). Shown faintly from the first frame, so that image is
  /// painted (its one costly frame) as "add" is pressed, not halfway
  /// through the motion. Without a melt it is [Cooked]'s own image, which
  /// the next steps (Box, Swap) share.
  static Widget _liteProduct(
    AnimStepInput input,
    double cook,
    double saturation,
    MeltSpec? melt,
    double baseScale,
  ) {
    // Invisible (no pixel of it drawn) but painted, so captured.
    final a = max(cook, 1e-3);
    if (melt == null) {
      return Cooked(
        amount: a,
        saturation: saturation,
        lite: true,
        child: input.product,
      );
    }
    final baked = LiteBaked(
      key: const ValueKey(_Part.baked),
      product: input.product,
      share: input.product,
      saturation: saturation,
      melt: melt,
      baseScale: baseScale,
      contents: bakedContents(input),
      opacity: a,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (a < 1)
          KeyedSubtree(key: const ValueKey(_Part.raw), child: input.product),
        baked,
      ],
    );
  }

  /// The front wall, for a phone: painted once into an image the size of
  /// the wall, then only moved (and faded while it appears and goes).
  static Widget _liteWall(_OvenFront geo, double opacity, double drop) {
    // Room for the stone arch's stroke beyond the wall's edge.
    final bounds = geo.wall.inflate(2);
    // Faded by the image itself: no layer, nor painted again.
    final wall = Still(
      inputs: [geo.wall, geo.arch],
      opacity: opacity,
      child: CustomPaint(
        painter: _OvenWallPainter(
          geo: geo,
          opacity: 1,
          glow: 0.75,
          origin: bounds.topLeft,
        ),
      ),
    );
    return Positioned.fromRect(
      key: const ValueKey(_Part.wall),
      rect: bounds.shift(Offset(0, drop)),
      child: IgnorePointer(child: wall),
    );
  }

  /// [child] cut to the opening's shape: by its path, or for a phone by the
  /// same shape as a rounded rectangle.
  static Widget _clipArch(bool lite, Size size, Widget child) => lite
      ? ClipRRect(borderRadius: _archRadius(size), child: child)
      : ClipPath(clipper: _ArchClip(size), child: child);

  /// The oven's front wall for a product at [productRect] on [screen].
  @visibleForTesting
  static Rect ovenBounds(
    Rect productRect,
    Size screen, {
    double archWidth = 0.95,
  }) => _place(productRect, screen, archWidth).oven.wall;

  /// Where the oven goes so that all of it, and the product in front of it,
  /// is on [screen]: as near the product as it fits, its size (the radius
  /// of the product in front of it) at most the product's.
  static ({_OvenFront oven, double radius}) _place(
    Rect rect,
    Size screen,
    double archWidth,
  ) {
    final r = rect.shortestSide / 2;
    // Height of the wall above its mouth, in product radii.
    final above = archWidth * 1.6 + 0.55;
    if (!screen.isFinite || screen.isEmpty) {
      return (
        oven: _OvenFront(center: rect.center, radius: r, archWidth: archWidth),
        radius: r,
      );
    }
    final w = screen.width - 2 * _margin, h = screen.height - 2 * _margin;
    final radius = max(0.0, min(r, min(w / 3.4, h / (above + 2))));
    double fit(double v, double lo, double hi) =>
        lo > hi ? (lo + hi) / 2 : v.clamp(lo, hi);
    final mouthY = fit(
      rect.top,
      _margin + above * radius,
      screen.height - _margin - 2 * radius,
    );
    final x = fit(
      rect.center.dx,
      _margin + 1.7 * radius,
      screen.width - _margin - 1.7 * radius,
    );
    return (
      oven: _OvenFront(
        center: Offset(x, mouthY + radius),
        radius: radius,
        archWidth: archWidth,
      ),
      radius: radius,
    );
  }
}

/// Where the oven's front wall and its arched opening sit, from the product
/// in front of it (centre and radius): the wall's bottom edge (the mouth)
/// is that product's top edge, the opening is centred above it.
@immutable
class _OvenFront {
  _OvenFront({
    required Offset center,
    required double radius,
    required double archWidth,
  }) : frontCenter = center,
       mouthY = center.dy - radius,
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

  /// Where the product's centre stands in front of the oven.
  final Offset frontCenter;

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

/// The opening's round top as the corners of a rounded rectangle: the same
/// outline as [_archPath].
BorderRadius _archRadius(Size size) {
  final top = Radius.elliptical(
    max(size.width / 2, 1e-3),
    max(min(size.width / 2, size.height), 1e-3),
  );
  return BorderRadius.only(topLeft: top, topRight: top);
}

class _ArchClip extends CustomClipper<Path> {
  const _ArchClip(this.size);

  final Size size;

  @override
  Path getClip(Size s) => _archPath(s);

  @override
  bool shouldReclip(_ArchClip oldClipper) => oldClipper.size != size;
}

/// Keys of the parts that change places in the stack.
enum _Part { product, wall, raw, baked }

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
    this.lite = false,
  });

  final _OvenFront geo;
  final double opacity;
  final double glow;
  final double flicker;

  /// Cut by a rounded rectangle (the same outline) instead of a path.
  final bool lite;

  @override
  void paint(Canvas canvas, Size size) {
    final arch = geo.arch;
    if (arch.isEmpty) return;
    canvas.save();
    if (lite) {
      canvas.clipRRect(_archRadius(arch.size).toRRect(arch));
    } else {
      canvas.clipPath(geo.archPath());
    }
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
      old.flicker != flicker ||
      old.lite != lite;
}

/// The oven's front wall: brick, domed on top, with the arched opening cut
/// out, its stone arch lit by the fire inside.
class _OvenWallPainter extends CustomPainter {
  _OvenWallPainter({
    required this.geo,
    required this.opacity,
    required this.glow,
    this.origin = Offset.zero,
  });

  final _OvenFront geo;
  final double opacity;
  final double glow;

  /// Where its canvas starts, in the overlay's coordinates (the geometry's).
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final wall = geo.wall;
    if (wall.isEmpty) return;
    if (origin != Offset.zero) {
      canvas.save();
      canvas.translate(-origin.dx, -origin.dy);
      _paint(canvas);
      canvas.restore();
    } else {
      _paint(canvas);
    }
  }

  void _paint(Canvas canvas) {
    final wall = geo.wall;
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
      old.glow != glow ||
      old.origin != origin;
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
