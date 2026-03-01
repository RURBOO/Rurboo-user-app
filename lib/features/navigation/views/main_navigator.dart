import 'package:flutter/material.dart';
import 'package:rurboo/features/history/views/history_screen.dart';
import 'package:rurboo/features/home/views/home_screen.dart';
import 'package:rurboo/features/profile/views/profile_screen.dart';
import 'package:provider/provider.dart';
import '../../language/viewmodels/language_vm.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;
  final GlobalKey _navBarKey = GlobalKey();

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = [
      HomeScreen(navBarKey: _navBarKey),
      const HistoryScreen(),
      const ProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    return Scaffold(
      body: Stack(
        children: [
          Center(child: _widgetOptions.elementAt(_selectedIndex)),
          // Voice command feature disabled for v1.0 - only announcements active
          // Will be enabled in future updates
          // const VoiceAssistantWidget(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        key: _navBarKey,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: lang.getText('nav_home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history_outlined),
            activeIcon: const Icon(Icons.history),
            label: lang.getText('nav_history'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: lang.getText('nav_profile'),
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
