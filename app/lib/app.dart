import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/design/design.dart';
import 'features/auth/auth_state.dart';
import 'features/home/main_shell.dart';
import 'features/onboarding/learner_details_screen.dart';
import 'features/onboarding/subjects_screen.dart';
import 'features/onboarding/welcome_screen.dart';

class TutoriaApp extends StatelessWidget {
  const TutoriaApp({super.key, this.api});

  /// Lets tests supply a fake API; the real app builds its own.
  final ApiClient? api;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => api ?? ApiClient()),
        ChangeNotifierProvider<AuthState>(
          create: (context) =>
              AuthState(api: context.read<ApiClient>())..bootstrap(),
        ),
      ],
      child: MaterialApp(
        title: 'Tutoria',
        debugShowCheckedModeBanner: false,
        theme: buildTutoriaTheme(),
        home: const AuthGate(),
      ),
    );
  }
}

/// Decides what to show from who is signed in and how far through setting up they are.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const _LoadingScreen();
      case AuthStatus.unauthenticated:
        return const WelcomeScreen();
      case AuthStatus.authenticated:
        final me = auth.me;
        if (me == null) {
          return auth.profileFailed
              ? _LoadFailedScreen(
                  onRetry: auth.refreshMe,
                  onLogout: auth.logout,
                )
              : const _LoadingScreen();
        }
        // Still setting up: a parent with no children yet, or a student who hasn't said their
        // class and subjects. Everything else goes to the app.
        if (me.isParent && me.learners.isEmpty) {
          return const LearnerDetailsScreen(onboarding: true);
        }
        if (!me.isParent) {
          final self = me.learners.first;
          if (self.grade == null) {
            return LearnerDetailsScreen(
              onboarding: true,
              initialName: self.name,
            );
          }
          if (self.subjects.isEmpty) {
            return SubjectsScreen(learnerId: self.id, onboarding: true);
          }
        }
        return const MainShell();
    }
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: HeroBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wordmark(onBlue: true, size: 38),
              SizedBox(height: TSpace.xl),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadFailedScreen extends StatelessWidget {
  const _LoadFailedScreen({required this.onRetry, required this.onLogout});

  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SoftBlobs(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(TSpace.page + 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Mascot(size: 120),
                const SizedBox(height: TSpace.lg),
                Text(
                  'We couldn’t load your account',
                  textAlign: TextAlign.center,
                  style: TText.heading,
                ),
                const SizedBox(height: 6),
                Text(
                  'Check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: TText.body.copyWith(color: TColors.muted),
                ),
                const SizedBox(height: TSpace.xl),
                TButton(label: 'Try again', onPressed: onRetry),
                TextButton(onPressed: onLogout, child: const Text('Log out')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
