import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:moviles_auth/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:moviles_auth/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:moviles_auth/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:moviles_auth/features/home/ui/bloc/home_bloc.dart';
import 'package:moviles_auth/features/login/ui/bloc/login_bloc.dart';
import 'package:moviles_auth/features/register/ui/bloc/register_bloc.dart';

import '../helpers/fakes.dart';

const _submitted = RegisterSubmitted(
  username: 'ana',
  fullName: 'Ana Gómez',
  email: 'ana@icesi.edu.co',
  password: 'secreto123',
);

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  setUp(() {
    auth = FakeAuthRepository();
    profiles = FakeProfileRepository();
  });

  group('RegisterBloc', () {
    late RegisterBloc bloc;

    setUp(() {
      bloc = RegisterBloc(
        signUpUseCase: SignUpUseCase(
          authRepository: auth,
          profileRepository: profiles,
        ),
      );
    });

    tearDown(() => bloc.close());

    test('starts in initial without profile or error', () {
      expect(bloc.state, const RegisterState());
      expect(bloc.state.status, RegisterStatus.initial);
      expect(bloc.state.profile, isNull);
      expect(bloc.state.errorMessage, isNull);
    });

    test('emits loading and then success with the profile', () async {
      final states = expectLater(
        bloc.stream,
        emitsInOrder([
          const RegisterState(status: RegisterStatus.loading),
          const RegisterState(
            status: RegisterStatus.success,
            profile: testProfile,
            user: testUser,
          ),
        ]),
      );

      bloc.add(_submitted);
      await states;
      expect(bloc.state.session?.user.email, testUser.email);
    });

    test('emits loading and then failure with a message', () async {
      auth.signUpError = const NetworkFailure();
      final states = expectLater(
        bloc.stream,
        emitsInOrder([
          const RegisterState(status: RegisterStatus.loading),
          RegisterState(
            status: RegisterStatus.failure,
            errorMessage: const NetworkFailure().message,
          ),
        ]),
      );

      bloc.add(_submitted);
      await states;
      expect(bloc.state.profile, isNull);
    });

    test('hides technical details of unexpected errors', () async {
      auth.signUpError = StateError('stack trace with secrets');

      bloc.add(_submitted);
      await bloc.stream.firstWhere((s) => s.status == RegisterStatus.failure);

      expect(bloc.state.errorMessage, const UnexpectedFailure().message);
    });

    test('ignores a second submit while loading', () async {
      auth.gate = Completer<void>();

      bloc.add(_submitted);
      await bloc.stream.firstWhere((s) => s.status == RegisterStatus.loading);
      bloc.add(_submitted);
      await Future<void>.delayed(Duration.zero);
      auth.gate?.complete();
      await bloc.stream.firstWhere((s) => s.status == RegisterStatus.success);

      expect(auth.log.where((call) => call == 'auth.signUp'), hasLength(1));
    });

    test('a new submit after a failure clears the previous error', () async {
      auth.signUpError = const NetworkFailure();
      bloc.add(_submitted);
      await bloc.stream.firstWhere((s) => s.status == RegisterStatus.failure);

      auth.signUpError = null;
      final states = expectLater(
        bloc.stream,
        emitsInOrder([
          const RegisterState(status: RegisterStatus.loading),
          isA<RegisterState>().having(
            (s) => s.status,
            'status',
            RegisterStatus.success,
          ),
        ]),
      );
      bloc.add(_submitted);
      await states;
    });
  });

  group('LoginBloc', () {
    late LoginBloc bloc;

    setUp(() {
      bloc = LoginBloc(
        signInUseCase: SignInUseCase(
          authRepository: auth,
          profileRepository: profiles,
        ),
      );
    });

    tearDown(() => bloc.close());

    test('starts in initial', () {
      expect(bloc.state, const LoginState());
    });

    test('emits loading and success with profile and Auth email', () async {
      profiles.profiles[testUser.id] = testProfile;
      final states = expectLater(
        bloc.stream,
        emitsInOrder([
          const LoginState(status: LoginStatus.loading),
          const LoginState(
            status: LoginStatus.success,
            profile: testProfile,
            user: testUser,
          ),
        ]),
      );

      bloc.add(
        const LoginSubmitted(email: 'ana@icesi.edu.co', password: 'pw1234'),
      );
      await states;
    });

    test('emits loading and failure for wrong credentials', () async {
      auth.signInError = const InvalidCredentialsFailure();
      final states = expectLater(
        bloc.stream,
        emitsInOrder([
          const LoginState(status: LoginStatus.loading),
          LoginState(
            status: LoginStatus.failure,
            errorMessage: const InvalidCredentialsFailure().message,
          ),
        ]),
      );

      bloc.add(const LoginSubmitted(email: 'ana@icesi.edu.co', password: 'x'));
      await states;
      expect(bloc.state.session, isNull);
    });

    test('a missing profile is a failure, never a success', () async {
      profiles.getError = const ProfileNotFoundFailure();

      bloc.add(
        const LoginSubmitted(email: 'ana@icesi.edu.co', password: 'pw1234'),
      );
      await bloc.stream.firstWhere((s) => s.status == LoginStatus.failure);

      expect(bloc.state.errorMessage, const ProfileNotFoundFailure().message);
      expect(auth.log, contains('auth.signOut'));
    });
  });

  group('HomeBloc', () {
    test('emits loading and signedOut after closing the session', () async {
      final bloc = HomeBloc(
        signOutUseCase: SignOutUseCase(authRepository: auth),
      );
      final states = expectLater(
        bloc.stream,
        emitsInOrder([
          const HomeState(status: HomeStatus.loading),
          const HomeState(status: HomeStatus.signedOut),
        ]),
      );

      bloc.add(const SignOutRequested());
      await states;
      expect(auth.log, ['auth.signOut']);
      await bloc.close();
    });

    test('emits failure when the session could not be closed', () async {
      auth.signOutError = const NetworkFailure();
      final bloc = HomeBloc(
        signOutUseCase: SignOutUseCase(authRepository: auth),
      );

      bloc.add(const SignOutRequested());
      await bloc.stream.firstWhere((s) => s.status == HomeStatus.failure);

      expect(bloc.state.errorMessage, const NetworkFailure().message);
      await bloc.close();
    });
  });
}
