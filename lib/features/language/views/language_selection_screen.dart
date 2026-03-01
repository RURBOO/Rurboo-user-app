import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rurboo/features/language/viewmodels/language_vm.dart';
import 'package:rurboo/features/onboarding/views/onboarding_screen.dart';
import 'package:rurboo/core/theme/app_colors.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final bool fromProfile;
  const LanguageSelectionScreen({super.key, this.fromProfile = false});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? selectedLang;

  void _onProceed() {
    if (selectedLang == null) return;
    
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    lang.setLanguage(selectedLang!);
    
    if (widget.fromProfile) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.fromProfile 
          ? AppBar(
              title: const Text("Language Selection", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              elevation: 0, 
              backgroundColor: Colors.transparent, 
              iconTheme: const IconThemeData(color: AppColors.textPrimary),
            ) 
          : null,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.primary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.fromProfile) ...[
                  const Spacer(),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
                      ),
                      child: const Icon(Icons.language_rounded, size: 64, color: AppColors.primary),
                    ),
                  ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      "Welcome to RURBOO",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ).animate().fade(delay: 200.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      "Choose your preferred language to continue",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ).animate().fade(delay: 300.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 48),
                ],

                Text(
                  "Select Language",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ).animate().fade(delay: 400.ms).slideX(begin: -0.1, end: 0),
                const SizedBox(height: 16),

                _LanguageCard(
                  title: "English",
                  subtitle: "Default Language",
                  isSelected: selectedLang == 'en',
                  onTap: () => setState(() => selectedLang = 'en'),
                ).animate().fade(delay: 500.ms).slideX(begin: 0.1, end: 0),

                const SizedBox(height: 16),

                _LanguageCard(
                  title: "हिन्दी",
                  subtitle: "हिन्दी भाषा",
                  isSelected: selectedLang == 'hi',
                  onTap: () => setState(() => selectedLang = 'hi'),
                ).animate().fade(delay: 600.ms).slideX(begin: 0.1, end: 0),

                const Spacer(),

                ElevatedButton(
                  onPressed: selectedLang != null ? _onProceed : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        selectedLang == 'hi' ? "आगे बढ़ें" : "Proceed",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ).animate().fade(delay: 800.ms).scale(begin: const Offset(0.9, 0.9)),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: 250.ms,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.translate_rounded,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 28),
          ],
        ),
      ),
    ).animate(target: isSelected ? 1 : 0).scale(
      begin: const Offset(1, 1),
      end: const Offset(1.02, 1.02),
      duration: 200.ms,
    );
  }
}
