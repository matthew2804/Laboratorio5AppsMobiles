/// Errors that the auth feature can report. Each one carries a message that
/// can be shown to the user as is, without technical details.
sealed class AuthFailure implements Exception {
  final String message;

  const AuthFailure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class EmailAlreadyRegisteredFailure extends AuthFailure {
  const EmailAlreadyRegisteredFailure()
    : super(
        'Ya existe una cuenta con este correo. Inicia sesión o usa otro correo.',
      );
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure() : super('Correo o contraseña incorrectos.');
}

class InvalidEmailFailure extends AuthFailure {
  const InvalidEmailFailure() : super('El correo no tiene un formato válido.');
}

class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure()
    : super(
        'La contraseña es demasiado débil. Usa al menos 6 caracteres '
        'combinando letras y números.',
      );
}

class EmailConfirmationRequiredFailure extends AuthFailure {
  const EmailConfirmationRequiredFailure()
    : super(
        'Debes confirmar tu correo antes de continuar. Revisa tu bandeja de '
        'entrada y vuelve a intentarlo con los mismos datos.',
      );
}

class NetworkFailure extends AuthFailure {
  const NetworkFailure()
    : super(
        'No hay conexión con el servidor. Revisa tu conexión a internet e '
        'inténtalo de nuevo.',
      );
}

class RateLimitFailure extends AuthFailure {
  const RateLimitFailure()
    : super('Demasiados intentos. Espera unos minutos e inténtalo de nuevo.');
}

/// Auth answered without a user (or without a session) where one is required.
class InvalidAuthResponseFailure extends AuthFailure {
  const InvalidAuthResponseFailure()
    : super('El servidor no devolvió un usuario válido. Inténtalo de nuevo.');
}

class PermissionDeniedFailure extends AuthFailure {
  const PermissionDeniedFailure()
    : super('No tienes permiso para guardar o consultar este perfil.');
}

class ProfileNotFoundFailure extends AuthFailure {
  const ProfileNotFoundFailure()
    : super(
        'Tu cuenta existe, pero no tiene un perfil asociado. Completa el '
        'registro con el mismo correo y contraseña.',
      );
}

/// The account was created in Auth but its row in `profiles` could not be
/// saved. Both operations are not atomic, so the user is told how to finish.
class ProfileCreationFailure extends AuthFailure {
  final AuthFailure? cause;

  ProfileCreationFailure({this.cause})
    : super(
        'Tu cuenta se creó, pero no pudimos guardar tu perfil'
        '${_reason(cause)}. Vuelve a pulsar "Registrarme" con el mismo '
        'correo y contraseña para completarlo.',
      );

  static String _reason(AuthFailure? cause) => switch (cause) {
    NetworkFailure() => ' por falta de conexión',
    PermissionDeniedFailure() => ' por un problema de permisos',
    _ => '',
  };
}

class ServerFailure extends AuthFailure {
  const ServerFailure([
    super.message =
        'El servidor no pudo completar la operación. Inténtalo más tarde.',
  ]);
}

class UnexpectedFailure extends AuthFailure {
  const UnexpectedFailure()
    : super('Ocurrió un error inesperado. Inténtalo de nuevo.');
}
