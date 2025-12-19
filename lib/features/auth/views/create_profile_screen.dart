import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rubo/features/language/viewmodels/language_vm.dart';
import '../../../core/services/user_preferences.dart';
import '../../navigation/views/main_navigator.dart';

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

  String gender = "";
  bool whatsappUpdates = false;

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
        'emergencyContact': emergencyController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'whatsappUpdates': whatsappUpdates,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(newUserId)
          .set(userProfile);

      await UserPreferences.saveUserId(newUserId);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigator()),
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
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: fullNameLbl,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Enter your full name";
                            }
                            if (v.trim().split(' ').length < 2) {
                              return "Enter First and Last name";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),
                        Text(
                          genderLbl,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: ["Male", "Female", "Other"].map((g) {
                            final selected = gender == g;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: OutlinedButton(
                                  onPressed: () => setState(() => gender = g),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: selected
                                        ? Colors.yellow[100]
                                        : Colors.white,
                                    side: BorderSide(
                                      color: selected
                                          ? Colors.orange
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    g,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.orange
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 20),

                        TextFormField(
                          controller: emergencyController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: InputDecoration(
                            labelText: emergencyLbl,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Enter emergency contact number";
                            }
                            if (v.length != 10) {
                              return "Enter valid 10-digit number";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Checkbox(
                              value: whatsappUpdates,
                              onChanged: (v) =>
                                  setState(() => whatsappUpdates = v!),
                            ),
                            Expanded(child: Text(whatsappLbl)),
                          ],
                        ),

                        const SizedBox(height: 30),

                        ElevatedButton(
                          onPressed: submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: Text(proceed),
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
