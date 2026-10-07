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
                const SizedBox(height: TSpace.md),
                Text(
                  'A personal tutor that explains every lesson, step by step.',
                  style: TText.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
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

/// A friendly stand-in for the hero photograph until the artwork is supplied: the mascot on a
/// glowing disc.
class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          const Mascot(size: 190),
          Positioned(
            right: 14,
            top: 8,
            child: Icon(Icons.star_rounded, color: TColors.yellow, size: 34),
          ),
          Positioned(
            left: 10,
            bottom: 34,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: TColors.yellow.withValues(alpha: 0.9),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
