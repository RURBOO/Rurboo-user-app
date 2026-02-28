import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:rurboo/features/language/viewmodels/language_vm.dart';
import '../../../core/services/user_preferences.dart';
import '../../../core/services/notification_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import 'create_profile_screen.dart';
import 'location_disclosure_screen.dart';

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
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  int seconds = 60;
  Timer? _timer;
  late String _verificationId;
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (seconds > 0) {
        setState(() => seconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    final otp = _pinController.text.trim();

    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.getText('enter_6_digit_otp'))),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );

      final UserCredential userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCred.user == null) {
        throw Exception("User is null after OTP verification");
      }

      final uid = userCred.user!.uid;
      await UserPreferences.saveUserId(uid);

      // Updating FCM Token
      final token = await NotificationService().getDeviceToken();
      if (token != null) await NotificationService().saveTokenToDatabase(token);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) return;
      Navigator.pop(context);

      if (userDoc.exists) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LocationDisclosureScreen()),
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
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.pop(context);
        debugPrint("Firebase OTP Error: ${e.code}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'invalid-verification-code'
                  ? lang.getText('invalid_otp')
                  : lang.getText('auth_failed').replaceAll('{error}', e.code),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        debugPrint("OTP Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                lang.getText('auth_failed').replaceAll('{error}', e.toString())),
          ),
        );
      }
    }
  }

  Future<void> _resendOtp() async {
    _startTimer();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${widget.phone}',
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          final lang =
              Provider.of<LanguageViewModel>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.getText('otp_resend_failed'))),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          final lang =
              Provider.of<LanguageViewModel>(context, listen: false);
          _verificationId = verificationId;
          _resendToken = resendToken;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.getText('otp_resent'))),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;
      final lang = Provider.of<LanguageViewModel>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.getText('otp_resend_failed'))),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    final theme = Theme.of(context);

    if (lang.loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final defaultPinTheme = PinTheme(
      width: 50,
      height: 56,
      textStyle: theme.textTheme.headlineMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerColor),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary),
      borderRadius: BorderRadius.circular(12),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                lang.getText('otp_title'),
                style: theme.textTheme.headlineLarge,
              ).animate().fade(duration: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 8),
              Text(
                "${lang.getText('otp_subtitle')} ${widget.phone}",
                style: theme.textTheme.bodyMedium,
              ).animate().fade(delay: 200.ms).slideY(begin: 0.1),

              const SizedBox(height: 40),

              // ─── Pinput OTP Field ───────────────────────────────────
              Center(
                child: Pinput(
                  length: 6,
                  controller: _pinController,
                  focusNode: _pinFocusNode,
                  autofocus: true,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: submittedPinTheme,
                  keyboardType: TextInputType.number,
                  closeKeyboardWhenCompleted: true,
                  onCompleted: (_) => _verifyOtp(),
                  cursor: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        width: 22,
                        height: 2,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
              ),

              const SizedBox(height: 32),

              // ─── Countdown / Resend ─────────────────────────────────
              Center(
                child: seconds == 0
                    ? TextButton(
                        onPressed: _resendOtp,
                        child: Text(
                          lang.getText('resend_otp_btn'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: AppColors.primary),
                        ),
                      )
                    : Text(
                        lang
                            .getText('resend_otp_msg')
                            .replaceAll('{seconds}', seconds.toString()),
                        style: theme.textTheme.bodyMedium,
                      ),
              ).animate().fade(delay: 600.ms),

              const Spacer(),

              ElevatedButton(
                onPressed: _verifyOtp,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Text(lang.getText('verify')),
              ).animate().fade(delay: 700.ms).slideY(begin: 0.2),
            ],
          ),
        ),
      ),
    );
  }
}
