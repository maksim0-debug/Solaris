import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/theme/app_theme.dart';
import 'package:glassmorphism/glassmorphism.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: GlassmorphicAppBar(
          title: Text(
            'Privacy Policy',
            style: GoogleFonts.outfit(
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
        child: FutureBuilder(
          future: rootBundle.loadString('assets/privacy_policy.md'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading privacy policy',
                  style: GoogleFonts.outfit(color: Colors.redAccent),
                ),
              );
            }

            return SafeArea(
              child: Markdown(
                data: snapshot.data ?? 'No content available',
                selectable: true,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                styleSheet: MarkdownStyleSheet(
                  h1: GoogleFonts.outfit(
                    color: AppTheme.accent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                  h2: GoogleFonts.outfit(
                    color: AppTheme.accent.withOpacity(0.9),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                  h3: GoogleFonts.outfit(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                  p: GoogleFonts.outfit(
                    color: AppTheme.textPrimary.withOpacity(0.8),
                    fontSize: 16,
                    height: 1.6,
                  ),
                  strong: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  listBullet: GoogleFonts.outfit(
                    color: AppTheme.accent,
                  ),
                  a: GoogleFonts.outfit(
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

class GlassmorphicAppBar extends StatelessWidget {
  final Widget title;
  final Widget? leading;

  const GlassmorphicAppBar({
    super.key,
    required this.title,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 70,
      borderRadius: 0,
      blur: 20,
      alignment: Alignment.bottomCenter,
      border: 1,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFFF).withOpacity(0.05),
          const Color(0xFFFFFF).withOpacity(0.02),
        ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFFF).withOpacity(0.1),
          const Color(0xFFFFFF).withOpacity(0.05),
        ],
      ),
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
