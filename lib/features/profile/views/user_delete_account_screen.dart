import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/user_preferences.dart';
import '../../auth/views/phone_input_screen.dart';

class UserDeleteAccountScreen extends StatefulWidget {
  const UserDeleteAccountScreen({super.key});

  @override
  State<UserDeleteAccountScreen> createState() =>
      _UserDeleteAccountScreenState();
}

class _UserDeleteAccountScreenState extends State<UserDeleteAccountScreen> {
  bool _isLoading = false;

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final activeRides = await FirebaseFirestore.instance
          .collection('rideRequests')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'accepted', 'in_progress'])
          .get();

      if (activeRides.docs.isNotEmpty) {
        throw Exception(
          "You have an active ride. Please complete or cancel it first.",
        );
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'status': 'deleted',
        'phoneNumber':
            '${user.phoneNumber}_deleted_${DateTime.now().millisecondsSinceEpoch}',
        'deletedAt': FieldValue.serverTimestamp(),
      });

      await user.delete();

      await UserPreferences.clearUserData();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
          (r) => false,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Account deleted.")));
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains("requires-recent-login")) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please logout and login again to delete."),
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Delete Account")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              "Delete your account?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "This action is permanent. You will lose your ride history and saved places.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isLoading ? null : _deleteAccount,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Delete Permanently"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
