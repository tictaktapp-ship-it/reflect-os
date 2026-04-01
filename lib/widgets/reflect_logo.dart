import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Two-line brand logo: teal icon mark + stacked REFLECT / DECISION INTELLIGENCE OS.
///
/// Scales uniformly via [iconSize]. Use [darkBackground] to force the
/// dark text colour when rendering on a dark surface that doesn't match the
/// current Material theme brightness (e.g. a teal splash screen).
class ReflectLogo extends StatelessWidget {
  const ReflectLogo({
    super.key,
    this.iconSize = 36,
    this.darkBackground = false,
  });

  final double iconSize;

  /// When `true`, forces light text regardless of the theme brightness.
  /// Leave `false` (default) to auto-detect via `Theme.of(context).brightness`.
  final bool darkBackground;

  @override
  Widget build(BuildContext context) {
    final isDark =
        darkBackground || Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/branding/icon.svg',
              width: iconSize,
              height: iconSize,
            ),
            const SizedBox(width: 8),
            Text(
              'REFLECT',
              style: TextStyle(
                fontSize: iconSize * 0.5,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFF4F5F7)
                    : const Color(0xFF0D1117),
                height: 1.1,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        Text(
          'DECISION INTELLIGENCE OS',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: iconSize * 0.24,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF19CBD6),
            letterSpacing: 1.5,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
