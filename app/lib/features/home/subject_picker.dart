import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/models.dart';
import '../chat/chat_screen.dart';

/// Asks "Which subject?" when a learner has several; with one subject it is chosen for them.
Future<Subject?> pickSubject(BuildContext context, Learner learner) async {
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

/// Opens the tutor chat for a learner, asking for the subject first if they have several.
Future<void> openTutorChat(
  BuildContext context,
  Learner learner, {
  bool camera = false,
  bool voice = false,
}) async {
  final subject = await pickSubject(context, learner);
  if (subject == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        grade: learner.grade,
        subject: subject.name,
        learnerId: learner.id,
        startWithCamera: camera,
        startWithVoice: voice,
      ),
    ),
  );
}
