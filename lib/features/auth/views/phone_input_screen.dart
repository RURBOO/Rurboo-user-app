import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rurboo/features/language/viewmodels/language_vm.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/user_preferences.dart';
import '../../../core/theme/app_colors.dart';
import 'otp_screen.dart';
import 'location_disclosure_screen.dart';
import 'create_profile_screen.dart';
import '../../voice/viewmodels/voice_agent_viewmodel.dart'; // Added Voice Agent
class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final phoneCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = Provider.of<LanguageViewModel>(context, listen: false);
      final voice = Provider.of<VoiceAgentViewModel>(context, listen: false);
      voice.speak(lang.getText('voice_enter_phone_number'));
    });
  }

  void _next() async {
    if (_isLoading) return;

    final phone = phoneCtrl.text.trim();
    if (phone.length != 10) {
      final lang = Provider.of<LanguageViewModel>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.getText('uiEnterValidPhone'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        timeout: const Duration(seconds: 30), // Reduced from default 60s → 30s for faster OTP screen
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
            if (userCred.user != null) {
              if (mounted) {
                // Remove progress dialog if showing
                if (_isLoading) {
                  Navigator.pop(context);
                  setState(() => _isLoading = false);
                }

                final uid = userCred.user!.uid;
                await UserPreferences.saveUserId(uid);

                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get();

                if (!mounted) return;
                
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
                      builder: (_) => CreateProfileScreen(phoneNumber: phone),
                    ),
                  );
                }
              }
            }
          } catch (e) {
            debugPrint("Auto-verification failed: $e");
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            Navigator.pop(context);
            setState(() => _isLoading = false);
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
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            Navigator.pop(context);
            setState(() => _isLoading = false);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    OtpScreen(phone: phone, verificationId: verificationId),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    // Beautifully styled, uncropped logo
                    Center(
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.white, // Ensure white background for transparent logos
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: Image.asset(
                            "assets/images/app_logo.jpg",
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => Container(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.local_taxi, size: 70, color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                    ).animate().fade(duration: 600.ms).scale(curve: Curves.easeOutBack),
                    
                    const SizedBox(height: 48),
                    Text(
                      lang.getText('login_title'),
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
                    
                    const SizedBox(height: 12),
                    Text(
                      lang.getText('login_subtitle'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
                    
                    const SizedBox(height: 48),
                    
                    // Premium Text Input Field
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: AppColors.dividerColor.withValues(alpha: 0.5)),
                              ),
                            ),
                            child: Text(
                              "🇮🇳 +91",
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                hintText: lang.getText('enter_phone_hint'),
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                                counterText: "",
                              ),
                              cursorColor: AppColors.primary,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 400.ms).slideY(begin: 0.2),
                    
                    const Spacer(),
                    
                    // Premium Button
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
                        minimumSize: const Size(double.infinity, 60),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shadowColor: AppColors.primary.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        lang.getText('proceed'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ).animate().fade(delay: 600.ms).slideY(begin: 0.3),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
