import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/services/user_preferences.dart';
import '../../language/viewmodels/language_vm.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _suggestionController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitSuggestion(LanguageViewModel lang) async {
    if (_suggestionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.getText('enter_feedback_comment'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = await UserPreferences.getUserId();
      
      String userName = "Anonymous";
      if (userId != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (userDoc.exists) {
              userName = userDoc.data()?['name'] ?? "User";
          }
      }

      await FirebaseFirestore.instance.collection('suggestions').add({
        'userId': userId,
        'userName': userName,
        'type': 'improvement_suggestion',
        'comment': _suggestionController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'appType': 'user',
        'status': 'open',
        'version': '1.0.0',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.getText('suggestions_submitted')),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    
    return Scaffold(
      
      appBar: AppBar(
        title: Text(lang.getText('feedback_suggestions')),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.tips_and_updates, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              lang.getText('suggestions_title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              lang.getText('suggestions_desc_text'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _suggestionController, // Assuming _feedbackController is _suggestionController
              maxLines: 5,
              decoration: InputDecoration(
                hintText: lang.getText('suggestions_hint'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _submitSuggestion(lang),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        lang.getText('submit_review'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                lang.getText('help_build_better_rurboo'),
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
