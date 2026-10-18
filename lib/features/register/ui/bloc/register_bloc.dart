import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:moviles_auth/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:moviles_auth/features/register/ui/bloc/register_event.dart';
import 'package:moviles_auth/features/register/ui/bloc/register_state.dart';

export 'package:moviles_auth/features/register/ui/bloc/register_event.dart';
export 'package:moviles_auth/features/register/ui/bloc/register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final SignUpUseCase signUpUseCase;

  RegisterBloc({required this.signUpUseCase}) : super(const RegisterState()) {
    on<RegisterSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    // A second submit while the first one is running is ignored.
    if (state.status == RegisterStatus.loading) return;

    emit(state.copyWith(status: RegisterStatus.loading, clearError: true));
    try {
      final session = await signUpUseCase(
        username: event.username,
        fullName: event.fullName,
        email: event.email,
        password: event.password,
      );
      emit(
        RegisterState(
          status: RegisterStatus.success,
          profile: session.profile,
          user: session.user,
        ),
      );
    } on AuthFailure catch (failure) {
      emit(
        RegisterState(
          status: RegisterStatus.failure,
          errorMessage: failure.message,
        ),
      );
    } catch (_) {
      emit(
        RegisterState(
          status: RegisterStatus.failure,
          errorMessage: const UnexpectedFailure().message,
        ),
      );
    }
  }
}
