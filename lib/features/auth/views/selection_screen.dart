import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rubo/features/language/viewmodels/language_vm.dart';
import 'phone_input_screen.dart';

class SelectionScreen extends StatefulWidget {
  const SelectionScreen({super.key});

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  String buttonText = "Get Started";

  @override
  void initState() {
    super.initState();
    _translate();
  }

  Future<void> _translate() async {
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    final res = await lang.translate([buttonText]);

    if (!mounted) return;
    setState(() => buttonText = res.first);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/screen5.jpg', fit: BoxFit.cover),

          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black87],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: lang.loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Text(
                            "RUBO",
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                      ),
                      Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD54F),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 40,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PhoneInputScreen(),
                              ),
                            );
                          },
                          child: Text(
                            buttonText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
