# Guía de pruebas — Laboratorio 5 (registro e inicio de sesión con Supabase)

Esta guía explica cómo comprobar el laboratorio en un equipo Windows con VS Code, desde la preparación hasta el registro de resultados. Hay tres tipos de prueba y conviene no mezclarlos:

| Tipo | Qué comprueba | ¿Necesita Supabase? | Sección |
| --- | --- | --- | --- |
| **A. Automatizadas** | Casos de uso, repositorios, BLoC, pantallas y navegación con *fakes* | No | 4 |
| **B. Manuales de interfaz** | Validaciones, carga y mensajes que se ven en la app | Solo algunas | 6 |
| **C. Reales contra Supabase** | Que Auth y `profiles` reciben los datos con el mismo UID, el login y el cierre de sesión | Sí | 7 |

Los comandos están escritos para **Windows PowerShell** y se ejecutan desde la raíz del proyecto.

---

## 1. Requisitos previos

- Flutter estable con Dart 3.12 o superior. El proyecto se verificó con Flutter 3.44.8 y Dart 3.12.2.
- VS Code con las extensiones **Dart** y **Flutter**.
- Google Chrome o Microsoft Edge. Este repositorio no tiene la carpeta `windows/`, así que la forma más directa de ejecutarlo en Windows es en el navegador. Un emulador Android también sirve si ya lo tienes configurado, pero **no hace falta Android Studio**.
- Acceso al panel de tu proyecto Supabase (Authentication, Table Editor, SQL Editor y Logs).
- La **URL** del proyecto y su **publishable key** (`sb_publishable_...`), que se ven en *Project Settings → API Keys*. **Nunca** uses la `secret` ni la `service_role` key: la app se niega a arrancar si detecta una.

Comprueba la instalación:

```powershell
flutter --version
flutter doctor
```

## 2. Comprobar la raíz del proyecto Flutter

La raíz de Flutter es la carpeta que contiene `pubspec.yaml`. En este repositorio coincide con la raíz del repositorio.

```powershell
Test-Path .\pubspec.yaml          # debe mostrar True
Select-String -Path .\pubspec.yaml -Pattern '^name:'   # name: moviles_auth
```

Si `Test-Path` devuelve `False`, cambia con `cd` a la carpeta correcta antes de seguir.

## 3. Configurar la URL y la publishable key

La app lee la configuración en **tiempo de compilación** mediante `--dart-define-from-file`. La URL y la clave ya no están escritas en el código.

1. Crea tu archivo local a partir de la plantilla. Si `config\supabase.json` ya existe, revisa que tenga los valores de tu proyecto.

   ```powershell
   if (-not (Test-Path .\config\supabase.json)) { Copy-Item .\config\supabase.example.json .\config\supabase.json }
   notepad .\config\supabase.json
   ```

2. Escribe los valores reales:

   ```json
   {
     "SUPABASE_URL": "https://<ref-de-tu-proyecto>.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
   }
   ```

3. Comprueba que git ignora el archivo. Debe aparecer la regla de `.gitignore`:

   ```powershell
   git check-ignore -v config/supabase.json
   ```

En VS Code, la configuración **«moviles_auth (Supabase)»** de `.vscode/launch.json` ya pasa `--dart-define-from-file=config/supabase.json`.

> La publishable key está pensada para ir dentro de la app. Lo que protege los datos son las políticas RLS de la sección 5, no el hecho de que la clave sea secreta.

## 4. Pruebas automatizadas (tipo A)

No necesitan internet ni una cuenta de Supabase, porque usan *fakes* de los repositorios.

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Para ver el nombre de cada prueba:

```powershell
flutter test -r expanded
```

**Resultado esperado:** `dart format` termina con código 0 sin listar archivos, `flutter analyze` muestra `No issues found!` y `flutter test` termina con `All tests passed!`. En la ejecución de referencia pasaron 52 pruebas.

Para ver el código de salida en PowerShell, ejecuta `$LASTEXITCODE` justo después de cada comando. Debe ser `0`.

| Archivo de pruebas | Qué cubre |
| --- | --- |
| `test/features/auth/domain/sign_up_usecase_test.dart` | Primero se crea la cuenta y luego el perfil; el perfil usa el ID de Auth; si Auth falla no se crea el perfil; el fallo del perfil se propaga; reintento y recuperación |
| `test/features/auth/domain/sign_in_and_out_usecase_test.dart` | El login consulta el perfil con el ID de Auth; credenciales incorrectas; perfil inexistente; `SignOutUseCase` delega |
| `test/features/auth/data/data_layer_test.dart` | Traducción `full_name` ↔ `fullName`, la contraseña nunca va a la fila, repositorios y traducción de errores del SDK |
| `test/core/supabase_config_test.dart` | Configuración que falta, URL inválida y rechazo de las claves `secret` y `service_role` |
| `test/features/blocs_test.dart` | Estados de `RegisterBloc`, `LoginBloc` y `HomeBloc`; envío duplicado ignorado; errores sin detalles técnicos |
| `test/features/screens_test.dart` | Campos vacíos, contraseñas distintas, correo inválido, indicador de carga, errores visibles, `HomeScreen` y `/home` sin sesión |
| `test/navigation_test.dart` | Flujos completos login → perfil → cerrar sesión y registro → perfil |

## 5. Comprobar la base de datos (antes de las pruebas reales)

### 5.1 Tabla y columnas

En *Table Editor → profiles* deben aparecer las columnas `id`, `username`, `full_name` y `email`. También puedes comprobarlo en *SQL Editor*:

```sql
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'profiles'
order by ordinal_position;

-- id debe ser la clave primaria y referenciar auth.users(id)
select conname, pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'public.profiles'::regclass;
```

**Esperado:** `id uuid` (PK, `REFERENCES auth.users(id) ON DELETE CASCADE`), `username text`, `full_name text` y `email text`. La columna `email` no está en el enunciado, pero sí en las migraciones de este repositorio. La app la rellena con el correo que devuelve Auth.

### 5.2 RLS, políticas y permisos

```sql
select relrowsecurity as rls_activo
from pg_class where oid = 'public.profiles'::regclass;

select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = 'profiles';

select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'profiles'
order by grantee, privilege_type;
```

**Esperado:**

- `rls_activo = true`.
- Las políticas `profiles_select_own`, `profiles_insert_own` y `profiles_update_own`, para `{authenticated}`, con la condición `auth.uid() = id`.
- `authenticated` solo tiene `SELECT`, `INSERT` y `UPDATE`.
- `anon` no tiene ningún permiso.

### 5.3 Aplicar la migración si falta algo

Si RLS está desactivado o faltan políticas, aplica `supabase/migrations/20261017120000_profiles_rls.sql`. Es idempotente y no borra datos: crea la tabla solo si no existe, activa RLS y crea las políticas.

1. Abre *SQL Editor → New query*.
2. Pega el contenido completo del archivo y pulsa **Run**.
3. Repite las consultas de 5.2.

> **No** uses `supabase db push` con este repositorio sin revisarlo antes. Las tres migraciones anteriores intentan crear la misma tabla y la primera tiene un error de sintaxis (una coma al final), así que un `push` o un `db reset` fallaría.

### 5.4 Confirmación de correo

El laboratorio inserta el perfil justo después de `signUp`, y eso solo funciona si Supabase devuelve una sesión en ese momento. Revisa *Authentication → Sign In / Providers → Email → Confirm email*:

- **Desactivado** (lo esperado para el laboratorio): el registro crea la cuenta y el perfil en un solo paso.
- **Activado**: la app muestra *«Debes confirmar tu correo antes de continuar…»* y no crea el perfil. Después de confirmar el correo, vuelve a pulsar **Registrarme** con los mismos datos y el perfil se completa (sección 7.8). No hace falta desactivar RLS en ningún caso.

## 6. Iniciar la aplicación

```powershell
flutter devices
```

Elige uno de los dispositivos que aparezcan (`chrome`, `edge`, un emulador o un teléfono Android).

- **Chrome:**

  ```powershell
  flutter run -d chrome --dart-define-from-file=config/supabase.json
  ```

- **Edge:** el mismo comando con `-d edge`.
- **Android:** si `flutter emulators` lista un emulador, arráncalo con `flutter emulators --launch <id>` y después ejecuta `flutter run -d <id> --dart-define-from-file=config/supabase.json`.
- **VS Code:** abre *Run and Debug* (`Ctrl+Shift+D`), elige **«moviles_auth (Supabase)»**, selecciona el dispositivo en la barra de estado y pulsa `F5`.

**Esperado:** se abre «Iniciar sesión» con el título «Bienvenido de nuevo».

### 6.1 Pruebas manuales de interfaz (tipo B)

| ID | Pasos | Resultado esperado |
| --- | --- | --- |
| B1 | En «Iniciar sesión», pulsa el botón con los campos vacíos | «Escribe tu correo y tu contraseña» |
| B2 | Ve a «¿No tienes cuenta? Regístrate», deja «Nombre completo» vacío y pulsa **Registrarme** | «Completa todos los campos». No se envía nada a Supabase |
| B3 | Rellena todo con `Contraseña = 123456` y `Confirmar = 654321` | «Las contraseñas no coinciden» |
| B4 | Escribe un correo sin `@` | «Escribe un correo válido» |
| B5 | Escribe una contraseña de menos de 6 caracteres (en los dos campos) | «La contraseña debe tener al menos 6 caracteres» |
| B6 | Envía un formulario válido y observa el botón | Aparece un indicador circular, los campos se desactivan y no se puede pulsar dos veces |
| B7 | **Error de configuración:** cierra la app y ejecuta `flutter run -d chrome` **sin** `--dart-define-from-file` | Pantalla «Configuración incompleta» con «Falta configurar SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY». No se modifica ningún servicio |
| B8 | **Sin conexión:** con la app en Chrome, abre DevTools (`F12`) → *Network* → *No throttling* → **Offline** e intenta iniciar sesión. En Android, activa el modo avión | «No hay conexión con el servidor…». La app no se cierra y puedes reintentar al volver a **Online** |

## 7. Pruebas reales contra Supabase (tipo C)

Usa siempre **cuentas de prueba nuevas**. Te sirve un correo tuyo con alias, como `tucorreo+lab5a@gmail.com`. No uses datos de otras personas. Supabase limita el número de registros por hora. Si aparece «Demasiados intentos…», espera unos minutos.

Anota en la tabla de la sección 8 el correo de prueba (puedes enmascararlo) y el UID.

### 7.1 Registrar un usuario nuevo

1. En la app, pulsa **¿No tienes cuenta? Regístrate**.
2. Rellena: usuario `lab5_ana`, nombre completo `Ana Prueba`, correo `tucorreo+lab5a@gmail.com`, contraseña y confirmación `Lab5Prueba!`.
3. Pulsa **Registrarme**.

**Esperado:** aparece el indicador de carga y después la pantalla **Perfil** con «Ana Prueba», «@lab5_ana» y el correo usado.

### 7.2 Verificar el UID en Authentication → Users

En el panel, ve a *Authentication → Users*, busca el correo y copia el **User UID**.

### 7.3 Verificar la fila en Table Editor → profiles

En *Table Editor → profiles*, busca la fila con ese `id` y comprueba que `username = lab5_ana` y `full_name = Ana Prueba`. **No hay ninguna columna de contraseña.**

### 7.4 Comprobar que el UID coincide

```sql
select u.id as auth_uid, p.id as profile_id, u.email, p.username, p.full_name,
       (u.id = p.id) as mismo_uid
from auth.users u
join public.profiles p on p.id = u.id
where u.email = 'tucorreo+lab5a@gmail.com';
```

**Esperado:** una fila con `mismo_uid = true`.

Esta consulta busca cuentas que no tienen perfil. Debe devolver 0 filas para tus cuentas de prueba:

```sql
select u.id, u.email
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;
```

### 7.5 Correo duplicado

Cierra sesión, vuelve a «Crear cuenta» e intenta registrar el **mismo correo** con otros datos y otra contraseña.

**Esperado:** «Ya existe una cuenta con este correo. Inicia sesión o usa otro correo.» No se crea otra cuenta en *Authentication → Users* ni otra fila en `profiles`.

### 7.6 Iniciar sesión

En «Iniciar sesión», escribe el correo y la contraseña de 7.1 y pulsa **Iniciar sesión**.

**Esperado:** pantalla **Perfil** con el nombre completo, el usuario y el **correo real de Auth** en el campo «Correo».

### 7.7 Credenciales incorrectas

Escribe el mismo correo con una contraseña equivocada.

**Esperado:** «Correo o contraseña incorrectos.» La app se queda en la pantalla de login.

### 7.8 (Opcional) Recuperación cuando Auth crea la cuenta y el perfil falla

Esta prueba comprueba que el registro se puede completar sin crear una cuenta duplicada. Eliminar la política de inserción hace la tabla **más restrictiva** temporalmente; no la debilita.

1. En *SQL Editor*, ejecuta `drop policy if exists "profiles_insert_own" on public.profiles;`
2. Registra un correo nuevo, por ejemplo `tucorreo+lab5b@gmail.com`. **Esperado:** «Tu cuenta se creó, pero no pudimos guardar tu perfil por un problema de permisos…». La cuenta aparece en *Authentication → Users* y la consulta de cuentas sin perfil de 7.4 la muestra.
3. Vuelve a ejecutar la migración `20261017120000_profiles_rls.sql` (sección 5.3) para restaurar la política.
4. Pulsa **Registrarme** otra vez con **el mismo correo y la misma contraseña**. **Esperado:** se abre el perfil, sigue existiendo una sola cuenta con ese correo y la consulta de 7.4 ya no la lista.

### 7.9 Cerrar sesión y verificar que la sesión terminó

1. En **Perfil**, pulsa **Cerrar sesión**. **Esperado:** vuelves a «Iniciar sesión».
2. Verifica el cierre de una de estas formas:
   - **En Chrome:** antes de pulsar el botón, abre DevTools → *Network* y filtra por `logout`. Al cerrar sesión aparece `POST …/auth/v1/logout` con estado **204**. En *Application → Local Storage* desaparece la clave `sb-<ref>-auth-token`.
   - **En el panel:** en *Logs → Auth*, busca la petición `/logout` con estado 204 a la hora de la prueba.
3. Pulsa el botón «Atrás» del navegador o del sistema. **Esperado:** no vuelves al perfil, porque la pila de navegación se vació.

### 7.10 Limpieza (opcional)

Para borrar los usuarios de prueba, ve a *Authentication → Users → ⋮ → Delete user*. La fila de `profiles` se elimina sola gracias a `ON DELETE CASCADE`. Hazlo solo con tus cuentas de prueba.

## 8. Tabla de resultados

Completa una fila por prueba. En Estado usa ✅ Aprobada, ❌ Fallida o ⏳ Pendiente.

| ID | Tipo | Prueba | Resultado esperado | Resultado real | Estado | Observaciones / evidencia |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | Auto | `flutter pub get` | Código 0 | | | |
| A2 | Auto | `dart format --set-exit-if-changed` | Código 0 | | | |
| A3 | Auto | `flutter analyze` | `No issues found!` | | | |
| A4 | Auto | `flutter test` | `All tests passed!` (52) | | | |
| B1 | UI | Login con campos vacíos | Mensaje de validación | | | |
| B2 | UI | Registro con campos vacíos | «Completa todos los campos» | | | |
| B3 | UI | Contraseñas distintas | «Las contraseñas no coinciden» | | | |
| B4 | UI | Correo inválido | «Escribe un correo válido» | | | |
| B5 | UI | Contraseña corta | Mensaje de longitud mínima | | | |
| B6 | UI | Indicador de carga | Spinner y formulario bloqueado | | | |
| B7 | UI | Sin configuración | Pantalla «Configuración incompleta» | | | |
| B8 | UI | Sin conexión | Mensaje de conexión, sin cierre | | | |
| C1 | Real | Registro nuevo | Navega a Perfil con los datos | | | UID: |
| C2 | Real | UID en Authentication → Users | El usuario existe | | | |
| C3 | Real | Fila en profiles | `username` y `full_name` correctos, sin contraseña | | | |
| C4 | Real | UID coincide (SQL 7.4) | `mismo_uid = true` | | | |
| C5 | Real | Correo duplicado | Mensaje de correo existente, sin duplicados | | | |
| C6 | Real | Login correcto | Perfil y correo real de Auth | | | |
| C7 | Real | Credenciales incorrectas | «Correo o contraseña incorrectos.» | | | |
| C8 | Real | Recuperación del perfil (opcional) | Se completa sin cuenta duplicada | | | |
| C9 | Real | Cerrar sesión | `POST /logout` 204 y vuelta a login | | | |
| D1 | BD | RLS y políticas (5.2) | RLS activo y 3 políticas propias | | | |

### Capturas recomendadas para `evidencias/`

No incluyas claves, tokens ni correos personales sin enmascarar.

1. Salida de `flutter test` y de `flutter analyze`.
2. Pantalla Perfil después del registro (C1) y después del login (C6).
3. *Authentication → Users* con el UID (C2) y *Table Editor → profiles* con la misma fila (C3).
4. Resultado de la consulta SQL de 7.4 con `mismo_uid = true`.
5. Mensajes de error de B3, C5 y C7.
6. DevTools con `POST /auth/v1/logout` 204 (C9).
7. Resultado de las consultas de políticas de 5.2.
