import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviles_auth/features/auth/domain/entities/user_session.dart';
import 'package:moviles_auth/features/auth/domain/failures/auth_failure.dart';
import 'package:moviles_auth/main.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  setUp(() {
    auth = FakeAuthRepository();
    profiles = FakeProfileRepository();
  });

  Future<void> openRegister(WidgetTester tester) async {
    await tester.pumpWidget(
      App(authRepository: auth, profileRepository: profiles),
    );
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();
  }

  Future<void> fillRegister(
    WidgetTester tester, {
    String username = 'ana',
    String fullName = 'Ana Gómez',
    String email = 'ana@icesi.edu.co',
    String password = '123456',
    String? confirmation,
  }) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), username);
    await tester.enterText(fields.at(1), fullName);
    await tester.enterText(fields.at(2), email);
    await tester.enterText(fields.at(3), password);
    await tester.enterText(fields.at(4), confirmation ?? password);
  }

  Future<void> tapRegister(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Registrarme');
    await tester.ensureVisible(button);
    await tester.tap(button);
  }

  group('RegisterScreen', () {
    testWidgets('requires every field', (tester) async {
      await openRegister(tester);
      await fillRegister(tester, fullName: '');

      await tapRegister(tester);
      await tester.pump();

      expect(find.text('Completa todos los campos'), findsOneWidget);
      expect(auth.log, isEmpty);
    });

    testWidgets('rejects different passwords before calling the bloc', (
      tester,
    ) async {
      await openRegister(tester);
      await fillRegister(tester, confirmation: 'otra-clave');

      await tapRegister(tester);
      await tester.pump();

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(auth.log, isEmpty);
    });

    testWidgets('rejects an invalid email', (tester) async {
      await openRegister(tester);
      await fillRegister(tester, email: 'sin-arroba');

      await tapRegister(tester);
      await tester.pump();

      expect(find.text('Escribe un correo válido'), findsOneWidget);
      expect(auth.log, isEmpty);
    });

    testWidgets('shows a progress indicator and blocks the form', (
      tester,
    ) async {
      auth.gate = Completer<void>();
      await openRegister(tester);
      await fillRegister(tester);

      await tapRegister(tester);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Registrarme'), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.enabled, isFalse);

      auth.gate?.complete();
      await tester.pumpAndSettle();
      expect(find.text('Perfil'), findsOneWidget);
      expect(auth.log.where((c) => c == 'auth.signUp'), hasLength(1));
    });

    testWidgets('shows the error and lets the user try again', (tester) async {
      auth.signUpError = const EmailAlreadyRegisteredFailure();
      auth.signInError = const InvalidCredentialsFailure();
      await openRegister(tester);
      await fillRegister(tester);

      await tapRegister(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(const EmailAlreadyRegisteredFailure().message),
        findsOneWidget,
      );
      expect(find.text('Crea tu cuenta'), findsOneWidget);

      auth.signUpError = null;
      await tester.enterText(find.byType(TextField).at(2), 'otra@icesi.edu.co');
      await tapRegister(tester);
      await tester.pumpAndSettle();
      expect(find.text('Perfil'), findsOneWidget);
    });

    testWidgets('reports a profile that could not be saved', (tester) async {
      profiles.createError = const NetworkFailure();
      await openRegister(tester);
      await fillRegister(tester);

      await tapRegister(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('Tu cuenta se creó'), findsOneWidget);
      expect(find.text('Perfil'), findsNothing);
    });
  });

  group('LoginScreen', () {
    testWidgets('shows an error for wrong credentials', (tester) async {
      auth.signInError = const InvalidCredentialsFailure();
      await tester.pumpWidget(
        App(authRepository: auth, profileRepository: profiles),
      );

      await tester.enterText(find.byType(TextField).at(0), 'ana@icesi.edu.co');
      await tester.enterText(find.byType(TextField).at(1), 'mala');
      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(find.text('Perfil'), findsNothing);
    });

    testWidgets('shows a progress indicator while signing in', (tester) async {
      auth.gate = Completer<void>();
      profiles.profiles[testUser.id] = testProfile;
      await tester.pumpWidget(
        App(authRepository: auth, profileRepository: profiles),
      );

      await tester.enterText(find.byType(TextField).at(0), 'ana@icesi.edu.co');
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      auth.gate?.complete();
      await tester.pumpAndSettle();
      expect(find.text('Perfil'), findsOneWidget);
    });
  });

  group('HomeScreen', () {
    Future<void> openHome(WidgetTester tester) async {
      await tester.pumpWidget(
        App(authRepository: auth, profileRepository: profiles),
      );
      // Navigate the same way the login screen does after a success.
      final context = tester.element(find.text('Bienvenido de nuevo'));
      Navigator.of(context).pushReplacementNamed(
        '/home',
        arguments: const UserSession(user: testUser, profile: testProfile),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the profile and the Auth email', (tester) async {
      await openHome(tester);

      expect(find.text('Ana Gómez'), findsWidgets);
      expect(find.text('@ana'), findsOneWidget);
      expect(find.text('ana@icesi.edu.co'), findsOneWidget);
    });

    testWidgets('stays on the profile when sign out fails', (tester) async {
      auth.signOutError = const NetworkFailure();
      await openHome(tester);

      final button = find.widgetWithText(FilledButton, 'Cerrar sesión');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text(const NetworkFailure().message), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
    });

    testWidgets('/home without a session shows the login', (tester) async {
      await tester.pumpWidget(
        App(authRepository: auth, profileRepository: profiles),
      );
      final context = tester.element(find.text('Bienvenido de nuevo'));
      Navigator.of(context).pushReplacementNamed('/home');
      await tester.pumpAndSettle();

      expect(find.text('Bienvenido de nuevo'), findsOneWidget);
      expect(find.text('Perfil'), findsNothing);
    });
  });
}
