import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/constants/legal_versions.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/features/legal/providers/legal_consent_provider.dart';

/// /legal-acceptance — shown between account creation and subscription.
/// When [allowBack] is true (accessed from Settings) the back button works.
/// When [allowBack] is false (gate mode) back navigation is blocked.
class LegalAcceptanceScreen extends ConsumerStatefulWidget {
  const LegalAcceptanceScreen({super.key, this.allowBack = false});

  final bool allowBack;

  @override
  ConsumerState<LegalAcceptanceScreen> createState() =>
      _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState
    extends ConsumerState<LegalAcceptanceScreen> {
  bool _tcAccepted = false;
  bool _privacyAccepted = false;
  bool _cookieConsent = true; // pre-ticked, web only
  bool _isSubmitting = false;

  bool get _canActivate => _tcAccepted && _privacyAccepted;

  Future<void> _activate() async {
    if (!_canActivate || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(legalConsentCheckProvider.notifier)
          .acceptConsent(kIsWeb ? _cookieConsent : false);
      if (mounted) {
        // Router redirect will send to billing or dashboard as appropriate.
        context.go(Routes.dashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record consent: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: widget.allowBack,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1E),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Logo ────────────────────────────────────────────
                      Center(
                        child: SvgPicture.asset(
                          isDark
                              ? 'assets/branding/icon.svg'
                              : 'assets/branding/icon.svg',
                          height: 72,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Heading ─────────────────────────────────────────
                      Text(
                        'Before you continue',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please review and accept our agreements to activate your account.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                      ),
                      const SizedBox(height: 24),

                      // ── Tab viewer ──────────────────────────────────────
                      DefaultTabController(
                        length: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TabBar(
                              tabs: const [
                                Tab(text: 'Terms & Conditions'),
                                Tab(text: 'Privacy Policy'),
                              ],
                              labelColor: const Color(0xFF0D7377),
                              unselectedLabelColor:
                                  Colors.white.withValues(alpha: 0.5),
                              indicatorColor: const Color(0xFF0D7377),
                              dividerColor: Colors.white.withValues(alpha: 0.1),
                            ),
                            SizedBox(
                              height: screenHeight * 0.40,
                              child: TabBarView(
                                children: [
                                  _LegalDocTab(
                                    assetPath:
                                        'assets/legal/terms_and_conditions.txt',
                                    fallbackMessage:
                                        'Document loading — visit reflect-os.com/legal',
                                  ),
                                  _LegalDocTab(
                                    assetPath:
                                        'assets/legal/privacy_policy.txt',
                                    fallbackMessage:
                                        'Document loading — visit reflect-os.com/legal',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Checkboxes ──────────────────────────────────────
                      _ConsentCheckbox(
                        value: _tcAccepted,
                        onChanged: (v) =>
                            setState(() => _tcAccepted = v ?? false),
                        label:
                            'I have read and agree to the Terms & Conditions (v${LegalVersions.tcVersion})',
                      ),
                      const SizedBox(height: 8),
                      _ConsentCheckbox(
                        value: _privacyAccepted,
                        onChanged: (v) =>
                            setState(() => _privacyAccepted = v ?? false),
                        label:
                            'I have read and understood the Privacy Policy (v${LegalVersions.privacyVersion})',
                      ),

                      // ── Cookie consent (web only) ───────────────────────
                      if (kIsWeb) ...[
                        const SizedBox(height: 8),
                        _ConsentCheckbox(
                          value: _cookieConsent,
                          onChanged: (v) =>
                              setState(() => _cookieConsent = v ?? true),
                          label:
                              'I consent to functional cookies (theme preference, workspace memory)',
                          optional: true,
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Activate button ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7377),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF0D7377).withValues(alpha: 0.35),
                      disabledForegroundColor:
                          Colors.white.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _canActivate && !_isSubmitting ? _activate : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Activate Account',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Legal document tab ────────────────────────────────────────────────────────

class _LegalDocTab extends StatefulWidget {
  const _LegalDocTab({
    required this.assetPath,
    required this.fallbackMessage,
  });

  final String assetPath;
  final String fallbackMessage;

  @override
  State<_LegalDocTab> createState() => _LegalDocTabState();
}

class _LegalDocTabState extends State<_LegalDocTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<String>(
      future: DefaultAssetBundle.of(context).loadString(widget.assetPath),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final text = snap.data;
        return Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              text ?? widget.fallbackMessage,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: text != null
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.45),
                fontFamily: 'monospace',
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Consent checkbox ──────────────────────────────────────────────────────────

class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.onChanged,
    required this.label,
    this.optional = false,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF0D7377),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: optional
                        ? Colors.white.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
