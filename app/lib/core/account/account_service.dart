import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../org/org_store.dart';
import 'supabase_config.dart';

class AccountUser {
  const AccountUser({required this.id, this.email});
  final String id;
  final String? email;
}

/// The participant's account. The presenter never needs one.
/// Notifies listeners when the user signs in or out.
abstract class AccountService extends ChangeNotifier {
  AccountUser? get user;

  bool get isSignedIn => user != null;

  /// Token the server uses to act as this user (Row Level Security applies).
  String? get accessToken;

  /// Emails a one-time code (and a link) that signs in, creating the account if needed.
  Future<void> sendEmailCode(String email);

  Future<void> verifyEmailCode(String email, String code);

  Future<void> signInWithGoogle();

  /// Only the demo accounts made by tools/seed_test_accounts.py have a password; real accounts
  /// sign in with an emailed code.
  Future<void> signInWithPassword(String email, String password);

  Future<void> signOut();

  /// Deletes the account and everything saved with it, then signs out.
  Future<void> deleteAccount();
}

class SupabaseAccountService extends AccountService {
  SupabaseAccountService(this._client) {
    _changes = _client.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
      // An expired refresh token surfaces here; the user simply appears signed out.
      onError: (Object _) => notifyListeners(),
    );
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _changes;

  String? get _redirect => kIsWeb ? null : SupabaseConfig.mobileRedirect;

  @override
  AccountUser? get user {
    final current = _client.auth.currentUser;
    return current == null ? null : AccountUser(id: current.id, email: current.email);
  }

  @override
  String? get accessToken => _client.auth.currentSession?.accessToken;

  @override
  Future<void> sendEmailCode(String email) =>
      _client.auth.signInWithOtp(email: email.trim(), shouldCreateUser: true, emailRedirectTo: _redirect);

  @override
  Future<void> verifyEmailCode(String email, String code) async {
    await _client.auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.email);
  }

  @override
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(OAuthProvider.google, redirectTo: _redirect);
  }

  @override
  Future<void> signInWithPassword(String email, String password) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> deleteAccount() async {
    await guardLastAdmin(_client.rpc('delete_my_account'));
    // The session's user no longer exists; clear it locally only.
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  @override
  void dispose() {
    _changes.cancel();
    super.dispose();
  }
}
