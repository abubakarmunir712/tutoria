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
                style: TText.body.copyWith(
                  color: TColors.blue600,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: TSpace.xl),
              OptionCard(
                title: 'I’m a Parent',
                subtitle: 'I want to help my child\nlearn and grow',
                tint: TColors.yellowTint,
                leading: const _RoleArt(
                  icon: Icons.family_restroom_rounded,
                  color: TColors.yellowDeep,
                ),
                onTap: () => _choose(context, UserRole.parent),
              ),
              const SizedBox(height: TSpace.lg),
              OptionCard(
                title: 'I’m a Student',
                subtitle: 'I want to learn\nand improve',
                tint: TColors.blue100,
                leading: const _RoleArt(
                  icon: Icons.backpack_rounded,
                  color: TColors.blue500,
                ),
                onTap: () => _choose(context, UserRole.student),
              ),
              const SizedBox(height: TSpace.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Mascot(size: 110),
                  const SizedBox(width: TSpace.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                        'Better\nlearning.\nBrighter\nfutures.',
                        style: TText.heading.copyWith(
                          color: TColors.blue600,
                          fontStyle: FontStyle.italic,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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

/// A round illustration slot for the role cards (the mockups show portraits; this is the stand-in).
class _RoleArt extends StatelessWidget {
  const _RoleArt({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: color, width: 3),
      ),
      child: Icon(icon, size: 40, color: color),
    );
  }
}
