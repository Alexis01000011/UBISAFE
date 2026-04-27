# Notas de sesión — F2: Identity & Access

**Fecha:** 27/04/2026  
**Rama:** `feat/identity/f2-auth-drawer`  
**Autores:** Alexis Córdova · Miguel Esaú Rivera Román

---

## Qué se hizo en esta sesión

### Backend (FastAPI)

- **`schemas/user.py`** — `UserProfile` y `SyncProfileRequest` con `name`, `phone`, `role`, `fcm_token`, `last_location`, `last_location_at`, `created_at`, `updated_at`; campo `email` excluido (no está en SDD §7.2.1)
- **`routers/auth.py`** — `GET /auth/me` (devuelve perfil o 404), `POST /auth/sync-profile`, `PATCH /auth/device-token`
- **`services/firestore_service.py`** — `upsert_user` escribe `created_at` solo en primera escritura, siempre actualiza `updated_at`; `get_user(uid)`, `update_device_token(uid, token)`
- **`tests/test_auth.py`** (nuevo) — 10 tests: AuthMiddleware 401/404/200, sync-profile crea y actualiza, health checks, smoke

### Flutter

- **`models/user_profile.dart`** (nuevo) — modelo Dart del perfil con `fromJson`
- **`core/providers/auth_providers.dart`** (nuevo) — `userProfileProvider: FutureProvider<UserProfile?>` que llama `GET /auth/me` y se recalcula al cambiar sesión
- **`auth_module.dart`** — `login()` (signIn + sync-profile + device-token per SDD §8.4.B), `register()` (Firebase + sync-profile + device-token per SDD §8.4.A), `_syncDeviceToken()` (best-effort), `getCurrentToken()`, `signOut()`
- **`splash_screen.dart`** — SessionCheck real con `Timer` cancelable para evitar leak en tests
- **`login_screen.dart`** — usa `AuthModule.login()`, redirige a home según rol
- **`signup_data_screen.dart`** — paso 1: nombre, teléfono, correo, contraseña (correo y contraseña movidos aquí desde signup_role)
- **`signup_role_screen.dart`** — paso 2: solo selector BUYER/VENDOR; llama `AuthModule.register()` con datos recibidos vía route extra
- **`app_router.dart`** — redirect role-based; navegación interna del flujo auth usa `context.push()` para habilitar el botón de regreso
- **`drawer_module.dart`** — muestra nombre y rol desde `userProfileProvider`; Cerrar Sesión navega a Welcome
- **`signup_screen.dart`** — eliminado (código muerto)

### Tests y docs

- `tests/acceptance/auth.md` (nuevo) — 7 escenarios E2E de acceptance

**Resultados finales:** `flutter analyze` limpio · `flutter test` 12/12 · `python -m pytest` 10/10 · `ruff check` limpio

---

## Agentes ejecutados

### `firestore-rules-reviewer` ✅

Las reglas de `users/{uid}` coinciden exactamente con SDD §7.2.4. Sin cambios requeridos para F2.

Problemas encontrados **fuera del alcance de F2** (abrir issues separados):
- `stop_requests`: `allow write: if isAuthenticated()` — cualquier usuario autenticado puede modificar solicitudes ajenas. El SDD tiene esta misma regla, pero es un riesgo real de seguridad. Coordinar con el equipo si se actualiza el SDD §7.2.4 o se acepta como deuda declarada.
- `risk_zones`: `allow delete` permite borrado físico desde el cliente (el flujo de negocio usa borrado lógico vía Admin SDK).

### `sdd-traceability-checker` ✅

Conforme en: AuthModule, DrawerModule, AuthMiddleware, SessionCheck, flujo de registro, flujo de login, estructura Flutter, go_router.

---

## Correcciones aplicadas (sesión 27/04/2026)

### Por Miguel — D-03 / D-04 / D-08 / D-09 / D-10

| ID | Descripción | Estado |
|---|---|---|
| D-03 | Campo `email` eliminado de `SyncProfileRequest` y `UserProfile` Pydantic y de `auth_module.dart`. | ✅ |
| D-04 | `last_location: dict\|None` y `last_location_at: datetime\|None` agregados a `UserProfile` como opcionales. | ✅ |
| D-08 | `AuthModule._syncDeviceToken()` llamado al final de `register()`. Best-effort, silencia errores. | ✅ |
| D-09 | `AuthModule.login()` llama `POST /auth/sync-profile` + `PATCH /auth/device-token`. `LoginScreen` actualizado. | ✅ |
| D-10 | `GET /auth/me` documentado con comentario de decisión en `routers/auth.py`. ADR formal pendiente iter.2. | ✅ |

### Por Alexis — correcciones de UI post-acceptance

| ID | Descripción | Estado |
|---|---|---|
| D-11 | Navegación interna del flujo auth cambiada de `context.go()` a `context.push()` — WelcomeScreen y SignupDataScreen. Las pantallas Login, SignupData y SignupRole ahora muestran flecha de regreso automática. | ✅ |
| D-12 | Email y contraseña movidos de SignupRoleScreen (W-05) a SignupDataScreen (W-04). W-05 ahora muestra solo el selector BUYER/VENDOR, alineado con el wireframe. | ✅ |

---

## Acceptance Manual — ✅ TODOS LOS ESCENARIOS PASADOS (27/04/2026)

Ejecutado con Firebase Emulators + FastAPI local + `flutter run` en dispositivo Android.

| ID | Escenario | Resultado |
|---|---|---|
| A1 | Sin sesión → Welcome | ✅ |
| A2 | Registro BUYER → /home/buyer | ✅ |
| A3 | Registro VENDOR → /home/vendor | ✅ |
| A4 | Sesión persistente (cerrar/reabrir app) | ✅ |
| A5 | Drawer muestra nombre/rol + Cerrar Sesión | ✅ |
| A6 | Login incorrecto → error inline | ✅ |
| A7 | Login correcto → home según rol | ✅ |

---

## Definition of Done — F2 ✅ COMPLETO

| Ítem | Estado |
|---|---|
| Tests unitarios: 12 Flutter + 10 pytest — todos verdes | ✅ |
| `flutter analyze` 0 issues · `ruff check` limpio | ✅ |
| `users/{uid}` con campos exactos del SDD §7.2.1 | ✅ |
| Reglas Firestore `users` verificadas con `firestore-rules-reviewer` | ✅ |
| `AuthModule.login()` llama sync-profile + device-token (SDD §8.4.A/B) | ✅ |
| Acceptance manual A1–A7 pasados en dispositivo real | ✅ |
| PR abierto contra `main` | ✅ |

---

## Deuda declarada (no bloquea el PR)

| ID | Descripción | Fase donde se corrige |
|---|---|---|
| D-01 | FastAPI estructura plana (`routers/`, `schemas/`, `services/`) vs. domain-first del SDD §11.2 (`modules/identity/`). | `refactor/infra/fastapi-modules` antes de F3 |
| D-05 | RiskZone schema con campos incorrectos y faltantes. | F5 (Safety) |
| D-06 | `update_stop_status` no actualiza `updated_at`, `accepted_at`, `completed_at`. | F4 (Dispatching) |
| D-07 | `create_stop_request` no calcula ni escribe `expires_at`, `created_at`, `updated_at`. | F4 (Dispatching) |
| Firestore rules | `stop_requests`: `allow write: if isAuthenticated()` demasiado permisivo. | F4 o chore independiente |
| D-10 | ADR formal para `GET /auth/me` (fuera del SDD §5.3.1.4). | Iter.2 |
