import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../shared/widgets/card_avatar.dart';
import '../data/atlas_data_provider.dart';

/// One face-card tile inside an [AtlasBranch]. Renders the politician's
/// photo with a mastery ring around it (0..1 fill), name + title below,
/// and a locked overlay (desaturated + padlock) when the user hasn't
/// unlocked the parent node yet.
///
/// Tap → existing /node/:id detail route. The detail screen handles
/// study-this-node flow; the Atlas itself is read-only.
class AtlasCard extends StatelessWidget {
  const AtlasCard({super.key, required this.data, required this.branchColor});

  final AtlasCardData data;
  final Color branchColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Locked cards stay slightly muted as a "you haven't studied this"
    // hint, but not so faint that the role becomes unreadable on dark.
    final muted = data.isLocked
        ? theme.colorScheme.onSurface.withOpacity(0.75)
        : theme.colorScheme.onSurface;
    final mutedSecondary = data.isLocked
        ? theme.colorScheme.onSurfaceVariant.withOpacity(0.70)
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        // Atlas is a library — every card opens its detail page regardless
        // of lock status. The lock badge stays as a "you haven't studied
        // this yet" signal but never blocks looking it up.
        onTap: () {
          HapticFeedback.lightImpact();
          context.go('/politician/${data.cardId}');
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline,
              width: 1.5,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PortraitWithRing(
                photoUrl: data.photoUrl,
                lqipBase64: data.lqipBase64,
                name: data.name,
                masteryFraction: data.masteryFraction,
                ringColor: branchColor,
                isLocked: data.isLocked,
              ),
              const SizedBox(height: 10),
              Text(
                data.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: muted,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: mutedSecondary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortraitWithRing extends StatelessWidget {
  const _PortraitWithRing({
    required this.photoUrl,
    required this.lqipBase64,
    required this.name,
    required this.masteryFraction,
    required this.ringColor,
    required this.isLocked,
  });

  final String? photoUrl;
  final String? lqipBase64;
  final String name;
  final double masteryFraction;
  final Color ringColor;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    const radius = 36.0;
    const ringStroke = 3.5;
    final size = (radius + ringStroke + 2) * 2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Mastery ring — drawn outside the avatar.
          CustomPaint(
            size: Size(size, size),
            painter: _MasteryRingPainter(
              fraction: masteryFraction,
              color: isLocked
                  ? Theme.of(context).colorScheme.outlineVariant
                  : ringColor,
              trackColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              stroke: ringStroke,
            ),
          ),
          // Avatar — desaturated when locked.
          ColorFiltered(
            colorFilter: isLocked
                ? const ColorFilter.matrix([
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0,      0,      0,      1, 0,
                  ])
                : const ColorFilter.matrix([
                    1, 0, 0, 0, 0,
                    0, 1, 0, 0, 0,
                    0, 0, 1, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
            child: CardAvatar(
              name: name,
              radius: radius,
              photoUrl: photoUrl,
              lqipBase64: lqipBase64,
            ),
          ),
          // Padlock overlay for locked cards.
          if (isLocked)
            Positioned(
              bottom: 0,
              right: 4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: EditorialPalette.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.lock_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom-paints the mastery ring around the avatar. Single arc, clamped
/// to [0, 1]. Track is the muted background; foreground is the branch
/// color.
class _MasteryRingPainter extends CustomPainter {
  _MasteryRingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.stroke,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - stroke / 2 - 1;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, track);

    final f = fraction.clamp(0.0, 1.0);
    if (f <= 0) return;

    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at top
      f * 2 * math.pi,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _MasteryRingPainter old) {
    return old.fraction != fraction ||
        old.color != color ||
        old.trackColor != trackColor ||
        old.stroke != stroke;
  }
}
