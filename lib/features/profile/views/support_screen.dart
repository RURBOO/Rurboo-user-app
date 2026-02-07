import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../language/viewmodels/language_vm.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(Provider.of<LanguageViewModel>(context, listen: false).getText('cannot_perform_action'))),
          );
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(lang.getText('support')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.getText('need_help'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              lang.getText('contact_support_text'),
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.email_outlined, color: Colors.blue),
                title: Text(lang.getText('email_support')),
                subtitle: const Text('support@Rurboo.com'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _launch(
                  context,
                  Uri(
                    scheme: 'mailto',
                    path: 'support@Rurboo.com',
                    query: 'subject=Support Request',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.phone_in_talk, color: Colors.green),
                title: Text(lang.getText('call_helpline')),
                subtitle: const Text('+91 12345 67890'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () =>
                    _launch(context, Uri(scheme: 'tel', path: '+911234567890')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
