# UBISAFE

> **Urban safety mobile app** built with Flutter · Firebase · Riverpod · FastAPI

---

## Table of Contents

1. [Overview](#overview)
2. [Tech Stack](#tech-stack)
3. [Architecture — Modular Monolith](#architecture--modular-monolith)
4. [Project Structure](#project-structure)
   - [ubisafe\_app/](#ubisafe_app)
   - [ubisafe\_api/](#ubisafe_api)
5. [Module Breakdown](#module-breakdown)
   - [core/](#core)
   - [features/identity/](#featuresidentity)
   - [features/presence/](#featurespresence)
   - [features/dispatching/](#featuresdispatching)
   - [features/safety/](#featuressafety)
   - [features/community/](#featurescommunity)
   - [features/shared/](#featuresshared)
   - [router/](#router)
6. [API Module Breakdown](#api-module-breakdown)
7. [Iteration Roadmap](#iteration-roadmap)
8. [Getting Started](#getting-started)

---

## Overview

UBISAFE connects street vendors and buyers in real time on a shared map, while layering community-driven safety features (risk zones, community reports, ride requests) on top.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile UI | Flutter 3.x |
| State management | Riverpod 2 (code-gen ready) |
| Navigation | GoRouter 13 |
| Auth & Database | Firebase Auth + Cloud Firestore |
| Realtime presence | Firebase Realtime Database (RTDB) |
| Push notifications | Firebase Cloud Messaging (FCM) |
| Scheduled jobs | Firebase Cloud Functions |
| Backend API | FastAPI (Python) — accessed via Dio |
| Maps | Google Maps Flutter |
| Location | Geolocator |

---

## Architecture — Modular Monolith

The app follows a **modular monolith** pattern:

- All code lives in one Flutter project (`ubisafe_app/`).
- Each **feature module** (`identity`, `presence`, `dispatching`, `safety`, `community`) is a self-contained vertical slice with its own screens, services, widgets and models.
- Modules communicate **only** through Riverpod providers — never through direct imports between feature directories (except `shared/`).
- The `core/` layer holds infrastructure that every module may import: design system tokens, API client, etc.
- `shared/` holds truly cross-cutting concerns: notification handling, reusable widgets.

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter App                                                    │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  router/  (GoRouter — navigation shell)                    │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌──────────┐ ┌──────────┐ ┌─────────────┐ ┌────────┐ ┌──────┐ │
│  │ identity │ │ presence │ │ dispatching │ │ safety │ │ comm.│ │
│  └──────────┘ └──────────┘ └─────────────┘ └────────┘ └──────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  shared/  (notifications, common widgets)                  │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  core/  (api_client, design_system)                        │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
         │ Dio (HTTP)                │ Firestore / RTDB / FCM
         ▼                           ▼
   FastAPI backend              Firebase services
```

---

## Project Structure

### `ubisafe_app/`

```
ubisafe_app/
├── lib/
│   ├── main.dart                          # App entry point (Firebase init, ProviderScope)
│   │
│   ├── core/
│   │   ├── api/
│   │   │   └── api_client.dart            # Dio instance + auth interceptor (FastAPI)
│   │   └── design_system/
│   │       ├── colors.dart                # Brand palette
│   │       ├── typography.dart            # Text-style catalogue
│   │       ├── spacing.dart               # 4-pt spacing scale
│   │       └── theme.dart                 # Material 3 ThemeData (light + dark)
│   │
│   ├── features/
│   │   │
│   │   ├── identity/                      # 🔐 Identity & Access
│   │   │   ├── auth/
│   │   │   │   ├── auth_module.dart       # Firebase Auth helpers + providers
│   │   │   │   └── screens/
│   │   │   │       ├── splash_screen.dart
│   │   │   │       ├── welcome_screen.dart
│   │   │   │       ├── login_screen.dart
│   │   │   │       ├── signup_data_screen.dart  # Paso 1: nombre, email, contraseña
│   │   │   │       └── signup_role_screen.dart  # Paso 2: rol (BUYER/VENDOR) + producto
│   │   │   └── profile/
│   │   │       ├── screens/
│   │   │       │   ├── profile_screen.dart
│   │   │       │   └── history_screen.dart
│   │   │       └── widgets/
│   │   │           └── drawer_module.dart # App-wide nav drawer
│   │   │                                  # [iter.2] +toggle ride_enabled +active reports
│   │   │
│   │   ├── presence/                      # 📡 Presence
│   │   │   ├── services/
│   │   │   │   ├── gps_service.dart       # Geolocator stream provider; escribe en RTDB vendedores_activos
│   │   │   │   └── vendor_tracker.dart    # RTDB vendedores_activos → filtro 4 km → VendorMarker stream
│   │   │   └── models/
│   │   │       └── vendor_marker.dart     # [iter.2] +rideEnabled +product +lastTimestamp
│   │   │
│   │   ├── dispatching/                   # 🗺️ Dispatching
│   │   │   ├── screens/
│   │   │   │   ├── map_screen_buyer.dart  # [iter.2 ext] +SpeedDial FAB +ride +community
│   │   │   │   ├── map_screen_vendor.dart # [iter.2 ext] +incoming ride dialog +community
│   │   │   │   └── tracking_screen.dart   # Reused for ride (CU-04) & stop tracking
│   │   │   ├── services/
│   │   │   │   ├── stop_request_module.dart
│   │   │   │   └── ride_request_module.dart  # ☆ [iter.2] CU-04 full lifecycle
│   │   │   ├── widgets/
│   │   │   │   ├── visibility_toggle.dart
│   │   │   │   └── destination_picker.dart   # ☆ [iter.2] Map-tap destination widget
│   │   │   └── models/
│   │   │       ├── stop_request.dart
│   │   │       └── ride.dart                 # ☆ [iter.2] Ride model (CU-04)
│   │   │
│   │   ├── safety/                        # ⚠️ Safety
│   │   │   ├── screens/
│   │   │   │   └── risk_form_bottom_sheet.dart
│   │   │   ├── services/
│   │   │   │   └── risk_zone_service.dart  # StreamProvider<List<RiskZone>> directo a Firestore
│   │   │   └── models/
│   │   │       └── risk_zone.dart
│   │   │
│   │   ├── community/                     # 🌐 Community  ☆ ACTIVATED IN ITER. 2
│   │   │   ├── screens/
│   │   │   │   ├── active_reports_screen.dart             # ☆ [iter.2] Lista de reportes activos + votación
│   │   │   │   ├── report_detail_screen.dart              # ☆ [iter.2] Detalle + confirmar/desestimar
│   │   │   │   ├── community_form_bottom_sheet.dart       # ☆ [iter.2] Formulario de nuevo reporte
│   │   │   │   └── community_reports_history_screen.dart  # ☆ [iter.2] Historial de reportes propios
│   │   │   ├── services/
│   │   │   │   ├── community_report_module.dart           # ☆ [iter.2] CU-05
│   │   │   │   └── report_validation_module.dart          # ☆ [iter.2] CU-06
│   │   │   ├── widgets/
│   │   │   │   └── report_marker_panel.dart               # ☆ [iter.2]
│   │   │   └── models/
│   │   │       └── community_report.dart                  # ☆ [iter.2]
│   │   │
│   │   └── shared/                        # 🔔 Shared (transversal)
│   │       ├── notifications/
│   │       │   └── notification_handler.dart  # FCM setup + event routing
│   │       │                                  # [iter.2 ext] +4 FCM events
│   │       └── widgets/
│   │           └── gps_required_empty_state.dart
│   │
│   └── router/
│       └── app_router.dart                # GoRouter + auth-guard redirect
│                                          # [iter.2] +community routes
│
├── pubspec.yaml
└── android/
    ├── build.gradle
    └── app/
        ├── build.gradle
        └── src/main/
            └── AndroidManifest.xml
```

### `ubisafe_api/`

```
ubisafe_api/
├── main.py                              # Entry point: FastAPI app, routers, lifespan
├── dependencies.py                      # get_current_user (Bearer JWT via firebase-admin)
│
├── modules/                             # Domain modules — one folder per bounded context
│   ├── identity/
│   │   ├── router.py                    # GET /auth/me · POST /auth/sync-profile · PATCH /auth/device-token
│   │   └── schemas.py                   # UserProfile · SyncProfileRequest · DeviceTokenRequest
│   ├── dispatching/
│   │   ├── router.py                    # POST /stops · GET /stops/{id} · PATCH /stops/{id}/status
│   │   └── schemas.py                   # StopRequest · CreateStopRequestBody · UpdateStatusBody · StopRequestStatus
│   ├── safety/
│   │   ├── router.py                    # GET /risk-zones · POST /risk-zones
│   │   └── schemas.py                   # RiskZone · CreateRiskZoneBody
│   └── shared/                          # Transversal services (no public endpoints)
│       ├── firebase_admin_init.py       # FirebaseAdminInit — SDK init + emulator credential
│       ├── firestore_service.py         # FirestoreService — CRUD on Firestore collections
│       └── notification_service.py     # NotificationService — FCM dispatch
│
├── tests/                               # pytest test suite
├── requirements.txt
├── .env.example                         # Template — copy to .env, never commit .env
└── Dockerfile
```

---

## Module Breakdown

### `core/`

| File | Purpose |
|---|---|
| `api/api_client.dart` | Singleton `Dio` instance configured for the FastAPI backend. Attach Firebase ID token as Bearer header here. |
| `design_system/colors.dart` | `AppColors` — brand palette constants. |
| `design_system/typography.dart` | `AppTypography` — all text styles. |
| `design_system/spacing.dart` | `AppSpacing` — 4-pt grid constants (`xs`…`xxxl`). |
| `design_system/theme.dart` | `AppTheme.light` / `AppTheme.dark` — Material 3 `ThemeData`. |

### `features/identity/`

Handles **authentication** (Firebase Auth) and **user profile**.

| File | Purpose |
|---|---|
| `auth/auth_module.dart` | `AuthModule` class + `authStateProvider` stream. |
| `auth/screens/splash_screen.dart` | Session check on cold start; redirige a mapa o welcome. |
| `auth/screens/welcome_screen.dart` | Landing screen with Login / Sign-up CTAs. |
| `auth/screens/login_screen.dart` | Email + password login form. |
| `auth/screens/signup_data_screen.dart` | Paso 1 del registro: nombre, email, contraseña. |
| `auth/screens/signup_role_screen.dart` | Paso 2 del registro: rol BUYER/VENDOR + producto (obligatorio para VENDOR). |
| `profile/screens/profile_screen.dart` | Displays current user info. |
| `profile/screens/history_screen.dart` | Trip / report history list. |
| `profile/widgets/drawer_module.dart` | `Drawer` widget con nav links, toggle ride_enabled, sign-out con abandon de solicitud activa. |

### `features/presence/`

Tracks **vendor locations** in real time via Firestore.

| File | Purpose |
|---|---|
| `services/gps_service.dart` | `StreamProvider<Position?>` — device GPS con permisos; escribe presencia del vendedor en RTDB `vendedores_activos`. |
| `services/vendor_tracker.dart` | `StreamProvider<List<VendorMarker>>` — lee RTDB `vendedores_activos` y filtra vendedores activos en radio 4 km; detecta desconexiones vía `vendorOfflineStream`. |
| `models/vendor_marker.dart` | Modelo de presencia del vendedor: uid, lat, lng, activo, product, rideEnabled, lastTimestamp. |

### `features/dispatching/`

Core **map + request** flow for both buyers and vendors.

| File | Purpose |
|---|---|
| `screens/map_screen_buyer.dart` | Buyer map with vendor markers. |
| `screens/map_screen_vendor.dart` | Vendor map with self-location. |
| `screens/tracking_screen.dart` | Real-time tracking (stop request & ride). |
| `services/stop_request_module.dart` | CRUD for stop requests on Firestore. |
| `services/ride_request_module.dart` | ☆ [iter.2] Full CU-04 lifecycle (request → accept → complete / cancel). |
| `widgets/visibility_toggle.dart` | Switch to show/hide vendor on the map. |
| `widgets/destination_picker.dart` | ☆ [iter.2] Map-tap widget for selecting a ride destination. |
| `models/stop_request.dart` | Stop-request Firestore model. |
| `models/ride.dart` | ☆ [iter.2] Ride Firestore model (id, buyer_uid, vendor_uid, status, route, timestamps). |

### `features/safety/`

Community-reported **risk zones**.

| File | Purpose |
|---|---|
| `screens/risk_form_bottom_sheet.dart` | Modal form for reporting a risk zone. |
| `services/risk_zone_service.dart` | `StreamProvider<List<RiskZone>>` — suscripción directa a Firestore `risk_zones where active==true`; reacciona a expiraciones en ~1 s. |
| `models/risk_zone.dart` | Firestore-serialisable risk-zone model (riskLevel, radiusMeters, expiresAt). |

### `features/community/`

☆ Activated in **Iteration 2** — community safety reports with voting.

| File | Purpose |
|---|---|
| `screens/active_reports_screen.dart` | ☆ Lista de reportes comunitarios activos cerca del usuario. |
| `screens/report_detail_screen.dart` | ☆ Detalle de reporte + botones Confirmar / Desestimar (CU-06). |
| `screens/community_form_bottom_sheet.dart` | ☆ Formulario de nuevo reporte con selección de tipo y punto en mapa. |
| `screens/community_reports_history_screen.dart` | ☆ Historial de reportes propios del usuario. |
| `services/community_report_module.dart` | ☆ CU-05: POST reporte + `StateNotifier` de reportes activos con stale-while-revalidate. |
| `services/report_validation_module.dart` | ☆ CU-06: votar confirmar / desestimar vía transacción Firestore atómica. |
| `widgets/report_marker_panel.dart` | ☆ Bottom-card detail panel when a report marker is tapped. |
| `models/community_report.dart` | ☆ `CommunityReport` Firestore model with status + vote counters. |

### `features/shared/`

Cross-cutting concerns consumed by multiple feature modules.

| File | Purpose |
|---|---|
| `notifications/notification_handler.dart` | FCM initialisation + foreground / tap event routing. Despacha eventos de stop, ride, zonas de riesgo, reportes comunitarios y `route_zone_warning` a sus providers de Riverpod. |
| `widgets/gps_required_empty_state.dart` | Empty-state widget shown when GPS is unavailable. |

### `router/`

| File | Purpose |
|---|---|
| `app_router.dart` | `GoRouter` with auth-guard redirect. [iter.2] adds `/community/reports` route. |

---

## API Module Breakdown

### `modules/identity/`

| File | Purpose |
|---|---|
| `router.py` | `GET /auth/me` — fetch own profile. `POST /auth/sync-profile` — upsert user in Firestore. `PATCH /auth/device-token` — store FCM token. `PATCH /auth/location` — sync last known location for proximity-based FCM. `PATCH /auth/ride-enabled` — toggle vendor ride offering. |
| `schemas.py` | `UserProfile`, `SyncProfileRequest`, `DeviceTokenRequest`, `UpdateLocationBody` |

### `modules/dispatching/`

| File | Purpose |
|---|---|
| `router.py` | `POST /stops` — create stop request + FCM to vendor. `GET /stops/{id}` — read request. `PATCH /stops/{id}/status` — transition state machine (pending → accepted / rejected / expired / cancelled / completed / abandoned). |
| `schemas.py` | `StopRequest`, `CreateStopRequestBody`, `UpdateStatusBody` (incl. `route_warnings`), `VALID_TRANSITIONS` map. |
| `ride_router.py` | ☆ [iter.2] `POST /rides` — create ride + FCM to vendor. `PATCH /rides/{id}/status` — lifecycle (pending → accepted / rejected / expired / cancelled / in_progress / completed / abandoned). `PATCH /rides/{id}/vendor-arrived` — vendor signals arrival at pickup. |
| `ride_schemas.py` | ☆ [iter.2] `Ride`, `CreateRideBody`, `UpdateRideStatusBody`, `RIDE_VALID_TRANSITIONS` map. |

### `modules/safety/`

| File | Purpose |
|---|---|
| `router.py` | `GET /risk-zones` — list zones near a coordinate. `POST /risk-zones` — report a new risk zone. `DELETE /risk-zones/{id}` — deactivate a zone. |
| `schemas.py` | `RiskZone`, `CreateRiskZoneBody` |

### `modules/community/` ☆ [iter.2]

| File | Purpose |
|---|---|
| `report_router.py` | `POST /community-reports` — submit report + FCM a usuarios en radio 1 km. `GET /community-reports` — reportes activos cerca de una coordenada. |
| `validation_router.py` | `POST /community-reports/{id}/vote` — voto confirmar/desestimar con transacción atómica; envía FCM `report_status_changed` al reportador al alcanzar umbral. |
| `schemas.py` | `CommunityReport`, `CreateReportBody`, `VoteBody`, `ThreatType` enum. |

### `modules/shared/`

| File | Purpose |
|---|---|
| `firebase_admin_init.py` | `FirebaseAdminInit` — singleton SDK init. Uses `_EmulatorCredential` (AnonymousCredentials) when `FIREBASE_AUTH_EMULATOR_HOST` is set; `Certificate` when `FIREBASE_SERVICE_ACCOUNT_JSON` is set; `ApplicationDefault` otherwise. |
| `firestore_service.py` | `FirestoreService` — async CRUD helpers for `users`, `stop_requests`, `rides`, `risk_zones`, `community_reports` collections. Incluye helpers de transacción atómica y filtro Haversine para FCM por proximidad. |
| `notification_service.py` | `NotificationService` — envío de FCM data-only vía Firebase Admin SDK. Métodos especializados por evento (stop, ride, risk zone, community report, route zone warning). |

### `dependencies.py`

FastAPI dependency `get_current_user` — validates the Firebase ID token from `Authorization: Bearer <token>` and returns the decoded claims. Logs the exact exception on failure to help diagnose emulator token issues.

---

## Iteration Roadmap

| Tag | Status | Description |
|---|---|---|
| iter.1 | ✅ Structure | Core skeleton, auth, presence, dispatching (stop requests). |
| iter.2 | ✅ Completed | CU-04 Rides, CU-05/06 Community reports, FCM events. Hardening en `Rama-Miguel`: ~156 correcciones de producto, concurrencia, GPS/RTDB offline, zonas de riesgo y lifecycle. |

---

## Getting Started

El entorno activo del proyecto usa **Firebase de producción** (`ubisafe-ca262`) y el backend FastAPI desplegado en la nube. No se requieren emuladores locales para desarrollar.

### Flujo de producción (activo)

#### 1. Requisitos previos

- `google-services.json` del proyecto `ubisafe-ca262` en `ubisafe_app/android/app/` (nunca commitear)
- Maps API key en `ubisafe_app/android/local.properties`:
  ```
  MAPS_API_KEY=<tu_key>
  ```
  La key debe tener habilitada "Maps SDK for Android" en Google Cloud Console.

#### 2. Flutter app

```bash
cd ubisafe_app
flutter pub get

# Instalar en dispositivo físico Android vía ADB (wireless o USB):
flutter build apk
adb install build/app/outputs/flutter-apk/app-debug.apk
```

> No se usa `adb reverse` de puertos — la app se conecta directamente a Firebase y al backend en la nube.

---

### Flujo local con emuladores (desarrollo opcional)

Útil para correr los tests de pytest o desarrollar sin tocar datos de producción.

#### 1. Firebase Emulators

```bash
# From the repo root
firebase emulators:start --project demo-ubisafe
# UI: http://localhost:4000
# Auth: 9099 | Firestore: 8080 | RTDB: 9000 | Functions: 5001
```

#### 2. FastAPI backend

```bash
cd ubisafe_api
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
python -m pip install -r requirements.txt

cp .env.example .env
# Mínimo para desarrollo con emuladores:
#   FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
#   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
# (No se requiere service account — _EmulatorCredential maneja auth cuando el host de emulador está configurado)

python -m uvicorn main:app --reload
# API docs: http://localhost:8000/docs
```

#### 3. Flutter app contra emuladores

```bash
cd ubisafe_app
# adb reverse para redirigir puertos del emulador al dispositivo físico:
adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9000 tcp:9000
adb reverse tcp:8000 tcp:8000

flutter run
```

#### Docker (FastAPI)

```bash
cd ubisafe_api
docker build -t ubisafe-api .
docker run -p 8000:8000 --env-file .env ubisafe-api
```
