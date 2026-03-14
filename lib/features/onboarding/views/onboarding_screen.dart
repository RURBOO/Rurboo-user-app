import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rurboo/features/language/viewmodels/language_vm.dart';
import '../../auth/views/phone_input_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);

    final List<Map<String, String>> onboarding = [
      {
        'image': 'assets/images/screen1.jpg',
        'title1': lang.getText('onboarding_title1_1'),
        'title2': lang.getText('onboarding_title2_1'),
        'desc': lang.getText('onboarding_desc_1'),
      },
      {
        'image': 'assets/images/screen2.jpg',
        'title1': lang.getText('onboarding_title1_2'),
        'title2': lang.getText('onboarding_title2_2'),
        'desc': lang.getText('onboarding_desc_2'),
      },
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: onboarding.length,
              onPageChanged: (i) => setState(() => currentPage = i),
              itemBuilder: (_, i) {
                final item = onboarding[i];
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(item['image']!, fit: BoxFit.cover),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.8),
                              Colors.black,
                            ],
                            stops: const [0.3, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 140,
                      left: 30,
                      right: 30,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.3,
                              ),
                              children: [
                                TextSpan(text: item['title1']),
                                TextSpan(
                                  text: item['title2'],
                                  style: const TextStyle(
                                    color: Color(0xFFFFD84D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item['desc']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            Positioned(
              bottom: 35,
              left: 25,
              right: 25,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PhoneInputScreen(),
                      ),
                    ),
                    child: Text(
                      lang.getText('skip'), // "Skip"
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  Row(
                    children: List.generate(
                      onboarding.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: currentPage == i ? 20 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: currentPage == i
                              ? const Color(0xFFFFD84D)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  GestureDetector(
                    onTap: () {
                        if (currentPage < onboarding.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
                          );
                        }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD84D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            lang.getText('next'), // "Next"
                            style: const TextStyle(
                              
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_right_alt),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
