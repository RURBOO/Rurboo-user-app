import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Cannot perform this action on this device."),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Help & Support"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              "How can we help you?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.email_outlined, color: Colors.blue),
            ),
            title: const Text("Email Support"),
            subtitle: const Text("support@rubo.com"),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _launch(
              context,
              Uri(scheme: 'mailto', path: 'support@rubo.com'),
            ),
          ),
          const Divider(height: 1, indent: 70),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.phone_outlined, color: Colors.green),
            ),
            title: const Text("Call Customer Care"),
            subtitle: const Text("+91 12345 67890"),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () =>
                _launch(context, Uri(scheme: 'tel', path: '+911234567890')),
          ),
          const Divider(height: 1, indent: 70),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.language, color: Colors.purple),
            ),
            title: const Text("Visit Website / FAQs"),
            subtitle: const Text("www.rubo.com/help"),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _launch(context, Uri.parse('https://www.google.com')),
          ),
        ],
      ),
    );
  }
}
