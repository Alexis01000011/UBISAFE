# Notas de sesión — F2: Identity & Access

**Fecha:** 27/04/2026  
**Rama:** `feat/identity/f2-auth-drawer`  
**Autor:** Alexis Córdova

---

## Qué se hizo en esta sesión

### Backend (FastAPI)

- **`schemas/user.py`** — extendido `UserProfile` y `SyncProfileRequest` con `name`, `phone`, `role`, `created_at`, `updated_at`
- **`routers/auth.py`** — agregado `GET /auth/me` (devuelve perfil o 404); renombrado `POST /device-token` → `PATCH /device-token`
- **`services/firestore_service.py`** — `upsert_user` ahora escribe `created_at` solo en primera escritura y siempre actualiza `updated_at`; agregado `get_user(uid)`
- **`tests/test_auth.py`** (nuevo) — 6 tests: AuthMiddleware 401/404, sync-profile crea y actualiza usuario

### Flutter

- **`models/user_profile.dart`** (nuevo) — modelo Dart del perfil con `fromJson`
- **`core/providers/auth_providers.dart`** (nuevo) — `userProfileProvider: FutureProvider<UserProfile?>` que llama `GET /auth/me` y se recalcula al cambiar sesión
- **`auth_module.dart`** — agregado `register(name, phone, role, email, password)` (crea cuenta Firebase + llama `POST /sync-profile`); agregado `getCurrentToken()`
- **`splash_screen.dart`** — implementado SessionCheck real: escucha `authStateProvider`, lee rol, navega al home correcto; usa `Timer` cancelable para evitar leak en tests
- **`login_screen.dart`** — redirige a `/home/buyer` o `/home/vendor` leyendo rol desde `userProfileProvider`
- **`signup_role_screen.dart`** — llama `AuthModule.register()` con nombre, teléfono y rol tras crear cuenta
- **`app_router.dart`** — redirect usa `userProfileProvider` en lugar de hardcodear `/home/buyer`
- **`drawer_module.dart`** — muestra nombre y rol desde `userProfileProvider`
- **`signup_screen.dart`** — eliminado (código muerto, reemplazado por flujo de 2 pasos)

### Tests y docs

- `tests/acceptance/auth.md` (nuevo) — 7 escenarios E2E de acceptance para Auth
- `widget_test.dart` — sin cambios en lógica; el timer cancelable de SplashScreen ya no causa pending timer en tests

**Resultados:** `flutter analyze` limpio · `flutter test` 12/12 · `pytest` 10/10

---

## Agentes ejecutados

### `firestore-rules-reviewer` ✅

Las reglas de `users/{uid}` coinciden exactamente con SDD §7.2.4. Sin cambios requeridos para F2.

Problemas encontrados **fuera del alcance de F2** (abrir issues separados):
- `stop_requests`: `allow write: if isAuthenticated()` — cualquier usuario autenticado puede modificar solicitudes ajenas. El SDD tiene esta misma regla, pero es un riesgo real de seguridad. Coordinar con el equipo si se actualiza el SDD §7.2.4 o se acepta como deuda declarada.
- `risk_zones`: `allow delete` permite borrado físico desde el cliente (el flujo de negocio usa borrado lógico vía Admin SDK).

### `sdd-traceability-checker` — SOLICITA CAMBIOS

Conforme en: AuthModule, DrawerModule, AuthMiddleware, SessionCheck, flujo de registro, flujo de login, estructura Flutter, go_router.

---

## Pendientes antes de mergear a `main`

### En alcance de F2 (arreglar en este PR)

| ID | Descripción | Archivo |
|---|---|---|
| D-03 | Campo `email` se está guardando en Firestore pero no pertenece al esquema SDD §7.2.1. Quitar de `SyncProfileRequest` o documentar decisión con ADR. | `schemas/user.py`, `auth_module.dart` |
| D-04 | Campos `last_location` y `last_location_at` ausentes en `UserProfile` Pydantic. Agregar como opcionales aunque no se usen en iter.1. | `schemas/user.py` |
| D-08 | Después del registro (`AuthModule.register()`), el SDD §8.4.A prescribe llamar a `PATCH /auth/device-token`. Actualmente no se llama. FCM token queda `null` para usuarios nuevos hasta que `NotificationHandler` lo actualice. | `auth_module.dart` |
| D-09 | En el flujo de login, el SDD §8.4.B prescribe llamar a `POST /auth/sync-profile` (actualiza `updated_at`) y luego `PATCH /auth/device-token`. La implementación actual solo lee el perfil via `GET /auth/me`. | `login_screen.dart` |
| D-02/D-10 | `GET /auth/me` no está en la tabla de endpoints del SDD §5.3.1.4. Fue una decisión intencional (más limpio que leer Firestore directo desde el cliente). Documentar como ADR antes de mergear. | ADR a escribir |

### Deuda de F1 (abrir issues separados, NO bloquean este PR)

| ID | Descripción | Fase donde se corrige |
|---|---|---|
| D-01 | Estructura FastAPI plana (`routers/`, `schemas/`, `services/`) vs. domain-first del SDD §11.2 (`modules/identity/`, etc.). Requiere refactor mayor. | Antes de F3 o como `refactor/infra/fastapi-modules` |
| D-05 | RiskZone schema con nombres incorrectos: `reported_by` → `reporter_uid`, `description` → `threat_type`, `level` → `risk_level`. También faltan `radius_meters`, `active`, `expires_at`, `expired_at`. | F5 (Safety) |
| D-06 | `update_stop_status` no actualiza `updated_at`, `accepted_at` ni `completed_at` en Firestore. | F4 (Dispatching) |
| D-07 | `create_stop_request` no calcula ni escribe `expires_at`, `created_at`, `updated_at`. | F4 (Dispatching) |
| Firestore rules | `stop_requests`: `allow write: if isAuthenticated()` demasiado permisivo. Separar en `create`/`update`/`delete: if false`. Coordinar si se actualiza el SDD o se registra como deuda declarada. | F4 o chore independiente |

---

## Verificación 3 pendiente — Acceptance Manual

Ejecutar los 7 escenarios de `tests/acceptance/auth.md` con:

```bash
# Terminal 1 — Firebase Emulators
firebase emulators:start --project demo-ubisafe

# Terminal 2 — FastAPI
cd ubisafe_api
uvicorn main:app --reload

# Terminal 3 — Flutter
cd ubisafe_app
flutter run
```

Escenarios a validar: A1 (sin sesión → Welcome) · A2 (registro BUYER → /home/buyer) · A3 (registro VENDOR → /home/vendor) · A4 (sesión persistente) · A5 (Drawer muestra nombre/rol + Cerrar sesión) · A6 (login incorrecto → error inline) · A7 (login correcto → home según rol).
