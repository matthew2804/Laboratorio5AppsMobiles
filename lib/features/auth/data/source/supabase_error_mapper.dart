import 'dart:async';
import 'dart:developer' as developer;

import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates the exceptions of the Supabase SDK into [AuthFailure]s.
///
/// Only the exception type and its error code are logged, never the request
/// data, so passwords and tokens do not end up in the logs.
AuthFailure mapSupabaseError(Object error, {required String operation}) {
  final failure = switch (error) {
    AuthFailure() => error,
    AuthException() => _mapAuthException(error),
    PostgrestException() => _mapPostgrestException(error),
    TimeoutException() => const NetworkFailure(),
    _ when _looksLikeNetworkError(error) => const NetworkFailure(),
    _ => const UnexpectedFailure(),
  };
  developer.log(
    '$operation failed with ${error.runtimeType} -> ${failure.runtimeType}'
    '${_codeOf(error)}',
    name: 'auth',
  );
  return failure;
}

AuthFailure _mapAuthException(AuthException error) {
  if (error is AuthRetryableFetchException) return const NetworkFailure();
  if (error is AuthWeakPasswordException) return const WeakPasswordFailure();

  switch (error.code) {
    case 'user_already_exists' || 'email_exists':
      return const EmailAlreadyRegisteredFailure();
    case 'invalid_credentials':
      return const InvalidCredentialsFailure();
    case 'email_not_confirmed':
      return const EmailConfirmationRequiredFailure();
    case 'weak_password':
      return const WeakPasswordFailure();
    case 'email_address_invalid':
      return const InvalidEmailFailure();
    case 'over_request_rate_limit' || 'over_email_send_rate_limit':
      return const RateLimitFailure();
    case 'signup_disabled':
      return const ServerFailure(
        'El registro de usuarios está deshabilitado en el proyecto.',
      );
  }

  // Older Auth servers answer without a code.
  final message = error.message.toLowerCase();
  if (message.contains('already registered')) {
    return const EmailAlreadyRegisteredFailure();
  }
  if (message.contains('invalid login credentials')) {
    return const InvalidCredentialsFailure();
  }
  if (message.contains('email not confirmed')) {
    return const EmailConfirmationRequiredFailure();
  }
  if (error.statusCode == '429') return const RateLimitFailure();
  if (_looksLikeNetworkError(error)) return const NetworkFailure();
  return const ServerFailure();
}

AuthFailure _mapPostgrestException(PostgrestException error) {
  switch (error.code) {
    // insufficient_privilege: blocked by RLS or by missing grants.
    case '42501':
      return const PermissionDeniedFailure();
    // JWT expired or missing: the request was not authenticated.
    case 'PGRST301' || 'PGRST302' || '401':
      return const PermissionDeniedFailure();
    case '23505':
      return const ServerFailure(
        'Ya existe un perfil para esta cuenta o ese nombre de usuario.',
      );
    case '23502' || '42703' || 'PGRST204':
      return const ServerFailure(
        'La tabla profiles no tiene la estructura esperada. Revisa la '
        'migración de la base de datos.',
      );
    case '42P01' || 'PGRST205':
      return const ServerFailure('La tabla profiles no existe en el proyecto.');
  }
  return const ServerFailure();
}

/// `SocketException` and `ClientException` are not available on every
/// platform, so they are recognised by name.
bool _looksLikeNetworkError(Object error) {
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('Network is unreachable') ||
      text.contains('XMLHttpRequest error');
}

String _codeOf(Object error) => switch (error) {
  AuthException(:final code, :final statusCode) =>
    ' (code: $code, status: $statusCode)',
  PostgrestException(:final code) => ' (code: $code)',
  _ => '',
};
