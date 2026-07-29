// lib/features/shared/widgets/neo/neo_kit.dart
//
// The neo-brutalist primitive kit (DESIGN.md section 7). Six components
// every redesigned screen composes from. Rules enforced here so screens
// cannot get them wrong:
//   - Hard offset shadows only, zero blur. Black on light surfaces,
//     signal yellow on dark (the substitution is required, not optional).
//   - Press collapses the element into its own footprint (no hover
//     anywhere; this is a phone).
//   - All motion respects MediaQuery.disableAnimations.
//   - Interactive targets are at least 48dp tall.
//   - State is never colour alone: solid-vs-hollow + icon + position.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/editorial_theme.dart';

/// Hard offset shadow for the current surface: black on light, signal on
/// dark (a black shadow is invisible on near-black).
BoxShadow neoShadow(BuildContext context, {double offset = 6}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxShadow(
    color: dark ? EditorialPalette.signal : const Color(0xFF000000),
    offset: Offset(offset, offset),
  );
}

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Card border for the current surface: hairline slate on dark, solid
/// black on light (the brutalist rule; the dark hairline is invisible on
/// a light canvas).
Color neoLine(BuildContext c) =>
    _isDark(c) ? EditorialPalette.line : const Color(0xFF000000);

/// Secondary border (inactive controls, quiet tiles).
Color neoLineDim(BuildContext c) =>
    _isDark(c) ? EditorialPalette.lineDim : const Color(0xFF6E6E7A);

/// Card surface for the current mode.
Color neoCardBg(BuildContext c) =>
    _isDark(c) ? EditorialPalette.slate : EditorialPalette.cardLt;

/// The primary CTA: signal yellow, 3px black border, hard shadow, press
/// collapse. THE one yellow action on its screen; a second BrutalButton
/// on the same screen should be [BrutalButton.quiet].
class BrutalButton extends StatefulWidget {
  const BrutalButton({
    required this.label,
    required this.onPressed,
    this.subtitle,
    this.quiet = false,
    super.key,
  });

  /// Quiet secondary: hollow, muted border, no shadow, never yellow.
  const BrutalButton.quiet({
    required this.label,
    required this.onPressed,
    this.subtitle,
    super.key,
  }) : quiet = true;

  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;
  final bool quiet;

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    const shadowOffset = 4.0;
    final collapsed = _pressed && widget.onPressed != null;

    final box = AnimatedContainer(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 120),
      curve: const Cubic(0.2, 0, 0, 1),
      transform: Matrix4.translationValues(
        collapsed ? shadowOffset : 0,
        collapsed ? shadowOffset : 0,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: widget.quiet
          ? BoxDecoration(
              border: Border.all(
                color: EditorialPalette.mutedBorder,
                width: 3,
              ),
            )
          : BoxDecoration(
              color: EditorialPalette.signal,
              border: Border.all(width: 3),
              boxShadow:
                  collapsed ? const [] : [neoShadow(context, offset: 4)],
            ),
      child: Text(
        widget.label.toUpperCase(),
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge?.copyWith(
          color: widget.quiet
              ? theme.colorScheme.onSurfaceVariant
              : EditorialPalette.ink,
          letterSpacing: 1.2,
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              box,
              if (widget.subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    widget.subtitle!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// State-driven corner ribbon (DESIGN.md 7.2). Renders ONLY when a state
/// earned it; a ribbon that always appears is wallpaper. Place inside a
/// Stack whose parent clips (the ticket does this for you).
class CornerRibbon extends StatelessWidget {
  const CornerRibbon({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Positioned(
      top: 18,
      right: -44,
      child: Transform.rotate(
        angle: 45 * 3.14159265 / 180,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 4),
          decoration: const BoxDecoration(
            color: EditorialPalette.signal,
            border: Border.symmetric(
              horizontal: BorderSide(width: 3),
            ),
          ),
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.6,
              color: EditorialPalette.ink,
            ),
          ),
        ),
      ),
    );
}

/// The signature data motif (DESIGN.md 7.3): one bar per unit. Dark
/// surface: solid mint hit, 58%-height orange miss. Light surface: solid
/// black hit, hollow outlined miss. Colourblind-proof by shape either way.
class DataBarcode extends StatelessWidget {
  const DataBarcode({
    required this.hits,
    this.height = 34,
    this.startLabel,
    this.endLabel,
    super.key,
  });

  /// true = hit, false = miss, in order.
  final List<bool> hits;
  final double height;
  final String? startLabel;
  final String? endLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    final bars = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < hits.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: hits[i]
                ? Container(
                    height: height,
                    color: dark
                        ? EditorialPalette.correct
                        : const Color(0xFF000000),
                  )
                : Container(
                    height: height * 0.58,
                    decoration: dark
                        ? const BoxDecoration(color: EditorialPalette.notyet)
                        : BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            border: Border.all(width: 2),
                          ),
                  ),
          ),
        ],
      ],
    );

    if (startLabel == null && endLabel == null) return bars;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bars,
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(startLabel ?? '', style: theme.textTheme.labelSmall),
            Text(endLabel ?? '', style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

/// Readiness stages in canonical order. Colours per DESIGN.md 7.4.
enum ReadinessStage { notYet, onTrack, ready, lockedIn }

extension ReadinessStageX on ReadinessStage {
  String get label => switch (this) {
        ReadinessStage.notYet => 'not yet',
        ReadinessStage.onTrack => 'on track',
        ReadinessStage.ready => 'ready',
        ReadinessStage.lockedIn => 'locked in',
      };

  Color get color => switch (this) {
        ReadinessStage.notYet => EditorialPalette.notyet,
        ReadinessStage.onTrack => EditorialPalette.signal,
        ReadinessStage.ready => EditorialPalette.correct,
        ReadinessStage.lockedIn => EditorialPalette.tier,
      };
}

/// The powerline readiness bar (DESIGN.md 7.4). Only the active segment
/// is coloured; solid chevrons flank the active segment (clip-path
/// triangles, never font glyphs); a thin "›" separates two inactive
/// segments, because a solid chevron between identical fills is
/// invisible. [trailing] carries the volatile right group (projection,
/// days remaining).
class PowerlineBar extends StatelessWidget {
  const PowerlineBar({
    required this.active,
    this.trailing,
    this.height = 30,
    super.key,
  });

  final ReadinessStage active;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    const stages = ReadinessStage.values;
    final activeIndex = stages.indexOf(active);
    final dark = _isDark(context);
    final inactiveBg =
        dark ? EditorialPalette.slate2 : const Color(0xFFE4E4DF);
    final spacerBg =
        dark ? EditorialPalette.slate : const Color(0xFFDCDCD6);
    final inactiveText =
        dark ? EditorialPalette.textDim : const Color(0xFF55555C);
    final separator =
        dark ? EditorialPalette.lineDim : const Color(0xFFB9B9B2);
    final segmentStyle = TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 13,
      letterSpacing: 0.8,
      color: inactiveText,
    );

    final children = <Widget>[];
    for (var i = 0; i < stages.length; i++) {
      final isActive = i == activeIndex;
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          color: isActive ? stages[i].color : inactiveBg,
          alignment: Alignment.center,
          child: Text(
            stages[i].label,
            style: segmentStyle.copyWith(
              color:
                  isActive ? EditorialPalette.inkInverted : inactiveText,
              fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      );
      if (i == stages.length - 1) break;
      // Junction: solid chevron out of the active segment, solid chevron
      // into the active segment, thin separator otherwise.
      if (i == activeIndex) {
        children.add(
          _Chevron(color: stages[i].color, bg: inactiveBg, height: height),
        );
      } else if (i + 1 == activeIndex) {
        children.add(
          _Chevron(
            color: stages[i + 1].color,
            bg: inactiveBg,
            height: height,
          ),
        );
      } else {
        children.add(
          Container(
            color: inactiveBg,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text('›', style: segmentStyle.copyWith(color: separator)),
          ),
        );
      }
    }

    return Semantics(
      label: 'Readiness: ${active.label}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              ...children,
              Expanded(child: ColoredBox(color: spacerBg)),
              if (trailing != null)
                Container(
                  color: inactiveBg,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  alignment: Alignment.center,
                  child: trailing,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.color,
    required this.bg,
    required this.height,
  });

  final Color color;
  final Color bg;
  final double height;

  // The arrow's own fill is the pointing segment's colour over the
  // adjacent segment's background (DESIGN.md's "easy to get backwards"
  // rule, expressed the Flutter way).
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: bg,
        child: ClipPath(
          clipper: _TriangleClipper(),
          child: Container(width: 13, height: height, color: color),
        ),
      );
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, size.height / 2)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// The end-of-session results ticket (DESIGN.md 7.1). Poster variant:
/// rotated paper artifact with ribbon, barcode, return hook, share.
/// Daily variant ([ResultsTicket.daily]): flat, unrotated, unribboned.
/// The three jobs in priority order: deliver the reward, hook the return,
/// enable the share.
class ResultsTicket extends StatelessWidget {
  const ResultsTicket({
    required this.serial,
    required this.score,
    required this.outOf,
    required this.subline,
    required this.hits,
    required this.streakDays,
    required this.nextIn,
    required this.onShare,
    this.ribbon,
    this.poster = true,
    super.key,
  });

  const ResultsTicket.daily({
    required this.serial,
    required this.score,
    required this.outOf,
    required this.subline,
    required this.hits,
    required this.streakDays,
    required this.nextIn,
    required this.onShare,
    super.key,
  })  : ribbon = null,
        poster = false;

  final String serial;
  final int score;
  final int outOf;
  final String subline;
  final List<bool> hits;
  final int streakDays;
  final String nextIn;
  final VoidCallback onShare;

  /// Ribbon text, or null for no ribbon. State-driven only: PERFECT,
  /// NEW BEST, STREAK SAVED, CLOSE ONE. Never decorative.
  final String? ribbon;
  final bool poster;

  @override
  Widget build(BuildContext context) {
    const inkOnPaper = Color(0xFF0B0B0F);
    const metaOnPaper = Color(0xFF55555C);

    final card = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      width: double.infinity,
      decoration: BoxDecoration(
        color: EditorialPalette.paper,
        border: Border.all(width: poster ? 6 : 4),
        boxShadow: [neoShadow(context, offset: poster ? 12 : 6)],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serial.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.6,
                      color: metaOnPaper,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Container(
                        color: EditorialPalette.signal,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '$score',
                          style: const TextStyle(
                            fontFamily: 'Archivo',
                            fontSize: 50,
                            fontWeight: FontWeight.w500,
                            height: 1,
                            color: inkOnPaper,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Text(
                        ' / $outOf',
                        style: const TextStyle(
                          fontFamily: 'Archivo',
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: metaOnPaper,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subline,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF3A3A40),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TicketBarcode(hits: hits),
                  const SizedBox(height: 14),
                  Container(
                    height: 0,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0x55000000), width: 3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\u{1F525} $streakDays DAYS',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF26262B),
                        ),
                      ),
                      Text(
                        'NEXT IN ${nextIn.toUpperCase()}',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          color: Color(0xFF26262B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: 'Share',
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onShare();
                      },
                      child: Container(
                        width: double.infinity,
                        color: const Color(0xFF000000),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        alignment: Alignment.center,
                        child: const Text(
                          'SHARE',
                          style: TextStyle(
                            fontFamily: 'Archivo',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.6,
                            color: EditorialPalette.paper,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (ribbon != null) CornerRibbon(text: ribbon!),
          ],
        ),
      ),
    );

    if (!poster) return card;
    return Transform.rotate(angle: -2 * 3.14159265 / 180, child: card);
  }
}

class _TicketBarcode extends StatelessWidget {
  const _TicketBarcode({required this.hits});

  final List<bool> hits;

  // The ticket is always paper (light), but semantic colours hold here
  // because the ticket is a reward artifact, not chrome: solid mint hit
  // + 58% orange miss, per the results-card spec.
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < hits.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: hits[i] ? 40 : 40 * 0.58,
                  color: hits[i]
                      ? EditorialPalette.correct
                      : EditorialPalette.notyet,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Q1', style: _axisStyle),
            Text('Q${hits.length}', style: _axisStyle),
          ],
        ),
      ],
    );

  static const _axisStyle = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 11,
    color: Color(0xFF55555C),
  );
}

/// A settings row whose ENTIRE surface is the tap target (the 52x28
/// switch alone is under the 44pt minimum), with the spec's brutal
/// switch: yellow track when on, ink knob, knob-only hard shadow.
class NeoToggleRow extends StatelessWidget {
  const NeoToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      toggled: value,
      label: title,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.bodyLarge),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                ExcludeSemantics(child: _NeoSwitch(value: value)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NeoSwitch extends StatelessWidget {
  const _NeoSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
    return AnimatedContainer(
      duration: duration,
      width: 52,
      height: 28,
      decoration: BoxDecoration(
        color: value ? EditorialPalette.signal : EditorialPalette.slate,
        border: Border.all(
          color:
              value ? EditorialPalette.signal : EditorialPalette.mutedBorder,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: AnimatedAlign(
        duration: duration,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: value
                ? EditorialPalette.inkInverted
                : EditorialPalette.text2,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: value
                    ? EditorialPalette.signalDk
                    : EditorialPalette.inkInverted,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
