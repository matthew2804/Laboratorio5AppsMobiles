import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:moviles_auth/features/auth/domain/usecases/sign_out_usecase.dart';

sealed class HomeEvent {
  const HomeEvent();
}

class SignOutRequested extends HomeEvent {
  const SignOutRequested();
}

enum HomeStatus { initial, loading, signedOut, failure }

class HomeState {
  final HomeStatus status;
  final String? errorMessage;

  const HomeState({this.status = HomeStatus.initial, this.errorMessage});

  @override
  bool operator ==(Object other) =>
      other is HomeState &&
      other.status == status &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(status, errorMessage);

  @override
  String toString() =>
      'HomeState(status: $status, errorMessage: $errorMessage)';
}

/// Closes the Supabase session from the profile screen.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final SignOutUseCase signOutUseCase;

  HomeBloc({required this.signOutUseCase}) : super(const HomeState()) {
    on<SignOutRequested>(_onSignOutRequested);
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (state.status == HomeStatus.loading) return;

    emit(const HomeState(status: HomeStatus.loading));
    try {
      await signOutUseCase();
      emit(const HomeState(status: HomeStatus.signedOut));
    } on AuthFailure catch (failure) {
      emit(
        HomeState(status: HomeStatus.failure, errorMessage: failure.message),
      );
    } catch (_) {
      emit(
        HomeState(
          status: HomeStatus.failure,
          errorMessage: const UnexpectedFailure().message,
        ),
      );
    }
  }
}
