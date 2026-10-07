import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design.dart';
import '../../core/models.dart';
import '../auth/auth_state.dart';
import '../chat/chat_screen.dart';
import '../onboarding/subjects_screen.dart';
import '../subjects/subject_screen.dart';
import 'header.dart';

/// A learner's home: a greeting, quick ways to get help, and their subjects. Shown as the
/// student's own Home tab, or pushed from a parent's list of children.
class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({
    super.key,
    required this.learnerId,
    this.isOwn = false,
  });

  final String learnerId;

  /// True when this is the signed-in student's own Home tab (no back button).
  final bool isOwn;

  Future<Subject?> _pickSubject(BuildContext context, Learner learner) async {
    if (learner.subjects.length == 1) return learner.subjects.first;
    return showModalBottomSheet<Subject>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TSpace.page,
            0,
            TSpace.page,
            TSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Which subject?', style: TText.heading),
              const SizedBox(height: TSpace.md),
              for (final s in learner.subjects)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: IconBadge(
                    icon: SubjectStyle.of(s.name).icon,
                    color: SubjectStyle.of(s.name).accent,
                    size: 40,
                  ),
                  title: Text(s.name, style: TText.bodyBold),
                  onTap: () => Navigator.pop(context, s),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openChat(
    BuildContext context,
    Learner learner, {
    bool camera = false,
  }) async {
    final subject = await _pickSubject(context, learner);
    if (subject == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          grade: learner.grade,
          subject: subject.name,
          startWithCamera: camera,
        ),
      ),
    );
  }

  Future<void> _openTopics(BuildContext context, Learner learner) async {
    final subject = await _pickSubject(context, learner);
    if (subject == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubjectScreen(learnerId: learner.id, subject: subject),
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
    final hasSubjects = learner.subjects.isNotEmpty;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: auth.refreshMe,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            WaveHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!isOwn)
                        IconButton(
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      const Spacer(),
                      Pill.onBlue(
                        text: learner.classLabel,
                        icon: Icons.school_rounded,
                      ),
                      const SizedBox(width: TSpace.sm),
                      Avatar(name: learner.name, size: 44),
                    ],
                  ),
                  const SizedBox(height: TSpace.sm),
                  Greeting(
                    text: 'Hi ${learner.firstName}',
                    style: TText.title.copyWith(
                      color: Colors.white,
                      fontSize: 30,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ready to learn today?',
                    style: TText.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: TSpace.lg),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Mascot(size: 84),
                      SizedBox(width: TSpace.md),
                      Expanded(
                        child: SpeechBubble(
                          text: 'Small steps every day lead to big progress!',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TSpace.page,
                0,
                TSpace.page,
                TSpace.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasSubjects) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            label: 'Ask\nTutoria',
                            icon: Icons.chat_bubble_rounded,
                            accent: TColors.blue600,
                            tint: TColors.blue100,
                            onTap: () => _openChat(context, learner),
                          ),
                        ),
                        const SizedBox(width: TSpace.md),
                        Expanded(
                          child: _ActionTile(
                            label: 'Take a\nPicture',
                            icon: Icons.photo_camera_rounded,
                            accent: TColors.socialAccent,
                            tint: TColors.socialTint,
                            onTap: () =>
                                _openChat(context, learner, camera: true),
                          ),
                        ),
                        const SizedBox(width: TSpace.md),
                        Expanded(
                          child: _ActionTile(
                            label: 'Learn by\nTopic',
                            icon: Icons.auto_stories_rounded,
                            accent: TColors.englishAccent,
                            tint: TColors.englishTint,
                            onTap: () => _openTopics(context, learner),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TSpace.xl),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Your Subjects', style: TText.heading),
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
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: TSpace.md,
                      crossAxisSpacing: TSpace.md,
                      childAspectRatio: 0.95,
                      children: [
                        for (final s in learner.subjects)
                          _SubjectTile(
                            subject: s,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SubjectScreen(
                                  learnerId: learner.id,
                                  subject: s,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ] else
                    TCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Choose your subjects', style: TText.subheading),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.accent,
    required this.tint,
    required this.onTap,
  });

  final String label;
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
      padding: const EdgeInsets.symmetric(
        vertical: TSpace.lg,
        horizontal: TSpace.sm,
      ),
      child: Column(
        children: [
          IconBadge(icon: icon, color: accent),
          const SizedBox(height: TSpace.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TText.smallBold.copyWith(color: TColors.ink, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.subject, required this.onTap});

  final Subject subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(subject.name);
    return TCard(
      onTap: onTap,
      color: style.tint,
      borderColor: Colors.transparent,
      shadow: false,
      padding: const EdgeInsets.all(TSpace.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconBadge(icon: style.icon, color: style.accent, size: 44),
          const SizedBox(height: TSpace.sm),
          Text(
            SubjectStyle.shortName(subject.name),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TText.smallBold.copyWith(color: TColors.ink),
          ),
        ],
      ),
    );
  }
}
