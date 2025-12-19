import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/profile_viewmodel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileViewModel()..fetchUserProfile(),
      child: const _ProfileScreenBody(),
    );
  }
}

class _ProfileScreenBody extends StatelessWidget {
  const _ProfileScreenBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileViewModel>(
      builder: (context, vm, child) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: const Text(
              "My Profile",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 1,
          ),
          body: vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : vm.errorMessage != null
              ? Center(child: Text(vm.errorMessage!))
              : _buildProfileContent(context, vm),
        );
      },
    );
  }

  Widget _buildProfileContent(BuildContext context, ProfileViewModel vm) {
    return ListView(
      children: [
        _buildUserHeader(context, vm),
        const SizedBox(height: 20),
        _buildMenuSection(context, vm),
        const SizedBox(height: 30),
        _buildAppInfo(context),
      ],
    );
  }

  Widget _buildUserHeader(BuildContext context, ProfileViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      color: Colors.white,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 35,
            backgroundColor: Colors.black,
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vm.userName ?? 'Loading...',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  vm.phoneNumber ?? 'Loading...',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: Colors.grey[700]),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Edit Profile feature coming soon!"),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, ProfileViewModel vm) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.history,
            title: 'Ride History',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Already on the History tab!")),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Payments',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Payments feature coming soon!")),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Help feature coming soon!")),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Settings feature coming soon!")),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.logout,
            title: 'Logout',
            color: Colors.red,
            onTap: () => _showLogoutConfirmation(context, vm),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.black,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildAppInfo(BuildContext context) {
    return Column(
      children: [
        Text('Version 1.0.0', style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(onPressed: () {}, child: const Text("Terms of Service")),
            const Text("•"),
            TextButton(onPressed: () {}, child: const Text("Privacy Policy")),
          ],
        ),
      ],
    );
  }

  void _showLogoutConfirmation(BuildContext context, ProfileViewModel vm) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                vm.logout(context);
              },
            ),
          ],
        );
      },
    );
  }
}
