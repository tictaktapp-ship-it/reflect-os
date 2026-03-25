import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:reflect_os/core/design_system/tokens.dart';

/// Brand-consistent dialog shell used by every dialog in the app.
///
/// Wraps any content with:
///   - Centred on screen (Dialog widget, not bottom sheet)
///   - White background
///   - Rounded corners 16px
///   - 1.5px #19CBD6 border
///   - Brand icon (assets/branding/icon.svg) ~40px, centred at top
///   - Title below icon: fontWeight 600, fontSize 18, color #1A1A2E
///   - Content area with 24px horizontal padding
///   - BoxShadow blurRadius 20, Colors.black12
///   - Backdrop dismiss on tap outside (barrierDismissible: true)
class DialogShell extends StatelessWidget {
  const DialogShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Dialog(
      backgroundColor: cs.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF19CBD6), width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.backgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(blurRadius: 20, color: Colors.black12),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: SvgPicture.asset(
                  'assets/branding/icon.svg',
                  height: 40,
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: cs.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: child,
              ),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: actions!,
                  ),
                ),
              ] else
                const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
