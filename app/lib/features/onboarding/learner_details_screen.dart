import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design.dart';
import '../../core/grade_labels.dart';
import '../../core/models.dart';
import '../auth/auth_state.dart';
import 'subjects_screen.dart';

/// Step 2 of 3: the learner's name, class and school type. For a parent this describes a child;
/// for a student it is their own profile. With [existing] it edits that learner instead.
class LearnerDetailsScreen extends StatefulWidget {
  const LearnerDetailsScreen({
    super.key,
    this.existing,
    this.onboarding = false,
    this.initialName,
  });

  final Learner? existing;

  /// A name to start the name field with (a student's own, from sign-up).
  final String? initialName;

  /// True while finishing sign-up (shows the step dots, and finishing returns to the app root).
  final bool onboarding;

  @override
  State<LearnerDetailsScreen> createState() => _LearnerDetailsScreenState();
}

class _LearnerDetailsScreenState extends State<LearnerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  String? _grade;
  String? _schoolType;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final learner = widget.existing;
    _name = TextEditingController(
      text: learner?.name ?? widget.initialName ?? '',
    );
    _grade = learner?.grade;
    _schoolType = learner?.schoolType;
    _name.addListener(
      () => setState(() {}),
    ); // keeps the avatar's initials live
    context.read<AuthState>().error = null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthState>();
    final isParent = auth.me?.isParent ?? false;
    final name = _name.text.trim();

    final Learner? learner;
    if (_editing) {
      learner = await auth.editLearner(
        widget.existing!.id,
        name: name,
        grade: _grade,
        schoolType: _schoolType,
      );
    } else if (isParent) {
      learner = await auth.addLearner(
        name: name,
        grade: _grade!,
        schoolType: _schoolType,
      );
    } else {
      // A student's own profile already exists (made at sign-up); fill it in.
      learner = await auth.editLearner(
        auth.me!.learners.first.id,
        name: name,
        grade: _grade,
        schoolType: _schoolType,
      );
    }
    if (learner == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubjectsScreen(
          learnerId: learner!.id,
          onboarding: widget.onboarding,
        ),
      ),
    );
  }

  Future<void> _remove() async {
    final learner = widget.existing!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${learner.firstName}?'),
        content: const Text(
          'Their subjects and chats will be removed from your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: TColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (await context.read<AuthState>().removeLearner(learner.id) && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final isParent = auth.me?.isParent ?? false;
    final title = _editing
        ? 'Edit ${widget.existing!.firstName}'
        : isParent
        ? 'Tell us about your child'
        : 'Tell us about you';
    return Scaffold(
      appBar: AppBar(),
      body: SoftBlobs(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              TSpace.page + 4,
              0,
              TSpace.page + 4,
              TSpace.xl,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.onboarding) ...[
                    const StepDots(count: 3, index: 1),
                    const SizedBox(height: TSpace.xl),
                  ],
                  Text(title, style: TText.title),
                  const SizedBox(height: 4),
                  Text(
                    'This helps us personalise their learning experience.',
                    style: TText.body.copyWith(color: TColors.muted),
                  ),
                  const SizedBox(height: TSpace.xl),
                  Center(child: Avatar(name: _name.text, size: 88)),
                  const SizedBox(height: TSpace.xl),
                  TTextField(
                    controller: _name,
                    label: isParent ? 'Child’s name' : 'Your name',
                    hint: 'e.g. Ama',
                    icon: Icons.face_rounded,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: TSpace.lg),
                  TDropdownField<String>(
                    label: 'Class',
                    hint: 'Choose a class',
                    icon: Icons.school_rounded,
                    value: _grade,
                    items: [
                      for (final g in gradeCodes)
                        DropdownMenuItem(value: g, child: Text(gradeLabel(g))),
                    ],
                    onChanged: (v) => setState(() => _grade = v),
                    validator: (v) => v == null ? 'Choose a class' : null,
                  ),
                  const SizedBox(height: TSpace.lg),
                  TDropdownField<String>(
                    label: 'School type',
                    hint: 'Choose a school type',
                    icon: Icons.apartment_rounded,
                    value: _schoolType,
                    items: [
                      for (final e in schoolTypeLabels.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _schoolType = v),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: TSpace.md),
                    Text(
                      auth.error!,
                      style: TText.body.copyWith(color: TColors.danger),
                    ),
                  ],
                  const SizedBox(height: TSpace.xl),
                  TButton(
                    label: _editing ? 'Save and choose subjects' : 'Next',
                    loading: auth.isLoading,
                    onPressed: _submit,
                  ),
                  if (_editing && isParent) ...[
                    const SizedBox(height: TSpace.md),
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: TColors.danger,
                        ),
                        onPressed: _remove,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                        ),
                        label: Text('Remove ${widget.existing!.firstName}'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
