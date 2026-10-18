# moviles_auth

Proyecto base para el **Laboratorio 5: Flujo de login**. Trae las tres pantallas ya dibujadas, en las mismas carpetas y con los mismos nombres del mapa del laboratorio, y la navegación entre ellas. No tiene `Supabase` ni `Bloc` conectados: eso es lo que construyes en el laboratorio.

## Cómo correrlo

```bash
flutter pub get
# Una sola vez: copia la plantilla y escribe la URL y la publishable key
cp config/supabase.example.json config/supabase.json
flutter run --dart-define-from-file=config/supabase.json
```

`config/supabase.json` está en `.gitignore`. En VS Code, la configuración
`moviles_auth (Supabase)` de `.vscode/launch.json` ya pasa ese archivo.
Detalles en `GUIA_PRUEBAS_LABORATORIO_5.md` e `INFORME_LABORATORIO_5.md`.

`flutter_bloc` y `supabase_flutter` ya están en el `pubspec.yaml`.

## Qué trae

```
lib/
├── main.dart                 tema y rutas nombradas
├── theme/app_theme.dart      AppColors y buildTheme()
├── components/
│   ├── primary_button.dart   botón con estado de carga
│   ├── error_message.dart    mensaje de error bajo el formulario
│   └── profile_field.dart    fila de dato del perfil
└── features/
    ├── login/ui/screens/login_screen.dart
    ├── register/ui/screens/register_screen.dart
    └── home/ui/screens/home_screen.dart
```

| Ruta | Pantalla | Qué hace hoy |
| --- | --- | --- |
| `/login` | `LoginScreen` | Valida que los campos no estén vacíos y navega a `/home` |
| `/register` | `RegisterScreen` | Valida los campos, compara las dos contraseñas y navega a `/home` |
| `/home` | `HomeScreen` | Muestra datos de ejemplo y vuelve a `/login` al cerrar sesión |

## Qué te toca conectar

- **Las capas de adentro.** Crea `features/auth/domain` y `features/auth/data` como indica el mapa del laboratorio.
- **Los `Bloc`.** Crea `login/ui/bloc/` y `register/ui/bloc/` junto a la carpeta `screens/` de cada feature.
- **`main.dart`.** Inicializa `Supabase` y envuelve cada ruta en su `BlocProvider`.
- **`LoginScreen` y `RegisterScreen`.** Hoy guardan `_isLoading` y `_errorMessage` con `setState`, y `_submit()` navega directo. Reemplaza eso por tu `Bloc`: `_submit()` lanza el evento, `BlocBuilder` decide el `isLoading` del `PrimaryButton` y el `ErrorMessage`, y `BlocListener` navega cuando el estado es `success`.
- **`HomeScreen`.** Hoy recibe `username`, `fullName` y `email` con valores de ejemplo. Pásale los datos reales del usuario que inició sesión, y haz que `Cerrar sesión` llame a `signOut` antes de navegar.
