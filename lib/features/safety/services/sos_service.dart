import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../language/viewmodels/language_vm.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class SOSService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Show the Dual-Option SOS Dialog
  Future<void> showSOSDialog({
    required BuildContext context,
    String? rideId,
    List<Map<String, dynamic>>? trustedContacts,
    String? guardianPhone,
  }) async {
    // If contacts aren't provided, try to fetch them silently or just use defaults
    // For now, we assume the caller (ViewModel) provides them if available,
    // or we fetch them if null.
    
    String? effectiveGuardianPhone = guardianPhone;
    
    if (effectiveGuardianPhone == null && (trustedContacts == null || trustedContacts.isEmpty)) {
       // Try quick fetch if missing
       try {
         final user = _auth.currentUser;
         if (user != null) {
            final doc = await _firestore.collection('users').doc(user.uid).get();
            if (doc.exists) {
              final data = doc.data();
              effectiveGuardianPhone = data?['guardianPhone'];
              if (effectiveGuardianPhone == null && data?['trustedContacts'] != null) {
                 final list = List<Map<String, dynamic>>.from(data?['trustedContacts']);
                 if (list.isNotEmpty) effectiveGuardianPhone = list.first['phone'];
              }
            }
         }
       } catch (e) {
         debugPrint("Error fetching contacts for SOS: $e");
       }
    } else if (effectiveGuardianPhone == null && trustedContacts != null && trustedContacts.isNotEmpty) {
      effectiveGuardianPhone = trustedContacts.first['phone'];
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Forces user to make a choice
      builder: (ctx) {
        final lang = Provider.of<LanguageViewModel>(context, listen: false); // Listen false as dialog might not rebuild
        return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.red, width: 2)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            const SizedBox(width: 10),
            Text(lang.getText('emergency_sos'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Who do you want to call?\n\nThis action will be logged for your safety.", // Keeping English for now as key might be missing, or add generic
          style: TextStyle(fontSize: 16),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Option 1: Call Guardian (if available)
              if (effectiveGuardianPhone != null) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _triggerCall(effectiveGuardianPhone!, rideId, 'guardian');
                  },
                  icon: const Icon(Icons.person),
                  label: Text("${lang.getText('call_guardian')} ($effectiveGuardianPhone)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Option 2: Call Police (112)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _triggerCall('112', rideId, 'police');
                },
                icon: const Icon(Icons.local_police),
                label: Text(lang.getText('call_police')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              const SizedBox(height: 10),
              
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(lang.getText('cancel'), style: const TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ],
      );
     },
    );
  }

  Future<void> _triggerCall(String phoneNumber, String? rideId, String type) async {
    // 1. Log the Alert First (Fire and Forget)
    _logSOSAlert(rideId, type, phoneNumber);

    // 2. Make the Call
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint("Could not launch call to $phoneNumber");
    }
  }

  Future<void> _logSOSAlert(String? rideId, String type, String sentTo) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('sos_alerts').add({
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'rideId': rideId,
        'status': 'active',
        'type': 'one_tap_sos',
        'callType': type, // guardian vs police
        'sentTo': sentTo,
        // We could add location here if we had position stream passed in
      });
      debugPrint("✅ SOS Incident Logged to Backend");
    } catch (e) {
      debugPrint("❌ Failed to log SOS: $e");
    }
  }
}
