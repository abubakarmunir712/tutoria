import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design.dart';
import '../../core/models.dart';
import 'auth_state.dart';
import 'login_screen.dart';

/// Step 1 of 3: create the account. A parent then adds a child; a student fills in their own
/// class and subjects.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthState>();
    final ok = await auth.signup(
      fullName: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      password: _password.text,
      role: widget.role,
    );
    // Signed in: drop back to the root, where the app routes on to the next onboarding step.
    if (ok && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final isParent = widget.role == UserRole.parent;
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
                  const StepDots(count: 3, index: 0),
                  const SizedBox(height: TSpace.xl),
                  Text('Create Account', style: TText.title),
                  const SizedBox(height: 4),
                  Text(
                    isParent ? 'Let’s get you set up' : 'Let’s get you started',
                    style: TText.body.copyWith(color: TColors.muted),
                  ),
                  const SizedBox(height: TSpace.xl),
                  TTextField(
                    controller: _name,
                    hint: isParent ? 'Full name' : 'Your full name',
                    icon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: (v) =>
                        (v ?? '').trim().length < 2 ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: TSpace.md),
                  TTextField(
                    controller: _email,
                    hint: 'Email address',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) =>
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch((v ?? '').trim())
                        ? null
                        : 'Enter a valid email',
                  ),
                  const SizedBox(height: TSpace.md),
                  TTextField(
                    controller: _phone,
                    hint: 'Phone number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: (v) =>
                        (v ?? '').replaceAll(RegExp(r'\D'), '').length < 9
                        ? 'Enter a valid phone number'
                        : null,
                  ),
                  const SizedBox(height: TSpace.md),
                  TTextField(
                    controller: _password,
                    hint: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => _submit(),
                    validator: (v) => (v ?? '').length < 8
                        ? 'Use at least 8 characters'
                        : null,
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: TSpace.md),
                    _ErrorBanner(auth.error!),
                  ],
                  const SizedBox(height: TSpace.xl),
                  TButton(
                    label: 'Create Account',
                    loading: auth.isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: TSpace.md),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text('Already have an account? Sign In'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TSpace.md),
      decoration: BoxDecoration(
        color: TColors.dangerTint,
        borderRadius: BorderRadius.circular(TRadius.md),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: TColors.danger,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TText.body.copyWith(color: TColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
