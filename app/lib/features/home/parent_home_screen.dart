import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design.dart';
import '../../core/models.dart';
import '../auth/auth_state.dart';
import '../onboarding/learner_details_screen.dart';
import '../onboarding/subjects_screen.dart';
import 'header.dart';
import 'student_home_screen.dart';

/// A parent's home: their children, each one tap from their tutor.
class ParentHomeScreen extends StatelessWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final me = auth.me!;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: auth.refreshMe,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            WaveHeader(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Greeting(
                          text: 'Hello, ${me.firstName}',
                          style: TText.title.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          me.learners.length == 1
                              ? 'Your child is ready to learn.'
                              : 'Choose a child to start learning.',
                          style: TText.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Mascot(size: 78),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TSpace.page,
                TSpace.sm,
                TSpace.page,
                TSpace.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your children', style: TText.heading),
                  const SizedBox(height: TSpace.md),
                  for (final learner in me.learners) ...[
                    _ChildCard(learner: learner),
                    const SizedBox(height: TSpace.md),
                  ],
                  _AddChildCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LearnerDetailsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.learner});

  final Learner learner;

  @override
  Widget build(BuildContext context) {
    return TCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudentHomeScreen(learnerId: learner.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: learner.name, size: 56),
              const SizedBox(width: TSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(learner.name, style: TText.subheading),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        Pill(
                          text: learner.classLabel,
                          icon: Icons.school_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: TColors.ink),
            ],
          ),
          const SizedBox(height: TSpace.md),
          if (learner.subjects.isEmpty)
            Row(
              children: [
                Expanded(
                  child: Text('No subjects chosen yet', style: TText.small),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SubjectsScreen(learnerId: learner.id),
                    ),
                  ),
                  child: const Text('Choose subjects'),
                ),
              ],
            )
          else
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
      ),
    );
  }
}

class _AddChildCard extends StatelessWidget {
  const _AddChildCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: TSpace.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TRadius.lg),
          border: Border.all(color: TColors.blue200, width: 2),
          color: TColors.blue100.withValues(alpha: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_rounded, color: TColors.blue600),
            const SizedBox(width: 8),
            Text(
              'Add a child',
              style: TText.bodyBold.copyWith(color: TColors.blue600),
            ),
          ],
        ),
      ),
    );
  }
}
