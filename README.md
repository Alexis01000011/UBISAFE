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
7. [Cloud Functions](#cloud-functions)
8. [Iteration Roadmap](#iteration-roadmap)
9. [Getting Started](#getting-started)

---

## Overview

UBISAFE connects street vendors and buyers in real time on a shared map, while layering community-driven safety features (risk zones, community reports, ride requests, group stays) on top.

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
| Local notifications | flutter_local_notifications (interactive RSVP) |
| Scheduled jobs | Firebase Cloud Functions (2nd Gen) |
| Backend API | FastAPI (Python) — accessed via Dio |
| Maps | Google Maps Flutter |
| Location | Geolocator |

---

## Architecture — Modular Monolith

The app follows a **modular monolith** pattern:

- All code lives in one Flutter project (`ubisafe_app/`).
- Each **feature module** (`identity`, `presence`, `dispatching`, `safety`, `community`) is a self-contained vertical slice with its own screens, services, widgets and models.
- Modules communicate **only** through Riverpod providers — never through direct imports between feature directories (except `shared/`).
- The `core/` layer holds infrastructure that every module may import: design system tokens, API client, cross-cutting providers.
- `shared/` holds truly cross-cutting concerns: notification handling, subscriptions, reusable widgets.

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
│  │  shared/  (notifications, subscriptions, common widgets)   │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  core/  (api_client, design_system, providers)             │ │
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
│   │   ├── design_system/
│   │   │   ├── colors.dart                # Brand palette
│   │   │   ├── typography.dart            # Text-style catalogue
│   │   │   ├── spacing.dart               # 4-pt spacing scale
│   │   │   └── theme.dart                 # Material 3 ThemeData (light + dark)
│   │   └── providers/
│   │       ├── app_lifecycle_provider.dart  # AppLifecycleState via WidgetsBindingObserver
│   │       └── auth_providers.dart          # userProfileProvider (GET /auth/me)
│   │
│   ├── features/
│   │   │
│   │   ├── identity/                      # 🔐 Identity & Access
│   │   │   ├── auth/
│   │   │   │   ├── auth_module.dart       # Firebase Auth helpers + providers
│   │   │   │   ├── models/
│   │   │   │   │   └── user_profile.dart  # UserProfile Firestore model
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
│   │   │
│   │   ├── presence/                      # 📡 Presence
│   │   │   ├── services/
│   │   │   │   ├── gps_service.dart       # Geolocator stream provider; escribe en RTDB vendedores_activos
│   │   │   │   └── vendor_tracker.dart    # RTDB vendedores_activos → filtro 4 km → VendorMarker stream
│   │   │   └── models/
│   │   │       └── vendor_marker.dart     # uid, lat, lng, activo, product, rideEnabled, lastTimestamp
│   │   │
│   │   ├── dispatching/                   # 🗺️ Dispatching
│   │   │   ├── screens/
│   │   │   │   ├── map_screen_buyer.dart  # SpeedDial FAB + ride + community + group stays
│   │   │   │   ├── map_screen_vendor.dart # Incoming ride dialog + community + group stays
│   │   │   │   └── tracking_screen.dart   # Reused for ride (CU-04) & stop tracking
│   │   │   ├── services/
│   │   │   │   ├── stop_request_module.dart
│   │   │   │   └── ride_request_module.dart  # CU-04 full lifecycle
│   │   │   ├── widgets/
│   │   │   │   ├── visibility_toggle.dart
│   │   │   │   └── destination_picker.dart   # Map-tap destination widget
│   │   │   ├── models/
│   │   │   │   ├── stop_request.dart
│   │   │   │   └── ride.dart                 # Ride model (CU-04)
│   │   │   ├── utils/
│   │   │   │   └── map_utils.dart            # RouteZones + Haversine helpers para zonas en ruta
│   │   │   └── group_stays/                  # ☆ [iter.3] CU-09 — Estancias Grupales
│   │   │       ├── models/
│   │   │       │   └── group_stay.dart       # GroupStay + CreateGroupStayResponse
│   │   │       ├── services/
│   │   │       │   └── group_stay_module.dart  # GroupStayModule + activeGroupStaysProvider
│   │   │       └── screens/
│   │   │           ├── schedule_group_stay_screen.dart       # Vendor programa estancia (CU-09-A)
│   │   │           ├── group_stay_detail_screen.dart         # Detalle + cancelar/confirmar asistencia (CU-09-B)
│   │   │           └── group_stay_location_picker_sheet.dart # Selector de ubicación en mapa
│   │   │
│   │   ├── safety/                        # ⚠️ Safety
│   │   │   ├── screens/
│   │   │   │   ├── risk_form_bottom_sheet.dart
│   │   │   │   └── risk_zone_detail_screen.dart  # ☆ [iter.3] Detalle + botón Desmentir (CU-03)
│   │   │   ├── services/
│   │   │   │   ├── risk_zone_service.dart         # StreamProvider<List<RiskZone>> directo a Firestore
│   │   │   │   └── risk_zone_dismiss_module.dart  # ☆ [iter.3] POST /risk-zones/{id}/dismiss (CU-03)
│   │   │   └── models/
│   │   │       └── risk_zone.dart                 # RiskZone + campos dismiss (dismiss_count, dismissers)
│   │   │
│   │   ├── community/                     # 🌐 Community
│   │   │   ├── screens/
│   │   │   │   ├── active_reports_screen.dart
│   │   │   │   ├── report_detail_screen.dart              # Detalle + confirmar/desestimar (CU-06)
│   │   │   │   ├── community_form_bottom_sheet.dart       # Formulario de nuevo reporte (CU-05)
│   │   │   │   ├── community_reports_history_screen.dart  # Historial de reportes propios
│   │   │   │   ├── lot_form_bottom_sheet.dart             # ☆ [iter.3] Formulario de lote baldío (CU-07)
│   │   │   │   └── lot_location_picker_sheet.dart         # ☆ [iter.3] Selector de ubicación de lote
│   │   │   ├── services/
│   │   │   │   ├── community_report_module.dart           # CU-05: POST reporte + StateNotifier stale-while-revalidate
│   │   │   │   └── report_validation_module.dart          # CU-06: votar confirmar/desestimar transacción atómica
│   │   │   ├── widgets/
│   │   │   │   └── report_marker_panel.dart               # Bottom-card al tocar marcador de reporte
│   │   │   └── models/
│   │   │       └── community_report.dart                  # CommunityReport: ThreatType (animal_muerto, zona_sucia, lote), ReportStatus (pending_validation, confirmed, dismissed, expired, resolved), campos lote (description, supportCount, supporters, resolvedAt)
│   │   │
│   │   └── shared/                        # 🔔 Shared (transversal)
│   │       ├── notifications/
│   │       │   ├── notification_handler.dart       # FCM setup + event routing (25 tipos de evento)
│   │       │   └── local_notification_service.dart # ☆ [iter.3] flutter_local_notifications; acción RSVP interactiva para group stays
│   │       ├── subscriptions/                      # ☆ [iter.3] CU-08 — Suscripciones
│   │       │   ├── models/
│   │       │   │   └── subscription.dart           # Subscription model
│   │       │   ├── services/
│   │       │   │   └── subscription_module.dart    # GET/POST/DELETE /subscriptions
│   │       │   └── screens/
│   │       │       └── subscriptions_screen.dart   # Pantalla "Mis suscripciones"
│   │       └── widgets/
│   │           └── gps_required_empty_state.dart
│   │
│   └── router/
│       └── app_router.dart                # GoRouter + auth-guard redirect
│                                          # Rutas: /splash, /welcome, /login, /signup-*,
│                                          # /home/buyer, /home/vendor, /tracking,
│                                          # /profile, /history, /subscriptions,
│                                          # /safety/risk-zones/detail,
│                                          # /community/reports, /community/reports/detail,
│                                          # /group-stays/schedule, /group-stays/detail
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
│   │   ├── router.py                    # GET /auth/me · POST /auth/sync-profile · PATCH /auth/device-token · PATCH /auth/location · PATCH /auth/ride-enabled
│   │   └── schemas.py                   # UserProfile · SyncProfileRequest · DeviceTokenRequest · UpdateLocationBody · UpdateRideEnabledRequest
│   ├── dispatching/
│   │   ├── router.py                    # POST /stops · GET /stops/{id} · PATCH /stops/{id}/status
│   │   ├── schemas.py                   # StopRequest · CreateStopRequestBody · UpdateStatusBody · StopRequestStatus
│   │   ├── ride_router.py               # POST /rides · PATCH /rides/{id}/status · PATCH /rides/{id}/vendor-arrived
│   │   ├── ride_schemas.py              # Ride · CreateRideBody · UpdateRideStatusBody · RIDE_VALID_TRANSITIONS
│   │   ├── group_stay_router.py         # ☆ [iter.3] POST /group-stays · GET /group-stays · GET /group-stays/{id} · PATCH /group-stays/{id}/cancel · POST /group-stays/{id}/attendances
│   │   └── group_stay_schemas.py        # ☆ [iter.3] GroupStay · CreateGroupStayBody · CreateGroupStayResponse · GroupStayStatus
│   ├── safety/
│   │   ├── router.py                    # GET /risk-zones · POST /risk-zones
│   │   ├── schemas.py                   # RiskZone (+ dismiss_count, dismissers, dismissed_at) · CreateRiskZoneBody
│   │   └── dismiss_router.py            # ☆ [iter.3] POST /risk-zones/{id}/dismiss (CU-03)
│   ├── community/
│   │   ├── report_router.py             # POST /community-reports · GET /community-reports
│   │   ├── validation_router.py         # POST /community-reports/{id}/vote (CU-06)
│   │   ├── lot_router.py                # ☆ [iter.3] POST /community-reports/{id}/support · PATCH /community-reports/{id}/resolve (CU-07)
│   │   └── schemas.py                   # CommunityReport (+ lote fields) · CreateReportBody · VoteBody · ThreatType · ReportStatus
│   └── shared/                          # Transversal services
│       ├── firebase_admin_init.py       # FirebaseAdminInit — SDK init + emulator credential
│       ├── firestore_service.py         # FirestoreService — CRUD helpers; transacciones atómicas; Haversine proximity
│       ├── notification_service.py      # NotificationService — FCM data-only; 25 métodos especializados por evento
│       ├── subscription_router.py       # ☆ [iter.3] POST /subscriptions · GET /subscriptions · DELETE /subscriptions/{id} (CU-08)
│       └── subscription_schemas.py      # ☆ [iter.3] Subscription · CreateSubscriptionBody
│
├── tests/                               # pytest suite (105 tests)
│   ├── test_smoke.py
│   ├── test_auth.py
│   ├── test_stops.py
│   ├── test_rides.py
│   ├── test_risk_zones.py
│   ├── test_community_reports.py
│   ├── test_lot_support.py
│   ├── test_subscriptions.py
│   ├── test_group_stays.py
│   ├── test_health.py
│   └── test_api.py
├── requirements.txt
├── .env.example                         # Template — copy to .env, never commit .env
└── Dockerfile
```

---

## Module Breakdown

### `core/`

| File | Purpose |
|---|---|
| `api/api_client.dart` | Singleton `Dio` instance configured for the FastAPI backend. Attaches Firebase ID token as Bearer header. |
| `design_system/colors.dart` | `AppColors` — brand palette constants. |
| `design_system/typography.dart` | `AppTypography` — all text styles. |
| `design_system/spacing.dart` | `AppSpacing` — 4-pt grid constants (`xs`…`xxxl`). |
| `design_system/theme.dart` | `AppTheme.light` / `AppTheme.dark` — Material 3 `ThemeData`. |
| `providers/app_lifecycle_provider.dart` | `appLifecycleProvider` — tracks `AppLifecycleState` via `WidgetsBindingObserver`; used by presence layer to detect background/foreground transitions. |
| `providers/auth_providers.dart` | `userProfileProvider` — `FutureProvider<UserProfile?>` that calls `GET /auth/me`; re-evaluates on auth state changes. |

### `features/identity/`

Handles **authentication** (Firebase Auth) and **user profile**.

| File | Purpose |
|---|---|
| `auth/auth_module.dart` | `AuthModule` class + `authStateProvider` stream. |
| `auth/models/user_profile.dart` | `UserProfile` Firestore model (uid, name, email, role, product, deviceToken). |
| `auth/screens/splash_screen.dart` | Session check on cold start; redirige a mapa o welcome. |
| `auth/screens/welcome_screen.dart` | Landing screen with Login / Sign-up CTAs. |
| `auth/screens/login_screen.dart` | Email + password login form. |
| `auth/screens/signup_data_screen.dart` | Paso 1 del registro: nombre, email, contraseña. |
| `auth/screens/signup_role_screen.dart` | Paso 2 del registro: rol BUYER/VENDOR + producto (obligatorio para VENDOR). |
| `profile/screens/profile_screen.dart` | Displays current user info. |
| `profile/screens/history_screen.dart` | Trip / report history list. |
| `profile/widgets/drawer_module.dart` | `Drawer` widget con nav links, toggle ride_enabled, acceso a suscripciones, sign-out con abandon de solicitud activa. |

### `features/presence/`

Tracks **vendor locations** in real time via Firebase RTDB.

| File | Purpose |
|---|---|
| `services/gps_service.dart` | `StreamProvider<Position?>` — device GPS con permisos; escribe presencia del vendedor en RTDB `vendedores_activos`. |
| `services/vendor_tracker.dart` | `StreamProvider<List<VendorMarker>>` — lee RTDB `vendedores_activos` y filtra vendedores activos en radio 4 km; detecta desconexiones vía `vendorOfflineStream`. |
| `models/vendor_marker.dart` | Modelo de presencia del vendedor: uid, lat, lng, activo, product, rideEnabled, lastTimestamp. |

### `features/dispatching/`

Core **map + request** flow for both buyers and vendors, incluyendo rides y estancias grupales.

| File | Purpose |
|---|---|
| `screens/map_screen_buyer.dart` | Buyer map with vendor markers, group stay markers, risk zones; SpeedDial FAB. |
| `screens/map_screen_vendor.dart` | Vendor map with self-location, incoming ride dialog, group stay actions. |
| `screens/tracking_screen.dart` | Real-time tracking for stop request & ride (CU-04). |
| `services/stop_request_module.dart` | CRUD for stop requests on Firestore. |
| `services/ride_request_module.dart` | Full CU-04 lifecycle (request → accept → arrived → in_progress → complete / cancel). |
| `widgets/visibility_toggle.dart` | Switch to show/hide vendor on the map. |
| `widgets/destination_picker.dart` | Map-tap widget for selecting a ride destination. |
| `models/stop_request.dart` | Stop-request Firestore model. |
| `models/ride.dart` | Ride Firestore model (id, buyer_uid, vendor_uid, status, route, timestamps). |
| `utils/map_utils.dart` | `RouteZones` + `zonesOnRoute()` — Haversine helpers to detect risk zones along a route polyline. |
| `group_stays/models/group_stay.dart` | ☆ [iter.3] `GroupStay` + `CreateGroupStayResponse` (con campo `warning` para zonas MEDIUM/LOW). |
| `group_stays/services/group_stay_module.dart` | ☆ [iter.3] `GroupStayModule` (POST/GET/cancel/attendances) + `activeGroupStaysProvider` (`StateNotifier`). |
| `group_stays/screens/schedule_group_stay_screen.dart` | ☆ [iter.3] CU-09-A — Vendor programa nueva estancia grupal. |
| `group_stays/screens/group_stay_detail_screen.dart` | ☆ [iter.3] CU-09-B — Detalle; vendor cancela, buyer confirma asistencia; escucha `groupStayCancelledProvider`. |
| `group_stays/screens/group_stay_location_picker_sheet.dart` | ☆ [iter.3] Selector de punto en mapa para ubicación de la estancia. |

### `features/safety/`

Community-reported **risk zones** con desmentido comunitario.

| File | Purpose |
|---|---|
| `screens/risk_form_bottom_sheet.dart` | Modal form for reporting a new risk zone. |
| `screens/risk_zone_detail_screen.dart` | ☆ [iter.3] Detalle de zona: `LinearProgressIndicator` de votos dismiss + botón Desmentir (CU-03). |
| `services/risk_zone_service.dart` | `StreamProvider<List<RiskZone>>` — suscripción directa a Firestore `risk_zones where active==true`. |
| `services/risk_zone_dismiss_module.dart` | ☆ [iter.3] `RiskZoneDismissModule` — `POST /risk-zones/{id}/dismiss`; 3 votos desactivan la zona. |
| `models/risk_zone.dart` | Firestore-serialisable risk-zone model (riskLevel, radiusMeters, expiresAt, dismissCount, dismissers, dismissedAt). |

### `features/community/`

Community safety reports con votación y soporte a lotes baldíos.

| File | Purpose |
|---|---|
| `screens/active_reports_screen.dart` | Lista de reportes comunitarios activos cerca del usuario. |
| `screens/report_detail_screen.dart` | Detalle de reporte + botones Confirmar / Desestimar (CU-06). |
| `screens/community_form_bottom_sheet.dart` | Formulario de nuevo reporte con selección de tipo y punto en mapa (CU-05). |
| `screens/community_reports_history_screen.dart` | Historial de reportes propios del usuario. |
| `screens/lot_form_bottom_sheet.dart` | ☆ [iter.3] CU-07 — Formulario de reporte de lote baldío con descripción. |
| `screens/lot_location_picker_sheet.dart` | ☆ [iter.3] Selector de ubicación en mapa para lote baldío. |
| `services/community_report_module.dart` | CU-05: POST reporte + `StateNotifier` de reportes activos con stale-while-revalidate. |
| `services/report_validation_module.dart` | CU-06: votar confirmar / desestimar vía transacción Firestore atómica. |
| `widgets/report_marker_panel.dart` | Bottom-card detail panel when a report marker is tapped. |
| `models/community_report.dart` | `CommunityReport` con `ThreatType` (animal_muerto, zona_sucia, lote), `ReportStatus` (pending_validation, confirmed, dismissed, expired, **resolved**) y campos lote: description, supportCount, supporters, pendingResolverUid, resolvedAt, resolvedByUid. |

### `features/shared/`

Cross-cutting concerns consumed by multiple feature modules.

| File | Purpose |
|---|---|
| `notifications/notification_handler.dart` | FCM init + foreground/tap routing. Despacha 25 tipos de evento a sus providers de Riverpod (stop, ride, risk zone, community report, group stay, subscriptions, route_zone_warning). |
| `notifications/local_notification_service.dart` | ☆ [iter.3] flutter_local_notifications — notificación local con acción RSVP interactiva `rsvp_confirm` para group stays; funciona desde app en background/killed. |
| `subscriptions/models/subscription.dart` | ☆ [iter.3] `Subscription` model (id, buyerUid, vendorUid, active, createdAt, vendorName). |
| `subscriptions/services/subscription_module.dart` | ☆ [iter.3] `SubscriptionModule` — GET / POST / DELETE `/subscriptions`; máx. 5 suscripciones activas. |
| `subscriptions/screens/subscriptions_screen.dart` | ☆ [iter.3] Pantalla "Mis suscripciones" — lista + cancelar. |
| `widgets/gps_required_empty_state.dart` | Empty-state widget shown when GPS is unavailable. |

### `router/`

| File | Purpose |
|---|---|
| `app_router.dart` | `GoRouter` con auth-guard redirect. Rutas agregadas en iter.2+3: `/community/reports`, `/community/reports/detail`, `/subscriptions`, `/safety/risk-zones/detail`, `/group-stays/schedule`, `/group-stays/detail`. |

---

## API Module Breakdown

### `modules/identity/`

| File | Purpose |
|---|---|
| `router.py` | `GET /auth/me` — fetch own profile. `POST /auth/sync-profile` — upsert user in Firestore. `PATCH /auth/device-token` — store FCM token. `PATCH /auth/location` — sync last known location for proximity-based FCM. `PATCH /auth/ride-enabled` — toggle vendor ride offering. |
| `schemas.py` | `UserProfile`, `SyncProfileRequest`, `DeviceTokenRequest`, `UpdateLocationBody`, `UpdateRideEnabledRequest` |

### `modules/dispatching/`

| File | Purpose |
|---|---|
| `router.py` | `POST /stops` — create stop request + FCM to vendor. `GET /stops/{id}` — read request. `PATCH /stops/{id}/status` — state machine (pending → accepted / rejected / expired / cancelled / completed / abandoned). |
| `schemas.py` | `StopRequest`, `CreateStopRequestBody`, `UpdateStatusBody` (incl. `route_warnings`), `VALID_TRANSITIONS` map. |
| `ride_router.py` | `POST /rides` — create ride + FCM to vendor. `PATCH /rides/{id}/status` — lifecycle (pending → accepted → in_progress → completed / cancelled / abandoned). `PATCH /rides/{id}/vendor-arrived` — vendor signals arrival at pickup. |
| `ride_schemas.py` | `Ride`, `CreateRideBody`, `UpdateRideStatusBody`, `RIDE_VALID_TRANSITIONS` map. |
| `group_stay_router.py` | ☆ [iter.3] `POST /group-stays` — schedule stay (validación zona + solapamiento + distancia 2 km). `GET /group-stays` — list active stays near coordinate. `GET /group-stays/{id}` — fetch stay with `has_attended`. `PATCH /group-stays/{id}/cancel` — vendor cancela + FCM multicast. `POST /group-stays/{id}/attendances` — buyer confirma asistencia. |
| `group_stay_schemas.py` | ☆ [iter.3] `GroupStay`, `CreateGroupStayBody`, `CreateGroupStayResponse` (con `warning`), `GroupStayStatus` |

### `modules/safety/`

| File | Purpose |
|---|---|
| `router.py` | `GET /risk-zones` — list zones near a coordinate. `POST /risk-zones` — report a new risk zone. |
| `schemas.py` | `RiskZone` (+ `dismiss_count`, `dismissers`, `dismissed_at`), `CreateRiskZoneBody` |
| `dismiss_router.py` | ☆ [iter.3] `POST /risk-zones/{zone_id}/dismiss` — voto de desmentido; 3 votos → `active=False`; FCM al reportante al alcanzar umbral. No auto-dismiss, no double-vote, reporter no puede desmentir su propia zona. |

### `modules/community/`

| File | Purpose |
|---|---|
| `report_router.py` | `POST /community-reports` — submit report + FCM a usuarios en radio 1 km. `GET /community-reports` — reportes activos cerca de una coordenada. |
| `validation_router.py` | `POST /community-reports/{id}/vote` — voto confirmar/desestimar con transacción atómica; envía FCM `report_status_changed` al reportador al alcanzar umbral (CU-06). |
| `lot_router.py` | ☆ [iter.3] `POST /community-reports/{id}/support` — agregar soporte a lote baldío (máx. 3). `PATCH /community-reports/{id}/resolve` — marcar lote como resuelto; FCM al reportante y supporters (CU-07). |
| `schemas.py` | `CommunityReport` (+ campos lote), `CreateReportBody`, `VoteBody`, `ThreatType` enum, `ReportStatus` enum. |

### `modules/shared/`

| File | Purpose |
|---|---|
| `firebase_admin_init.py` | `FirebaseAdminInit` — singleton SDK init. Usa `_EmulatorCredential` cuando `FIREBASE_AUTH_EMULATOR_HOST` está configurado; `Certificate` cuando `FIREBASE_SERVICE_ACCOUNT_JSON` está configurado; `ApplicationDefault` en otro caso. |
| `firestore_service.py` | `FirestoreService` — async CRUD helpers para `users`, `stop_requests`, `rides`, `risk_zones`, `community_reports`, `group_stays`, `subscriptions`. Incluye helpers de transacción atómica, Haversine proximity, dismiss voting y solapamiento de estancias. |
| `notification_service.py` | `NotificationService` — FCM data-only vía Firebase Admin SDK. 25 métodos especializados por evento (stop, ride, risk zone dismiss, community report, lot resolved, group stay created/cancelled, subscription created, route zone warning). |
| `subscription_router.py` | ☆ [iter.3] `POST /subscriptions` — buyer se suscribe a un vendedor (máx. 5; FCM al vendedor). `GET /subscriptions` — lista suscripciones activas del caller. `DELETE /subscriptions/{id}` — cancelar suscripción (CU-08). |
| `subscription_schemas.py` | ☆ [iter.3] `Subscription`, `CreateSubscriptionBody` |

### `dependencies.py`

FastAPI dependency `get_current_user` — validates the Firebase ID token from `Authorization: Bearer <token>` and returns the decoded claims. Logs the exact exception on failure to help diagnose emulator token issues.

---

## Cloud Functions

7 funciones desplegadas en Firebase (2nd Gen) para el proyecto `ubisafe-ca262`:

| Función | Trigger | Propósito |
|---|---|---|
| `aggregate_duplicate_reports` | Firestore `onCreate` community_reports | Detecta reportes duplicados por proximidad y los agrupa bajo un `canonical_report_id`. |
| `expire_risk_zones` | Scheduler (cada 30 min) | Desactiva zonas de riesgo cuyo `expires_at` haya pasado. |
| `on_risk_zone_write` | Firestore `onWrite` risk_zones | Distingue expiración de desmentido (`dismissed_at`); notifica al reportante en ambos casos. |
| `notify_vendor_proximity_to_subscribers` | Firestore `onUpdate` users | Detecta cuando un vendedor se activa y notifica a sus suscriptores cercanos (CU-08). |
| `expire_group_stays` | Scheduler (cada 5 min) | Marca como `expired` las estancias grupales cuyo `end_at` haya pasado. |
| `cancel_stay_on_risk_zone_change` | Firestore `onUpdate` risk_zones | Cancela estancias grupales en radio 200 m cuando una zona HIGH se activa cerca. |
| `notify_group_stay_in_radius` | Firestore `onCreate` group_stays | Envía notificación local interactiva (RSVP) a usuarios en radio 2 km al crearse una estancia (CU-09). |

---

## Iteration Roadmap

| Tag | Status | Description |
|---|---|---|
| iter.1 | ✅ Structure | Core skeleton, auth, presence, dispatching (stop requests). |
| iter.2 | ✅ Completed | CU-04 Rides, CU-05/06 Community reports, FCM events. Hardening en `Rama-Miguel`: ~156 correcciones de producto, concurrencia, GPS/RTDB offline, zonas de riesgo y lifecycle. |
| iter.3 | ✅ Completed | CU-03 Dismiss (desmentido comunitario de zonas), CU-07 Lotes Baldíos, CU-08 Suscripciones/Radar, CU-09 Estancias Grupales. 7 Cloud Functions desplegadas. 105/105 pytest, 0 flutter analyze issues. |

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
