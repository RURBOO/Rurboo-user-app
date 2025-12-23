import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Terms & Conditions',
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
              'Terms of Service',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _TermSection(
              title: '1. Acceptance of Terms',
              content:
                  'By accessing or using the Rubo app, you agree to be bound by these Terms.',
            ),
            _TermSection(
              title: '2. Ride Services',
              content:
                  'Rubo connects riders with independent drivers. We are not responsible for the behavior of drivers or riders, though we enforce strict community guidelines.',
            ),
            _TermSection(
              title: '3. Payments',
              content:
                  'Riders must pay the fare shown in the app. Drivers must settle platform commissions daily/weekly as per the agreement.',
            ),
            _TermSection(
              title: '4. User Conduct',
              content:
                  'You agree not to use the service for unlawful purposes or to harass other users.',
            ),
            _TermSection(
              title: '5. Termination',
              content:
                  'We reserve the right to suspend accounts that violate safety policies or accumulate unpaid debt.',
            ),
          ],
        ),
      ),
    );
  }
}

class _TermSection extends StatelessWidget {
  final String title;
  final String content;
  const _TermSection({required this.title, required this.content});

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
          Text(content, style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}
