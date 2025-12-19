import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rubo/features/language/viewmodels/language_vm.dart';
import '../../auth/views/selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int currentPage = 0;

  List<Map<String, String>> onboarding = [];

  final List<Map<String, String>> originalData = [
    {
      'image': 'assets/images/screen1.jpg',
      'title1': 'Easy way to book\n',
      'title2': 'your ride',
      'desc': 'Book your ride and get picked up by the nearest driver.',
    },
    {
      'image': 'assets/images/screen2.jpg',
      'title1': 'Select\n',
      'title2': 'your ride',
      'desc': 'Choose a ride type that suits your need and pricing.',
    },
    {
      'image': 'assets/images/screen3.jpg',
      'title1': 'Live ride\n',
      'title2': 'tracking',
      'desc': 'Track your ride in real-time with updates.',
    },
    {
      'image': 'assets/images/screen4.jpg',
      'title1': 'Share your\n',
      'title2': 'trip',
      'desc': 'Share your ride details with family/friends.',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTranslations();
    });
  }

  Future<void> _loadTranslations() async {
    final lang = Provider.of<LanguageViewModel>(context, listen: false);

    final texts = originalData
        .expand((e) => [e['title1']!, e['title2']!, e['desc']!])
        .toList();

    final translated = await lang.translateOnboarding(texts);

    List<Map<String, String>> result = [];
    int i = 0;

    for (var item in originalData) {
      result.add({
        'image': item['image']!,
        'title1': translated[i],
        'title2': translated[i + 1],
        'desc': translated[i + 2],
      });
      i += 3;
    }

    if (mounted) {
      setState(() => onboarding = result);
    }
  }

  void nextPage() {
    if (currentPage < onboarding.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);

    if (lang.loading || onboarding.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
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
                      child: Container(color: Colors.black.withOpacity(0.45)),
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
                        builder: (_) => const SelectionScreen(),
                      ),
                    ),
                    child: const Text(
                      "Skip",
                      style: TextStyle(
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
                    onTap: nextPage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD84D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            "Next",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_right_alt, color: Colors.black),
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
