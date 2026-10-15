import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/activity.dart';
import '../../core/design/design.dart';
import '../../core/models.dart';
import '../auth/auth_state.dart';
import '../chat/chat_screen.dart';
import '../onboarding/subjects_screen.dart';
import '../subjects/subject_screen.dart';
import 'subject_picker.dart';

/// "Good morning" / "Good afternoon" / "Good evening" for the learner's local time.
String greetingFor(DateTime now) => now.hour < 12
    ? 'Good morning'
    : now.hour < 17
    ? 'Good afternoon'
    : 'Good evening';

/// "today", "yesterday" or "3 days ago".
String sinceLabel(DateTime then, DateTime now) {
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(then.year, then.month, then.day)).inDays;
  return switch (days) {
    <= 0 => 'today',
    1 => 'yesterday',
    _ => '$days days ago',
  };
}

/// A learner's home: a greeting, where they left off, quick ways to get help, how they are
/// doing and their subjects. Shown as the student's own Home tab, or pushed from a parent's list
/// of children.
class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({
    super.key,
    required this.learnerId,
    this.isOwn = false,
    this.now,
  });

  final String learnerId;

  /// True when this is the signed-in student's own Home tab (no back button).
  final bool isOwn;

  /// The current time; tests pass a fixed one.
  final DateTime? now;

  Future<void> _openChat(
    BuildContext context,
    Learner learner, {
    bool camera = false,
    bool voice = false,
  }) => openTutorChat(context, learner, camera: camera, voice: voice);

  Future<void> _openTopics(BuildContext context, Learner learner) async {
    final subject = await pickSubject(context, learner);
    if (subject == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubjectScreen(learnerId: learner.id, subject: subject),
      ),
    );
  }

  void _continue(
    BuildContext context,
    Learner learner,
    LearnerActivity activity,
  ) {
    final subject = activity.lastSubject;
    if (subject == null) {
      _openChat(context, learner);
      return;
    }
    final topic = activity.lastTopic;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          grade: learner.grade,
          subject: subject,
          learnerId: learner.id,
          topic: topic,
          initialQuestion: topic == null ? null : 'Teach me about $topic',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final learner = auth.learnerById(learnerId);
    if (learner == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final activity = context.watch<ActivityTracker>().of(learnerId);
    final clock = now ?? DateTime.now();
    final hasSubjects = learner.subjects.isNotEmpty;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: TColors.pageGradient),
        child: RefreshIndicator(
          onRefresh: auth.refreshMe,
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
                    TSpace.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (!isOwn)
                            IconButton(
                              style: IconButton.styleFrom(
                                foregroundColor: TColors.ink,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(36, 36),
                              ),
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                          const Wordmark(size: 30),
                          const Spacer(),
                          Pill(
                            text: learner.classLabel,
                            icon: Icons.school_rounded,
                            background: TColors.blue100,
                            foreground: TColors.blue600,
                          ),
                          const SizedBox(width: TSpace.sm),
                          Avatar(name: learner.name, size: 44),
                        ],
                      ),
                      const SizedBox(height: TSpace.xl),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${greetingFor(clock)}, ${learner.firstName}!',
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
                        'Ready to learn something new today?',
                        style: TText.body.copyWith(
                          color: TColors.muted,
                          fontSize: 16,
                        ),
                      ),
                      if (hasSubjects) ...[
                        const SizedBox(height: TSpace.xl),
                        _ContinueCard(
                          activity: activity,
                          now: clock,
                          onContinue: () =>
                              _continue(context, learner, activity),
                        ),
                        const SizedBox(height: TSpace.xl),
                        Text(
                          'What would you like to do?',
                          style: TText.heading,
                        ),
                        const SizedBox(height: TSpace.md),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _ActionTile(
                                  title: 'Ask\nTutoria',
                                  subtitle: 'Get\nhelp',
                                  icon: Icons.chat_bubble_rounded,
                                  accent: TColors.blue600,
                                  tint: const Color(0xFFE3F1FF),
                                  onTap: () => _openChat(context, learner),
                                ),
                              ),
                              const SizedBox(width: TSpace.sm),
                              Expanded(
                                child: _ActionTile(
                                  title: 'Voice\nTutor',
                                  subtitle: 'Talk and\nlearn',
                                  icon: Icons.mic_rounded,
                                  accent: const Color(0xFFFFA400),
                                  tint: const Color(0xFFFFF0D9),
                                  onTap: () =>
                                      _openChat(context, learner, voice: true),
                                ),
                              ),
                              const SizedBox(width: TSpace.sm),
                              Expanded(
                                child: _ActionTile(
                                  title: 'Take a\nPicture',
                                  subtitle: 'Solve with\nyour camera',
                                  icon: Icons.photo_camera_rounded,
                                  accent: const Color(0xFFFF4B6E),
                                  tint: TColors.englishTint,
                                  onTap: () =>
                                      _openChat(context, learner, camera: true),
                                ),
                              ),
                              const SizedBox(width: TSpace.sm),
                              Expanded(
                                child: _ActionTile(
                                  title: 'Learn by\nTopic',
                                  subtitle: 'Explore\nsubjects',
                                  icon: Icons.auto_stories_rounded,
                                  accent: TColors.computingAccent,
                                  tint: TColors.computingTint,
                                  onTap: () => _openTopics(context, learner),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: TSpace.xl),
                        Text('Your learning journey', style: TText.heading),
                        const SizedBox(height: TSpace.md),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: StatCard(
                                  label: 'Questions asked',
                                  value: '${activity.questions}',
                                  icon: Icons.track_changes_rounded,
                                  accent: TColors.blue600,
                                  tint: TColors.blue100,
                                ),
                              ),
                              const SizedBox(width: TSpace.md),
                              Expanded(
                                child: StatCard(
                                  label: 'Learning streak',
                                  value: _days(activity.streakAt(clock)),
                                  icon: Icons.local_fire_department_rounded,
                                  accent: const Color(0xFFFF9500),
                                  tint: const Color(0xFFFFF0D9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: TSpace.xl),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Your subjects',
                                style: TText.heading,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SubjectsScreen(learnerId: learner.id),
                                ),
                              ),
                              child: const Text('Edit'),
                            ),
                          ],
                        ),
                        const SizedBox(height: TSpace.sm),
                        SubjectGrid(
                          subjects: learner.subjects,
                          subtitle: learner.classLabel,
                          onTap: (s) => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SubjectScreen(
                                learnerId: learner.id,
                                subject: s,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: TSpace.xl),
                        TCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose your subjects',
                                style: TText.subheading,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pick the subjects you want help with and your tutor will be ready.',
                                style: TText.small,
                              ),
                              const SizedBox(height: TSpace.md),
                              TButton(
                                label: 'Choose subjects',
                                expanded: false,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SubjectsScreen(learnerId: learner.id),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _days(int n) => n == 1 ? '1 day' : '$n days';
}

/// "Continue learning": where the learner left off, or an invitation to start.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.activity,
    required this.now,
    required this.onContinue,
  });

  final LearnerActivity activity;
  final DateTime now;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final started = activity.hasActivity;
    final title = started
        ? [
            SubjectStyle.shortName(activity.lastSubject!),
            if (activity.lastTopic != null) activity.lastTopic!,
          ].join(' · ')
        : 'Start your first lesson';
    final detail = started
        ? 'Last studied ${sinceLabel(activity.lastAt ?? now, now)}'
        : 'Ask a question, snap your homework or pick a topic.';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: TColors.cardGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x240072FF),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: _Disc(150, Colors.white.withValues(alpha: 0.10)),
            ),
            Positioned(
              right: -30,
              bottom: -60,
              child: _Disc(170, const Color(0xFF188FFF).withValues(alpha: 0.7)),
            ),
            Positioned(
              right: 28,
              bottom: 76,
              child: _Disc(26, const Color(0xFF5DBBFF).withValues(alpha: 0.7)),
            ),
            Padding(
              padding: const EdgeInsets.all(TSpace.lg + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: TColors.blue600,
                        ),
                      ),
                      const SizedBox(width: TSpace.md),
                      Text(
                        started ? 'Continue learning' : 'Welcome',
                        style: TText.subheading.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: TSpace.lg),
                  Text(
                    title,
                    style: TText.heading.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: TText.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: TSpace.lg),
                  TButton(
                    label: started ? 'Continue learning' : 'Ask Tutoria',
                    style: TButtonStyle.cta,
                    icon: Icons.arrow_forward_rounded,
                    iconAfter: true,
                    onPressed: onContinue,
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

class _Disc extends StatelessWidget {
  const _Disc(this.size, this.color);

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TCard(
      onTap: onTap,
      color: tint,
      borderColor: Colors.transparent,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(4, TSpace.md, 4, TSpace.md),
      child: Column(
        children: [
          IconBadge(icon: icon, color: accent, size: 44),
          const SizedBox(height: TSpace.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TText.smallBold.copyWith(color: TColors.ink, height: 1.15),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TText.caption.copyWith(color: TColors.muted, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/// A figure with a label and a round icon: "Questions asked 12", "Learning streak 3 days".
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return TCard(
      borderColor: Colors.transparent,
      padding: const EdgeInsets.all(TSpace.md),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: TSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TText.caption.copyWith(
                    color: TColors.muted,
                    height: 1.1,
                  ),
                  maxLines: 2,
                ),
                Text(
                  value,
                  style: TText.heading.copyWith(fontSize: 22),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Subject tiles, four to a row, each tinted in its subject's colour.
class SubjectGrid extends StatelessWidget {
  const SubjectGrid({
    super.key,
    required this.subjects,
    required this.onTap,
    this.subtitle,
  });

  final List<Subject> subjects;
  final ValueChanged<Subject> onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = TSpace.sm;
        final width = (box.maxWidth - gap * 3) / 4;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in subjects)
              SizedBox(
                width: width,
                child: _SubjectTile(
                  subject: s,
                  subtitle: subtitle,
                  onTap: () => onTap(s),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({
    required this.subject,
    required this.onTap,
    this.subtitle,
  });

  final Subject subject;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(subject.name);
    return TCard(
      onTap: onTap,
      color: style.tint,
      borderColor: Colors.transparent,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(2, TSpace.md, 2, TSpace.md),
      child: Column(
        children: [
          IconBadge(icon: style.icon, color: style.accent, size: 44),
          const SizedBox(height: TSpace.sm),
          Text(
            SubjectStyle.shortName(subject.name),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TText.caption.copyWith(
              color: TColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TText.caption.copyWith(color: TColors.muted, fontSize: 10),
            ),
        ],
      ),
    );
  }
}
