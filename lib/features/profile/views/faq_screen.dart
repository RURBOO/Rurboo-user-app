import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('FAQ', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          Text(
            'Frequently Asked Questions',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          _FAQItem(
            question: 'How is the fare calculated?',
            answer:
                'Fares are calculated based on base fare + distance traveled. Night charges apply between 10 PM and 6 AM.',
          ),
          _FAQItem(
            question: 'How do I contact the driver?',
            answer:
                'Once a ride is booked, you can call the driver using the Phone icon on the tracking screen.',
          ),
          _FAQItem(
            question: 'Can I cancel a ride?',
            answer:
                'Yes, you can cancel before the driver arrives. Frequent cancellations may affect your rating.',
          ),
          _FAQItem(
            question: 'Is my payment secure?',
            answer:
                'We accept Cash and direct UPI payments. We do not store your banking details directly.',
          ),
          _FAQItem(
            question: 'How do I delete my account?',
            answer:
                'Go to Settings > Delete Account. This action is permanent.',
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;
  const _FAQItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: const TextStyle(color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
