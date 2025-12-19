import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rubo/features/language/viewmodels/language_vm.dart';
import 'otp_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final phoneCtrl = TextEditingController();

  String title = "Let's get started";
  String subtitle =
      "This number will be used for all ride-related communication. You will receive an SMS with a verification code.";
  String proceed = "Proceed";

  @override
  void initState() {
    super.initState();
    _translateTexts();
  }

  Future<void> _translateTexts() async {
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    final res = await lang.translate([title, subtitle, proceed]);

    if (!mounted) return;
    setState(() {
      title = res[0];
      subtitle = res[1];
      proceed = res[2];
    });
  }

  void _next() async {
    final phone = phoneCtrl.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid 10-digit number")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91$phone',
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
      },
      codeSent: (String verificationId, int? resendToken) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OtpScreen(phone: phone, verificationId: verificationId),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: lang.loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        prefix: const Text(
                          "🇮🇳 +91 ",
                          style: TextStyle(fontSize: 16),
                        ),
                        counterText: "",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(
                        proceed,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
