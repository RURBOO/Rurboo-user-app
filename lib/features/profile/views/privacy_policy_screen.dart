import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy for Rubo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Last updated: January 2025',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 24),
            _PolicySection(
              title: '1. Information We Collect',
              content:
                  'We collect information you provide directly to us, including your name, phone number, location data (for ride matching), and transaction information.',
            ),
            _PolicySection(
              title: '2. Location Data Usage',
              content:
                  'Rubo collects location data to enable driver tracking, ride matching, and safety features even when the app is in the background (for drivers).',
            ),
            _PolicySection(
              title: '3. Information Sharing',
              content:
                  'We share your live location with the assigned driver/rider during an active trip. We do not sell your personal data to third parties.',
            ),
            _PolicySection(
              title: '4. Data Security',
              content:
                  'We use industry-standard encryption to protect your data stored in our secure cloud databases.',
            ),
            _PolicySection(
              title: '5. Account Deletion',
              content:
                  'You can delete your account at any time via the Settings menu. This will permanently remove your ride history and personal details.',
            ),
            _PolicySection(
              title: '6. Contact Us',
              content: 'If you have questions, contact us at: support@rubo.com',
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String content;

  const _PolicySection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
