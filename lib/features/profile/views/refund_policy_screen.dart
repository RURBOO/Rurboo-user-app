import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../language/viewmodels/language_vm.dart';

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    return Scaffold(
      
      appBar: AppBar(
        title: Text(
          lang.getText('refund_policy_menu'),
          style: const TextStyle(),
        ),
        elevation: 1,
        iconTheme: const IconThemeData(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.getText('rp_title'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _PolicySection(
              title: lang.getText('rp_can_user_title'),
              content: lang.getText('rp_can_user_body'),
            ),
            _PolicySection(
              title: lang.getText('rp_elig_title'),
              content: lang.getText('rp_elig_body'),
            ),
            _PolicySection(
              title: lang.getText('contact_us'),
              content: "${lang.getText('contact_us_desc')}\nEmail: adarshpandey@rurboo.com\nHelpline: +91 88102 20691",
            ),
            const SizedBox(height: 40),
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
            ),
          ),
        ],
      ),
    );
  }
}
