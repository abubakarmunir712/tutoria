import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/design/design.dart';
import '../../core/models.dart';
import '../auth/auth_state.dart';
import '../chat/chat_screen.dart';

/// A subject's topics for the learner's class, in curriculum order. Tapping a topic starts the
/// tutor on it; the card at the top starts an open conversation.
class SubjectScreen extends StatefulWidget {
  const SubjectScreen({
    super.key,
    required this.learnerId,
    required this.subject,
  });

  final String learnerId;
  final Subject subject;

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  List<CurriculumStrand>? _strands;
  String? _error;

  Learner get _learner =>
      context.read<AuthState>().learnerById(widget.learnerId)!;

  static const _badgeColors = [
    TColors.blue600,
    TColors.scienceAccent,
    TColors.socialAccent,
    TColors.englishAccent,
    TColors.danger,
    TColors.worldAccent,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final strands = await context.read<ApiClient>().topics(
        grade: _learner.grade!,
        subject: widget.subject.name,
      );
      if (mounted) setState(() => _strands = strands);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.statusCode == 404
              ? 'No topics yet for this class.'
              : e.message,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load topics. Check your connection.',
        );
      }
    }
  }

  void _openChat({String? question}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          grade: _learner.grade,
          subject: widget.subject.name,
          initialQuestion: question,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(widget.subject.name);
    final strands = _strands;
    var number = 0;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              TSpace.page,
              0,
              TSpace.page,
              TSpace.xl,
            ),
            children: [
              Row(
                children: [
                  IconBadge(icon: style.icon, color: style.accent, size: 52),
                  const SizedBox(width: TSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject.name,
                          style: TText.title.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: 4),
                        Pill(
                          text: _learner.classLabel,
                          background: style.tint,
                          foreground: style.accent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TSpace.xl),
              TCard(
                onTap: _openChat,
                color: style.tint,
                borderColor: Colors.transparent,
                shadow: false,
                child: Row(
                  children: [
                    const Mascot(size: 54),
                    const SizedBox(width: TSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ask Tutoria anything', style: TText.subheading),
                          Text(
                            'Questions, homework or a photo',
                            style: TText.small,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: TColors.ink),
                  ],
                ),
              ),
              const SizedBox(height: TSpace.xl),
              if (_error != null)
                Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TText.body.copyWith(color: TColors.muted),
                    ),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                )
              else if (strands == null)
                const Padding(
                  padding: EdgeInsets.all(TSpace.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final strand in strands) ...[
                  Text(strand.name, style: TText.heading),
                  const SizedBox(height: TSpace.md),
                  for (final topic in strand.topics) ...[
                    Builder(
                      builder: (context) {
                        number++;
                        return TCard(
                          onTap: () => _openChat(
                            question: 'Teach me about ${topic.name}',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: TSpace.lg,
                            vertical: TSpace.md,
                          ),
                          child: Row(
                            children: [
                              NumberBadge(
                                number: number,
                                color:
                                    _badgeColors[(number - 1) %
                                        _badgeColors.length],
                              ),
                              const SizedBox(width: TSpace.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      topic.name,
                                      style: TText.bodyBold.copyWith(
                                        color: TColors.ink,
                                      ),
                                    ),
                                    Text(
                                      topic.lessons == 1
                                          ? '1 lesson'
                                          : '${topic.lessons} lessons',
                                      style: TText.small,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: TColors.ink,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: TSpace.md),
                  ],
                  const SizedBox(height: TSpace.md),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
