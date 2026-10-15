import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/models.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

/// "Who are you?": a parent signs up and adds their children; a student signs up for themselves.
class UserTypeScreen extends StatelessWidget {
  const UserTypeScreen({super.key});

  void _choose(BuildContext context, UserRole role) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SignupScreen(role: role)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SoftBlobs(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              TSpace.page + 4,
              0,
              TSpace.page + 4,
              TSpace.xl,
            ),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Wordmark(size: 30, tagline: true),
              ),
              const SizedBox(height: TSpace.xl),
              Text(
                'Welcome to Tutoria!',
                style: TText.title.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 6),
              Text(
                'Let’s get started. Who are you?',
                style: TText.body.copyWith(color: TColors.muted, fontSize: 18),
              ),
              const SizedBox(height: TSpace.xl),
              OptionCard(
                title: 'I’m a Parent / Guardian',
                subtitle: 'I want to help my child learn and grow',
                tint: TColors.yellowTint,
                leading: const _RoleArt('assets/images/role_parent.png'),
                onTap: () => _choose(context, UserRole.parent),
              ),
              const SizedBox(height: TSpace.lg),
              OptionCard(
                title: 'I’m a Student',
                subtitle: 'I want to learn and improve',
                tint: TColors.blue100,
                leading: const _RoleArt('assets/images/role_student.png'),
                onTap: () => _choose(context, UserRole.student),
              ),
              const SizedBox(height: TSpace.xxl),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('Already have an account? Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The round portrait on a role card.
class _RoleArt extends StatelessWidget {
  const _RoleArt(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: 92,
      height: 92,
      excludeFromSemantics: true,
    );
  }
}
