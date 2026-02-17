import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../language/viewmodels/language_vm.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          lang.getText('privacy_policy'),
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
            _buildSection(lang.getText('pp_intro_title'), lang.getText('pp_intro_body')),
            _buildSection(lang.getText('pp_info_title'), lang.getText('pp_info_body')),
            _buildSection(lang.getText('pp_perms_title'), lang.getText('pp_perms_body')),
            _buildSection(lang.getText('pp_use_title'), lang.getText('pp_use_body')),
            _buildSection(lang.getText('pp_share_title'), lang.getText('pp_share_body')),
            _buildSection(lang.getText('pp_security_title'), lang.getText('pp_security_body')),
            _buildSection(lang.getText('pp_rights_title'), lang.getText('pp_rights_body')),
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
             lang.getText('pp_contact_title'),
             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
           ),
           const SizedBox(height: 8),
           Text(
             lang.getText('pp_contact_body'),
             style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.blueGrey),
           ),
         ],
       ),
     );
  }
}
