import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Two-line brand logo: teal hexagon mark + "REFLECT" wordmark + "DECISION
/// INTELLIGENCE OS" tagline spanning the full combined width.
///
/// Layout:
///   ┌──────┐  REFLECT
///   │ mark │  DECISION INTELLIGENCE OS
///   └──────┘
///
/// [CrossAxisAlignment.stretch] on the outer Column forces the tagline widget
/// to be exactly as wide as the Row above it. [letterSpacing] is proportional
/// to [iconSize] so the rendered text width ≈ icon + gap + wordmark width at
/// every size, making the tagline visually span edge-to-edge.
class ReflectLogo extends StatelessWidget {
  const ReflectLogo({
    super.key,
    this.iconSize = 32,
    this.iconColor,
    this.textColor,
    this.subtitleColor,
  });

  final double iconSize;
  final Color? iconColor;
  final Color? textColor;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedTextColor =
        textColor ?? (isDark ? Colors.white : const Color(0xFF0D1117));
    final resolvedSubtitleColor = subtitleColor ?? const Color(0xFF19CBD6);

    final iconWidget = SvgPicture.asset(
      'assets/branding/icon.svg',
      width: iconSize,
      height: iconSize,
    );

    final wordmarkWidget = Text(
      'REFLECT',
      style: TextStyle(
        fontSize: iconSize * 0.62,
        fontWeight: FontWeight.w500,
        fontFamily: 'DMSans',
        color: resolvedTextColor,
        letterSpacing: iconSize * 0.06,
        height: 1.0,
      ),
    );

    final taglineWidget = Text(
      'DECISION INTELLIGENCE OS',
      style: TextStyle(
        fontSize: iconSize * 0.21,
        fontWeight: FontWeight.w300,
        fontFamily: 'DMSans',
        color: resolvedSubtitleColor,
        letterSpacing: iconSize * 0.05,
        height: 1.0,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            iconWidget,
            SizedBox(width: iconSize * 0.18),
            wordmarkWidget,
          ],
        ),
        SizedBox(height: iconSize * 0.06),
        taglineWidget,
      ],
    );
  }
}
