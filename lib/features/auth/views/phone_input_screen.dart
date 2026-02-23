import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rurboo/features/language/viewmodels/language_vm.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
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
        final lang = Provider.of<LanguageViewModel>(context, listen: false);
        String msg = lang.getText('verification_failed');
        if (e.code == 'invalid-phone-number') {
          msg = lang.getText('invalid_phone_format');
        } else if (e.code == 'quota-exceeded') {
          msg = lang.getText('sms_quota_exceeded');
        } else if (e.code == 'billing-not-enabled') {
          msg = lang.getText('firebase_billing_error');
        } else {
          msg = "${lang.getText('error')}: ${e.message}";
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    "assets/images/app_logo.jpg",
                    height: 50,
                    errorBuilder: (c, e, s) => const Icon(Icons.local_taxi, size: 50, color: AppColors.primary),
                  ),
                ),
              ).animate().fade(duration: 500.ms).scale(curve: Curves.easeOutBack),
              
              const SizedBox(height: 32),
              Text(
                lang.getText('login_title'),
                style: theme.textTheme.headlineLarge,
              ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
              
              const SizedBox(height: 8),
              Text(
                lang.getText('login_subtitle'),
                style: theme.textTheme.bodyMedium,
              ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
              
              const SizedBox(height: 40),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  prefixIcon: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(right: 8),
                    child: Text(
                      "🇮🇳 +91",
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  hintText: lang.getText('enter_phone_hint'),
                  counterText: "",
                ),
              ).animate().fade(delay: 400.ms).slideY(begin: 0.2),
              
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
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Text(
                  lang.getText('proceed'),
                ),
              ).animate().fade(delay: 600.ms).slideY(begin: 0.3),
            ],
          ),
        ),
      ),
    );
  }
}
