import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../language/viewmodels/language_vm.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(lang.getText('faq'), style: const TextStyle()),
        elevation: 1,
        iconTheme: const IconThemeData(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            lang.getText('faq_title'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          _FAQItem(
            question: lang.getText('faq_q1'),
            answer: lang.getText('faq_a1'),
          ),
          _FAQItem(
            question: lang.getText('faq_q2'),
            answer: lang.getText('faq_a2'),
          ),
          _FAQItem(
            question: lang.getText('faq_q3'),
            answer: lang.getText('faq_a3'),
          ),
          _FAQItem(
            question: lang.getText('faq_q4'),
            answer: lang.getText('faq_a4'),
          ),
          _FAQItem(
            question: lang.getText('faq_q5'),
            answer: lang.getText('faq_a5'),
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
              style: const TextStyle( height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
