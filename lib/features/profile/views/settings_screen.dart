import 'package:flutter/material.dart';
import '../../language/views/language_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _promoEmails = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Preferences",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.translate, color: Colors.black87),
            title: const Text("App Language"),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LanguageSelectionScreen(),
                ),
              );
            },
          ),
          const Divider(),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.black,
            title: const Text("Push Notifications"),
            subtitle: const Text("Receive updates about your ride"),
            value: _pushNotifications,
            onChanged: (val) {
              setState(() => _pushNotifications = val);
            },
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.black,
            title: const Text("Promotional Emails"),
            value: _promoEmails,
            onChanged: (val) {
              setState(() => _promoEmails = val);
            },
          ),

          const Divider(),
          const SizedBox(height: 20),

          const Text(
            "About",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),

          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("App Version"),
            trailing: Text("1.0.0", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
