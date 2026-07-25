import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../state/providers.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/pill_button.dart';

/// Settings → Sign-in details. Change email and/or password. Unlike the old
/// website, this REQUIRES the current password before anything changes.
class SignInDetailsScreen extends ConsumerStatefulWidget {
  const SignInDetailsScreen({super.key});

  @override
  ConsumerState<SignInDetailsScreen> createState() =>
      _SignInDetailsScreenState();
}

class _SignInDetailsScreenState extends ConsumerState<SignInDetailsScreen> {
  final _email = TextEditingController();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = await ref.read(repoReadyProvider.future);
    final creds = await repo.getCredentials();

    if (_current.text != creds.password) {
      setState(() {
        _saving = false;
        _error = 'Your current password isn\'t right.';
      });
      return;
    }
    if (_new.text.isNotEmpty && _new.text != _confirm.text) {
      setState(() {
        _saving = false;
        _error = 'The new passwords don\'t match.';
      });
      return;
    }

    await repo.setCredentials(Credentials(
      email: _email.text.trim().isEmpty ? creds.email : _email.text.trim(),
      password: _new.text.isEmpty ? creds.password : _new.text,
    ));

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          "Your sign-in details are saved. You'll use the new ones next time."),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      final async = ref.watch(repoReadyProvider);
      return async.when(
        loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
        data: (repo) {
          return FutureBuilder(
            future: repo.getCredentials(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              if (!_loaded) {
                _email.text = snap.data!.email;
                _loaded = true;
              }
              return _form();
            },
          );
        },
      );
    }
    return _form();
  }

  Widget _form() {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign-in details')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(KnSpace.s4),
              children: [
                _label('Email address'),
                _field(_email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: KnSpace.s6),
                _label('Current password'),
                _field(_current, obscure: true),
                const SizedBox(height: KnSpace.s6),
                _label('New password'),
                _field(_new, obscure: true),
                const SizedBox(height: KnSpace.s3),
                _label('Confirm new password'),
                _field(_confirm, obscure: true),
                if (_error != null) ...[
                  const SizedBox(height: KnSpace.s4),
                  Text(_error!,
                      style: KnType.secondary.copyWith(color: context.kn.textRed)),
                ],
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.kn.surface,
              border: Border(top: BorderSide(color: context.kn.lineHairline)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(KnSpace.s4),
                child: PillButton('Save',
                    loading: _saving, loadingLabel: 'Saving…', onPressed: _save),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: KnSpace.s2),
        child: Text(t, style: KnType.label.copyWith(color: context.kn.textPrimary)),
      );

  Widget _field(TextEditingController c,
      {bool obscure = false, TextInputType? keyboardType}) {
    final kn = context.kn;
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: false,
      style: KnType.body.copyWith(color: kn.textPrimary),
      decoration: InputDecoration(
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
