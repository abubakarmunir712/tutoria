import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/design/design.dart';
import '../../core/models.dart';
import '../auth/auth_state.dart';

/// Step 3 of 3 (and the "change subjects" screen): which subjects the learner wants help with,
/// from those taught in their class.
class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({
    super.key,
    required this.learnerId,
    this.onboarding = false,
  });

  final String learnerId;
  final bool onboarding;

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  List<Subject>? _subjects;
  final _selected = <String>{};
  String? _loadError;

  Learner get _learner =>
      context.read<AuthState>().learnerById(widget.learnerId)!;

  @override
  void initState() {
    super.initState();
    _selected.addAll(_learner.subjects.map((s) => s.id));
    context.read<AuthState>().error = null;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final subjects = await context.read<ApiClient>().listSubjects(
        grade: _learner.grade!,
      );
      if (mounted) setState(() => _subjects = subjects);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _loadError = 'Could not load subjects. Check your connection.',
        );
      }
    }
  }

  Future<void> _save() async {
    final auth = context.read<AuthState>();
    final saved = await auth.chooseSubjects(
      widget.learnerId,
      _selected.toList(),
    );
    if (saved == null || !mounted) return;
    // Onboarding ends at the app root (which now shows the home screen); editing just goes back.
    if (widget.onboarding) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final subjects = _subjects;
    return Scaffold(
      appBar: AppBar(),
      body: SoftBlobs(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    TSpace.page + 4,
                    0,
                    TSpace.page + 4,
                    TSpace.lg,
                  ),
                  children: [
                    if (widget.onboarding) ...[
                      const StepDots(count: 3, index: 2),
                      const SizedBox(height: TSpace.xl),
                    ],
                    Text('What would you like\nhelp with?', style: TText.title),
                    const SizedBox(height: 4),
                    Text(
                      'You can select more than one subject.',
                      style: TText.body.copyWith(color: TColors.muted),
                    ),
                    const SizedBox(height: TSpace.xl),
                    if (_loadError != null)
                      Column(
                        children: [
                          Text(
                            _loadError!,
                            style: TText.body.copyWith(color: TColors.danger),
                          ),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                        ],
                      )
                    else if (subjects == null)
                      const Padding(
                        padding: EdgeInsets.all(TSpace.xl),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      for (final s in subjects) ...[
                        _SubjectRow(
                          subject: s,
                          selected: _selected.contains(s.id),
                          onTap: () => setState(
                            () => _selected.contains(s.id)
                                ? _selected.remove(s.id)
                                : _selected.add(s.id),
                          ),
                        ),
                        const SizedBox(height: TSpace.md),
                      ],
                    if (auth.error != null)
                      Text(
                        auth.error!,
                        style: TText.body.copyWith(color: TColors.danger),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TSpace.page + 4,
                  0,
                  TSpace.page + 4,
                  TSpace.lg,
                ),
                child: TButton(
                  label: widget.onboarding ? 'Finish' : 'Save',
                  loading: auth.isLoading,
                  onPressed: _selected.isEmpty ? null : _save,
                ),
              ),
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
    required this.selected,
    required this.onTap,
  });

  final Subject subject;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(subject.name);
    return TCard(
      onTap: onTap,
      selected: selected,
      color: style.tint,
      borderColor: Colors.transparent,
      shadow: false,
      padding: const EdgeInsets.symmetric(
        horizontal: TSpace.lg,
        vertical: TSpace.md,
      ),
      child: Row(
        children: [
          IconBadge(icon: style.icon, color: style.accent),
          const SizedBox(width: TSpace.lg),
          Expanded(child: Text(subject.name, style: TText.subheading)),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: selected ? TColors.blue600 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? TColors.blue600 : TColors.blue200,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
        ],
      ),
    );
  }
}
