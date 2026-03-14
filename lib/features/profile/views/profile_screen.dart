import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../../language/viewmodels/language_vm.dart';
import 'edit_profile_screen.dart';
import 'user_delete_account_screen.dart';
import '../../language/views/language_selection_screen.dart';
import 'support_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart'; // Added
import 'feedback_screen.dart'; // Added
import '../../../core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../safety/views/safety_dashboard_screen.dart';
import '../../safety/services/sos_service.dart';
import '../../../core/services/user_preferences.dart';
import '../../../core/theme/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late ProfileViewModel _viewModel;
  bool _announcementEnabled = true; // Default ON

  @override
  void initState() {
    super.initState();
    _viewModel = ProfileViewModel(); // Create VM once
    _loadAnnouncementPreference();
  }
  
  Future<void> _loadAnnouncementPreference() async {
    final enabled = await UserPreferences.getAnnouncementEnabled();
    if (mounted) {
      setState(() {
        _announcementEnabled = enabled;
      });
    }
  }

  @override
  void dispose() {
    _viewModel.dispose(); // Manually dispose if using .value locally, or let Provider handle it if providing
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: _ProfileScreenBody(announcementEnabled: _announcementEnabled, onAnnouncementToggle: _toggleAnnouncement),
    );
  }
  
  Future<void> _toggleAnnouncement(bool value) async {
    setState(() {
      _announcementEnabled = value;
    });
    await UserPreferences.saveAnnouncementEnabled(value);
  }
}

class _ProfileScreenBody extends StatelessWidget {
  final bool announcementEnabled;
  final Function(bool) onAnnouncementToggle;
  
  const _ProfileScreenBody({required this.announcementEnabled, required this.onAnnouncementToggle});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final lang = Provider.of<LanguageViewModel>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Light premium gray
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(context, vm),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildStatsRow(vm, lang),
                        const SizedBox(height: 24),
                        _buildProfileDetails(vm, lang),
                        const SizedBox(height: 24),
                        _buildMenuSection(context, vm),
                        const SizedBox(height: 24),
                        Text(
                          "${lang.getText('version')} 1.0.0",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, ProfileViewModel vm) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.black,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFF121212)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            
            // Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: () => vm.updateProfilePicture(context),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: vm.photoUrl != null 
                              ? NetworkImage(vm.photoUrl!) 
                              : null,
                          child: vm.photoUrl == null
                              ? const Icon(Icons.person, size: 50, color: Colors.white54)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
                const SizedBox(height: 16),
                Text(
                  vm.userName ?? "User",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vm.phoneNumber ?? "",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(ProfileViewModel vm, LanguageViewModel lang) {
    return Row(
      children: [
        _buildStatCard(lang.getText('total_rides'), "${vm.totalRides}", Icons.directions_car, color: AppColors.primary),
        const SizedBox(width: 16),
        _buildStatCard(lang.getText('rating_label'), "${vm.avgRating}", Icons.star, color: AppColors.accent),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {Color color = Colors.black}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
    );
  }

  // ignore: unused_element
  Widget _buildReferralDashboard(ProfileViewModel vm, LanguageViewModel lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.getText('referral_dashboard'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${lang.getText('referral_code_label')}: ${vm.myReferralCode ?? '---'}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildReferralStatItem(lang.getText('referred_label'), "${vm.referralCount}", Icons.people_outline, Colors.blue),
              _buildReferralStatItem(lang.getText('earnings_label'), "₹${vm.totalReferralEarnings.toInt()}", Icons.account_balance_wallet_outlined, Colors.green),
              _buildReferralStatItem(lang.getText('used_label'), "₹${vm.usedReferralEarnings.toInt()}", Icons.shopping_bag_outlined, Colors.orange),
            ],
          ),
        ],
      ),
    ).animate().scale(delay: 300.ms, curve: Curves.easeOutBack);
  }

  Widget _buildReferralStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context, ProfileViewModel vm) {
    final lang = Provider.of<LanguageViewModel>(context);
    return Container(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            context,
            lang.getText('edit_profile'), // "Edit Profile"
            Icons.edit_outlined,
            () async {
               final result = await Navigator.push(
                context, 
                MaterialPageRoute(
                    builder: (_) => EditProfileScreen(
                      currentName: vm.userName ?? "",
                      currentEmail: vm.email,
                      currentGender: vm.gender,
                      currentAge: vm.age,
                    ),
                ),
               );
               if (result == true) vm.fetchUserProfile();
            },
          ),
          _buildDivider(),
          _buildMenuItem(context, "${lang.getText('sos')} - ${lang.getText('emergency_contact')}", Icons.sos, // "SOS - Emergency"
              () => _triggerProfileSOS(context), isDestructive: true),
          _buildDivider(),
          _buildMenuItem(context, lang.getText('safety_center'), Icons.shield_moon_outlined, // "Safety Dashboard" -> "Safety Center"
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyDashboardScreen()))),
          _buildDivider(),
          _buildDivider(),
          _buildAnnouncementToggle(context, lang),
          _buildDivider(),
          _buildDarkModeToggle(context, lang),
        _buildDivider(),
          _buildMenuItem(context, lang.getText('change_language'), Icons.language, // "Language"
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageSelectionScreen(fromProfile: true)))),
          _buildDivider(),
          _buildMenuItem(context, lang.getText('help_support'), Icons.headset_mic_outlined, 
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()))),
          _buildDivider(),
          _buildMenuItem(context, lang.getText('feedback_suggestions'), Icons.tips_and_updates_outlined, 
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen()))),
          _buildDivider(),
          _buildMenuItem(context, lang.getText('terms_conditions_menu'), Icons.description_outlined, 
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()))),
          _buildDivider(),
          _buildMenuItem(context, lang.getText('privacy_policy'), Icons.privacy_tip_outlined, 
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()))),
          _buildDivider(),
          _buildMenuItem(context, lang.getText('logout'), Icons.logout, // "Logout"
              () => _showLogoutDialog(context, vm, lang), isDestructive: true),
          _buildDivider(),
          _buildMenuItem(context, lang.getText('delete_account'), Icons.delete_forever, 
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserDeleteAccountScreen())), isDestructive: true),
        ],
      ),
    ).animate().slideY(begin: 0.2, end: 0, delay: 300.ms, curve: Curves.easeOut);
  }

  Widget _buildProfileDetails(ProfileViewModel vm, LanguageViewModel lang) {
    if (vm.email == null && vm.age == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
             color: Colors.black.withValues(alpha: 0.05),
             blurRadius: 10,
             offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
           if (vm.email != null && vm.email!.isNotEmpty)
             _buildDetailRow(Icons.email_outlined, lang.getText('email'), vm.email!),
           if (vm.age != null) ...[
             const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
             _buildDetailRow(Icons.cake_outlined, lang.getText('age'), "${vm.age} ${lang.getText('years')}"),
           ],
           if (vm.gender != null) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
             _buildDetailRow(Icons.person_outline, lang.getText('gender'), vm.gender!),
           ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDestructive ? Colors.red : Theme.of(context).iconTheme.color, size: 20),
      ),
      title: Text(
        title,
          color: isDestructive ? Colors.red : Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
  
  Widget _buildAnnouncementToggle(BuildContext context, LanguageViewModel lang) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.volume_up, color: Colors.blue, size: 20),
      ),
      title: Text(
        lang.getText('voice_announcements_menu'),
        style: const TextStyle(
          
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        announcementEnabled ? lang.getText('enabled') : lang.getText('disabled'),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: Switch(
        value: announcementEnabled,
        onChanged: onAnnouncementToggle,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primary,
      ),
    );
  }

  Widget _buildDarkModeToggle(BuildContext context, LanguageViewModel lang) {
    final themeProvider = context.watch<ThemeProvider>();
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.indigo.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.dark_mode_rounded, color: Colors.indigo, size: 20),
      ),
      title: const Text(
        'Dark Mode / डार्क मोड',
        style: TextStyle(
          
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'Toggle app theme',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: Switch(
        value: themeProvider.isDarkMode,
        onChanged: (val) => context.read<ThemeProvider>().toggleTheme(val),
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primary,
      ),
    );
  }
  
  Widget _buildDivider() {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Divider(color: Colors.grey[100], height: 1),
    );
  }

  void _showLogoutDialog(BuildContext context, ProfileViewModel vm, LanguageViewModel lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.getText('logout')),
        content: Text(lang.getText('logout_confirmation_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.getText('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.logout(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(lang.getText('logout'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  void _triggerProfileSOS(BuildContext context) {
    // Use the unified Service
    SOSService().showSOSDialog(context: context);
  }
}
