/// Shared Fresh Court building blocks: buttons, hairlines, chips, stats.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Full-width primary CTA — ball-green fill, deep-green Archivo caps.
/// The only ball-green button allowed per screen.
class RcPrimaryButton extends StatelessWidget {
  const RcPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: RcColors.ball,
            foregroundColor: RcColors.line,
            disabledBackgroundColor: RcColors.net,
            disabledForegroundColor: RcColors.lineDim,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(RcDims.radius)),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            label.toUpperCase(),
            style: RcType.heading.copyWith(color: RcColors.line),
          ),
        ),
      );
}

class RcOutlineButton extends StatelessWidget {
  const RcOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: RcColors.line,
          side: const BorderSide(color: RcColors.line, width: 1),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(RcDims.radius)),
          ),
        ),
        onPressed: onPressed,
        child: Text(label.toUpperCase(),
            style: RcType.heading.copyWith(fontSize: 16)),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// 1dp full-bleed divider that reads as a court line.
class Hairline extends StatelessWidget {
  const Hairline({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: RcDims.hairline);
}

/// Monospace stat with optional dim label, e.g. "FH 68".
class StatText extends StatelessWidget {
  const StatText({
    super.key,
    required this.value,
    this.label,
    this.size = 16,
    this.color = RcColors.line,
  });

  final String value;
  final String? label;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          if (label != null)
            TextSpan(
              text: '$label ',
              style: RcType.caption.copyWith(fontSize: size * 0.8),
            ),
          TextSpan(
            text: value,
            style: RcType.stat.copyWith(fontSize: size, color: color),
          ),
        ]),
      );
}

/// Selectable tile used in the drill grid — outline only, no fills.
class RcSelectTile extends StatelessWidget {
  const RcSelectTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(RcDims.radius)),
        child: AnimatedContainer(
          // Border snaps — no scale bounce, per motion rules.
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: RcColors.courtRaised,
            borderRadius:
                const BorderRadius.all(Radius.circular(RcDims.radius)),
            border: Border.all(
              color: selected ? RcColors.ballText : RcColors.net,
              width: selected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: RcType.heading.copyWith(
              fontSize: 16,
              color: selected ? RcColors.ballText : RcColors.line,
            ),
          ),
        ),
      );
}

/// Pill chip (coach picker, stroke filters).
class RcChip extends StatelessWidget {
  const RcChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.sublabel,
  });

  final String label;
  final String? sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? RcColors.ballText : RcColors.net,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: RcType.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? RcColors.ballText : RcColors.line,
                  )),
              if (sublabel != null)
                Text(sublabel!, style: RcType.caption),
            ],
          ),
        ),
      );
}

/// Status chip with a leading dot (camera setup, brain status).
class RcStatusChip extends StatelessWidget {
  const RcStatusChip({
    super.key,
    required this.text,
    required this.dotColor,
    this.pulsing = false,
  });

  final String text;
  final Color dotColor;
  final bool pulsing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: RcColors.court.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.all(Radius.circular(RcDims.radius)),
          border: Border.all(color: RcColors.net),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(color: dotColor, pulsing: pulsing),
            const SizedBox(width: 8),
            Text(text, style: RcType.body.copyWith(fontSize: 14)),
          ],
        ),
      );
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.pulsing});

  final Color color;
  final bool pulsing;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.pulsing && _c.isAnimating) {
      _c.stop();
      _c.value = 1.0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: widget.pulsing
            ? Tween(begin: 0.3, end: 1.0).animate(_c)
            : const AlwaysStoppedAnimation(1.0),
        child: Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      );
}

/// Streak dots: filled ball-green for active days, net outline for empty.
class StreakDots extends StatelessWidget {
  const StreakDots({super.key, required this.days, this.total = 7});

  final int days;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < days ? RcColors.ball : Colors.transparent,
                  border: i < days
                      ? null
                      : Border.all(color: RcColors.net, width: 1.5),
                ),
              ),
            ),
        ],
      );
}

/// Caption bar mirroring TTS — every spoken cue appears here (a11y).
class CaptionBar extends StatelessWidget {
  const CaptionBar({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: text.isEmpty
            ? const SizedBox.shrink()
            : Container(
                key: ValueKey(text),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: RcColors.line.withValues(alpha: 0.85),
                  borderRadius:
                      const BorderRadius.all(Radius.circular(RcDims.radius)),
                ),
                child: Text(
                  text,
                  style: RcType.body.copyWith(
                    fontSize: 20,
                    color: RcColors.court,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
      );
}
