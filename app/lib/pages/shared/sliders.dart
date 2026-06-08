import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class SliderCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value, min, max;
  final Color color;
  final ValueChanged<double> onChanged;
  const SliderCard({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    this.min = 0,
    this.max = 255,
    required this.color,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final pct = ((value - min) / (max - min) * 100).round();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: color.withAlpha(25),
                  ),
                  child: Text(
                    t.brightnessPercent(pct),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 6,
                thumbShape: GlowThumb(color: color),
                activeTrackColor: color,
                inactiveTrackColor: color.withAlpha(30),
                thumbColor: color,
                overlayColor: color.withAlpha(20),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlowThumb extends RoundSliderThumbShape {
  final Color color;
  const GlowThumb({required this.color}) : super(enabledThumbRadius: 10);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final r = 10.0 * enableAnimation.value;
    canvas.drawCircle(center, r + 4, Paint()..color = color.withAlpha(34));
    canvas.drawCircle(center, r, Paint()..color = color.withAlpha(180));
    canvas.drawCircle(center, r, Paint()..color = Colors.white.withAlpha(200));
    canvas.drawCircle(center, r * 0.75, Paint()..color = color);
  }
}

class ChannelSlider extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;
  const ChannelSlider({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Row(
            children: [
              Icon(Icons.circle, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: color,
              inactiveTrackColor: color.withAlpha(25),
              thumbColor: color,
              overlayColor: color.withAlpha(20),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              onChanged: (x) => onChanged(x.round()),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
