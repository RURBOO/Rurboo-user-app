import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rubo/features/language/viewmodels/language_vm.dart';
import 'package:rubo/features/onboarding/views/onboarding_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context, listen: false);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Select Your Language",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: () {
                  lang.setLanguage('en');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("English"),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  lang.setLanguage('hi');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("हिन्दी"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
