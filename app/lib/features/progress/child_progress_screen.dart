import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design.dart';
import '../../core/models.dart';
import '../../core/photos.dart';
import '../../core/progress.dart';
import '../auth/auth_state.dart';
import '../home/student_home_screen.dart' show StudentHomeScreen, sinceLabel;
import '../quiz/mastery_widgets.dart';
import 'progress_widgets.dart';

/// What a parent sees for one child: how often they study, what they study, their score and
/// the badges they have won.
class ChildProgressScreen extends StatelessWidget {
  const ChildProgressScreen({super.key, required this.learnerId, this.now});

  final String learnerId;

  /// The current time; tests pass a fixed one.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final learner = context.watch<AuthState>().learnerById(learnerId);
    if (learner == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final store = context.watch<ProgressStore>();
    final p = store.of(learnerId);
    final clock = now ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text('${learner.firstName}’s progress')),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: TColors.pageGradient),
        child: RefreshIndicator(
          onRefresh: () => store.refresh(learnerId),
          child: ListView(
            padding: const EdgeInsets.all(TSpace.page),
            children: [
              _Header(learner: learner, progress: p, now: clock),
              const SizedBox(height: TSpace.lg),
              if (p == null)
                const Padding(
                  padding: EdgeInsets.all(TSpace.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!p.hasActivity)
                _NothingYet(learner: learner)
              else ...[
                LevelCard(progress: p, name: learner.firstName),
                const SizedBox(height: TSpace.md),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: MiniStat(
                          label: 'Questions this week',
                          value: '${p.questionsThisWeek}',
                          icon: Icons.track_changes_rounded,
                        ),
                      ),
                      const SizedBox(width: TSpace.md),
                      Expanded(
                        child: MiniStat.streak(
                          label: 'Learning streak',
                          value: daysLabel(p.streak),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TSpace.xl),
                Text('Last 7 days', style: TText.heading),
                const SizedBox(height: TSpace.md),
                TCard(child: WeekChart(week: p.week)),
                const SizedBox(height: TSpace.xl),
                Text('Subjects', style: TText.heading),
                const SizedBox(height: TSpace.md),
                _Subjects(bySubject: p.bySubject),
                MasterySection(learnerId: learnerId, forParent: true),
                if (p.recentTopics.isNotEmpty) ...[
                  const SizedBox(height: TSpace.xl),
                  Text('Recently studied', style: TText.heading),
                  const SizedBox(height: TSpace.md),
                  TCard(
                    child: Column(
                      children: [
                        for (final t in p.recentTopics)
                          _TopicRow(topic: t, now: clock),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: TSpace.xl),
                Row(
                  children: [
                    Expanded(child: Text('Badges', style: TText.heading)),
                    Pill(
                      text: '${p.earnedBadges.length} of ${p.badges.length}',
                      icon: Icons.workspace_premium_rounded,
                      background: TColors.yellowTint,
                      foreground: TColors.ink,
                    ),
                  ],
                ),
                const SizedBox(height: TSpace.md),
                BadgeGrid(badges: p.badges),
              ],
              const SizedBox(height: TSpace.xl),
              TButton(
                label: 'Open ${learner.firstName}’s tutor',
                icon: Icons.chat_bubble_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StudentHomeScreen(learnerId: learnerId),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.learner,
    required this.progress,
    required this.now,
  });

  final Learner learner;
  final Progress? progress;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final last = progress?.lastActiveAt;
    return Row(
      children: [
        LearnerAvatar(learnerId: learner.id, name: learner.name, size: 60),
        const SizedBox(width: TSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(learner.name, style: TText.subheading),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Pill(text: learner.classLabel, icon: Icons.school_rounded),
                  if (last != null)
                    Pill(
                      text: 'Active ${sinceLabel(last.toLocal(), now)}',
                      icon: Icons.schedule_rounded,
                      background: TColors.blue100,
                      foreground: TColors.blue600,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NothingYet extends StatelessWidget {
  const _NothingYet({required this.learner});

  final Learner learner;

  @override
  Widget build(BuildContext context) {
    return TCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nothing here yet', style: TText.subheading),
          const SizedBox(height: 4),
          Text(
            '${learner.firstName} hasn’t asked a question yet. Once they do, you’ll see '
            'their streak, score and what they are learning here.',
            style: TText.body,
          ),
        ],
      ),
    );
  }
}

class _Subjects extends StatelessWidget {
  const _Subjects({required this.bySubject});

  final Map<String, int> bySubject;

  @override
  Widget build(BuildContext context) {
    final rows = bySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final most = rows.isEmpty ? 1 : rows.first.value;
    return Column(
      children: [
        for (final e in rows) ...[
          TCard(
            color: SubjectStyle.of(e.key).tint,
            borderColor: Colors.transparent,
            shadow: false,
            child: Column(
              children: [
                Row(
                  children: [
                    IconBadge(
                      icon: SubjectStyle.of(e.key).icon,
                      color: SubjectStyle.of(e.key).accent,
                      size: 34,
                    ),
                    const SizedBox(width: TSpace.md),
                    Expanded(child: Text(e.key, style: TText.bodyBold)),
                    Text(
                      e.value == 1 ? '1 question' : '${e.value} questions',
                      style: TText.smallBold,
                    ),
                  ],
                ),
                const SizedBox(height: TSpace.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: e.value / most,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.7),
                    valueColor: AlwaysStoppedAnimation(
                      SubjectStyle.of(e.key).accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TSpace.sm),
        ],
      ],
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.now});

  final RecentTopic topic;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(topic.subject);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconBadge(icon: style.icon, color: style.accent, size: 32),
          const SizedBox(width: TSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.topic, style: TText.bodyBold, maxLines: 2),
                Text(
                  [
                    SubjectStyle.shortName(topic.subject),
                    if (topic.at != null) sinceLabel(topic.at!.toLocal(), now),
                  ].join(' · '),
                  style: TText.caption.copyWith(color: TColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
