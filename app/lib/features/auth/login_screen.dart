import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design.dart';
import '../onboarding/user_type_screen.dart';
import 'auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<AuthState>().login(
      identifier: _identifier.text.trim(),
      password: _password.text,
    );
    if (ok && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      backgroundColor: TColors.blue600,
      body: Column(
        children: [
          HeroBackground(
            child: SizedBox(
              width: double.infinity,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TSpace.page,
                    TSpace.sm,
                    TSpace.page,
                    56,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(height: TSpace.md),
                      const Wordmark(onBlue: true, size: 34),
                      const SizedBox(height: TSpace.lg),
                      Text(
                        'Welcome back!',
                        style: TText.title.copyWith(
                          color: Colors.white,
                          fontSize: 30,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to keep learning.',
                        style: TText.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: TColors.blue50,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(TRadius.xl),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    TSpace.page + 4,
                    TSpace.xl + 4,
                    TSpace.page + 4,
                    TSpace.xl,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TTextField(
                          controller: _identifier,
                          hint: 'Email or phone number',
                          icon: Icons.person_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Enter your email or phone number'
                              : null,
                        ),
                        const SizedBox(height: TSpace.md),
                        TTextField(
                          controller: _password,
                          hint: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          validator: (v) =>
                              (v ?? '').isEmpty ? 'Enter your password' : null,
                        ),
                        if (auth.error != null) ...[
                          const SizedBox(height: TSpace.md),
                          Container(
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
                                    auth.error!,
                                    style: TText.body.copyWith(
                                      color: TColors.danger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: TSpace.xl),
                        TButton(
                          label: 'Sign In',
                          loading: auth.isLoading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: TSpace.md),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context)
                                .pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const UserTypeScreen(),
                                  ),
                                ),
                            child: const Text(
                              'New to Tutoria? Create an account',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
