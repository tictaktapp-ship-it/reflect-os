import 'package:flutter/material.dart';

/// Simple scrollable viewer for bundled legal assets.
/// Used from Settings → Legal & Privacy for T&C and Privacy Policy.
class LegalDocumentViewerScreen extends StatelessWidget {
  const LegalDocumentViewerScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(assetPath),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final text = snap.data;
          if (text == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Document loading — visit reflect-os.com/legal',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.65,
                  ),
            ),
          );
        },
      ),
    );
  }
}
