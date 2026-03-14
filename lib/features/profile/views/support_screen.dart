import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../language/viewmodels/language_vm.dart';
import '../../support/viewmodels/support_viewmodel.dart';
import '../../support/models/ticket_model.dart';
import '../../../core/theme/app_colors.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SupportViewModel(),
      child: const SupportScreenBody(),
    );
  }
}

class SupportScreenBody extends StatefulWidget {
  const SupportScreenBody({super.key});

  @override
  State<SupportScreenBody> createState() => _SupportScreenBodyState();
}

class _SupportScreenBodyState extends State<SupportScreenBody> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategory;
  final _subjectController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    final vm = Provider.of<SupportViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.getText('support_ticket_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: lang.getText('create_ticket_tab')),
            Tab(text: lang.getText('my_tickets_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateTicketTab(context, vm, lang),
          _buildTicketListTab(context, vm, lang),
        ],
      ),
    );
  }

  Widget _buildCreateTicketTab(BuildContext context, SupportViewModel vm, LanguageViewModel lang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: lang.getText('ticket_category_label'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                'cat_ride', 'cat_payment', 'cat_account', 'cat_other'
              ].map((key) => DropdownMenuItem(
                value: key, 
                child: Text(lang.getText(key))
              )).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
              validator: (val) => val == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: lang.getText('ticket_subject_label'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: lang.getText('ticket_desc_label'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            // --- Attachment UI ---
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attach_file, size: 18, ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vm.selectedImage == null 
                                ? lang.getText('attach_screenshot_optional')
                                : vm.selectedImage!.name,
                            style: TextStyle(fontSize: 14, ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (vm.selectedImage != null)
                          GestureDetector(
                            onTap: vm.clearImage,
                            child: const Icon(Icons.close, size: 18, color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: vm.pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                    foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Icon(Icons.add_a_photo, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: vm.isLoading ? null : () async {
                  if (_formKey.currentState!.validate()) {
                    final success = await vm.createTicket(
                      category: lang.getText(_selectedCategory!),
                      subject: _subjectController.text, 
                      description: _descController.text
                    );
                    
                    if (!context.mounted) return;

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('ticket_created_success'))));
                      _subjectController.clear();
                      _descController.clear();
                      setState(() => _selectedCategory = null);
                      _tabController.animateTo(1); // Switch to list tab
                    } else if (vm.error != null) {
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vm.error!)));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: vm.isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(lang.getText('ticket_submit_btn'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketListTab(BuildContext context, SupportViewModel vm, LanguageViewModel lang) {
    return StreamBuilder<List<TicketModel>>(
      stream: vm.getUserTickets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
           return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
           return Center(child: Text(lang.getText('no_tickets_found'), style: const TextStyle()));
        }

        final tickets = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tickets.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
             final ticket = tickets[i];
             return Card(
               elevation: 2,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               child: ExpansionTile(
                 tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 leading: CircleAvatar(
                   backgroundColor: _getStatusColor(ticket.status).withValues(alpha: 0.1),
                   child: Icon(_getStatusIcon(ticket.status), color: _getStatusColor(ticket.status), size: 20),
                 ),
                 title: Text(ticket.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                 subtitle: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const SizedBox(height: 4),
                     Text("${lang.getText('ticket_id')}: ${ticket.id.length > 8 ? '${ticket.id.substring(0, 8)}...' : ticket.id}", style: const TextStyle(fontSize: 12, )),
                     Text(DateFormat('MMM dd, yyyy').format(ticket.createdAt), style: const TextStyle(fontSize: 12, )),
                   ],
                 ),
                 trailing: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: _getStatusColor(ticket.status).withValues(alpha: 0.1),
                     borderRadius: BorderRadius.circular(8),
                   ),
                    child: Text(
                      _getStatusText(ticket.status, lang),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getStatusColor(ticket.status)),
                    ),
                  ),
                  children: [
                     Padding(
                       padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            const Divider(),
                            Text(lang.getText('ticket_desc_label'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, )),
                            const SizedBox(height: 4),
                            Text(ticket.description),
                             if (ticket.adminResponse != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       Text(lang.getText('admin_response'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                                       const SizedBox(height: 4),
                                       Text(ticket.adminResponse!),
                                    ],
                                  ),
                                )
                             ],
                             if (ticket.imageUrl != null) ...[
                                const SizedBox(height: 12),
                                Text(lang.getText('attachment_label'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, )),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    ticket.imageUrl!,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Text(lang.getText('uiFailedToLoadImage')),
                                  ),
                                ),
                             ]
                          ],
                        ),
                     )
                  ],
                ),
              );
           },
        );
      },
    );
  }

  String _getStatusText(String status, LanguageViewModel lang) {
    switch (status.toLowerCase()) {
      case 'open': return lang.getText('ticket_status_pending'); // Open -> Pending
      case 'in progress': return lang.getText('ticket_status_processing'); // In Progress -> Processing
      case 'closed': return lang.getText('ticket_status_completed'); // Closed -> Completed
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open': return Colors.orange; // Pending - Orange
      case 'in progress': return Colors.blue; // Processing - Blue
      case 'closed': return Colors.green; // Completed - Green
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'open': return Icons.hourglass_empty;
      case 'in progress': return Icons.cached;
      case 'closed': return Icons.check_circle_outline;
      default: return Icons.help_outline;
    }
  }
}
