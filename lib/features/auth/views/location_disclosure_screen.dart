import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../features/navigation/views/main_navigator.dart';
import '../../language/viewmodels/language_vm.dart';

class LocationDisclosureScreen extends StatelessWidget {
  const LocationDisclosureScreen({super.key});

  Future<void> _handleAllow(BuildContext context, LanguageViewModel lang) async {
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigator()),
          (route) => false,
        );
      }
    } else if (permission == LocationPermission.deniedForever) {
      if (context.mounted) _showOpenSettingsDialog(context, lang);
    }
  }

  void _showOpenSettingsDialog(BuildContext context, LanguageViewModel lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.getText('permission_required')),
        content: Text(lang.getText('location_denied_forever')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.getText('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text(lang.getText('open_settings')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Icon(
                Icons.location_on_rounded,
                size: 48,
              ),
              const SizedBox(height: 24),
              Text(
                lang.getText('location_disclosure_title'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              Text(
                lang.getText('location_disclosure_desc'),
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),
              _buildBullet(lang.getText('location_benefit_1')),
              _buildBullet(lang.getText('location_benefit_2')),
              _buildBullet(lang.getText('location_benefit_3')),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => _handleAllow(context, lang),
                  child: Text(
                    lang.getText('allow_location_access'),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MainNavigator()),
                      (route) => false,
                    );
                  },
                  child: Text(
                    lang.getText('maybe_later'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 20, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
