import 'package:moviles_auth/features/auth/data/models/auth_user_model.dart';
import 'package:moviles_auth/features/auth/data/source/supabase_error_mapper.dart';
import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase Auth. Every error leaves this class as an `AuthFailure`.
class SupabaseAuthDataSource {
  final SupabaseClient client;

  const SupabaseAuthDataSource(this.client);

  Future<AuthUserModel> signUp({
    required String email,
    required String password,
  }) async {
    final AuthResponse response;
    try {
      response = await client.auth.signUp(email: email, password: password);
    } catch (error) {
      throw mapSupabaseError(error, operation: 'signUp');
    }

    final user = response.user;
    if (user == null) throw const InvalidAuthResponseFailure();

    // With email confirmation enabled, Supabase answers a taken email with a
    // fake user that has no identities instead of an error.
    final identities = user.identities;
    if (identities != null && identities.isEmpty) {
      throw const EmailAlreadyRegisteredFailure();
    }

    // Without a session the insert into profiles would run as `anon` and be
    // rejected by RLS, so the flow stops here.
    if (response.session == null) {
      throw const EmailConfirmationRequiredFailure();
    }

    return AuthUserModel(id: user.id, email: user.email ?? email);
  }

  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  }) async {
    final AuthResponse response;
    try {
      response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (error) {
      throw mapSupabaseError(error, operation: 'signIn');
    }

    final user = response.user;
    if (user == null || response.session == null) {
      throw const InvalidAuthResponseFailure();
    }
    return AuthUserModel(id: user.id, email: user.email ?? email);
  }

  /// Supabase removes the local session before revoking it on the server. If
  /// only the server call fails the device is already signed out, which is
  /// what the app needs, so that case is not reported as an error.
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (error) {
      final failure = mapSupabaseError(error, operation: 'signOut');
      if (client.auth.currentSession != null) throw failure;
    }
  }
}
