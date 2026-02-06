import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/safety_viewmodel.dart';
import 'package:flutter/services.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Safety Center 🛡️", style: TextStyle(fontWeight: FontWeight.bold)),
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
                          const Row(
                            children: [
                              Icon(Icons.shield_moon, color: Colors.indigo, size: 28),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Safety Mode",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "Auto-share rides with contacts",
                                    style: TextStyle(
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
                    const Text(
                      "Trusted Contacts",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddContactDialog(context, vm),
                      icon: const Icon(Icons.add),
                      label: const Text("Add New"),
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
                  child: const Column(
                    children: [
                      Row(children: [Icon(Icons.looks_one, size: 16), SizedBox(width: 8), Expanded(child: Text("Stay calm and do not panic."))]),
                      SizedBox(height: 8),
                      Row(children: [Icon(Icons.looks_two, size: 16), SizedBox(width: 8), Expanded(child: Text("Use the SOS button in ride screen."))]),
                      SizedBox(height: 8),
                      Row(children: [Icon(Icons.looks_3, size: 16), SizedBox(width: 8), Expanded(child: Text("Your live location will be shared."))]),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showAddContactDialog(BuildContext context, SafetyViewModel vm) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Trusted Contact"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Name", prefixIcon: Icon(Icons.person)),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone)),
              keyboardType: TextInputType.phone,
              inputFormatters: [LengthLimitingTextInputFormatter(10), FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.length == 10) {
                vm.addTrustedContact(nameCtrl.text.trim(), phoneCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text("Add Contact"),
          ),
        ],
      ),
    );
  }
}
