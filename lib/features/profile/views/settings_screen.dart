import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../language/views/language_selection_screen.dart';
import '../../../features/language/viewmodels/language_vm.dart';

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
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.getText('uiSettings')),
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            lang.getText('uiPreferences'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.translate),
            title: Text(lang.getText('uiAppLanguage')),
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
            activeThumbColor: Colors.black,
            title: Text(lang.getText('uiPushNotifications')),
            subtitle: Text(lang.getText('uiReceiveRideUpdates')),
            value: _pushNotifications,
            onChanged: (val) {
              setState(() => _pushNotifications = val);
            },
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: Colors.black,
            title: Text(lang.getText('uiPromotionalEmails')),
            value: _promoEmails,
            onChanged: (val) {
              setState(() => _promoEmails = val);
            },
          ),

          const Divider(),
          const SizedBox(height: 20),

          Text(
            lang.getText('uiAbout'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(lang.getText('uiAppVersion')),
            trailing: const Text("1.0.0", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
