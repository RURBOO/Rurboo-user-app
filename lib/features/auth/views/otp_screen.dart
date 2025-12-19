import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rubo/features/language/viewmodels/language_vm.dart';
import '../../../core/services/user_preferences.dart';
import '../../navigation/views/main_navigator.dart';
import 'create_profile_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String verificationId;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.verificationId,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  String title = "Enter the OTP";
  String subtitle = "We have sent an OTP to";
  String resend = "Resend OTP in";

  int seconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _translateTexts();
  }

  void _startTimer() {
    _timer?.cancel();
    seconds = 30;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (seconds > 0) {
        setState(() => seconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _translateTexts() async {
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    final res = await lang.translate([title, subtitle, resend]);

    if (!mounted) return;
    setState(() {
      title = res[0];
      subtitle = res[1];
      resend = res[2];
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text).join();

    if (otp.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter 6-digit OTP")));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final uid = userCred.user!.uid;

      await UserPreferences.saveUserId(uid);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) return;
      Navigator.pop(context);

      if (userDoc.exists) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigator()),
          (_) => false,
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CreateProfileScreen(phoneNumber: widget.phone),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);

    if (lang.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
              Text("$subtitle ${widget.phone}"),
              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  6,
                  (i) => SizedBox(
                    width: 40,
                    child: TextField(
                      controller: _controllers[i],
                      maxLength: 1,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        counterText: "",
                        contentPadding: const EdgeInsets.all(
                          8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty && i < 5) {
                          FocusScope.of(context).nextFocus();
                        } else if (val.isEmpty && i > 0) {
                          FocusScope.of(context).previousFocus();
                        }
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Text(
                "$resend ${seconds}s",
                style: const TextStyle(color: Colors.grey),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Verify"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
