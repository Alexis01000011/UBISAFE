# CLAUDE.md — UBISAFE
**Proyecto:** Los Borbotones · TSP · ITESM  
**Equipo:** Alexis Córdova (PM/líder) · Miguel Esaú Rivera Román (tech lead) · Leonardo Fernández Morales (QA)

---

## Arquitectura del repo

Este repositorio es un **monorepo** con tres componentes desplegables independientes:

| Carpeta | Tecnología | Iteración |
|---|---|---|
| `ubisafe_app/` | Flutter 3.x / Dart 3.x | 1 + 2 |
| `ubisafe_api/` | Python 3.12 / FastAPI 0.111+ | 1 + 2 |
| `functions/` | Python / Firebase Functions gen2 | 2 (F7) |

**Fuentes de verdad:**
- `INDICE_SDD_UBISAFE.md` — índice de todos los SDDs (leer antes de buscar en los SDDs individuales)
- `plan_code.md` — guía de implementación: qué se hace, en qué orden, y quién lidera cada fase
- Los SDDs individuales son la fuente de verdad técnica — si hay conflicto entre código y SDD, **gana el SDD**

---

## Comandos comunes

```bash
# Flutter
cd ubisafe_app
flutter pub get
flutter run                          # requiere dispositivo/emulador Android conectado
flutter analyze
flutter test

# FastAPI
cd ubisafe_api
python -m pip install -r requirements.txt   # usar python -m pip, no pip directamente
uvicorn main:app --reload                   # http://localhost:8000/docs
ruff check .
python -m pytest                            # usar python -m pytest, no pytest directamente

# Firebase Emulators (desde la raíz del repo)
firebase emulators:start --project demo-ubisafe
# UI en http://localhost:4000
# Auth: 9099 | Firestore: 8080 | RTDB: 9000 | Functions: 5001

# ADB (debug inalámbrico en dispositivo físico)
adb devices -l
adb reverse --list
adb reverse tcp:9099 tcp:9099   # Firebase Auth emulator
adb reverse tcp:8080 tcp:8080   # Firestore emulator
adb reverse tcp:9000 tcp:9000   # RTDB emulator
adb reverse tcp:8000 tcp:8000   # FastAPI local
adb reverse tcp:5001 tcp:5001   # Functions emulator (opcional)
adb tcpip 5555                  # habilita ADB por red (no sustituye adb reverse)
```

---

## Setup inicial (por desarrollador, una vez)

1. **Flutter:** Instalar Flutter 3.x stable. Verificar con `flutter doctor`.
2. **Firebase Tools:** `npm install -g firebase-tools` → `firebase login`
3. **`google-services.json`:** Descargar del proyecto Firebase en console.firebase.google.com y colocar en `ubisafe_app/android/app/google-services.json` (este archivo está en `.gitignore`, nunca se commitea).
4. **`.env`:** Copiar `ubisafe_api/.env.example` a `ubisafe_api/.env`. Para desarrollo con emuladores, el mínimo necesario es:
   ```
   FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
   ```
   No se necesita `FIREBASE_SERVICE_ACCOUNT_JSON` para emuladores — la clase `_EmulatorCredential` en `firebase_admin_init.py` maneja la inicialización automáticamente.
5. **Maps API Key:** Añadir al archivo `ubisafe_app/android/local.properties` (no se commitea):
   ```
   MAPS_API_KEY=<tu_clave>
   ```
   La clave debe tener habilitada la API **"Maps SDK for Android"** en Google Cloud Console, con billing activo. Sin esto el mapa muestra fondo amarillo.
6. **Demo project para emuladores:** El `.firebaserc` apunta a `demo-ubisafe`. Para desarrollo local con emuladores, no se necesita un proyecto real. Para deploy a producción, ejecutar `firebase use --add` y seleccionar el proyecto real.

---

## Bugs críticos resueltos — no revertir

Encontrados al correr F3/F4 en dispositivo físico Android (MIUI/Xiaomi, `firebase_auth 4.16.0`). Están en los commits de `feat/presence/f3-gps-vendor-tracker`. Revertir cualquiera rompe el flujo de autenticación.

| # | Síntoma | Causa | Archivo corregido |
|---|---|---|---|
| 1 | App congelada en Splash, decenas de 401 en uvicorn | `JwtInterceptor.onError` llamaba `signOut()` ante cualquier 401 → FCM sync 401 → signOut → rebuild → repeat | `core/api/api_client.dart` |
| 2 | Listeners de FCM acumulados en cada rebuild de la app | `NotificationHandler.init()` se llamaba en `build()` sin guard | `features/shared/notifications/notification_handler.dart` + `main.dart` |
| 3 | Crash al hacer login: `type 'List<Object?>' is not subtype of 'PigeonUserDetails?'` | Bug conocido de `firebase_auth 4.16.0` en Android — login exitoso lanza excepción de deserialización Pigeon | `features/identity/auth/auth_module.dart` |
| 4 | FastAPI 500 en todos los endpoints Firestore: `DefaultCredentialsError` | `ApplicationDefault()` falla sin ADC configurado; no hay service account en dev | `ubisafe_api/modules/shared/firebase_admin_init.py` |
| 5 | Firestore del emulador inaccesible aunque Auth funciona | Faltaba `FIRESTORE_EMULATOR_HOST` en `.env`; Firestore intentaba conectar a producción | `ubisafe_api/.env` + `firebase.json` (puerto 8080) |

**Comportamientos adicionales implementados:**
- La sesión se cierra automáticamente al cerrar la app (swipe desde recientes) — implementado con `WidgetsBindingObserver` + `AppLifecycleState.detached` en `main.dart`.
- El token JWT inválido (ej. emulador reiniciado con sesión persistida) hace `signOut()` silencioso desde `onRequest`, no desde `onError`.

---

## Estado de iter.1 al 28/04/2026

### Funciona en dispositivo físico ✅
- Registro y login (Firebase Auth emulador)
- Perfil en Firestore (drawer muestra nombre, rol, opciones de navegación)
- Mapa se renderiza con tiles cuando Maps SDK for Android está habilitado en Cloud Console
- Cierre de sesión desde drawer y automático al cerrar la app

### Pendiente de validación manual ⏳
- **F4 — CU-01 completo:** El código está implementado (rama `feat/dispatching/f4-cu01-stop-request` de Alexis). Falta probar con dos dispositivos simultáneos los 4 escenarios de `tests/acceptance/cu-01.md` (flujo normal, rechazo, timeout 60s, race condition 409).
- **Presencia RTDB:** `GPSService` y `VendorTracker` implementados. Verificar en el emulador UI (http://localhost:4000 → RTDB) que los nodos `/vendedores_activos/{uid}` se crean al activar visibilidad y se eliminan al desactivarla.
- **FCM:** Las notificaciones push no funcionan con emuladores locales (limitación de Firebase Cloud Messaging). El token se sincroniza correctamente; las notificaciones en vivo requieren staging/producción.
- **F5 — CU-03 Safety:** Aún no iniciado. Ver plan_code.md §F5.

---

## Configuración Android — matrix de versiones

| Componente | Versión | Notas |
|---|---|---|
| Flutter | 3.41.7 stable | Verificar con `flutter doctor` |
| AGP (Android Gradle Plugin) | **8.9.1** | Mínimo para `androidx.core:core-ktx:1.17.0` |
| KGP (Kotlin Gradle Plugin) | **2.3.21** | Debe coincidir con stdlib que traen los plugins de terceros |
| Gradle Wrapper | **8.11.1** | Satisface el mínimo de AGP 8.9.x |
| NDK | **28.2.13676358** | Requerido por `jni 1.0.0` (transitiva de Firebase/maps) |
| compileSdk / targetSdk | 36 | |
| minSdk | 29 | |

### Por qué NO subir a AGP 9.x

Los plugins de pub en sus versiones actuales (`google_maps_flutter_android 2.19.8`, `geolocator_android 4.6.2`, `firebase_core 2.32.0`, `firebase_auth 4.16.0`, `cloud_firestore 4.17.5`, `firebase_messaging 14.7.10`, `firebase_database 10.5.7`) aplican `kotlin-android` en sus propios `build.gradle`. AGP 9 registra la extensión `kotlin` internamente, lo que produce `Cannot add extension with name 'kotlin'` al compilar cualquiera de esos plugins. Para usar AGP 9 habría que actualizar todos a sus versiones mayores (firebase_core 4.x, geolocator 14.x, etc.) — cambio disruptivo fuera del alcance actual.

### Por qué KGP 2.3.21 y no una versión menor

`google_maps_flutter_android 2.19.8` trae `kotlin-stdlib 2.3.10` (compilado con KGP 2.3.x). Si el KGP del proyecto es inferior a 2.3.x, el compilador Kotlin falla con `Module was compiled with an incompatible version of Kotlin. The binary version of its metadata is 2.3.0`. KGP debe ser ≥ 2.3.x.

### Instalar el NDK correcto

El NDK **no se instala automáticamente** con `flutter doctor`. Debe instalarse manualmente:
> Android Studio → SDK Manager → SDK Tools → NDK (Side by side) → 28.2.13676358 → Apply

Verificar desde terminal:
```bash
ls "$LOCALAPPDATA/Android/Sdk/ndk/"
# debe aparecer 28.2.13676358 en la lista
```

---

## Reglas Git para Claude Code

### Claude Code PUEDE hacer sin preguntar:
- `git status`, `git diff`, `git log`, `git branch` — comandos de lectura
- `git checkout -b feat/<dominio>/<descripcion>` — crear rama nueva
- `git add <archivos específicos>` (nunca `git add .` sin revisión previa)
- `git commit -m "<mensaje conventional>"` con el mensaje propuesto
- `git push` a la rama propia (nunca a `main`)

### Claude Code SIEMPRE debe preguntar antes de:
- `git push --force` o `git push --force-with-lease`
- `git rebase`, `git reset --hard`, `git cherry-pick`
- `git merge` directo a `main`
- Eliminar ramas remotas
- Tocar archivos sensibles: `.env`, `firebase-service-account.json`, `google-services.json`

### Claude Code NUNCA debe:
- Commitear secretos (claves de API, tokens, credenciales)
- Pushear a `main` directamente
- Reescribir historia ya pusheada (sin permiso explícito)

### Naming de ramas:
`<tipo>/<dominio>/<descripcion-corta>`
- Tipos: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`
- Dominios: `identity`, `presence`, `dispatching`, `safety`, `community`, `shared`, `setup`, `infra`

### Commits — Conventional Commits:
`<tipo>(<scope>): <mensaje en imperativo>`  
Ejemplo: `feat(dispatching): implement POST /stops with FCM notification`

---

## Estructura de carpetas canónica

### Flutter — `ubisafe_app/lib/`

```
lib/
├── main.dart
├── core/
│   ├── api/api_client.dart
│   ├── design_system/          # colors, spacing, theme, typography
│   └── providers/              # app_lifecycle_provider, auth_providers
├── features/
│   ├── identity/               # AuthModule, DrawerModule
│   │   ├── auth/               # auth_module, screens/, models/
│   │   └── profile/            # screens/, widgets/drawer_module
│   ├── presence/               # GPSService, VendorTracker
│   │   ├── services/
│   │   └── models/
│   ├── dispatching/            # MapScreenBuyer, MapScreenVendor, StopRequestModule, RideRequestModule
│   │   ├── screens/
│   │   ├── services/
│   │   ├── widgets/
│   │   └── models/
│   ├── safety/                 # RiskReportModule
│   │   ├── screens/
│   │   └── models/
│   ├── community/              # CommunityReportModule, ReportValidationModule [iter.2]
│   │   ├── screens/
│   │   ├── services/
│   │   ├── widgets/
│   │   └── models/
│   └── shared/                 # NotificationHandler, GpsRequiredEmptyState
│       ├── notifications/
│       └── widgets/
└── router/app_router.dart
```

**Asignación de componentes por dominio (SDD_FASE2_PASO25 §5.3):**

| Dominio | Componentes Flutter |
|---|---|
| `identity` | AuthModule, DrawerModule |
| `presence` | GPSService, **VendorTracker** |
| `dispatching` | **MapScreenBuyer, MapScreenVendor**, StopRequestModule, RideRequestModule [iter.2] |
| `safety` | RiskReportModule |
| `community` | CommunityReportModule, ReportValidationModule [iter.2] |
| `shared` | NotificationHandler, GpsRequiredEmptyState |

> Nota: MapScreenVendor pertenece a `dispatching` (orquesta CU-02, no el GPS en sí). VendorTracker pertenece a `presence` (suscribe RTDB de vendedores). DrawerModule pertenece a `identity` (acción principal = logout).

---

### FastAPI — `ubisafe_api/`

```
ubisafe_api/
├── main.py
├── dependencies.py             # get_current_user (AuthMiddleware)
├── modules/
│   ├── identity/               # AuthRouter
│   │   ├── router.py           # /auth endpoints
│   │   └── schemas.py          # UserProfile, SyncProfileRequest, DeviceTokenRequest
│   ├── dispatching/            # StopRequestRouter [+ RideRouter iter.2]
│   │   ├── router.py           # /stops endpoints
│   │   └── schemas.py          # StopRequest, CreateStopRequestBody, UpdateStatusBody
│   ├── safety/                 # RiskZoneRouter
│   │   ├── router.py           # /risk-zones endpoints
│   │   └── schemas.py          # RiskZone, CreateRiskZoneBody
│   ├── community/              # CommunityReportRouter, ReportValidationRouter [iter.2]
│   │   ├── router.py
│   │   └── schemas.py
│   └── shared/                 # Servicios transversales
│       ├── firebase_admin_init.py
│       ├── firestore_service.py
│       └── notification_service.py
├── tests/
└── requirements.txt
```

> No existe `modules/presence/` en iter.1 — el GPS escribe directo a RTDB desde Flutter (ADR #2).

---

## Guía de implementación

Las fases se ejecutan en este orden: **F0 → F1 → F2 → F3 → F4 → F5** (iter.1) **→ F6 → F7 → F8** (iter.2).

Cada fase tiene:
- Un **SDD a leer** antes de empezar (ver `plan_code.md` cabecera de cada fase)
- Subtareas numeradas (F1.1, F1.2, etc.)
- Un **Definition of Done** explícito — no marcar como completa hasta que pasen los tests + CI verde

**Cómo empezar una fase nueva:**
1. Leer los SDDs listados en la cabecera de la fase en `plan_code.md`
2. Crear la rama: `git checkout -b feat/<dominio>/f<N>-<descripcion>`
3. Ejecutar las subtareas en orden
4. Verificar el DoD
5. Abrir PR con la plantilla de `.github/pull_request_template.md`

---

## Agentes disponibles

| Agente | Cuándo usarlo | Archivo |
|---|---|---|
| `sdd-traceability-checker` | Antes de abrir cualquier PR de feature | `.claude/agents/sdd-traceability-checker.md` |
| `firestore-rules-reviewer` | Cada vez que se modifica `firestore.rules` o `database.rules.json` | `.claude/agents/firestore-rules-reviewer.md` |

---

## Notas de seguridad

- Las reglas de Firestore (`firestore.rules`) y RTDB (`database.rules.json`) son la primera línea de defensa del cliente.
- El Admin SDK de FastAPI **bypass** las reglas de Firestore — la autorización de negocio la aplica FastAPI.
- Nunca hardcodear claves de API en código de producción. Usar variables de entorno y `.env.example` como referencia.
- El agente `firestore-rules-reviewer` debe correr en cada PR que toque archivos de reglas.
