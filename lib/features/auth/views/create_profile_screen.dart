import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rurboo/features/language/viewmodels/language_vm.dart';
import '../../../core/services/user_preferences.dart';
import '../../../core/services/notification_service.dart';
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

  String title = "Create your profile";
  String subtitle = "Please create your account.";
  String fullNameLbl = "Full Name";
  String genderLbl = "Gender";
  String emergencyLbl = "Emergency Number";
  String whatsappLbl = "Receive important updates on WhatsApp";
  String proceed = "Proceed";

  @override
  void initState() {
    super.initState();
    _translateTexts();
    
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
        _announceField("Full name darj karein. Apna pura naam likhein.");
      }
    });
    
    ageFocus.addListener(() {
      if (ageFocus.hasFocus) {
        _announceField("Apni umar darj karein.");
      }
    });
    
    emergencyFocus.addListener(() {
      if (emergencyFocus.hasFocus) {
        _announceField("Emergency contact number darj karein. 10 digit ka number.");
      }
    });
    
    guardianNameFocus.addListener(() {
      if (guardianNameFocus.hasFocus) {
        _announceField("Guardian ka naam darj karein.");
      }
    });
    
    guardianPhoneFocus.addListener(() {
      if (guardianPhoneFocus.hasFocus) {
        _announceField("Guardian ka phone number darj karein. 10 digit ka number.");
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

  Future<void> _translateTexts() async {
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    final res = await lang.translate([
      title,
      subtitle,
      fullNameLbl,
      genderLbl,
      emergencyLbl,
      whatsappLbl,
      proceed,
    ]);

    if (!mounted) return;

    setState(() {
      title = res[0];
      subtitle = res[1];
      fullNameLbl = res[2];
      genderLbl = res[3];
      emergencyLbl = res[4];
      whatsappLbl = res[5];
      proceed = res[6];
    });
  }

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
        ).showSnackBar(const SnackBar(content: Text("Please select gender")));
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
            const SnackBar(
              content: Text("Authentication Error. Please login again."),
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
        ).showSnackBar(SnackBar(content: Text("Failed to create profile: $e")));
      }
    }
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
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
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
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: nameController,
                          focusNode: nameFocus,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: fullNameLbl,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Enter full name";
                            if (v.trim().split(' ').length < 2) return "Enter First and Last name";
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

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
                                decoration: const InputDecoration(
                                  labelText: "Age",
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                onChanged: (v) => setState(() {}),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return "Required";
                                  int? age = int.tryParse(v);
                                  if (age == null || age < 5 || age > 100) return "Invalid";
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                initialValue: gender.isEmpty ? null : gender, // Use initialValue to fix deprecation
                                decoration: InputDecoration(
                                  labelText: genderLbl,
                                  border: const OutlineInputBorder(),
                                ),
                                items: ["Male", "Woman", "Other"].map((g) => 
                                  DropdownMenuItem(value: g, child: Text(g))).toList(),
                                onChanged: (v) => setState(() => gender = v!),
                                validator: (v) => v == null ? "Required" : null,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // --- USER CATEGORY ---
                        DropdownButtonFormField<String>(
                          initialValue: userCategory, // Use initialValue to fix deprecation
                          decoration: const InputDecoration(
                            labelText: "Category",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: ["Adult", "Woman", "Student", "Child"].map((c) => 
                            DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => userCategory = v!),
                          validator: (v) => v == null ? "Required" : null,
                        ),

                        const SizedBox(height: 20),

                        // --- GUARDIAN DETAILS (Conditional) ---
                        if (_isGuardianRequired()) ...[
                           Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.shield, color: Colors.orange, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      "Guardian Details Required",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: guardianNameController,
                                  focusNode: guardianNameFocus,
                                  decoration: const InputDecoration(
                                    labelText: "Guardian Name",
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (v) => _isGuardianRequired() && (v == null || v.isEmpty) 
                                      ? "Required" : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: guardianPhoneController,
                                  focusNode: guardianPhoneFocus,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [LengthLimitingTextInputFormatter(10)],
                                  decoration: const InputDecoration(
                                    labelText: "Guardian Phone",
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (v) => _isGuardianRequired() && (v == null || v.length != 10) 
                                      ? "Valid phone required" : null,
                                ),
                              ],
                            ),
                           ),
                           const SizedBox(height: 20),
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
                            labelText: emergencyLbl,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.contact_emergency),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Enter emergency contact";
                            if (v.length != 10) return "Enter valid 10-digit number";
                            return null;
                          },
                        ),
                        // ... Checkbox and Button ...
                        const SizedBox(height: 20),
                          Row(
                            children: [
                              Checkbox(
                                value: whatsappUpdates,
                                onChanged: (v) => setState(() => whatsappUpdates = v!),
                              ),
                              Expanded(child: Text(whatsappLbl)),
                            ],
                          ),
                          
                          const SizedBox(height: 10),
                          
                          // Referral Code Input
                          TextFormField(
                            controller: referralController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: "Referral Code (Optional)",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.confirmation_number_outlined),
                              hintText: "e.g. ADAR1234",
                            ),
                          ),

                        const SizedBox(height: 30),

                        ElevatedButton(
                          onPressed: submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(proceed, style: const TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
