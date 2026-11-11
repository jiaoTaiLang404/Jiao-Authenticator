import 'package:flutter/material.dart';

Color countdownColor(ColorScheme colors, int remaining, int period) {
  final ratio = remaining / period;
  final dark = colors.brightness == Brightness.dark;
  if (ratio <= .2) {
    return dark ? const Color(0xffff6b6b) : const Color(0xffc62828);
  }
  if (ratio <= .5) {
    return dark ? const Color(0xfff5c451) : const Color(0xffa66c00);
  }
  return colors.primary;
}

class CountdownIndicator extends StatelessWidget {
  const CountdownIndicator({
    super.key,
    required this.remaining,
    required this.period,
  });
  final int remaining;
  final int period;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final target = countdownColor(colors, remaining, period);
    return Semantics(
      label: remaining / period <= .2
          ? '剩余 $remaining 秒，即将刷新'
          : '剩余 $remaining 秒',
      excludeSemantics: true,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: target),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        builder: (context, color, _) => SizedBox.square(
          dimension: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: remaining / period,
                  strokeWidth: 1.9,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: colors.outlineVariant,
                ),
              ),
              Text(
                '$remaining',
                textScaler: const TextScaler.linear(1),
                style: TextStyle(
                  color: color,
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
