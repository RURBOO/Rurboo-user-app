import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'edit_profile_screen.dart';
import 'user_delete_account_screen.dart';
import '../../language/views/language_selection_screen.dart';
import 'support_screen.dart';
import 'privacy_policy_screen.dart';
import '../../safety/views/safety_dashboard_screen.dart';
import '../../safety/services/sos_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileViewModel(), // Fetch called in constructor
      child: const _ProfileScreenBody(),
    );
  }
}

class _ProfileScreenBody extends StatelessWidget {
  const _ProfileScreenBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light premium gray
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
                        _buildStatsRow(vm),
                        _buildProfileDetails(vm),
                        const SizedBox(height: 24),
                        _buildMenuSection(context, vm),
                        const SizedBox(height: 24),
                        Text(
                          "Version 1.0.0",
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
                  colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
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
                ),
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

  Widget _buildStatsRow(ProfileViewModel vm) {
    return Row(
      children: [
        _buildStatCard("Total Rides", "${vm.totalRides}", Icons.directions_car),
        const SizedBox(width: 16),
        _buildStatCard("Rating", "${vm.avgRating}", Icons.star, color: Colors.amber),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {Color color = Colors.black}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
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
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, ProfileViewModel vm) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
            "Edit Profile",
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
          _buildMenuItem(context, "SOS - Emergency", Icons.sos, 
              () => _triggerProfileSOS(context), isDestructive: true),
          _buildDivider(),
          _buildMenuItem(context, "Safety Dashboard", Icons.shield_moon_outlined, 
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyDashboardScreen()))),
          _buildDivider(),
          _buildMenuItem(context, "Language", Icons.language, 
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageSelectionScreen(fromProfile: true)))),
          _buildDivider(),
          _buildMenuItem(context, "Support", Icons.headset_mic_outlined, 
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()))),
          _buildDivider(),
          _buildMenuItem(context, "Privacy Policy", Icons.privacy_tip_outlined, 
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()))),
          _buildDivider(),
          _buildMenuItem(context, "Logout", Icons.logout, 
              () => _showLogoutDialog(context, vm), isDestructive: true),
          _buildDivider(),
          _buildMenuItem(context, "Delete Account", Icons.delete_forever, 
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserDeleteAccountScreen())), isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildProfileDetails(ProfileViewModel vm) {
    if (vm.email == null && vm.age == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
             _buildDetailRow(Icons.email_outlined, "Email", vm.email!),
           if (vm.age != null) ...[
             const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
             _buildDetailRow(Icons.cake_outlined, "Age", "${vm.age} years"),
           ],
           if (vm.gender != null) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
             _buildDetailRow(Icons.person_outline, "Gender", vm.gender!),
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
        child: Icon(icon, color: isDestructive ? Colors.red : Colors.black87, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
  
  Widget _buildDivider() {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Divider(color: Colors.grey[100], height: 1),
    );
  }

  void _showLogoutDialog(BuildContext context, ProfileViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to end your session?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.logout(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
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
