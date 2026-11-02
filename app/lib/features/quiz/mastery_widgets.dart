import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/design/design.dart';
import '../../core/progress.dart';
import '../../core/quiz.dart';

/// A small coloured label for where a learner stands on a unit.
class MasteryChip extends StatelessWidget {
  const MasteryChip({super.key, required this.mastery, this.compact = false});

  final Mastery mastery;
  final bool compact;

  @override
  Widget build(BuildContext context) => Pill(
    text: mastery.label,
    icon: compact ? null : mastery.icon,
    background: mastery.tint,
    foreground: mastery == Mastery.notStarted ? TColors.muted : mastery.color,
  );
}

/// "Topic mastery": how many units are Secure or Mastered, per subject, and what to revisit.
/// Loads itself, and loads again when the learner earns XP (a quiz was finished).
class MasterySection extends StatefulWidget {
  const MasterySection({
    super.key,
    required this.learnerId,
    this.forParent = false,
  });

  final String learnerId;

  /// Wording for a parent looking at a child's progress.
  final bool forParent;

  @override
  State<MasterySection> createState() => _MasterySectionState();
}

class _MasterySectionState extends State<MasterySection> {
  MasteryOverview? _overview;
  bool _failed = false;
  int? _loadedAtXp;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final xp = context.watch<ProgressStore>().peek(widget.learnerId)?.xp ?? 0;
    if (_loadedAtXp != xp) {
      _loadedAtXp = xp;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final o = await context.read<ApiClient>().masteryOverview(
        widget.learnerId,
      );
      if (mounted) {
        setState(() {
          _overview = o;
          _failed = false;
        });
      }
    } catch (_) {
      // Mastery is extra information: a failed load just hides the section.
      if (mounted && _overview == null) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _overview;
    if (_failed || o == null || o.summary.total == 0) {
      return const SizedBox.shrink();
    }
    final s = o.summary;
    return Padding(
      padding: const EdgeInsets.only(top: TSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Topic mastery', style: TText.heading),
          const SizedBox(height: TSpace.md),
          TCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.started == 0
                            ? widget.forParent
                                  ? 'No quizzes taken yet.'
                                  : 'Take a quiz to start your mastery map.'
                            : '${s.done} of ${s.total} topics secure',
                        style: TText.subheading,
                      ),
                    ),
                    if (s.mastered > 0)
                      Pill(
                        text: '${s.mastered} mastered',
                        icon: Mastery.mastered.icon,
                        background: Mastery.mastered.tint,
                        foreground: Mastery.mastered.color,
                      ),
                  ],
                ),
                const SizedBox(height: TSpace.md),
                _SegmentBar(summary: s),
                if (o.bySubject.any((b) => b.summary.started > 0)) ...[
                  const SizedBox(height: TSpace.lg),
                  for (final b in o.bySubject.where(
                    (b) => b.summary.started > 0,
                  ))
                    _SubjectRow(mastery: b),
                ],
              ],
            ),
          ),
          if (o.needsRevision.isNotEmpty) ...[
            const SizedBox(height: TSpace.md),
            Text(
              widget.forParent ? 'Worth revisiting' : 'Time to revise',
              style: TText.subheading,
            ),
            const SizedBox(height: TSpace.sm),
            for (final u in o.needsRevision)
              Padding(
                padding: const EdgeInsets.only(bottom: TSpace.sm),
                child: TCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TSpace.lg,
                    vertical: TSpace.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.name, style: TText.bodyBold),
                            Text(u.subject, style: TText.small),
                          ],
                        ),
                      ),
                      MasteryChip(mastery: u.mastery, compact: true),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One bar split by state: mastered, secure, developing, needs revision, not started.
class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.summary});

  final MasterySummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final parts = [
      (s.mastered, Mastery.mastered.color),
      (s.secure, Mastery.secure.color),
      (s.developing, Mastery.developing.color),
      (s.needsRevision, Mastery.needsRevision.color),
      (s.total - s.started, TColors.blue100),
    ].where((p) => p.$1 > 0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 12,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in parts)
              Expanded(
                flex: p.$1,
                child: ColoredBox(color: p.$2),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.mastery});

  final SubjectMastery mastery;

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(mastery.subject);
    final s = mastery.summary;
    return Padding(
      padding: const EdgeInsets.only(bottom: TSpace.md),
      child: Row(
        children: [
          IconBadge(icon: style.icon, color: style.accent, size: 34),
          const SizedBox(width: TSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mastery.subject, style: TText.bodyBold),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: s.fraction,
                    minHeight: 8,
                    backgroundColor: style.tint,
                    color: style.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: TSpace.md),
          Text('${s.done}/${s.total}', style: TText.smallBold),
        ],
      ),
    );
  }
}
