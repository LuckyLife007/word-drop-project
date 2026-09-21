// ============================================================================
// PARTICLE BURST
// ============================================================================
// A short shower of small dots that flies out from the middle of a card.
//
// The game uses it 2 ways (REDESIGN.md, Polish section):
//   - GREEN, when the player answers a card correctly.
//   - RED, when a card runs out of time.
//
// WHY A BURST AND NOT AN IMAGE OR A GIF?
// A burst drawn in code needs no asset file, works at any size, and takes
// almost no space in the APK. It also lets each burst look slightly different,
// which stops 20 correct answers in a row from looking like a loop.
//
// HOW IT IS DRAWN
// One CustomPainter draws every dot of one burst. A CustomPainter paints
// straight onto the canvas: it makes no widgets, so 14 dots cost about the
// same as 1 widget, not 14. That matters, because up to 6 bursts can run at
// the same time when several cards end together.
//
// THE PHYSICS
// Each dot gets a direction, a speed and a size when the burst starts, and
// then follows the same 3 rules on every frame:
//   1. It moves outward along its direction.
//   2. Gravity pulls it down, more and more as time passes.
//   3. It fades out and gets smaller.
// Real fireworks behave this way, so the eye accepts it without thinking.
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// How long one burst lives, in milliseconds.
///
/// 700ms is chosen to sit just after the 500ms green flash of a matched card
/// and the 600ms red flash of a failed card. The dots are therefore still in
/// the air for a moment after the card itself has gone, which carries the eye
/// from the card to the empty space.
const int kBurstDurationMs = 700;

/// How many dots are in one burst.
///
/// 16 reads as "a burst" and still leaves the card text readable underneath.
/// Below about 8 it looks like a mistake. Above about 20 it hides the grid.
///
/// TUNED ON THE DEVICE (2026-09-21): 14 dots of radius 1.6 to 3.6 were hard
/// to see on a 720x1600 phone. The count and the radius below are the values
/// that read clearly without covering the clue text.
const int kBurstParticleCount = 16;

/// One dot inside a burst.
///
/// Every value is decided once, when the burst starts, and never changes.
/// The painter works out where the dot is from these values and the current
/// time, so no object is created on any frame.
class _Particle {
  /// Direction of travel, in radians. 0 points right, and the angle turns
  /// clockwise on the screen because the y axis points down.
  final double angle;

  /// How far the dot would travel in the whole burst with no gravity, in
  /// logical pixels.
  final double distance;

  /// The radius of the dot at the start, in logical pixels.
  final double radius;

  /// How strongly gravity pulls this dot down, in pixels over the burst.
  /// Each dot gets its own value, so they do not fall as one sheet.
  final double gravity;

  const _Particle({
    required this.angle,
    required this.distance,
    required this.radius,
    required this.gravity,
  });
}

/// A one-shot shower of dots. It plays once, then calls [onComplete].
///
/// The parent must remove this widget when [onComplete] fires. The widget
/// cannot remove itself, because a widget does not own its place in the tree.
class ParticleBurst extends StatefulWidget {
  /// The colour of the dots. Green for a correct word, red for a failed card.
  final Color colour;

  /// A number that decides the random layout of this burst.
  ///
  /// WHY PASS IT IN INSTEAD OF USING Random() WITH NO SEED?
  /// The layout must be the same on every frame of one burst, or the dots
  /// jump about. A seed also makes a bug repeatable: the same seed always
  /// draws the same burst.
  final int seed;

  /// Called once, when the burst has finished.
  final VoidCallback onComplete;

  const ParticleBurst({
    super.key,
    required this.colour,
    required this.seed,
    required this.onComplete,
  });

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<ParticleBurst>
    with SingleTickerProviderStateMixin {
  /// Runs 0.0 to 1.0 over kBurstDurationMs. It is the burst clock.
  late AnimationController _controller;

  /// The dots. Built one time in initState, never changed after that.
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    _buildParticles();

    _controller = AnimationController(
      duration: const Duration(milliseconds: kBurstDurationMs),
      vsync: this,
    );

    // Tell the parent when the burst ends, so it can drop this widget.
    //
    // WHY addStatusListener AND NOT forward().then()?
    // .then() also runs if the controller is stopped or disposed early. A
    // status listener that tests for 'completed' runs only on a real finish.
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  /// Makes the dots. Called one time.
  void _buildParticles() {
    final random = math.Random(widget.seed);

    _particles = List<_Particle>.generate(kBurstParticleCount, (i) {
      // SPREAD THE DOTS EVENLY, THEN DISTURB THEM.
      // Pure random angles leave gaps and clumps. So we place each dot in its
      // own equal slice of the circle, then move it inside that slice by a
      // random amount. The result looks random but has no hole in it.
      final double slice = (2 * math.pi) / kBurstParticleCount;
      final double angle = (i * slice) + (random.nextDouble() * slice);

      return _Particle(
        angle: angle,
        // 22 to 52 pixels. A card is 88px tall, so this keeps the dots near
        // their own card and out of the neighbouring one.
        distance: 22 + random.nextDouble() * 30,
        // 2.2 to 4.8 pixels. Mixed sizes give the burst depth.
        radius: 2.2 + random.nextDouble() * 2.6,
        // 30 to 70 pixels of fall. Without gravity the burst looks like a
        // flat sticker instead of something thrown into the air.
        gravity: 30 + random.nextDouble() * 40,
      );
    });
  }

  @override
  void dispose() {
    // Always dispose a controller. Its ticker runs on every frame otherwise,
    // even after the widget has gone.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IgnorePointer lets taps pass straight through the dots to whatever is
    // under them. Without it, a burst over the grid would swallow a scroll.
    return IgnorePointer(
      // RepaintBoundary keeps the repaint of these dots off the rest of the
      // grid. Without it, every frame of the burst would also repaint the
      // card behind it, and the 5 other cards in the same layer.
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              // The painter fills whatever box the parent gives it, which is
              // the grid cell.
              size: Size.infinite,
              painter: _BurstPainter(
                particles: _particles,
                progress: _controller.value,
                colour: widget.colour,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Draws one burst at one moment in time.
class _BurstPainter extends CustomPainter {
  final List<_Particle> particles;

  /// 0.0 at the start of the burst, 1.0 at the end.
  final double progress;

  final Color colour;

  _BurstPainter({
    required this.particles,
    required this.progress,
    required this.colour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Everything flies out from the middle of the cell.
    final Offset centre = Offset(size.width / 2, size.height / 2);

    // SLOW THE DOTS DOWN AS THEY GO.
    // A dot that travels at one speed looks mechanical. Air resistance slows
    // a real particle most at the end, so we bend the clock with a curve:
    // the dot covers most of its distance early and drifts at the end.
    final double travel = Curves.easeOutCubic.transform(progress);

    // FADE OUT, BUT NOT AT ONCE.
    // The dots stay solid for the first 45% of the burst, then fade over the
    // rest. An immediate fade makes the burst look weak at the moment the
    // player is actually looking at it.
    final double fade = progress < 0.45
        ? 1.0
        : 1.0 - ((progress - 0.45) / 0.55);

    // The dots shrink, but never below 45% of their starting size. A dot that
    // shrinks to nothing disappears before it has finished fading, and the
    // burst then ends with a few stray specks instead of a clean fade.
    final double shrink = (1.0 - (progress * 0.55)).clamp(0.0, 1.0);

    // ONE Paint OBJECT FOR EVERY DOT.
    // Making a Paint inside the loop would build 14 objects on every frame,
    // which is 840 objects a second for one burst. We make 1 and change its
    // colour, which costs nothing.
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // 1. Move outward along the dot's own direction.
      final double dx = math.cos(p.angle) * p.distance * travel;

      // 2. Move outward on y, then add the fall.
      //    Gravity grows with the SQUARE of time, the way real gravity does.
      //    progress * progress gives a slow start and a fast drop.
      final double dy =
          (math.sin(p.angle) * p.distance * travel) +
          (p.gravity * progress * progress);

      // 3. Fade and shrink.
      paint.color = colour.withValues(alpha: fade.clamp(0.0, 1.0));

      final double r = p.radius * shrink;
      if (r <= 0) continue; // nothing left to draw

      canvas.drawCircle(centre + Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) {
    // Repaint only when something visible changed. progress changes on every
    // frame, so this is true during the burst and false if the widget is
    // rebuilt for another reason.
    return old.progress != progress || old.colour != colour;
  }
}
