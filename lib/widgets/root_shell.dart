import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '../screens/home_screen.dart';
import '../screens/pdf_tools_screen.dart';
import '../screens/file_manager_screen.dart';
import '../screens/settings_screen.dart';

/// Hosts the four primary destinations behind a premium NavigationBar,
/// swapping bodies with a shared-axis fade+scale transition rather than
/// an abrupt cut.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    PdfToolsScreen(),
    FileManagerScreen(),
    SettingsScreen(),
  ];

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
    NavigationDestination(
        icon: Icon(Icons.picture_as_pdf_outlined),
        selectedIcon: Icon(Icons.picture_as_pdf_rounded),
        label: 'Tools'),
    NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder_rounded), label: 'Files'),
    NavigationDestination(
        icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, primary, secondary) => FadeThroughTransition(
          animation: primary,
          secondaryAnimation: secondary,
          child: child,
        ),
        child: KeyedSubtree(key: ValueKey(_index), child: _screens[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations,
      ),
    );
  }
}
