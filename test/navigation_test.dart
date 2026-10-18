import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviles_auth/main.dart';

import 'helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  setUp(() {
    final log = <String>[];
    auth = FakeAuthRepository(log);
    profiles = FakeProfileRepository(log);
  });

  Widget app() => App(authRepository: auth, profileRepository: profiles);

  testWidgets('sign in goes to profile and sign out comes back', (
    tester,
  ) async {
    profiles.profiles[testUser.id] = testProfile;
    await tester.pumpWidget(app());
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pump();
    expect(find.text('Escribe tu correo y tu contraseña'), findsOneWidget);
    expect(auth.log, isEmpty);

    await tester.enterText(find.byType(TextField).at(0), 'ana@icesi.edu.co');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('@ana'), findsOneWidget);
    expect(find.text('ana@icesi.edu.co'), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Cerrar sesión'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(auth.log, ['auth.signIn', 'profile.get', 'auth.signOut']);
  });

  testWidgets('sign up rejects passwords that do not match', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'ana');
    await tester.enterText(find.byType(TextField).at(1), 'Ana Gómez');
    await tester.enterText(find.byType(TextField).at(2), 'ana@icesi.edu.co');
    await tester.enterText(find.byType(TextField).at(3), '123456');
    await tester.enterText(find.byType(TextField).at(4), '654321');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Registrarme'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrarme'));
    await tester.pump();
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    expect(auth.log, isEmpty);

    await tester.enterText(find.byType(TextField).at(4), '123456');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Registrarme'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrarme'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Ana Gómez'), findsWidgets);
    expect(find.text('@ana'), findsOneWidget);
    expect(profiles.createdId, testUser.id);
  });
}
