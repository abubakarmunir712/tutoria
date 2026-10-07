import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design.dart';
import '../auth/auth_state.dart';
import '../profile/profile_screen.dart';
import 'parent_home_screen.dart';
import 'student_home_screen.dart';

/// The signed-in app: Home and Profile tabs under a bottom navigation bar. A parent's Home lists
/// their children; a student's Home is their own learning screen.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthState>().me!;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          me.isParent
              ? const ParentHomeScreen()
              : StudentHomeScreen(learnerId: me.learners.first.id, isOwn: true),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: TNavBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
        items: const [
          TNavItem('Home', Icons.home_outlined, Icons.home_rounded),
          TNavItem(
            'Profile',
            Icons.person_outline_rounded,
            Icons.person_rounded,
          ),
        ],
      ),
    );
  }
}
