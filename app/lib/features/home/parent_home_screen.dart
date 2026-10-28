import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/photos.dart';
import '../../core/design/design.dart';
import '../../core/models.dart';
import '../../core/progress.dart';
import '../auth/auth_state.dart';
import '../onboarding/learner_details_screen.dart';
import '../onboarding/subjects_screen.dart';
import '../progress/child_progress_screen.dart';
import 'student_home_screen.dart';

/// A parent's home: their children with how each is doing, one tap from their progress and
/// their tutor.
class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key, this.now});

  /// The current time; tests pass a fixed one.
  final DateTime? now;

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  @override
  void initState() {
    super.initState();
    // One request for the whole family rather than one per child.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<ProgressStore>().refreshAll());
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final store = context.watch<ProgressStore>();
    final me = auth.me!;
    final clock = widget.now ?? DateTime.now();
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: TColors.pageGradient),
        child: RefreshIndicator(
          onRefresh: () async {
            await auth.refreshMe();
            await store.refreshAll();
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TSpace.page,
                    TSpace.lg,
                    TSpace.page,
                    TSpace.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Wordmark(size: 30),
                          const Spacer(),
                          Avatar(name: me.fullName, size: 44),
                        ],
                      ),
                      const SizedBox(height: TSpace.xl),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${greetingFor(clock)}, ${me.firstName}!',
                              style: TText.title.copyWith(fontSize: 26),
                            ),
                          ),
                          const SizedBox(width: TSpace.sm),
                          Icon(
                            clock.hour < 17
                                ? Icons.wb_sunny_rounded
                                : Icons.nights_stay_rounded,
                            color: const Color(0xFFFFB800),
                            size: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        me.learners.length == 1
                            ? 'Your child is ready to learn.'
                            : 'Choose a child to start learning.',
                        style: TText.body.copyWith(
                          color: TColors.muted,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
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
                      _ChildCard(
                        learner: learner,
                        progress: store.peek(learner.id),
                      ),
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
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.learner, this.progress});

  final Learner learner;

  /// How the child is doing; null until it has loaded.
  final Progress? progress;

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
              LearnerAvatar(
                learnerId: learner.id,
                name: learner.name,
                size: 56,
              ),
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
          if (progress != null) ...[
            const SizedBox(height: TSpace.md),
            _Scoreboard(progress: progress!),
          ],
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
          const SizedBox(height: TSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChildProgressScreen(learnerId: learner.id),
                ),
              ),
              icon: const Icon(Icons.insights_rounded, size: 18),
              label: const Text('View progress'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A child's score on the parent's list: streak, XP and what they did this week.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.progress});

  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: TSpace.md),
      decoration: BoxDecoration(
        color: TColors.blue50,
        borderRadius: BorderRadius.circular(TRadius.md),
      ),
      child: Row(
        children: [
          _Figure(
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFFF9500),
            value: '${p.streak}',
            label: 'day streak',
          ),
          _Figure(
            icon: Icons.star_rounded,
            color: TColors.gold,
            value: '${p.xp}',
            label: 'XP · level ${p.level}',
          ),
          _Figure(
            icon: Icons.track_changes_rounded,
            color: TColors.blue600,
            value: '${p.questionsThisWeek}',
            label: 'this week',
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 4),
              Text(value, style: TText.heading.copyWith(fontSize: 20)),
            ],
          ),
          Text(
            label,
            style: TText.caption.copyWith(color: TColors.muted),
            textAlign: TextAlign.center,
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
