import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

@immutable
class AuthState {
  const AuthState({
    this.signedIn = false,
    this.loading = false,
    this.error,
    this.attempts = 0,
    this.lockedUntil,
  });

  final bool signedIn;
  final bool loading;

  /// Plain-English message shown inline above the Sign in button, or null.
  final String? error;

  final int attempts;
  final DateTime? lockedUntil;

  bool get isLockedOut =>
      lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  AuthState copyWith({
    bool? signedIn,
    bool? loading,
    Object? error = _sentinel,
    int? attempts,
    Object? lockedUntil = _sentinel,
  }) {
    return AuthState(
      signedIn: signedIn ?? this.signedIn,
      loading: loading ?? this.loading,
      error: error == _sentinel ? this.error : error as String?,
      attempts: attempts ?? this.attempts,
      lockedUntil:
          lockedUntil == _sentinel ? this.lockedUntil : lockedUntil as DateTime?,
    );
  }

  static const _sentinel = Object();
}

/// Local demo authentication. Compares the typed details against the
/// credentials held in the repository (see Credentials note in app_settings).
/// In production this is replaced by Supabase Auth + a biometric re-entry gate;
/// the screens only ever call [signIn]/[signOut], so that swap is invisible.
class AuthController extends Notifier<AuthState> {
  static const _maxAttempts = 8;
  static const _lockout = Duration(minutes: 5);

  @override
  AuthState build() => const AuthState();

  Future<void> signIn(String email, String password) async {
    if (state.isLockedOut) return;
    state = state.copyWith(loading: true, error: null);

    final repo = await ref.read(repoReadyProvider.future);
    final creds = await repo.getCredentials();

    final ok = email.trim().toLowerCase() == creds.email.toLowerCase() &&
        password == creds.password;

    if (ok) {
      state = const AuthState(signedIn: true);
      return;
    }

    final attempts = state.attempts + 1;
    if (attempts >= _maxAttempts) {
      state = state.copyWith(
        loading: false,
        attempts: attempts,
        lockedUntil: DateTime.now().add(_lockout),
        error: 'Too many tries. Wait five minutes and have another go.',
      );
    } else {
      state = state.copyWith(
        loading: false,
        attempts: attempts,
        error:
            "That email or password isn't right. Check for a stray space, then try again.",
      );
    }
  }

  void signOut() {
    state = const AuthState();
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(error: null);
  }
}

final authProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
