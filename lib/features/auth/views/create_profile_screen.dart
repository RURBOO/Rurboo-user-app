import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rurboo/features/language/viewmodels/language_vm.dart';
import '../../../core/services/user_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import 'location_disclosure_screen.dart';
import '../../voice/viewmodels/voice_agent_viewmodel.dart';


class CreateProfileScreen extends StatefulWidget {
  final String phoneNumber;
  const CreateProfileScreen({super.key, required this.phoneNumber});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emergencyController = TextEditingController();
  final referralController = TextEditingController(); // Moved to class level
  
  // New Safety Fields
  final ageController = TextEditingController();
  final guardianNameController = TextEditingController();
  final guardianPhoneController = TextEditingController();
  
  // Focus Nodes for placeholder announcements
  final nameFocus = FocusNode();
  final ageFocus = FocusNode();
  final emergencyFocus = FocusNode();
  final guardianNameFocus = FocusNode();
  final guardianPhoneFocus = FocusNode();
  
  String gender = "";
  String? userCategory;
  bool whatsappUpdates = false;

  bool _isGuardianRequired() {
    int age = int.tryParse(ageController.text) ?? 18;
    // Rule: Guardian mandatory if Age < 18 OR Category is Child
    // Exception: Student >= 18 does not need guardian
    if (userCategory == 'Child') return true;
    if (age < 18) return true;
    return false;
  }

  // Removed hardcoded strings used for translation

  @override
  void initState() {
    super.initState();
    
    // Setup focus listeners for placeholder announcements
    _setupFocusListeners();
    
    // Auto-start Voice Agent
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final voice = Provider.of<VoiceAgentViewModel>(context, listen: false);
       voice.startProfileCreation();
       voice.addListener(_onVoiceUpdate);
    });
  }
  
  void _setupFocusListeners() {
    nameFocus.addListener(() {
      if (nameFocus.hasFocus) {
        _announceField(lang.getText('profile_name_voice'));
      }
    });
    
    ageFocus.addListener(() {
      if (ageFocus.hasFocus) {
        _announceField(lang.getText('profile_age_voice'));
      }
    });
    
    emergencyFocus.addListener(() {
      if (emergencyFocus.hasFocus) {
        _announceField(lang.getText('profile_emergency_voice'));
      }
    });
    
    guardianNameFocus.addListener(() {
      if (guardianNameFocus.hasFocus) {
        _announceField(lang.getText('profile_guardian_name_voice'));
      }
    });
    
    guardianPhoneFocus.addListener(() {
      if (guardianPhoneFocus.hasFocus) {
        _announceField(lang.getText('profile_guardian_phone_voice'));
      }
    });
  }
  
  void _announceField(String message) {
    final voice = Provider.of<VoiceAgentViewModel>(context, listen: false);
    voice.speak(message);
  }

  @override
  void dispose() {
    final voice = Provider.of<VoiceAgentViewModel>(context, listen: false);
    voice.removeListener(_onVoiceUpdate);
    
    // Dispose focus nodes
    nameFocus.dispose();
    ageFocus.dispose();
    emergencyFocus.dispose();
    guardianNameFocus.dispose();
    guardianPhoneFocus.dispose();
    
    super.dispose();
  }

  void _onVoiceUpdate() {
     final voice = Provider.of<VoiceAgentViewModel>(context, listen: false);
     
     if (voice.tempName != null && nameController.text != voice.tempName) {
       nameController.text = voice.tempName!;
     }
     if (voice.tempAge != null && ageController.text != voice.tempAge) {
       ageController.text = voice.tempAge!;
     }
     if (voice.tempCategory != null && userCategory != voice.tempCategory) {
       setState(() {
         userCategory = voice.tempCategory;
         // Auto-set gender if Woman
         if (userCategory == 'Woman') gender = "Woman";
       });
     }
     
     // Auto-Submit if logic allows? Maybe just wait for user to press button or say "Save"
     // For now, let's keep it manual save or via "Confirm" voice command later
  }

  // Removed _translateTexts as it is replaced by lang.getText in build

  String _generateReferralCode(String name) {
    String prefix = name.trim().replaceAll(" ", "").toUpperCase();
    if (prefix.length > 4) prefix = prefix.substring(0, 4);
    if (prefix.isEmpty) prefix = "USER";
    
    // Add 4 random digits
    final random = DateTime.now().millisecondsSinceEpoch.toString(); 
    final suffix = random.substring(random.length - 4);
    
    return "$prefix$suffix";
  }

  Future<void> _processReferral(String newUserId, String enteredCode) async {
    if (enteredCode.isEmpty) return;
    
    try {
       final query = await FirebaseFirestore.instance
           .collection('users')
           .where('referralCode', isEqualTo: enteredCode)
           .limit(1)
           .get();
           
       if (query.docs.isNotEmpty) {
         final referrerDoc = query.docs.first;
         final referrerId = referrerDoc.id;
         
         // 1. Credit Referrer
         await FirebaseFirestore.instance
             .collection('users')
             .doc(referrerId)
             .collection('coupons')
             .add({
               'code': 'REF-${DateTime.now().millisecondsSinceEpoch}',
               'amount': 50.0,
               'type': 'referral_bonus',
               'isUsed': false,
               'createdAt': FieldValue.serverTimestamp(),
               'expiryDate': DateTime.now().add(const Duration(days: 30)),
               'description': 'Referral Bonus for inviting a friend'
             });
             
         // 2. Link New User (Optional, strict mapping)
         await FirebaseFirestore.instance.collection('users').doc(newUserId).update({
           'referredBy': referrerId,
           'redeemedReferralCode': enteredCode,
         });
       }
    } catch (e) {
      debugPrint("Referral Error: $e");
    }
  }

  void submit() async {
    if (!formKey.currentState!.validate() || gender.isEmpty) {
      if (gender.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(lang.getText('select_gender'))));
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lang.getText('auth_error_login_again')),
            ),
          );
        }
        return;
      }

      String newUserId = user.uid;

      final userProfile = {
        'uid': newUserId,
        'phoneNumber': widget.phoneNumber,
        'name': nameController.text.trim(),
        'gender': gender,
        'age': int.tryParse(ageController.text) ?? 18,
        'userCategory': userCategory ?? 'Adult',
        'guardianName': _isGuardianRequired() ? guardianNameController.text.trim() : null,
        'guardianPhone': _isGuardianRequired() ? guardianPhoneController.text.trim() : null,
        'emergencyContact': emergencyController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'whatsappUpdates': whatsappUpdates,
        'safetyModeEnabled': (gender == 'Woman' || userCategory == 'Child'), // Auto-enable for safety
        'fcmToken': await NotificationService().getDeviceToken(),
      };

      // Referral Code Logic removed from here (moved to class level)

      await FirebaseFirestore.instance
          .collection('users')
          .doc(newUserId)
          .set({
            ...userProfile,
            'referralCode': _generateReferralCode(nameController.text),
          });

      // Process Referral if code entered
      if (referralController.text.trim().isNotEmpty) {
         await _processReferral(newUserId, referralController.text.trim().toUpperCase());
      }

      await UserPreferences.saveUserId(newUserId);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LocationDisclosureScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(lang.getText('create_profile_failed').replaceAll('{error}', e.toString()))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: lang.loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          lang.getText('create_profile_title'),
                          style: theme.textTheme.headlineLarge,
                        ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
                        const SizedBox(height: 8),
                        Text(
                          lang.getText('create_profile_subtitle'),
                          style: theme.textTheme.bodyMedium,
                        ).animate().fade(delay: 150.ms).slideY(begin: 0.1),
                        const SizedBox(height: 28),

                        TextFormField(
                          controller: nameController,
                          focusNode: nameFocus,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                          ],
                          decoration: InputDecoration(
                            labelText: lang.getText('full_name_label'),
                            prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return lang.getText('enter_full_name');
                            if (v.trim().split(' ').length < 2) return lang.getText('enter_first_last_name');
                            return null;
                          },
                        ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
                        const SizedBox(height: 16),

                        // --- AGE & GENDER ROW ---
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: ageController,
                                focusNode: ageFocus,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                decoration: InputDecoration(
                                  labelText: lang.getText('age_label'),
                                  prefixIcon: const Icon(Icons.calendar_today, color: AppColors.textSecondary),
                                ),
                                onChanged: (v) => setState(() {}),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return lang.getText('required');
                                  int? age = int.tryParse(v);
                                  if (age == null || age < 5 || age > 100) return lang.getText('invalid');
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                initialValue: gender.isEmpty ? null : gender,
                                decoration: InputDecoration(
                                  labelText: lang.getText('gender_label'),
                                ),
                                items: ["Male", "Woman", "Other"].map((g) =>
                                  DropdownMenuItem(value: g, child: Text(lang.getText(g.toLowerCase())))).toList(),
                                onChanged: (v) => setState(() => gender = v!),
                                validator: (v) => v == null ? lang.getText('required') : null,
                              ),
                            ),
                          ],
                        ).animate().fade(delay: 250.ms).slideY(begin: 0.1),

                        const SizedBox(height: 16),

                        // --- USER CATEGORY ---
                        DropdownButtonFormField<String>(
                          initialValue: userCategory,
                          decoration: InputDecoration(
                            labelText: lang.getText('category_label'),
                            prefixIcon: const Icon(Icons.category_outlined, color: AppColors.textSecondary),
                          ),
                          items: ["Adult", "Woman", "Student", "Child"].map((c) =>
                            DropdownMenuItem(value: c, child: Text(lang.getText(c.toLowerCase())))).toList(),
                          onChanged: (v) => setState(() => userCategory = v!),
                          validator: (v) => v == null ? lang.getText('required') : null,
                        ).animate().fade(delay: 300.ms).slideY(begin: 0.1),

                        const SizedBox(height: 16),

                        // --- GUARDIAN DETAILS (Conditional) ---
                        if (_isGuardianRequired()) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.shield, color: Colors.orange, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      lang.getText('guardian_required_title'),
                                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.orange),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                  TextFormField(
                                    controller: guardianNameController,
                                    focusNode: guardianNameFocus,
                                    decoration: InputDecoration(
                                      labelText: lang.getText('guardian_name_label'),
                                      fillColor: AppColors.surface,
                                      filled: true,
                                    ),
                                    validator: (v) => _isGuardianRequired() && (v == null || v.isEmpty)
                                        ? lang.getText('required') : null,
                                  ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: guardianPhoneController,
                                  focusNode: guardianPhoneFocus,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [LengthLimitingTextInputFormatter(10)],
                                    decoration: InputDecoration(
                                      labelText: lang.getText('guardian_phone_label'),
                                      fillColor: AppColors.surface,
                                      filled: true,
                                    ),
                                    validator: (v) => _isGuardianRequired() && (v == null || v.length != 10)
                                        ? lang.getText('invalid') : null,
                                  ),
                              ],
                            ),
                          ).animate().fade().scale(begin: const Offset(0.95, 0.95)),
                          const SizedBox(height: 16),
                        ],

                        TextFormField(
                          controller: emergencyController,
                          focusNode: emergencyFocus,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: InputDecoration(
                            labelText: lang.getText('emergency_contact_label'),
                            prefixIcon: const Icon(Icons.contact_emergency, color: AppColors.textSecondary),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return lang.getText('required');
                            if (v.length != 10) return lang.getText('invalid');
                            return null;
                          },
                        ).animate().fade(delay: 350.ms).slideY(begin: 0.1),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: whatsappUpdates,
                              activeColor: AppColors.primary,
                              onChanged: (v) => setState(() => whatsappUpdates = v!),
                            ),
                            Expanded(child: Text(lang.getText('whatsapp_updates_label'), style: theme.textTheme.bodyMedium)),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Referral Code Input
                        TextFormField(
                          controller: referralController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: lang.getText('referral_code_optional'),
                            prefixIcon: const Icon(Icons.confirmation_number_outlined, color: AppColors.textSecondary),
                            hintText: "e.g. ADAR1234",
                          ),
                        ).animate().fade(delay: 400.ms).slideY(begin: 0.1),

                        const SizedBox(height: 32),

                        ElevatedButton(
                          onPressed: submit,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                          ),
                          child: Text(lang.getText('proceed')),
                        ).animate().fade(delay: 500.ms).slideY(begin: 0.2),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
