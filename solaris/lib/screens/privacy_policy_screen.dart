import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/theme/app_theme.dart';
import 'package:solaris/widgets/glass_card.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  static const String _fontFamily = 'Outfit';

  late Future<String> _policyFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.maybeLocaleOf(context)?.languageCode;
    _policyFuture = _loadPrivacyPolicy(locale);
  }

  Future<String> _loadPrivacyPolicy(String? languageCode) async {
    final String assetPath;
    if (languageCode == 'uk') {
      assetPath = 'assets/privacy_policy_uk.md';
    } else if (languageCode == 'ru') {
      assetPath = 'assets/privacy_policy_ru.md';
    } else {
      assetPath = 'assets/privacy_policy.md';
    }

    try {
      return await rootBundle.loadString(assetPath);
    } catch (_) {
      return await rootBundle.loadString('assets/privacy_policy.md');
    }
  }

  void _retryLoading() {
    setState(() {
      final locale = Localizations.maybeLocaleOf(context)?.languageCode;
      _policyFuture = _loadPrivacyPolicy(locale);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: _GlassAppBar(
          title: Text(
            l10n.privacyPolicy,
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 0.5,
            ),
          ),
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.background,
              Color(0xFF0F172A),
              AppTheme.background,
            ],
          ),
        ),
        child: FutureBuilder<String>(
          future: _policyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.accent,
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.alertTriangle,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.errorLoadingPrivacyPolicy,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: _fontFamily,
                          color: Colors.redAccent,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _retryLoading,
                        icon: const Icon(LucideIcons.refreshCw, size: 18),
                        label: Text(l10n.tryAgain),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accent,
                          side: const BorderSide(color: AppTheme.accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SafeArea(
              child: Markdown(
                data: snapshot.data!,
                selectable: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                styleSheet: MarkdownStyleSheet(
                  h1: const TextStyle(
                    fontFamily: _fontFamily,
                    color: AppTheme.accent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                  h2: TextStyle(
                    fontFamily: _fontFamily,
                    color: AppTheme.accent.withOpacity(0.9),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                  h3: const TextStyle(
                    fontFamily: _fontFamily,
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                  p: TextStyle(
                    fontFamily: _fontFamily,
                    color: AppTheme.textPrimary.withOpacity(0.8),
                    fontSize: 16,
                    height: 1.6,
                  ),
                  strong: const TextStyle(
                    fontFamily: _fontFamily,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  listBullet: const TextStyle(
                    fontFamily: _fontFamily,
                    color: AppTheme.accent,
                  ),
                  a: const TextStyle(
                    fontFamily: _fontFamily,
                    color: AppTheme.accent,
                    decoration: TextDecoration.underline,
                  ),
                  blockSpacing: 20,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Replaces the external glassmorphism package's GlassmorphicContainer
/// with the project's own GlassCard, eliminating an unnecessary dependency.
class _GlassAppBar extends StatelessWidget {
  final Widget title;
  final Widget? leading;

  const _GlassAppBar({required this.title, this.leading});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 0,
      blur: 20,
      opacity: 0.03,
      padding: EdgeInsets.zero,
      child: AppBar(
        title: title,
        leading: leading,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}

