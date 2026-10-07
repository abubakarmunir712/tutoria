import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design.dart';
import '../../core/models.dart';
import '../auth/auth_state.dart';
import '../onboarding/learner_details_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final me = auth.me!;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            TSpace.page,
            TSpace.lg,
            TSpace.page,
            TSpace.xl,
          ),
          children: [
            Text('Profile', style: TText.title),
            const SizedBox(height: TSpace.lg),
            TCard(
              child: Row(
                children: [
                  Avatar(name: me.fullName, size: 64),
                  const SizedBox(width: TSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(me.fullName, style: TText.subheading),
                        const SizedBox(height: 2),
                        Text(
                          me.email,
                          style: TText.small,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(me.phone, style: TText.small),
                        const SizedBox(height: 6),
                        Pill(
                          text: me.isParent
                              ? 'Parent account'
                              : 'Student account',
                          icon: me.isParent
                              ? Icons.family_restroom_rounded
                              : Icons.backpack_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TSpace.xl),
            Text(
              me.isParent ? 'Your children' : 'My learning',
              style: TText.heading,
            ),
            const SizedBox(height: TSpace.md),
            for (final learner in me.learners) ...[
              _LearnerRow(learner: learner),
              const SizedBox(height: TSpace.md),
            ],
            if (me.isParent)
              TButton(
                label: 'Add a child',
                icon: Icons.add_rounded,
                style: TButtonStyle.soft,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LearnerDetailsScreen(),
                  ),
                ),
              ),
            const SizedBox(height: TSpace.xl),
            TButton(
              label: 'Log out',
              icon: Icons.logout_rounded,
              style: TButtonStyle.outline,
              onPressed: () => context.read<AuthState>().logout(),
            ),
            const SizedBox(height: TSpace.lg),
            Center(child: Text('Tutoria', style: TText.caption)),
          ],
        ),
      ),
    );
  }
}

class _LearnerRow extends StatelessWidget {
  const _LearnerRow({required this.learner});

  final Learner learner;

  @override
  Widget build(BuildContext context) {
    return TCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: learner.name, size: 48),
              const SizedBox(width: TSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      learner.name,
                      style: TText.bodyBold.copyWith(color: TColors.ink),
                    ),
                    Text(
                      [
                        learner.classLabel,
                        if (learner.schoolType != null)
                          schoolTypeText(learner.schoolType!),
                      ].join(' · '),
                      style: TText.small,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LearnerDetailsScreen(existing: learner),
                  ),
                ),
                child: const Text('Edit'),
              ),
            ],
          ),
          if (learner.subjects.isNotEmpty) ...[
            const SizedBox(height: TSpace.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in learner.subjects)
                  Pill(
                    text: SubjectStyle.shortName(s.name),
                    background: SubjectStyle.of(s.name).tint,
                    foreground: SubjectStyle.of(s.name).accent,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String schoolTypeText(String code) => switch (code) {
  'PRIVATE' => 'Private school',
  'PUBLIC' => 'Public school',
  _ => code,
};
