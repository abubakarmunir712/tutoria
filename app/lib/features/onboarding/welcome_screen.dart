import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../auth/login_screen.dart';
import 'user_type_screen.dart';

/// The first screen a signed-out user sees: the brand, the promise, and a way in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HeroBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              TSpace.page + 4,
              TSpace.xl,
              TSpace.page + 4,
              TSpace.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Wordmark(onBlue: true, tagline: true, size: 40),
                const SizedBox(height: TSpace.xxl + 8),
                Text(
                  'Brighter\nfutures',
                  style: TText.display.copyWith(
                    color: Colors.white,
                    fontSize: 44,
                    height: 1.05,
                  ),
                ),
                Text(
                  'start here',
                  style: TText.display.copyWith(
                    color: TColors.yellow,
                    fontSize: 44,
                    height: 1.1,
                  ),
                ),
                const Spacer(),
                const Center(child: _HeroArt()),
                const Spacer(),
                TButton(
                  label: 'Get Started',
                  style: TButtonStyle.cta,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UserTypeScreen()),
                  ),
                ),
                const SizedBox(height: TSpace.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: TText.body.copyWith(color: Colors.white),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: Text(
                        'Sign In',
                        style: TText.bodyBold.copyWith(
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The mascot on its glowing disc, from the approved splash artwork.
class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/mascot_hero.png',
      width: 300,
      height: 300,
      semanticLabel: 'Tutoria, your tutor',
    );
  }
}
