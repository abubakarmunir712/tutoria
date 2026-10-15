import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design.dart';
import '../auth/auth_state.dart';
import '../profile/profile_screen.dart';
import 'ask_screen.dart';
import 'learn_screen.dart';
import 'parent_home_screen.dart';
import 'progress_screen.dart';
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
    // A parent sees their children and their own profile; a student gets the full learning tabs.
    final learnerId = me.isParent ? null : me.learners.first.id;
    final tabs = <(TNavItem, Widget)>[
      (
        const TNavItem('Home', Icons.home_outlined, Icons.home_rounded),
        learnerId == null
            ? const ParentHomeScreen()
            : StudentHomeScreen(learnerId: learnerId, isOwn: true),
      ),
      if (learnerId != null) ...[
        (
          const TNavItem(
            'Learn',
            Icons.menu_book_outlined,
            Icons.menu_book_rounded,
          ),
          LearnScreen(learnerId: learnerId),
        ),
        (
          const TNavItem(
            'Ask',
            Icons.chat_bubble_outline_rounded,
            Icons.chat_bubble_rounded,
          ),
          AskScreen(learnerId: learnerId),
        ),
        (
          const TNavItem(
            'Progress',
            Icons.bar_chart_outlined,
            Icons.bar_chart_rounded,
          ),
          ProgressScreen(learnerId: learnerId),
        ),
      ],
      (
        const TNavItem(
          'Profile',
          Icons.person_outline_rounded,
          Icons.person_rounded,
        ),
        const ProfileScreen(),
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: [for (final t in tabs) t.$2]),
      bottomNavigationBar: TNavBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
        items: [for (final t in tabs) t.$1],
      ),
    );
  }
}
