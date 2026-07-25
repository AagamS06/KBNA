import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/auth_controller.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';
import '../widgets/pill_button.dart';

/// 2.1 Sign in. Prove it's the owner, then get out of the way.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  // Prefilled with the seeded demo email; the demo password is changeMe1234.
  final _email = TextEditingController(text: 'owner@knightsbridgenews.com.au');
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(authProvider.notifier)
        .signIn(_email.text, _password.text);
    if (!ref.read(authProvider).signedIn) {
      _password.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: KnSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: KnSpace.s9),
              // Logo mark (decorative).
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kn.accentRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text('K',
                        style: KnType.title2.copyWith(color: Colors.white)),
                  ),
                  const SizedBox(width: KnSpace.s3),
                  Text('KNIGHTSBRIDGE\nNEWSAGENCY',
                      style: KnType.eyebrow.copyWith(color: kn.textPrimary)),
                ],
              ),
              const SizedBox(height: KnSpace.s8),
              const Eyebrow('Owner sign-in'),
              const SizedBox(height: KnSpace.s2),
              Text('Sign in to manage\nyour stock.',
                  style: KnType.title1.copyWith(color: kn.textPrimary)),
              const SizedBox(height: KnSpace.s7),

              _FieldLabel('Email address'),
              _TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                hint: 'owner@knightsbridgenews.com.au',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: KnSpace.s5),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _FieldLabel('Password'),
                  IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ],
              ),
              _TextField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _canSubmit ? _submit() : null,
              ),

              if (auth.error != null) ...[
                const SizedBox(height: KnSpace.s4),
                _ErrorBanner(auth.error!),
              ],

              const SizedBox(height: KnSpace.s6),
              PillButton(
                'Sign in',
                showArrowBadge: true,
                loading: auth.loading,
                loadingLabel: 'Signing in…',
                onPressed:
                    (_canSubmit && !auth.isLockedOut) ? _submit : null,
              ),
              const SizedBox(height: KnSpace.s3),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => _showRecovery(context),
                  child: Text("I've forgotten my password",
                      style: KnType.button.copyWith(color: kn.textPrimary)),
                ),
              ),
              const SizedBox(height: KnSpace.s9),
              Center(
                child: Text(
                  'Shop 5, 159 Ridgecrop Drive\nCastle Hill NSW 2154',
                  textAlign: TextAlign.center,
                  style: KnType.caption.copyWith(color: kn.textSecondary),
                ),
              ),
              const SizedBox(height: KnSpace.s6),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecovery(BuildContext context) {
    final kn = context.kn;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(KnSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Forgotten password',
                style: KnType.title3.copyWith(color: kn.textPrimary)),
            const SizedBox(height: KnSpace.s3),
            Text(
              "We'll email a reset link to the address on file. "
              "It's the address ending …au.",
              style: KnType.body.copyWith(color: kn.textSecondary),
            ),
            const SizedBox(height: KnSpace.s5),
            PillButton('Send the link', onPressed: () {
              Navigator.pop(context);
            }),
            const SizedBox(height: KnSpace.s3),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KnSpace.s2),
      child: Text(text, style: KnType.label.copyWith(color: context.kn.textPrimary)),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.hint,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: false,
      style: KnType.body.copyWith(color: kn.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: KnType.body.copyWith(color: kn.textSecondary),
        constraints: const BoxConstraints(minHeight: 52),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: KnSpace.s4, vertical: KnSpace.s3),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KnRadius.control),
          borderSide: BorderSide(color: kn.lineControl, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KnRadius.control),
          borderSide: BorderSide(color: kn.textPrimary, width: 2),
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
    final kn = context.kn;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(KnSpace.s3),
        decoration: BoxDecoration(
          color: kn.washRed,
          border: Border.all(color: kn.textRed),
          borderRadius: BorderRadius.circular(KnRadius.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: kn.textRed, size: 20),
            const SizedBox(width: KnSpace.s2),
            Expanded(
              child: Text(message,
                  style: KnType.secondary.copyWith(color: kn.textRed)),
            ),
          ],
        ),
      ),
    );
  }
}

