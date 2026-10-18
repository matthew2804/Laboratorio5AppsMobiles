import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:moviles_auth/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:moviles_auth/features/login/ui/bloc/login_event.dart';
import 'package:moviles_auth/features/login/ui/bloc/login_state.dart';

export 'package:moviles_auth/features/login/ui/bloc/login_event.dart';
export 'package:moviles_auth/features/login/ui/bloc/login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final SignInUseCase signInUseCase;

  LoginBloc({required this.signInUseCase}) : super(const LoginState()) {
    on<LoginSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    // A second submit while the first one is running is ignored.
    if (state.status == LoginStatus.loading) return;

    emit(state.copyWith(status: LoginStatus.loading, clearError: true));
    try {
      final session = await signInUseCase(
        email: event.email,
        password: event.password,
      );
      emit(
        LoginState(
          status: LoginStatus.success,
          profile: session.profile,
          user: session.user,
        ),
      );
    } on AuthFailure catch (failure) {
      emit(
        LoginState(status: LoginStatus.failure, errorMessage: failure.message),
      );
    } catch (_) {
      emit(
        LoginState(
          status: LoginStatus.failure,
          errorMessage: const UnexpectedFailure().message,
        ),
      );
    }
  }
}
