/// Events that the login form sends to the `LoginBloc`.
sealed class LoginEvent {
  const LoginEvent();
}

/// The form passed its validations and asks to sign in.
class LoginSubmitted extends LoginEvent {
  final String email;
  final String password;

  const LoginSubmitted({required this.email, required this.password});
}
