import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/theme/app_theme.dart';
import 'package:solaris/widgets/glass_card.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _fontFamily = 'Outfit';

  Future<String> _loadLocalizedPrivacyPolicy(BuildContext context) async {
    final localeCode = Localizations.localeOf(context).languageCode;
    final localizedAssetPath = 'assets/privacy_policy_$localeCode.md';

    try {
      return await rootBundle.loadString(localizedAssetPath);
    } catch (_) {
      // Fallback to primary English policy if target language asset is missing
      return await rootBundle.loadString('assets/privacy_policy.md');
    }
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
          future: _loadLocalizedPrivacyPolicy(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Text(
                  l10n.errorLoadingPrivacyPolicy,
                  style: const TextStyle(fontFamily: _fontFamily, color: Colors.redAccent),
                ),
              );
            }

            return SafeArea(
              child: Markdown(
                data: snapshot.data ?? 'No content available',
                selectable: true,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

  const _GlassAppBar({
    required this.title,
    this.leading,
  });

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

