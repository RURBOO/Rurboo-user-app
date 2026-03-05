import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../language/viewmodels/language_vm.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String? currentEmail;
  final String? currentGender;
  final int? currentAge;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    this.currentEmail,
    this.currentGender,
    this.currentAge,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _phoneCtrl;
  final TextEditingController _otpCtrl = TextEditingController();

  String? _selectedGender;
  bool _isLoading = false;

  // Phone OTP flow
  bool _showOtpField = false;
  String? _verificationId;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  String? _newVerifiedPhone;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName);
    _emailCtrl = TextEditingController(text: widget.currentEmail ?? '');
    _ageCtrl = TextEditingController(text: widget.currentAge?.toString() ?? '');
    _phoneCtrl = TextEditingController();
    // Normalize old 'Woman' → 'Female'
    final g = widget.currentGender;
    _selectedGender = (g == 'Woman') ? 'Female' : g;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ── Email regex validator ──────────────────────────────────────────────────
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w.+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z0-9\-.]+$').hasMatch(email);
  }

  // ── Send OTP to new phone number ───────────────────────────────────────────
  Future<void> _sendOtp(LanguageViewModel lang) async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.getText('invalid_phone_10digits'))),
      );
      return;
    }

    setState(() => _sendingOtp = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        timeout: const Duration(seconds: 30),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _updatePhoneWithCredential(credential, lang);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _sendingOtp = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('OTP Error: ${e.message}')),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _showOtpField = true;
              _sendingOtp = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(lang.getText('otp_sent_success'))),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sendingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ── Verify OTP and update phone ────────────────────────────────────────────
  Future<void> _verifyOtp(LanguageViewModel lang) async {
    if (_verificationId == null || _otpCtrl.text.trim().length != 6) {
      // Show AlertDialog for invalid OTP input
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(lang.getText('invalid_otp_alert')),
            content: Text(lang.getText('enter_6digit_otp')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
    setState(() => _verifyingOtp = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
      );
      await _updatePhoneWithCredential(credential, lang);
    } catch (e) {
      if (mounted) {
        setState(() => _verifyingOtp = false);
        // Show AlertDialog for wrong OTP
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(lang.getText('invalid_otp_alert')),
            content: Text(lang.getText('invalid_otp_desc')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _updatePhoneWithCredential(PhoneAuthCredential credential, LanguageViewModel lang) async {
    try {
      await FirebaseAuth.instance.currentUser?.updatePhoneNumber(credential);
      final phone = '+91${_phoneCtrl.text.trim()}';
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'phoneNumber': phone,
        });
      }
      if (mounted) {
        setState(() {
          _newVerifiedPhone = phone;
          _showOtpField = false;
          _verifyingOtp = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('number_updated_success'))),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _verifyingOtp = false);
      rethrow; // Let _verifyOtp's catch show the AlertDialog
    }
  }

  // ── Save profile (name, email, gender, age) ────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'gender': _selectedGender,
          'age': int.tryParse(_ageCtrl.text.trim()),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.getText('profile_updated'))),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lang.getText('error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);

    final currentPhoneDisplay = _newVerifiedPhone ??
        FirebaseAuth.instance.currentUser?.phoneNumber ??
        '';

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.getText('edit_profile')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang.getText('basic_info'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              // ── Name ──────────────────────────────────────────────────
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: lang.getText('full_name'),
                  hintText: lang.getText('enter_name_hint'),
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? lang.getText('enter_full_name') : null,
              ),
              const SizedBox(height: 20),

              // ── Email ─────────────────────────────────────────────────
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: lang.getText('email'),
                  hintText: lang.getText('enter_email_hint'),
                  prefixIcon: const Icon(Icons.email),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null; // Email is optional
                  if (!_isValidEmail(v)) {
                    return lang.language == 'hi'
                        ? 'कृपया सही ईमेल दर्ज करें'
                        : 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Age & Gender Row ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: lang.getText('age'),
                        hintText: lang.getText('enter_age_hint'),
                        prefixIcon: const Icon(Icons.cake),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          final n = int.tryParse(v);
                          if (n == null || n < 5 || n > 120) {
                            return lang.language == 'hi' ? 'अमान्य' : 'Invalid';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: InputDecoration(
                        labelText: lang.getText('gender'),
                        prefixIcon: const Icon(Icons.people),
                        border: const OutlineInputBorder(),
                      ),
                      items: ['Male', 'Female', 'Other'].map((g) =>
                        DropdownMenuItem(
                          value: g,
                          child: Text(lang.getText(g.toLowerCase())),
                        ),
                      ).toList(),
                      onChanged: (v) => setState(() => _selectedGender = v),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Phone Number Update Section ───────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          lang.getText('update_mobile_number'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    if (currentPhoneDisplay.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${lang.getText('current_number_label')}: $currentPhoneDisplay',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // New phone input
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: lang.getText('new_mobile_number'),
                        prefixText: '+91 ',
                        counterText: '',
                        border: const OutlineInputBorder(),
                        suffixIcon: _sendingOtp
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : TextButton(
                                onPressed: () => _sendOtp(lang),
                                child: Text(
                                  lang.getText('send_otp'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                      ),
                    ),

                    // OTP field — appears after OTP is sent
                    if (_showOtpField) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _otpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                labelText: lang.getText('enter_otp_label'),
                                counterText: '',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _verifyingOtp
                              ? const SizedBox(
                                  width: 28, height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  onPressed: () => _verifyOtp(lang),
                                  child: Text(
                                    lang.getText('verify_otp_btn'),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                        ],
                      ),
                    ],

                    if (_newVerifiedPhone != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            lang.getText('number_updated_label'),
                            style: const TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ── Save Button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24, width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(lang.getText('save_changes'), style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
