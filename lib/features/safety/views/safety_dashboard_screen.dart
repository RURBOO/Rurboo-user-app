import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/safety_viewmodel.dart';
import 'package:flutter/services.dart';

import '../../language/viewmodels/language_vm.dart';

class SafetyDashboardScreen extends StatelessWidget {
  const SafetyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SafetyViewModel(),
      child: const _SafetyDashboardBody(),
    );
  }
}


class _SafetyDashboardBody extends StatelessWidget {
  const _SafetyDashboardBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SafetyViewModel>();
    final lang = Provider.of<LanguageViewModel>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("${lang.getText('safety_center')} 🛡️", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black,
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Safety Mode Toggle
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_moon, color: Colors.indigo, size: 28),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.getText('safety_mode'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    lang.getText('auto_share'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: vm.safetyMode,
                            onChanged: (val) => vm.toggleSafetyMode(val),
                            activeTrackColor: Colors.indigo,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 2. Trusted Contacts Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.getText('trusted_contacts'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddContactDialog(context, vm),
                      icon: const Icon(Icons.add),
                      label: Text(lang.getText('add_new')),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // 3. Contacts List
                if (vm.trustedContacts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(30),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.perm_contact_calendar_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text(
                          "No trusted contacts added yet.\nAdd family or friends for emergencies.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                else
                  ...vm.trustedContacts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final contact = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo[50],
                          child: Text(
                            contact['name'][0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                        ),
                        title: Text(contact['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(contact['phone']),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => vm.removeTrustedContact(index),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 24),
                
                // 4. Emergency Guidelines
                 const Text(
                  "Emergency Guidelines",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: Column(
                    children: [
                      Row(children: [const Icon(Icons.looks_one, size: 16), const SizedBox(width: 8), Expanded(child: Text(lang.getText('safety_tips_1')))]),
                      const SizedBox(height: 8),
                      Row(children: [const Icon(Icons.looks_two, size: 16), const SizedBox(width: 8), Expanded(child: Text(lang.getText('safety_tips_2')))]),
                      const SizedBox(height: 8),
                      Row(children: [const Icon(Icons.looks_3, size: 16), const SizedBox(width: 8), Expanded(child: Text(lang.getText('safety_tips_3')))]),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showAddContactDialog(BuildContext context, SafetyViewModel vm) {
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.getText('add_trusted_contact')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: lang.getText('full_name'),
                hintText: lang.getText('enter_contact_name_hint'),
                prefixIcon: const Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(
                labelText: lang.getText('guardian_phone'), // Using guardian_phone or similar short label
                hintText: lang.getText('enter_contact_phone_hint'),
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [LengthLimitingTextInputFormatter(10), FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.getText('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.length == 10) {
                vm.addTrustedContact(nameCtrl.text.trim(), phoneCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: Text(lang.getText('add_contact')),
          ),
        ],
      ),
    );
  }
}
