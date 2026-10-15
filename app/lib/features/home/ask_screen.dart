import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design.dart';
import '../auth/auth_state.dart';
import 'subject_picker.dart';

/// The Ask tab: three ways to put a question to the tutor.
class AskScreen extends StatelessWidget {
  const AskScreen({super.key, required this.learnerId});

  final String learnerId;

  @override
  Widget build(BuildContext context) {
    final learner = context.watch<AuthState>().learnerById(learnerId);
    if (learner == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final enabled = learner.subjects.isNotEmpty;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: TColors.pageGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(TSpace.page),
            children: [
              Text('Ask Tutoria', style: TText.title.copyWith(fontSize: 28)),
              const SizedBox(height: 2),
              Text(
                'Stuck on something? Ask in your own way.',
                style: TText.body.copyWith(color: TColors.muted, fontSize: 16),
              ),
              const SizedBox(height: TSpace.xl),
              Center(
                child: Image.asset(
                  'assets/images/mascot_hero.png',
                  width: 150,
                  height: 150,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(height: TSpace.xl),
              _AskOption(
                icon: Icons.chat_bubble_rounded,
                accent: TColors.blue600,
                tint: const Color(0xFFE3F1FF),
                title: 'Type a question',
                subtitle: 'Write it and get step-by-step help',
                onTap: enabled ? () => openTutorChat(context, learner) : null,
              ),
              const SizedBox(height: TSpace.md),
              _AskOption(
                icon: Icons.mic_rounded,
                accent: const Color(0xFFFFA400),
                tint: const Color(0xFFFFF0D9),
                title: 'Say it out loud',
                subtitle: 'Talk to your tutor and hear the answer',
                onTap: enabled
                    ? () => openTutorChat(context, learner, voice: true)
                    : null,
              ),
              const SizedBox(height: TSpace.md),
              _AskOption(
                icon: Icons.photo_camera_rounded,
                accent: const Color(0xFFFF4B6E),
                tint: TColors.englishTint,
                title: 'Take a picture',
                subtitle: 'Snap your homework question',
                onTap: enabled
                    ? () => openTutorChat(context, learner, camera: true)
                    : null,
              ),
              if (!enabled) ...[
                const SizedBox(height: TSpace.lg),
                Text(
                  'Choose your subjects on the Home tab first.',
                  style: TText.small,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AskOption extends StatelessWidget {
  const _AskOption({
    required this.icon,
    required this.accent,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TCard(
      onTap: onTap,
      color: tint,
      borderColor: Colors.transparent,
      shadow: false,
      child: Row(
        children: [
          IconBadge(icon: icon, color: accent, size: 52),
          const SizedBox(width: TSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TText.subheading),
                Text(subtitle, style: TText.small),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: TColors.ink),
        ],
      ),
    );
  }
}
