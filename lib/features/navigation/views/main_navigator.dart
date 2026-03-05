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

  // For double-tap-to-exit on the Home tab
  DateTime? _lastBackPress;

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

  // Returns true to allow the pop (exit), false to block it
  bool _onPopInvoked() {
    // If NOT on Home tab → navigate to Home tab instead of popping/exiting
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return false; // block the pop
    }

    // On Home tab → double-back-press to exit
    final now = DateTime.now();
    if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageViewModel>(context, listen: false).getText('press_back_again_to_exit')),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        ),
      );
      return false; // block first back press
    }

    return true; // allow exit on second back press within 2 seconds
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    return PopScope(
      canPop: false, // Always intercept; _onPopInvoked decides
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopInvoked();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Center(child: _widgetOptions.elementAt(_selectedIndex)),
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
      ),
    );
  }
}
