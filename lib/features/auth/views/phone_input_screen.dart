import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rurboo/features/language/viewmodels/language_vm.dart';
import 'otp_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final phoneCtrl = TextEditingController();

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
        String msg = "Verification failed";
        if (e.code == 'invalid-phone-number') {
          msg = "Invalid phone number format.";
        } else if (e.code == 'quota-exceeded') {
          msg = "SMS quota exceeded. Please try again later.";
        } else if (e.code == 'billing-not-enabled') {
          msg = "Firebase billing not enabled (dev error).";
        } else {
          msg = "Error: ${e.message}";
        }
        debugPrint("🔥 Phone Auth Error: ${e.code} - ${e.message}");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Image.asset(
                  "assets/images/app_logo.jpg",
                  height: 60,
                  errorBuilder: (c, e, s) => const SizedBox(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                lang.getText('login_title'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang.getText('login_subtitle'),
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
                  hintText: lang.getText('enter_phone_hint'),
                  counterText: "",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  final phone = phoneCtrl.text.trim();
                  if (phone.length != 10) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(lang.getText('enter_phone'))),
                    );
                    return;
                  }
                  _next();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(
                  lang.getText('proceed'),
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
