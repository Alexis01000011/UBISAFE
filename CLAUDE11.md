# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

UBISAFE is a cross-platform urban safety mobile app connecting street vendors and buyers, built as a **modular monolith** with:
- **Flutter** frontend (`ubisafe_app/`)
- **FastAPI** backend (`ubisafe_api/`)
- **Firebase** (Auth, Firestore, RTDB, Cloud Functions, FCM)

## Development Startup

Start in order: Firebase Emulators → FastAPI → Flutter App. The batch script `start_ubisafe.bat` automates this sequence (including `adb reverse` for physical Android devices).

**Firebase Emulators** (run from repo root):
```
firebase emulators:start --project demo-ubisafe
```
Ports: Auth 9099, Firestore 8080, RTDB 9000, Functions 5001, UI 4000

**FastAPI** (run from `ubisafe_api/`):
```
python -m uvicorn main:app --reload
```
API docs at `http://localhost:8000/docs`. Requires `.env` from `.env.example` with `FIREBASE_SERVICE_ACCOUNT_JSON` and `GOOGLE_MAPS_API_KEY`.

**Flutter** (run from `ubisafe_app/`):
```
flutter pub get
flutter run
```

**Flutter against production Render backend:**
```
flutter run --dart-define=API_BASE_URL=https://ubisafe-j1fg.onrender.com
```

**Flutter against production Firebase + Render (debug mode):**
```
flutter run --dart-define=USE_EMULATORS=false --dart-define=API_BASE_URL=https://ubisafe-j1fg.onrender.com
```

**Important:** Never run `gradle build` directly — the user always handles Android builds in their own terminal.

## Android Build Config

Canonical versions (changing these breaks the build):
- AGP **8.7.3**
- Gradle **8.11.1**
- KGP **2.0.21**

AGP 9 is incompatible with current Firebase v2, geolocator v10, and maps v2 plugins.

## Testing

**Flutter:**
```
flutter test                            # all tests
flutter test test/features/...          # single test file
```
Tests use `mocktail`. Widget tests that load Google Fonts must override `FlutterError.onError` and call `tester.pump()` to suppress font-loading errors.

**FastAPI:**
```
pytest --tb=short                       # all tests
pytest tests/test_auth.py               # single test file
```

## Linting / Analysis

**Flutter:**
```
flutter analyze
```
Config: `ubisafe_app/analysis_options.yaml` (extends `flutter_lints`, enforces `prefer_const_constructors`, `prefer_final_locals`).

**FastAPI:**
```
ruff check . --fix
```
Config in `ubisafe_api/pyproject.toml` — line length 100, Python 3.12, checks E/F/I/N/UP.

## Architecture

### Flutter — Feature Module Structure

All features live under `ubisafe_app/lib/features/`. Modules communicate **only** through Riverpod providers; no direct cross-feature imports except via `shared/`.

| Module | Responsibility |
|--------|---------------|
| `identity/` | Auth, user profile, app drawer |
| `presence/` | GPS service, real-time vendor location tracking (RTDB) |
| `dispatching/` | Google Maps screen, stop requests, rides |
| `safety/` | Risk zone creation and display |
| `community/` | Community reports (iter.2) |
| `shared/` | FCM notifications, reusable widgets |

Core infrastructure lives in `ubisafe_app/lib/core/`:
- `api/api_client.dart` — Dio HTTP client configured to point at FastAPI
- `design_system/` — Colors, typography, spacing, theme
- Navigation is handled by GoRouter in `router/app_router.dart` with auth guard

State management uses Riverpod with code generation (`riverpod_annotation` + `build_runner`).

### FastAPI — Module Structure

Routers are registered in `ubisafe_api/main.py`. Authentication uses Firebase JWT verification via `dependencies.py:get_current_user`.

```
modules/
├── identity/       # /auth endpoints
├── dispatching/    # /stops, /rides endpoints
├── safety/         # /risk-zones endpoints
├── community/      # /community-reports (iter.2)
└── shared/         # Firebase Admin init, Firestore client, FCM helpers
```

### Firebase Project

- Production project ID: `ubisafe-ca262` (`.firebaserc`)
- Local development uses `demo-ubisafe` (emulator-only project, no real Firebase connection)
- `main.dart` detects `kDebugMode` and connects Flutter to local emulators automatically

## CI Pipeline

`.github/workflows/ci.yml` runs two parallel jobs on every push:
- **flutter-job**: `flutter analyze` → `flutter test`
- **fastapi-job**: `ruff check . --fix` → `pytest --tb=short`
