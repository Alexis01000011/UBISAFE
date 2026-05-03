# Registro de Correcciones — UBISAFE

**Proyecto:** Los Borbotones · TSP · ITESM  
**Rama activa:** `feat/shared/f8-hardening-e2e-polish`  
**Dispositivo de prueba:** Físico Android (depuración inalámbrica ADB, NO emulador de computadora)  
**Última actualización:** 2026-05-01

---

## Formato de cada entrada

| Campo | Descripción |
|---|---|
| **Nombre clave** | Etiqueta corta para identificar la corrección |
| **Qué se corrigió (técnico)** | Términos de código exactos |
| **Qué se corrigió (simple)** | Explicación sin jerga |
| **Clase / Método / Módulo** | Ubicación exacta en el código |
| **Justificación** | Por qué era necesario el cambio |
| **Problema que resolvía** | Síntoma que el usuario/sistema reportaba |

---

## Correcciones ya aplicadas

---

### C-01 · Router sin watch de perfil

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se eliminó `ref.watch(userProfileProvider)` de `appRouterProvider`; el redirect de usuario logueado en ruta de auth ahora envía a `/splash` en lugar de calcular el rol directamente |
| **Qué se corrigió (simple)** | El enrutador de la app ya no intenta leer el perfil del usuario por su cuenta; delega esa responsabilidad a la pantalla de Splash |
| **Clase / Módulo** | `AppRouter` → cierre `redirect` en `app_router.dart` (`ubisafe_app/lib/router/app_router.dart`) |
| **Justificación** | `userProfileProvider` es asíncrono; cuando emitía un nuevo valor, GoRouter recreaba una instancia nueva del router, lo que reiniciaba la pila de navegación a `/splash` en medio de la sesión activa, creando una carrera entre el redirect y `SplashScreen._checkSession` |
| **Problema que resolvía** | Después de hacer login, la app volvía a Splash o a Welcome en lugar de ir a la pantalla del mapa correcta |

---

### C-02 · Login sin navegación manual

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se eliminaron `ref.invalidate(userProfileProvider)`, `ref.read(userProfileProvider.future)` y `context.go(home)` del handler de login exitoso en `LoginScreen` |
| **Qué se corrigió (simple)** | El botón de "Entrar" ya no intenta navegar por su cuenta; la navegación queda a cargo del router (que a su vez la delega a Splash) |
| **Clase / Método / Módulo** | `_LoginScreenState._submit()` → `login_screen.dart` (`ubisafe_app/lib/features/identity/auth/screens/login_screen.dart`) |
| **Justificación** | La navegación manual desde LoginScreen competía con el redirect del GoRouter; ambos intentaban cambiar la ruta al mismo tiempo y sólo uno ganaba, de forma no determinista |
| **Problema que resolvía** | Luego del login exitoso la app a veces no navegaba, o navegaba a la pantalla equivocada |

---

### C-03 · ProfileScreen usa Firestore en lugar de claims JWT

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se reemplazó `userClaimsProvider` (que leía `user.getIdTokenResult(true)`) por `userProfileProvider` (que lee Firestore); se eliminó el provider local `userClaimsProvider` |
| **Qué se corrigió (simple)** | La pantalla de Perfil ahora muestra nombre, teléfono y rol leyéndolos de la base de datos (Firestore), no del token de autenticación |
| **Clase / Módulo** | `ProfileScreen.build()` → `profile_screen.dart` (`ubisafe_app/lib/features/identity/profile/screens/profile_screen.dart`) |
| **Justificación** | El rol y datos del usuario se guardan en Firestore via `/auth/sync-profile`, no en custom claims de Firebase. Leer del token devolvía valores vacíos o desactualizados |
| **Problema que resolvía** | Pantalla de Perfil mostraba "Desconocido" como rol y campos vacíos para nombre y teléfono |

---

### C-04 · HistoryScreen usa rol de Firestore y ordena en cliente

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se reemplazó lectura de rol vía `user.getIdTokenResult(false).claims` por `userProfileProvider.future`; se eliminó `.orderBy('updated_at', descending: true)` de la query Firestore y se implementó ordenamiento en cliente (`docs.sort(...)`) |
| **Qué se corrigió (simple)** | El historial de viajes ahora obtiene el rol del usuario desde la base de datos (no del token), y ordena los viajes por fecha directamente en el teléfono para evitar requerir un índice compuesto en Firestore |
| **Clase / Módulo** | `historyProvider` (FutureProvider) → `history_screen.dart` (`ubisafe_app/lib/features/identity/profile/screens/history_screen.dart`) |
| **Justificación** | Claims no contiene el rol. `.orderBy` + `.where` en Firestore requiere índice compuesto; sin él la query lanza excepción. El ordenamiento en cliente es funcional para el volumen esperado |
| **Problema que resolvía** | El historial no cargaba (crash por índice faltante o rol vacío) y mostraba viajes del rol equivocado |

---

### C-05 · Deprecación withOpacity → withValues

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Reemplazo de `.withOpacity(x)` por `.withValues(alpha: x)` en múltiples widgets |
| **Qué se corrigió (simple)** | Se actualizó la forma de poner transparencia a los colores en la UI para usar la API moderna de Flutter |
| **Clase / Módulo** | `DrawerModule`, `ProfileScreen`, `HistoryScreen`, `MapScreenBuyer` → varios archivos en `ubisafe_app/lib/features/` |
| **Justificación** | `.withOpacity()` está marcado como deprecated en Flutter 3.x; produce warnings que ensucian los logs y eventualmente causará errores de compilación |
| **Problema que resolvía** | Warnings de deprecación en `flutter analyze` |

---

### C-06 · VendorTracker no emite vendedores sin GPS

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Cuando `_buyerLat == null || _buyerLng == null`, el método `_emitFiltered()` emite `const []` en lugar de `List.unmodifiable(_vendors.values)` |
| **Qué se corrigió (simple)** | Si el teléfono todavía no tiene ubicación GPS, el mapa no muestra ningún vendedor en lugar de mostrar todos sin filtrar por distancia |
| **Clase / Módulo** | `VendorTracker._emitFiltered()` → `vendor_tracker.dart` (`ubisafe_app/lib/features/presence/services/vendor_tracker.dart`) |
| **Justificación** | Mostrar todos los vendedores sin tener coordenadas del comprador hace que los cálculos de distancia sean erróneos (distancia desde lat=0, lng=0) |
| **Problema que resolvía** | El mapa mostraba marcadores de vendedores en posiciones incorrectas mientras el GPS se inicializaba |

---

### C-07 · ActiveReportsScreen maneja ausencia de GPS

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se convirtió `ActiveReportsScreen` de `ConsumerWidget` a `ConsumerStatefulWidget`; se agregó `initState → _loadIfNeeded()` que: (a) si el notifier ya tiene coordenadas, no hace nada; (b) si `gpsServiceProvider` tiene posición, llama `notifier.load(lat, lng)`; (c) si no hay GPS, llama `notifier.setGpsUnavailable()` |
| **Qué se corrigió (simple)** | La pantalla de "Reportes Activos" ya puede cargar datos por su cuenta si se accede desde el menú lateral sin haber pasado antes por el mapa; y si no hay GPS, muestra un mensaje legible en lugar de girar eternamente |
| **Clase / Módulo** | `ActiveReportsScreen` + `_ActiveReportsScreenState._loadIfNeeded()` → `active_reports_screen.dart` (`ubisafe_app/lib/features/community/screens/active_reports_screen.dart`) |
| **Justificación** | El notifier sólo tenía coordenadas si el mapa lo había inicializado antes; acceder directo desde drawer causaba un spinner infinito |
| **Problema que resolvía** | Pantalla de reportes atrapada en loading infinito al abrirla desde el drawer sin GPS activo |

---

### C-08 · CommunityReportModule — hasCoordinates y setGpsUnavailable

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se añadió getter `hasCoordinates` (devuelve `_lat != null && _lng != null`) y método `setGpsUnavailable()` (emite `AsyncValue.error('gps_unavailable', ...)`) al notifier `_CommunityReportsNotifier` |
| **Qué se corrigió (simple)** | El módulo de reportes comunitarios ahora puede indicar si ya tiene coordenadas cargadas y puede señalar explícitamente que no hay GPS disponible |
| **Clase / Módulo** | `_CommunityReportsNotifier` → `community_report_module.dart` (`ubisafe_app/lib/features/community/services/community_report_module.dart`) |
| **Justificación** | Sin estos métodos, `ActiveReportsScreen` no podía saber si el notifier estaba en estado "nunca cargado" vs "cargando" vs "sin GPS" |
| **Problema que resolvía** | Spinner infinito en pantalla de reportes; imposible mostrar mensaje de error de GPS |

---

### C-09 · Notificaciones FCM por proximidad — Community Reports

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se reemplazó `FirestoreService.get_all_user_fcm_tokens()` por `FirestoreService.get_nearby_user_fcm_tokens(report.location.lat, report.location.lng, _PROXIMITY_RADIUS_KM)` en `_notify_nearby()` |
| **Qué se corrigió (simple)** | Al crear un reporte comunitario, las notificaciones push sólo se envían a usuarios cercanos al reporte, no a todos los usuarios de la app |
| **Clase / Módulo** | `_notify_nearby()` → `report_router.py` (`ubisafe_api/modules/community/report_router.py`) |
| **Justificación** | Enviar FCM a todos los usuarios es costoso, no escalable e irrelevante para usuarios lejos del incidente |
| **Problema que resolvía** | Todos los usuarios recibían notificación de reportes ajenos a su zona |

---

### C-10 · Notificaciones FCM por proximidad — Risk Zones

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se reemplazó `FirestoreService.get_all_user_fcm_tokens()` por `FirestoreService.get_nearby_user_fcm_tokens(body.location.lat, body.location.lng, _RISK_ZONE_NOTIFY_RADIUS_KM)` en `_notify_all()`; se añadió constante `_RISK_ZONE_NOTIFY_RADIUS_KM = 5.0` |
| **Qué se corrigió (simple)** | Al crear una zona de riesgo, sólo se notifica a los usuarios que están a menos de 5 km del lugar |
| **Clase / Módulo** | `_notify_all()` → `router.py` (`ubisafe_api/modules/safety/router.py`) |
| **Justificación** | Misma razón que C-09: notificaciones masivas son ineficientes y molestas para usuarios no afectados |
| **Problema que resolvía** | Todos los usuarios recibían alertas de zonas de riesgo fuera de su área |

---

### C-11 · FirestoreService — filtro de tokens por distancia

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se añadió método de clase `get_nearby_user_fcm_tokens(lat, lng, radius_km)` que itera los documentos de `users`, calcula `_haversine_km` con `last_location` de cada usuario y filtra por radio |
| **Qué se corrigió (simple)** | El servicio de base de datos ahora puede devolver sólo los tokens de notificación de usuarios cercanos a una coordenada dada |
| **Clase / Módulo** | `FirestoreService.get_nearby_user_fcm_tokens()` → `firestore_service.py` (`ubisafe_api/modules/shared/firestore_service.py`) |
| **Justificación** | Sin este método, C-09 y C-10 no podían implementarse; la función anterior enviaba a todos sin distinción |
| **Problema que resolvía** | No existía un mecanismo para filtrar destinatarios de FCM por ubicación |

---

### C-12 · vote_community_report usa transacción Firestore

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se reemplazó `ArrayUnion([vote_entry])` + `Increment(1)` + `ref.update(update)` por una función decorada con `@fs_transactional` que lee, calcula y escribe dentro de una sola transacción atómica de Firestore |
| **Qué se corrigió (simple)** | Los votos en un reporte comunitario ahora se procesan de forma segura: si dos personas votan al mismo tiempo, el resultado siempre es correcto y no se pierden ni duplican votos |
| **Clase / Módulo** | `FirestoreService.vote_community_report()` → `firestore_service.py` (`ubisafe_api/modules/shared/firestore_service.py`) |
| **Justificación** | `Increment` + `ArrayUnion` sin transacción tienen condición de carrera: dos votos simultáneos pueden leer el mismo estado base y ambos creer ser el tercer voto que activa el cambio de status |
| **Problema que resolvía** | Conteo de votos incorrecto bajo concurrencia; cambio de status del reporte podía dispararse dos veces |

---

---

### C-13 · Restitución del import de auth_module en app_router

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se restituyó `import '../features/identity/auth/auth_module.dart'` en `app_router.dart`, que había sido eliminado en C-01 junto con la lógica de perfil |
| **Qué se corrigió (simple)** | El enrutador necesita el import de `auth_module.dart` para poder leer `authStateProvider`; sin él, la app no compilaba |
| **Clase / Módulo** | `appRouterProvider` → `app_router.dart` (`ubisafe_app/lib/router/app_router.dart`) |
| **Justificación** | Al eliminar el watch de `userProfileProvider` en C-01, se eliminó por error el import de `auth_module.dart` que también exporta `authStateProvider`, causando un error de compilación |
| **Problema que resolvía** | `Error: Undefined name 'authStateProvider'` en `app_router.dart:40` — la app no compilaba |

---

## Correcciones aplicadas (continuación)

---

### C-14 · Pigeon bug en register() — registro parcial sin perfil

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se envolvió `_auth.createUserWithEmailAndPassword()` en try-catch con la misma guardia `if (_auth.currentUser == null) rethrow` que ya existía en `login()` |
| **Qué se corrigió (simple)** | Al registrar una cuenta nueva en Android, Firebase puede lanzar una excepción aunque el usuario sí fue creado; ahora el código detecta que el registro fue exitoso y continúa en lugar de interrumpirse |
| **Clase / Método / Módulo** | `AuthModule.register()` → `auth_module.dart` (`ubisafe_app/lib/features/identity/auth/auth_module.dart`) |
| **Justificación** | `firebase_auth 4.16.0` en Android tiene el bug Pigeon (Bug #3 del CLAUDE.md); aplica tanto a `signIn` como a `createUserWithEmailAndPassword`, pero el workaround sólo estaba en `login()`, no en `register()` |
| **Problema que resolvía** | Al registrar, la excepción detenía `register()` antes de llamar `POST /auth/sync-profile`, dejando al usuario autenticado en Firebase pero sin perfil en Firestore; esto desencadenaba el bucle infinito Splash↔Welcome |

---

### C-15 · SplashScreen hace signOut cuando el perfil es null

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se descomentó `await ref.read(authModuleProvider).signOut()` en la rama `profile == null` de `_checkSession()`; se añadió el mismo signOut en los bloques `on TimeoutException` y `catch (_)` |
| **Qué se corrigió (simple)** | Si la pantalla de carga detecta que el usuario está autenticado pero no tiene perfil (o que la API no respondió), ahora cierra la sesión antes de redirigir a la pantalla de bienvenida |
| **Clase / Método / Módulo** | `_SplashScreenState._checkSession()` → `splash_screen.dart` (`ubisafe_app/lib/features/identity/auth/screens/splash_screen.dart`) |
| **Justificación** | Sin el signOut, el usuario quedaba autenticado al llegar a `/welcome`; el redirect del router lo devolvía a `/splash`; splash volvía a encontrar perfil null y volvía a `/welcome` → bucle infinito que bloqueaba la app |
| **Problema que resolvía** | App colgada permanentemente en la pantalla de carga ("UbiSafe") al registrar o al reabrir la app tras un registro parcial |

---

### C-16 · Router no redirige /welcome a /splash para usuarios logueados

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se añadió `&& path != '/welcome'` a la condición `if (isLoggedIn && isAuthPath && path != '/splash')` del redirect en `appRouterProvider` |
| **Qué se corrigió (simple)** | Ahora la pantalla de bienvenida puede mostrarse aunque el usuario esté autenticado; antes, cualquier usuario logueado que llegara a `/welcome` era automáticamente devuelto a `/splash`, creando el bucle |
| **Clase / Método / Módulo** | `appRouterProvider` cierre `redirect` → `app_router.dart` (`ubisafe_app/lib/router/app_router.dart`) |
| **Justificación** | `/welcome` es la pantalla de respaldo correcta cuando el perfil Firestore no existe (registro incompleto, API caída); redirigirla a splash cerraba el ciclo del bucle; ahora el usuario puede interactuar con la app (retry de login o registro) |
| **Problema que resolvía** | Segundo eslabón del bucle Splash↔Welcome; necesario como "cinturón de seguridad" incluso después de C-15 para el caso de que el signOut no haya propagado todavía a Riverpod cuando el redirect evalúa |

---

### C-17 · stopTransmission — remove RTDB como fire-and-forget con deadline (revisado)

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se reemplazó `await _rtdbRefFactory(vendorUid).remove()` con try-catch por una llamada no-awaited con `.timeout(2s, onTimeout: () {}).catchError((_) {})`; `stopTransmission` ahora retorna sin esperar a RTDB |
| **Qué se corrigió (simple)** | El Firebase SDK encola operaciones RTDB y puede esperar indefinidamente cuando el emulador no está disponible — si nunca lanza excepción, el try-catch no sirve. Ahora el remove se lanza en segundo plano: si no responde en 2 s se descarta y la UI se actualiza igual |
| **Clase / Método / Módulo** | `GPSService.stopTransmission()` → `gps_service.dart` (`ubisafe_app/lib/features/presence/services/gps_service.dart`) |
| **Justificación** | La versión con try-catch no resolvía el cuelgue: `await remove()` bloqueaba el `async` de `stopTransmission` si el Future nunca completaba ni lanzaba excepción; `_isVisible` nunca se actualizaba. El `remove()` es best-effort: el handler `onDisconnect().remove()` limpia el nodo eventualmente |
| **Problema que resolvía** | Botón "Activar Visibilidad" se quedaba encendido y no podía desactivarse porque `stopTransmission` colgaba esperando RTDB sin lanzar nunca |

---

### C-18 · Toggle de visibilidad usa uid de authStateProvider en lugar de userProfileProvider

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | En `_onToggle`, se reemplazó `ref.read(userProfileProvider).valueOrNull` por `ref.read(authStateProvider).valueOrNull?.uid`; también se añadió guardia `if (mounted)` antes de cada `setState` post-await |
| **Qué se corrigió (simple)** | El botón de visibilidad del vendedor ahora obtiene el identificador del usuario directamente de Firebase Auth (siempre disponible) en lugar de la llamada a la API; así el toggle funciona aunque el perfil esté recargando |
| **Clase / Método / Módulo** | `_MapScreenVendorState._onToggle()` → `map_screen_vendor.dart` (`ubisafe_app/lib/features/dispatching/screens/map_screen_vendor.dart`) |
| **Justificación** | `userProfileProvider` es un `FutureProvider` que depende de `authStateProvider` y hace `GET /auth/me`. Cada vez que `authStateProvider` emite (incluso el mismo usuario), el provider se re-evalúa y `.valueOrNull` es `null` durante esa ventana. El guard `if (profile?.uid == null) return` salía silencioso en cada re-evaluación, bloqueando el toggle. El `uid` del usuario autenticado es siempre accesible desde `authStateProvider` sin pasar por la API |
| **Problema que resolvía** | Botón "Activar Visibilidad" se encendía correctamente pero no podía apagarse; los logs Android confirmaban los toques registrados pero sin ninguna reacción de Flutter (la función salía por el guard silencioso) |

---

### C-19 · Import faltante de auth_module en map_screen_vendor

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se añadió `import '../../identity/auth/auth_module.dart'` a `map_screen_vendor.dart` |
| **Qué se corrigió (simple)** | Al usar `authStateProvider` en C-18, faltaba el import del archivo donde está definido ese provider |
| **Clase / Módulo** | Cabecera de imports → `map_screen_vendor.dart` (`ubisafe_app/lib/features/dispatching/screens/map_screen_vendor.dart`) |
| **Justificación** | `authStateProvider` vive en `auth_module.dart`; `auth_providers.dart` lo importa internamente pero no lo re-exporta, por lo que cada archivo que lo use directamente necesita su propio import |
| **Problema que resolvía** | `Error: The getter 'authStateProvider' isn't defined for the type '_MapScreenVendorState'` — la app no compilaba |

---

### C-20 · VendorTracker inicializa posición del comprador con valor actual del GPS

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se añadió `ref.read(gpsServiceProvider).valueOrNull` antes del `ref.listen` en `_vendorTrackerInstanceProvider` para sembrar `_buyerLat/_buyerLng` con la posición ya disponible; se cambió `next.value` por `next.valueOrNull` en el listener |
| **Qué se corrigió (simple)** | El rastreador de vendedores ahora lee la posición GPS del comprador en el momento en que se crea, no solo cuando el GPS cambia después. Sin esto, si el GPS ya estaba activo al abrir el mapa, los vendedores nunca aparecían |
| **Clase / Método / Módulo** | `_vendorTrackerInstanceProvider` (Provider closure) → `vendor_tracker.dart` (`ubisafe_app/lib/features/presence/services/vendor_tracker.dart`) |
| **Justificación** | `ref.listen` en Riverpod solo dispara en cambios **posteriores** a su registro. Si `gpsServiceProvider` ya tenía una posición cuando `_vendorTrackerInstanceProvider` se creó, `_buyerLat/_buyerLng` quedaba `null` → `_emit()` siempre devolvía lista vacía sin importar cuántos vendedores estuvieran activos en RTDB |
| **Problema que resolvía** | Vendedores activos en RTDB no aparecían en el mapa del comprador al probarlo con dos dispositivos físicos |

---

### C-21 · adb reverse actualizado a puerto 8088 para dos dispositivos

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se ejecutó `adb -t <transport_id> reverse tcp:9099/8088/9000/8000` para ambos dispositivos (Xiaomi transport_id:19, HONOR transport_id:20); puerto Firestore corregido de 8080 a 8088 |
| **Qué se corrigió (simple)** | Ambos teléfonos ahora tienen tuneados los cuatro puertos necesarios para comunicarse con los emuladores Firebase y FastAPI en la computadora de desarrollo |
| **Clase / Módulo** | Configuración de infraestructura ADB — no es código de la app |
| **Justificación** | Con dos dispositivos físicos cada uno necesita su propio `adb reverse`; el segundo dispositivo (comprador) no tenía ningún túnel activo, por lo que no podía conectarse al emulador RTDB ni leer la posición del vendedor. El puerto de Firestore es 8088 (no 8080) según `main.dart` y `firebase.json` actuales |
| **Problema que resolvía** | Vendedor activo en RTDB no aparecía en el mapa del comprador; comprador no podía autenticarse ni leer Firestore desde su dispositivo |

---

### C-22 · Cast inseguro de lat/lng en VendorMarker

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-22 · VendorMarker cast seguro |
| **Qué se corrigió (técnico)** | `(map['lat'] as num).toDouble()` reemplazado por `num.parse(map['lat'].toString()).toDouble()` en `VendorMarker.fromMap` |
| **Qué se corrigió (simple)** | Si RTDB almacena coordenadas como string en lugar de número, el cast anterior lanzaba `_CastError` y rompía el stream completo; ahora se parsea como string para soportar ambos formatos |
| **Clase / Método / Módulo** | `VendorMarker.fromMap` · `presence/models/vendor_marker.dart` |
| **Justificación** | Firebase RTDB puede devolver valores numéricos como String dependiendo del cliente que los escribió; `num.parse(toString())` es robusto contra ambos tipos |
| **Problema que resolvía** | Vendedor no aparecía en el mapa del comprador cuando el nodo RTDB tenía lat/lng como string |

---

### C-23 · Entries malformadas crashean el stream de VendorTracker

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-23 · VendorTracker try-catch por entrada |
| **Qué se corrigió (técnico)** | `_init` listener envuelve cada `VendorMarker.fromMap()` en un try-catch individual; entradas corruptas se saltan sin interrumpir el resto ni abortar `_emit()` |
| **Qué se corrigió (simple)** | Si un nodo de vendedor en RTDB tiene datos inválidos, antes toda la actualización fallaba silenciosamente y el mapa no se actualizaba; ahora solo se omite ese vendedor y el resto sí aparece |
| **Clase / Método / Módulo** | `VendorTracker._init` · `presence/services/vendor_tracker.dart` líneas 43-58 |
| **Justificación** | Las excepciones lanzadas dentro del callback `data` de `listen()` no son capturadas por `onError`; van directo a la zona Flutter y silencian `_emit()`, impidiendo cualquier actualización del stream |
| **Problema que resolvía** | Vendedor activo en RTDB no aparecía en el mapa del comprador cuando algún nodo tenía campos corruptos |

---

### C-24 · Single-subscription risk en stream RTDB de VendorTracker

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-24 · asBroadcastStream en VendorTracker |
| **Qué se corrigió (técnico)** | `ref.onValue.map(...)` ahora encadena `.asBroadcastStream()` antes de pasarse a `_init` |
| **Qué se corrigió (simple)** | El stream de Firebase RTDB es single-subscription; si Riverpod recrea el provider (p.ej. hot-reload o dispose/re-create), suscribirse dos veces lanzaba `StateError: Stream already listened to`. Convertirlo a broadcast permite múltiples suscriptores sin error |
| **Clase / Método / Módulo** | `VendorTracker()` constructor · `presence/services/vendor_tracker.dart` línea 23 |
| **Justificación** | Previene `StateError` al recompilar en caliente o cuando Riverpod destruye y recrea el provider |
| **Problema que resolvía** | App podía crashear silenciosamente tras hot-reload durante pruebas en dispositivo físico |

---

### C-25 · distanceFilter + timeLimit bloqueaban primera escritura RTDB

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-25 · GPS sin timeLimit ni distanceFilter |
| **Qué se corrigió (técnico)** | Eliminados `distanceFilter: 10` y `timeLimit: _kNoSignalTimeout` de `LocationSettings` en `GPSService._subscribe`; eliminada la constante `_kNoSignalTimeout` |
| **Qué se corrigió (simple)** | Con `distanceFilter: 10`, un vendedor estático nunca recibía actualizaciones de GPS. Con `timeLimit: 10s`, Geolocator lanzaba error tras 10 s sin movimiento, activando el retry. En la práctica: el primer nodo RTDB tardaba >10 s en escribirse (o nunca lo hacía si el dispositivo no se movía) |
| **Clase / Método / Módulo** | `GPSService._subscribe` · `presence/services/gps_service.dart` líneas 140-146 |
| **Justificación** | En pruebas en interiores con dos dispositivos estáticos, `distanceFilter: 10` suprime todas las actualizaciones de posición → el vendedor nunca escribe en RTDB → nunca aparece en el mapa del comprador |
| **Problema que resolvía** | Vendedor no aparecía en el mapa del comprador cuando ambos dispositivos estaban estáticos |

---

### C-26 · Regla RTDB faltante impide leer lista completa de vendedores activos

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se añadió `".read": "auth != null"` al nivel `vendedores_activos` en `database.rules.json` |
| **Qué se corrigió (simple)** | El comprador ahora puede leer la lista completa de vendedores activos desde RTDB; antes solo podía leer nodos individuales por UID |
| **Clase / Módulo** | `database.rules.json` — nodo `vendedores_activos` |
| **Justificación** | Firebase RTDB no propaga reglas `.read` de hijos hacia el padre. `VendorTracker` suscribe a `/vendedores_activos` (padre), pero la regla `.read: "auth != null"` solo existía en el hijo `$vendor_uid`. Firebase lanzaba `permission_denied` silenciosamente capturado por `onError: (_) { controller.add([]) }`, haciendo que `vendorMarkersProvider` siempre emitiera `[]` |
| **Problema que resolvía** | Vendedores activos nunca aparecían en el mapa del comprador aunque el RTDB tenía datos y el GPS de ambos dispositivos funcionaba |

---

### C-27 · distanceFilter: 10 en gpsServiceProvider impedía actualización de posición del comprador

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se cambió `distanceFilter: 10` a `distanceFilter: 0` en `gpsServiceProvider` (`gps_service.dart`) |
| **Qué se corrigió (simple)** | El GPS del comprador ahora actualiza su posición en todo momento, no solo cuando se mueve 10 metros |
| **Clase / Módulo** | `gpsServiceProvider` → `gps_service.dart` (`ubisafe_app/lib/features/presence/services/gps_service.dart`) líneas 56-61 |
| **Justificación** | C-25 documentó que `distanceFilter: 10` suprime TODAS las actualizaciones GPS en dispositivos estáticos (no solo las subsecuentes). La corrección se aplicó solo al GPS del vendedor (`GPSService._subscribe`), pero no al proveedor de GPS del comprador (`gpsServiceProvider`). Si el comprador está estático, `_buyerLat/_buyerLng` en `VendorTracker` quedaba `null` y `_emit()` siempre retornaba `[]` |
| **Problema que resolvía** | En pruebas en interiores (dispositivos estáticos), el comprador no obtenía posición GPS → VendorTracker nunca filtraba correctamente → marcadores de vendedores no aparecían |

---

### CP-01 · Botón faltante en pantalla UbiSafe-Mapa ⚠️ EN DIAGNÓSTICO

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Por determinar — se requiere identificar qué botón específico no aparece y en qué condición |
| **Qué se corrigió (simple)** | Algún botón no aparece en la pantalla del mapa del comprador (`MapScreenBuyer`) aunque la pantalla sí carga |
| **Clase / Módulo** | Probable: `_SpeedDial`, `_VendorBottomSheet`, o FAB de zona de riesgo/reporte en `map_screen_buyer.dart` |
| **Justificación** | Por determinar |
| **Problema que resolvía** | El usuario reporta que cierto botón no aparece a pesar de estar en la pantalla correcta |

> **Nota:** Pendiente de clarificación — se necesita saber exactamente qué botón y en qué momento del flujo no aparece.

---

### CP-02 · Puerto Firestore — posible conflicto en dispositivo físico ⚠️ EN REVISIÓN

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | `FirebaseFirestore.instance.useFirestoreEmulator(host, 8088)` en `main.dart` y `"port": 8088` en `firebase.json` (cambio sin commitear; HEAD aún tiene 8080) |
| **Qué se corrigió (simple)** | Se está probando si cambiar el puerto del emulador de Firestore de 8080 a 8088 resuelve un posible bloqueo de puerto en el dispositivo físico |
| **Clase / Módulo** | `_connectToEmulators()` en `main.dart`; bloque `"firestore"` en `firebase.json` |
| **Justificación** | El puerto 8080 puede estar ocupado por otro proceso en la máquina de desarrollo; en dispositivo físico, el `adb reverse` mapea ese puerto, por lo que si está bloqueado el emulador es inaccesible |
| **Problema que resolvía** | Firestore del emulador inaccesible desde dispositivo físico vía `adb reverse tcp:8080` |

> **Nota:** Este cambio aún no está commiteado. Verificar que el comando `adb reverse tcp:8088 tcp:8088` se ejecutó, y que el emulador de Firebase inicia con el puerto 8088.

---

## Notas de contexto para diagnóstico

- **Dispositivo de prueba:** Físico Android (MIUI/Xiaomi recomendado para reproducibilidad), depuración inalámbrica ADB. **No se usa emulador de Android Studio.**
- **Emuladores Firebase activos:** Auth `:9099`, Firestore `:8080` (o `:8088` si CP-02 se aplica), RTDB `:9000`, Functions `:5001`.
- **ADB reverse necesario para dispositivo físico:** Antes de probar, ejecutar:
  ```
  adb reverse tcp:9099 tcp:9099
  adb reverse tcp:8080 tcp:8080   # (o 8088 si CP-02 se aplica)
  adb reverse tcp:9000 tcp:9000
  adb reverse tcp:8000 tcp:8000
  ```
- **Fuente de verdad para roles:** Firestore colección `users`, campo `role`. NO usar custom claims JWT para roles.
