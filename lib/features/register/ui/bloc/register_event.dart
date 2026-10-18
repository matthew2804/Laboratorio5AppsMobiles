/// Events that the register form sends to the `RegisterBloc`.
sealed class RegisterEvent {
  const RegisterEvent();
}

/// The form passed its validations and asks to create the account.
class RegisterSubmitted extends RegisterEvent {
  final String username;
  final String fullName;
  final String email;
  final String password;

  const RegisterSubmitted({
    required this.username,
    required this.fullName,
    required this.email,
    required this.password,
  });
}
