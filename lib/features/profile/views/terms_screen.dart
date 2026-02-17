import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../language/viewmodels/language_vm.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          lang.getText('terms_conditions_menu'),
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             _buildSection(lang.getText('ts_intro_title'), lang.getText('ts_intro_body')),
             _buildSection(lang.getText('ts_services_title'), lang.getText('ts_services_body')),
             _buildSection(lang.getText('ts_account_title'), lang.getText('ts_account_body')),
             _buildSection(lang.getText('ts_conduct_title'), lang.getText('ts_conduct_body')),
             _buildSection(lang.getText('ts_payment_title'), lang.getText('ts_payment_body')),
             _buildSection(lang.getText('ts_liability_title'), lang.getText('ts_liability_body')),
             _buildSection(lang.getText('ts_termination_title'), lang.getText('ts_termination_body')),
             _buildSection(lang.getText('ts_changes_title'), lang.getText('ts_changes_body')),
             _buildConactSection(lang),
             const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConactSection(LanguageViewModel lang) {
     return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: Colors.blue.withValues(alpha: 0.05),
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             lang.getText('contact_us'),
             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
           ),
           const SizedBox(height: 8),
           Text(
             "${lang.getText('contact_us_desc')} legal@rurboo.com",
             style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.blueGrey),
           ),
         ],
       ),
     );
  }
}
