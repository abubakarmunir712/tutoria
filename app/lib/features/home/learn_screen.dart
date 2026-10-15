import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design.dart';
import '../../core/models.dart';
import '../auth/auth_state.dart';
import '../onboarding/subjects_screen.dart';
import '../subjects/subject_screen.dart';

/// The Learn tab: every subject, each opening its topics.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key, required this.learnerId});

  final String learnerId;

  @override
  Widget build(BuildContext context) {
    final learner = context.watch<AuthState>().learnerById(learnerId);
    if (learner == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: TColors.pageGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(TSpace.page),
            children: [
              Text('Learn', style: TText.title.copyWith(fontSize: 28)),
              const SizedBox(height: 2),
              Text(
                'Pick a subject to explore its topics.',
                style: TText.body.copyWith(color: TColors.muted, fontSize: 16),
              ),
              const SizedBox(height: TSpace.xl),
              if (learner.subjects.isEmpty)
                TCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No subjects yet', style: TText.subheading),
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
                )
              else
                for (final s in learner.subjects) ...[
                  _SubjectRow(
                    subject: s,
                    classLabel: learner.classLabel,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SubjectScreen(learnerId: learner.id, subject: s),
                      ),
                    ),
                  ),
                  const SizedBox(height: TSpace.md),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.classLabel,
    required this.onTap,
  });

  final Subject subject;
  final String classLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(subject.name);
    return TCard(
      onTap: onTap,
      color: style.tint,
      borderColor: Colors.transparent,
      shadow: false,
      child: Row(
        children: [
          IconBadge(icon: style.icon, color: style.accent, size: 52),
          const SizedBox(width: TSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject.name, style: TText.subheading),
                Text('$classLabel · Explore topics', style: TText.small),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: TColors.ink),
        ],
      ),
    );
  }
}
