# Informe técnico — Laboratorio 5

| | |
| --- | --- |
| **Asignatura** | Aplicaciones Móviles |
| **Laboratorio** | Laboratorio 5 — Registro e inicio de sesión con Supabase, BLoC y Clean Architecture |
| **Proyecto** | `moviles_auth` (basado en el repositorio `262App3`) |
| **Fecha de elaboración** | 17 de octubre de 2026 |
| **Estudiante** | ______________________________________ |
| **Código** | ______________________________________ |

---

## 1. Objetivos

1. Registrar usuarios en Supabase Auth y guardar su perfil (`username`, `full_name`) en `public.profiles` con el **mismo UID**.
2. Organizar el código en Clean Architecture: dominio sin dependencias externas, datos como única capa que conoce el SDK y presentación con BLoC.
3. Implementar inicio y cierre de sesión reales (parte 2 del laboratorio).
4. Manejar los errores de forma coherente y comprensible, sin exponer secretos.
5. Respaldar el comportamiento con pruebas automatizadas que no dependan de Supabase.

## 2. Descripción del problema y del flujo de registro

El proyecto base traía las pantallas `LoginScreen`, `RegisterScreen` y `HomeScreen` con navegación simulada. Además, tenía un `RegisterBloc` preliminar que llamaba a Supabase directamente desde la presentación (`lib/features/register/ui/bloc/register_bloc.dart` en el commit `f419ff3`). Ese BLoC tenía cuatro problemas:

- Insertaba `response.user?.id`, que podía ser `null`.
- Mostraba `e.toString()` al usuario.
- Mezclaba Auth y base de datos en la vista.
- No impedía envíos duplicados.

El registro necesita **dos operaciones independientes**:

1. `auth.signUp(email, password)` crea la cuenta en `auth.users` y devuelve el UID.
2. `insert` en `public.profiles` guarda `id = UID`, `username` y `full_name`.

Estas dos operaciones **no forman una transacción atómica**. Si la primera funciona y la segunda falla, queda una cuenta sin perfil. La sección 9.3 explica cómo se resuelve ese caso.

## 3. Arquitectura implementada

```
┌──────────────────────── Presentación (Flutter + BLoC) ─────────────────────────┐
│ RegisterScreen ─► RegisterBloc     LoginScreen ─► LoginBloc     HomeScreen ─► HomeBloc │
└───────────────┬───────────────────────────┬───────────────────────────┬────────┘
                ▼                           ▼                           ▼
┌──────────────────────────── Dominio (Dart puro) ───────────────────────────────┐
│ SignUpUseCase            SignInUseCase            SignOutUseCase              │
│ AuthRepository (contrato)   ProfileRepository (contrato)   AuthFailure (sealed)│
│ AuthUser   Profile   UserSession                                               │
└───────────────┬───────────────────────────────────────────────────────────────┘
                ▼ implementa
┌──────────────────────────── Datos ─────────────────────────────────────────────┐
│ AuthRepositoryImpl ─► SupabaseAuthDataSource ─┐                                │
│ ProfileRepositoryImpl ─► SupabaseProfileDataSource ─┼─► supabase_flutter (SDK) │
│ AuthUserModel / ProfileModel   supabase_error_mapper ─┘                        │
└───────────────────────────────────────────────────────────────────────────────┘
```

**Regla de dependencias.** La presentación depende del dominio, y los datos implementan los contratos del dominio. Se verificó con `grep` que `lib/features/auth/domain` no importa `flutter`, `flutter_bloc` ni `supabase_flutter`. El SDK solo se importa en los tres archivos de `data/source/` y en `main.dart`, que inicializa el cliente y conecta las dependencias.

**Inyección de dependencias.** `main.dart` construye los data sources y los repositorios y se los pasa a `App`. `App` publica los casos de uso con `MultiRepositoryProvider` y crea cada BLoC con un `BlocProvider` en su ruta. Como `App` recibe los repositorios por constructor, las pruebas de widgets pueden usar *fakes*.

## 4. Estructura final de directorios

```
lib/
├── main.dart                                 inicialización, inyección y rutas
├── core/config/
│   ├── supabase_config.dart                  lectura y validación de --dart-define
│   └── configuration_error_screen.dart       pantalla de configuración incompleta
├── components/                               (sin cambios) PrimaryButton, ErrorMessage, ProfileField
├── theme/app_theme.dart                      (sin cambios)
└── features/
    ├── auth/
    │   ├── domain/
    │   │   ├── entities/      auth_user.dart · profile.dart · user_session.dart
    │   │   ├── failures/      auth_failure.dart
    │   │   ├── repository/    auth_repository.dart · profile_repository.dart
    │   │   └── usecases/      sign_up_usecase.dart · sign_in_usecase.dart · sign_out_usecase.dart
    │   └── data/
    │       ├── models/        auth_user_model.dart · profile_model.dart
    │       ├── source/        supabase_auth_data_source.dart · supabase_profile_data_source.dart · supabase_error_mapper.dart
    │       └── repository/    auth_repository_impl.dart · profile_repository_impl.dart
    ├── register/ui/  bloc/ (register_event · register_state · register_bloc)  screens/register_screen.dart
    ├── login/ui/     bloc/ (login_event · login_state · login_bloc)           screens/login_screen.dart
    └── home/ui/      bloc/home_bloc.dart                                      screens/home_screen.dart
test/
├── helpers/fakes.dart
├── core/supabase_config_test.dart
├── features/auth/domain/  sign_up_usecase_test.dart · sign_in_and_out_usecase_test.dart
├── features/auth/data/data_layer_test.dart
├── features/blocs_test.dart
├── features/screens_test.dart
└── navigation_test.dart
config/supabase.example.json                  plantilla (el archivo supabase.json real está en .gitignore)
supabase/migrations/20261017120000_profiles_rls.sql
.vscode/launch.json
evidencias/                                   salidas reales de format, analyze, test y build
```

## 5. Componentes

### 5.1 Entidades (`features/auth/domain/entities`)

| Entidad | Campos | Uso |
| --- | --- | --- |
| `AuthUser` | `id`, `email` | Cuenta de Supabase Auth |
| `Profile` | `id`, `username`, `fullName` | Fila de `profiles` en el modelo de la app |
| `UserSession` | `user: AuthUser`, `profile: Profile` | Lo que reciben `/home` y los estados de éxito. Permite mostrar el **correo real de Auth** junto al perfil |

Todas las entidades son inmutables y definen `==` y `hashCode`, así las pruebas pueden comparar estados sin añadir la dependencia `equatable`.

### 5.2 Fallos (`domain/failures/auth_failure.dart`)

`AuthFailure` es una clase `sealed`. Cada subtipo lleva un mensaje en español listo para mostrar al usuario:

- `EmailAlreadyRegisteredFailure`
- `InvalidCredentialsFailure`
- `InvalidEmailFailure`
- `WeakPasswordFailure`
- `EmailConfirmationRequiredFailure`
- `NetworkFailure`
- `RateLimitFailure`
- `InvalidAuthResponseFailure`
- `PermissionDeniedFailure`
- `ProfileNotFoundFailure`
- `ProfileCreationFailure(cause)`
- `ServerFailure`
- `UnexpectedFailure`

### 5.3 Repositorios (contratos)

- `AuthRepository`: `signUp`, `signIn` y `signOut`.
- `ProfileRepository`:
  - `createProfile({id, username, fullName, email})`.
  - `getProfile(id)`, que lanza `ProfileNotFoundFailure` si el perfil no existe.

### 5.4 Data sources y repositorios (capa de datos)

- **`SupabaseAuthDataSource`**
  - `signUp` comprueba que `response.user` no sea nulo y lanza `InvalidAuthResponseFailure` si lo es, sin usar `!`.
  - Si `user.identities` está vacío, el correo ya existe: Supabase responde así cuando la confirmación está activa.
  - Si `response.session` es nula, la confirmación de correo está activa y el insert fallaría por RLS. En ese caso lanza `EmailConfirmationRequiredFailure`.
  - `signIn` exige usuario y sesión.
  - `signOut` llama a `auth.signOut()`. El SDK borra primero la sesión local y después la revoca en el servidor. Si solo falla la llamada al servidor, el dispositivo ya no tiene sesión y el cierre se considera correcto. Si la sesión local sigue existiendo, se lanza el error.
- **`SupabaseProfileDataSource`**
  - `insertProfile` hace el `insert` sin leer la fila de vuelta, para no depender de la política de `select`.
  - `getProfileById` usa `maybeSingle()` y devuelve `null` si no encuentra la fila.
- **`supabase_error_mapper.dart`** traduce `AuthException` (por `code` y, en servidores antiguos, por mensaje), `PostgrestException` (`42501` para RLS, `23505` para duplicados, `PGRST301` para JWT, y los errores de esquema) y los errores de red. Solo registra el tipo de error y su código con `dart:developer`, nunca los datos de la petición.
- **Modelos.** `ProfileModel.fromRow` y `ProfileModel.toRow` traducen entre `full_name` y `fullName`. `fromRow` valida los tipos y devuelve `null` si la fila está incompleta. `toRow` no incluye la contraseña.
- **`AuthRepositoryImpl` y `ProfileRepositoryImpl`** convierten los modelos en entidades. También garantizan que al dominio solo lleguen `AuthFailure`: cualquier otro error se convierte en `UnexpectedFailure`.

### 5.5 Casos de uso

- **`SignUpUseCase`**
  1. Llama a `authRepository.signUp`.
  2. Llama a `profileRepository.createProfile` con `id = user.id`.
  3. Devuelve `UserSession`.

  Coordina el orden de las dos operaciones, así que el BLoC hace una sola llamada. El tratamiento de fallos y la recuperación se explican en la sección 9.3.
- **`SignInUseCase`**
  1. Llama a `signIn`.
  2. Llama a `getProfile(user.id)`.
  3. Devuelve `UserSession`.

  Si el perfil no se puede cargar, cierra la sesión antes de propagar el error. Así un login fallido nunca deja una sesión abierta.
- **`SignOutUseCase`** delega en `authRepository.signOut()`.

### 5.6 BLoC

| BLoC | Evento | Estado | Estados del ciclo |
| --- | --- | --- | --- |
| `RegisterBloc` | `RegisterSubmitted(username, fullName, email, password)` | `RegisterState(status, profile?, user?, errorMessage?)` + `copyWith` | `initial → loading → success \| failure` |
| `LoginBloc` | `LoginSubmitted(email, password)` | `LoginState(status, profile?, user?, errorMessage?)` + `copyWith` | `initial → loading → success \| failure` |
| `HomeBloc` | `SignOutRequested` | `HomeState(status, errorMessage?)` | `initial → loading → signedOut \| failure` |

Los tres comparten estas reglas:

- Ignoran un evento que llega mientras el estado es `loading`.
- Al empezar limpian el error anterior (`copyWith(clearError: true)`).
- Muestran `AuthFailure.message`. Cualquier otro error se convierte en `UnexpectedFailure`, así el usuario nunca ve trazas técnicas.

### 5.7 Pantallas

Las pantallas conservan su diseño original y siguen usando `PrimaryButton`, `ErrorMessage` y `ProfileField`.

- **`RegisterScreen` y `LoginScreen`**
  - Validan el formulario en la propia pantalla: campos vacíos, formato del correo, longitud mínima, y en el registro que las contraseñas coincidan.
  - Solo cuando el formulario es válido envían el evento.
  - `BlocBuilder` decide `isLoading` y el mensaje de error. Durante la carga, el `PrimaryButton` muestra un spinner y los campos se desactivan.
  - `BlocListener` navega a `/home` con `arguments: UserSession` cuando el estado es `success`.
  - Se eliminó el `_isLoading` local. Se mantiene `_validationError` solo para los errores de validación.
- **`HomeScreen`**
  - Recibe `username`, `fullName` y `email` como parámetros obligatorios; se quitaron los valores de ejemplo.
  - «Cerrar sesión» envía `SignOutRequested` y navega a `/login` (vaciando la pila) solo cuando el estado es `signedOut`.
  - Si el cierre falla, muestra el error y se queda en la pantalla.
- **Ruta `/home`.** Si se abre sin un `UserSession` como argumento, muestra el login en lugar del perfil.

## 6. Flujos

### 6.1 Registro

```
Usuario ─► RegisterScreen: valida (vacíos, correo, longitud, coincidencia)
        └─► RegisterBloc.add(RegisterSubmitted) ─► emit(loading)
              └─► SignUpUseCase
                    1. AuthRepository.signUp ─► SupabaseAuthDataSource ─► auth.signUp
                         · user == null      → InvalidAuthResponseFailure
                         · identities vacías → EmailAlreadyRegisteredFailure
                         · session == null   → EmailConfirmationRequiredFailure
                    2. ProfileRepository.createProfile(id: user.id, …) ─► insert profiles
                    → UserSession
              ◄─ emit(success, profile, user)  |  emit(failure, mensaje)
BlocListener(success) ─► Navigator.pushReplacementNamed('/home', arguments: UserSession)
```

### 6.2 Inicio y cierre de sesión

```
LoginScreen ─► LoginBloc(LoginSubmitted) ─► SignInUseCase
                 1. signInWithPassword → AuthUser (exige user y session)
                 2. getProfile(user.id) → Profile  (si falla: signOut y error)
              ◄─ success(UserSession) → /home (perfil + correo de Auth)

HomeScreen ─► HomeBloc(SignOutRequested) ─► SignOutUseCase ─► auth.signOut()
              ◄─ signedOut → pushNamedAndRemoveUntil('/login')
```

## 7. Modelo de datos de Supabase

```
auth.users (Supabase Auth)            public.profiles
┌──────────────┐ 1        0..1 ┌─────────────────────────────────────────────────────┐
│ id uuid (PK) │◄──────────────│ id uuid PK  REFERENCES auth.users(id) ON DELETE CASCADE │
│ email        │               │ username text NOT NULL                              │
│ …            │               │ full_name text NOT NULL                             │
└──────────────┘               │ email text NOT NULL (columna existente del proyecto) │
                               └─────────────────────────────────────────────────────┘
```

**Verificación de la configuración real.** El 17 de octubre de 2026 se hicieron consultas **solo de lectura** con la publishable key, sin crear ni modificar datos:

| Comprobación | Resultado observado | Conclusión |
| --- | --- | --- |
| `GET /auth/v1/settings` | `mailer_autoconfirm: true`, `disable_signup: false` | La confirmación de correo está **desactivada** y `signUp` devuelve sesión, así que el insert como `authenticated` es posible. **La suposición del laboratorio se cumple.** |
| `GET /rest/v1/profiles?select=id,username,full_name&limit=0` | HTTP 200, `[]` | La tabla y las columnas del laboratorio existen |
| `GET /rest/v1/profiles?select=email&limit=0` | HTTP 200, `[]` | También existe la columna `email` (definida como `NOT NULL` en las migraciones). Por eso la app la rellena con el correo de Auth |
| Esquema OpenAPI | HTTP 401: *Secret API key required* | No se puede ver la nulabilidad ni el estado de RLS sin la secret key, que no se usó a propósito |

**Seguridad (RLS).** El repositorio no tenía políticas. Se añadió la migración `supabase/migrations/20261017120000_profiles_rls.sql`, que hace lo siguiente:

- Es idempotente y no borra datos.
- Activa RLS.
- Retira todos los permisos a `anon`.
- Deja a `authenticated` solo `SELECT`, `INSERT` y `UPDATE`.
- Crea tres políticas con `(select auth.uid()) = id`: `select_own`, `insert_own` y `update_own` (esta última con `USING` y `WITH CHECK`). Así nadie puede crear, leer ni modificar el perfil de otra persona.
- No permite `DELETE`; el borrado ocurre en cascada desde `auth.users`.

**La migración no se aplicó en el proyecto remoto** porque no había autorización. El estado actual de RLS en remoto **no se pudo verificar**. El dato de que `anon` puede hacer `SELECT` (HTTP 200) indica que sí tiene permiso de tabla, y si RLS estuviera desactivado podría leer filas. Por eso se recomienda aplicar la migración (guía, sección 5.3).

## 8. Configuración y despliegue local

- La URL y la clave se leen con `String.fromEnvironment` (`SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`) mediante `--dart-define-from-file=config/supabase.json`.
- `config/supabase.json` está en `.gitignore`. Se versiona solo la plantilla `config/supabase.example.json`.
- `SupabaseConfig.validate()` detecta los valores que faltan, una URL inválida y las claves `sb_secret_…` o JWT con `role = service_role`. En cualquiera de esos casos se muestra `ConfigurationErrorApp` en vez de fallar.
- Si falla `Supabase.initialize`, también se muestra esa pantalla.
- La URL y la publishable key estaban escritas en `main.dart` (commit `f419ff3`). Se quitaron del código y se movieron al archivo local ignorado. La publishable key está diseñada para ser pública, pero sigue en el historial de git. Si se quiere invalidar, se puede rotar en el panel.

## 9. Validaciones, manejo de errores y seguridad

### 9.1 Validaciones en la presentación

Estas validaciones se hacen antes de emitir el evento, así que no generan llamadas de red:

- Campos vacíos: «Completa todos los campos» y, en el login, «Escribe tu correo y tu contraseña».
- Formato del correo: «Escribe un correo válido».
- Longitud mínima de 6 caracteres, igual que el mínimo por defecto de Supabase.
- Contraseña y confirmación distintas: «Las contraseñas no coinciden».

### 9.2 Matriz de errores

| Caso | Origen / detección | Mensaje mostrado |
| --- | --- | --- |
| Campos incompletos | Pantalla | «Completa todos los campos» |
| Contraseñas distintas | Pantalla | «Las contraseñas no coinciden» |
| Correo ya registrado | `user_already_exists`, `email_exists`, «already registered» o identidades vacías | «Ya existe una cuenta con este correo…» |
| Credenciales incorrectas | `invalid_credentials` | «Correo o contraseña incorrectos.» |
| Sin conexión | `AuthRetryableFetchException`, `SocketException`, `ClientException`, `TimeoutException` | «No hay conexión con el servidor…» |
| Usuario nulo en Auth | `response.user == null` | «El servidor no devolvió un usuario válido…» |
| Sin sesión tras el registro | `response.session == null` | «Debes confirmar tu correo…» |
| Fallo al insertar el perfil | Cualquier error en `createProfile` | «Tu cuenta se creó, pero no pudimos guardar tu perfil [motivo]…» |
| Perfil inexistente al iniciar sesión | `maybeSingle()` devuelve `null` | «Tu cuenta existe, pero no tiene un perfil asociado…» (y se cierra la sesión) |
| Permisos o RLS | Postgrest `42501` o `PGRST301` | «No tienes permiso para guardar o consultar este perfil.» |
| Configuración incompleta | `SupabaseConfig.validate()` | Pantalla «Configuración incompleta» |
| Contraseña débil o límite de intentos | `weak_password` o `over_*_rate_limit` | Mensajes específicos |

### 9.3 Fallo entre Auth y el perfil (operaciones no atómicas)

Si Auth crea la cuenta pero falla el insert del perfil, `SignUpUseCase` hace lo siguiente:

1. Cierra la sesión para no dejarla a medias.
2. Lanza `ProfileCreationFailure`, cuyo mensaje dice que la cuenta **sí se creó** y cómo terminar el registro. El fallo no se oculta.

Para completar el registro, el usuario vuelve a pulsar **Registrarme** con el mismo correo y la misma contraseña:

1. Auth responde «correo ya registrado».
2. El caso de uso inicia sesión con esas credenciales.
3. Comprueba si la cuenta ya tiene perfil:
   - **No tiene perfil:** crea el perfil con el mismo UID.
   - **Ya tiene perfil:** cierra la sesión y muestra «correo ya registrado».
   - **La contraseña no coincide:** muestra «correo ya registrado» sin dar más detalles.

Este mecanismo **nunca crea una segunda cuenta** y solo el dueño de la contraseña puede completar el perfil. Las pruebas automatizadas cubren los tres casos.

Una alternativa más robusta, que queda como mejora, es crear el perfil con un *trigger* `AFTER INSERT ON auth.users` (`SECURITY DEFINER`) a partir de `raw_user_meta_data`. Así ambas operaciones serían atómicas dentro de la base de datos, pero cambia el flujo que pide el laboratorio.

### 9.4 Seguridad

- No se guarda la contraseña en `profiles`; la prueba `writes snake_case columns and no password` lo verifica.
- No se usa la `service_role` key, y la app la rechaza si se configura por error.
- Los registros de depuración contienen solo el tipo de error y su código.
- No se desactivó RLS ni se dieron permisos amplios.
- La app no usa el operador `!` sobre la respuesta de Auth.

## 10. Pruebas automatizadas

### 10.1 Comandos ejecutados y resultados reales

Todos los comandos se ejecutaron desde la raíz del proyecto el 17 de octubre de 2026, con Flutter 3.44.8 y Dart 3.12.2 en Windows 11. Las salidas están en `evidencias/`, sin rutas personales ni claves.

| Comando | Código de salida | Resultado observado | Evidencia |
| --- | --- | --- | --- |
| `flutter pub get` | 0 | `Got dependencies!` (no se cambió `pubspec.yaml`) | — |
| `dart format lib test` | 0 | 41 archivos, 3 reformateados en la primera pasada | — |
| `dart format --output=none --set-exit-if-changed lib test` | 0 | Sin cambios pendientes | `evidencias/dart_format.txt` |
| `flutter analyze` (primera ejecución) | 1 | 4 errores en `test/navigation_test.dart`: el test antiguo usaba la firma anterior de `App`. Se corrigió | — |
| `flutter test` (primera ejecución) | 1 | 51 aprobadas y 1 fallida: en el test los dos *fakes* usaban listas de registro distintas. Se corrigió el test | — |
| `flutter analyze` (final) | 0 | `No issues found!` | `evidencias/flutter_analyze.txt` |
| `flutter test -r expanded` (final) | 0 | `+52: All tests passed!` | `evidencias/flutter_test.txt` |
| `flutter build web --dart-define-from-file=config/supabase.json` | 0 | `√ Built build\web` (la app compila para web en modo release) | `evidencias/flutter_build_web.txt` |

### 10.2 Cobertura frente a lo pedido

| Requisito | Prueba(s) | Estado |
| --- | --- | --- |
| `SignUpUseCase` crea primero la cuenta y luego el perfil | `creates the account first and then the profile` | ✅ Aprobada |
| El perfil usa el ID de Auth | `uses the id returned by Auth for the profile` | ✅ Aprobada |
| Si Auth falla, no se crea el perfil | `does not create the profile when Auth fails` | ✅ Aprobada |
| El fallo del perfil se propaga | `propagates a profile failure and closes the session`, `wraps unexpected profile errors…` | ✅ Aprobada |
| Recuperación sin duplicados | `retrying after a failed profile insert…`, `a taken email…` (2) | ✅ Aprobada |
| `SignInUseCase` consulta el perfil con el ID correcto | `signs in and loads the profile with the Auth id` | ✅ Aprobada |
| `SignOutUseCase` delega | `delegates to the repository`, `propagates failures` | ✅ Aprobada |
| Capa de datos: `full_name` ↔ `fullName`, sin contraseña, errores | `data_layer_test.dart` (10 pruebas) | ✅ Aprobada |
| BLoC: estado inicial | `starts in initial…` (registro y login) | ✅ Aprobada |
| BLoC: `loading` → `success` | `emits loading and then success with the profile` | ✅ Aprobada |
| BLoC: `loading` → `failure` con mensaje | `emits loading and then failure with a message` | ✅ Aprobada |
| BLoC: sin trazas técnicas y sin envíos duplicados | `hides technical details…`, `ignores a second submit while loading` | ✅ Aprobada |
| Login exitoso y fallido | 4 pruebas de `LoginBloc` | ✅ Aprobada |
| Cierre de sesión | 2 pruebas de `HomeBloc` | ✅ Aprobada |
| UI: campos obligatorios, contraseñas distintas, correo inválido | `requires every field`, `rejects different passwords…`, `rejects an invalid email` | ✅ Aprobada |
| UI: indicador de carga | `shows a progress indicator…` (registro y login) | ✅ Aprobada |
| UI: errores visibles y reintento | `shows the error and lets the user try again`, `reports a profile that could not be saved`, `shows an error for wrong credentials` | ✅ Aprobada |
| UI: navegación en caso de éxito y bloqueo de `/home` sin sesión | `navigation_test.dart` (2), `/home without a session shows the login` | ✅ Aprobada |
| Configuración segura | `supabase_config_test.dart` (4 pruebas) | ✅ Aprobada |

No se añadieron dependencias: los *mocks* son *fakes* escritos a mano en `test/helpers/fakes.dart`.

## 11. Pruebas manuales y evidencias

| Prueba | Estado | Observación |
| --- | --- | --- |
| Ejecución interactiva de la app en un dispositivo | ⏳ Pendiente | `flutter devices` lista Windows (desktop), Chrome y Edge. El proyecto no tiene la carpeta `windows/` y el agente no podía manejar la interfaz del navegador. Solo se comprobó que compila (`flutter build web`) |
| Registro real, UID en Auth y fila en `profiles` | ⏳ Pendiente | No se crearon usuarios en el proyecto remoto porque no había autorización expresa. Pasos en la guía, 7.1–7.4 |
| Correo duplicado, login real, credenciales incorrectas | ⏳ Pendiente | Guía, 7.5–7.7 |
| Cierre de sesión real (`POST /logout` 204) | ⏳ Pendiente | Guía, 7.9 |
| Estado de RLS y políticas en remoto | ⏳ Pendiente | Necesita el SQL Editor del panel. Guía, 5.2 |
| Configuración de Auth en remoto (autoconfirmación) | ✅ Verificada (solo lectura) | `mailer_autoconfirm: true` |
| Existencia de la tabla y las columnas en remoto | ✅ Verificada (solo lectura) | `id`, `username`, `full_name` y `email` |

Las capturas que debe tomar el estudiante están en la lista final de `GUIA_PRUEBAS_LABORATORIO_5.md`. **No se generaron capturas de pantalla**: la carpeta `evidencias/` solo contiene las salidas de consola indicadas en la sección 10.

## 12. Instrucciones para reproducir

```powershell
Test-Path .\pubspec.yaml                                   # True
Copy-Item .\config\supabase.example.json .\config\supabase.json   # si no existe; edítalo con tus valores
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter devices
flutter run -d chrome --dart-define-from-file=config/supabase.json
```

Antes de las pruebas reales, aplica `supabase/migrations/20261017120000_profiles_rls.sql` en el SQL Editor y comprueba las políticas. El detalle está en `GUIA_PRUEBAS_LABORATORIO_5.md`.

## 13. Problemas encontrados y soluciones

| # | Problema | Solución |
| --- | --- | --- |
| 1 | `RegisterBloc` llamaba a Supabase directamente, insertaba `response.user?.id` (que podía ser nulo) y mostraba `e.toString()` | Se reescribió con un caso de uso, el data source valida los nulos y los errores se convierten en `AuthFailure` con mensajes comprensibles |
| 2 | La URL y la clave estaban escritas en `main.dart` | Se usa `--dart-define-from-file` con un archivo ignorado por git, una plantilla, validación y pantalla de error |
| 3 | La pantalla de registro reemplazaba el formulario por textos sueltos al cargar o fallar, y no se podía reintentar | El formulario siempre se ve. El estado decide el spinner del `PrimaryButton` y el `ErrorMessage` |
| 4 | La tabla real tiene `email NOT NULL`, que no está en el enunciado | El repositorio de perfiles recibe y guarda el correo que devuelve Auth |
| 5 | Las migraciones no tenían RLS, la primera tiene un error de sintaxis y las tres crean la misma tabla | Nueva migración idempotente con RLS. Las anteriores no se modificaron (pueden estar aplicadas) y la guía advierte no usar `db push` |
| 6 | El laboratorio supone que hay sesión justo después de `signUp` | Se verificó `mailer_autoconfirm: true`. Si la confirmación se activa, se detecta `session == null` y se informa, sin debilitar RLS |
| 7 | `navigation_test.dart` dependía de la navegación simulada | Se adaptó para inyectar *fakes* en `App`. Se mantuvieron sus dos escenarios originales |
| 8 | `HomeScreen` mostraba datos de ejemplo y no cerraba la sesión | Recibe datos reales, y `HomeBloc` con `SignOutUseCase` cierra la sesión antes de navegar |

## 14. Limitaciones pendientes

1. **Las pruebas reales contra Supabase y la ejecución interactiva de la interfaz están pendientes.** Ver la sección 11.
2. **La migración RLS no está aplicada en remoto** y no se verificó el estado actual de las políticas.
3. **Las dos operaciones del registro no son atómicas.** Se resuelve con reintento y recuperación, pero si el usuario nunca reintenta queda una cuenta sin perfil. Se puede detectar con la consulta de cuentas sin perfil de la guía (7.4). La mejora propuesta es un *trigger* en la base de datos.
4. `username` no tiene restricción `UNIQUE`; el enunciado no la pide. Si se añade, el error `23505` ya se traduce a un mensaje comprensible.
5. Si falla la revocación del token en el servidor pero la sesión local ya se borró, el cierre se da por bueno. El *refresh token* sigue siendo válido en el servidor hasta que caduque.
6. La app siempre empieza en `/login`, aunque `supabase_flutter` haya guardado una sesión anterior. No hay inicio de sesión automático, porque no forma parte del laboratorio.
7. El proyecto no incluye la plataforma Windows de escritorio. Para añadirla: `flutter create --platforms=windows .`.

## 15. Conclusiones técnicas

- Con Clean Architecture, el orden «primero la cuenta, después el perfil con el mismo UID» queda en un único caso de uso que se puede probar sin red. El BLoC hace una sola llamada y no conoce los pasos internos.
- Limitar el SDK de Supabase a los data sources permitió escribir 52 pruebas rápidas y deterministas con *fakes*, sin dependencias adicionales.
- La seguridad no depende de que la publishable key sea secreta, sino de RLS. La migración propuesta limita cada fila a su propietario (`auth.uid() = id`).
- Que Auth y la base de datos no formen una transacción debe tratarse de forma explícita: hay que informar al usuario y ofrecer un camino de recuperación que no cree cuentas duplicadas.
- El código, las pruebas y la compilación están verificados localmente. El funcionamiento real contra Supabase debe confirmarse con la guía de pruebas antes de darlo por aprobado.
