# Registro de Correcciones — UBISAFE

**Proyecto:** Los Borbotones · TSP · ITESM  
**Rama activa:** `Rama-Miguel`  
**Dispositivo de prueba:** Físico Android (depuración inalámbrica ADB, NO emulador de computadora)  
**Última actualización:** 2026-05-16 (C-75)

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
| **Nota (C-70)** | C-70 agrega de vuelta `if (mounted) context.go('/splash')` pero como **fallback**, no como navegación concurrente. El Pigeon bug de `firebase_auth 4.16.0` impide que `authStateChanges()` emita y por tanto el redirect de GoRouter no dispara; el fallback lo suple. No compite porque navega al mismo destino (`/splash`) y solo actúa si el widget sigue montado |

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

### C-28 · Timer único de parada podía cancelar solicitud incorrecta (BUG-005)

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | `Timer? _timeoutTimer` reemplazado por `Map<String, Timer> _timers`; `_startTimer` ahora indexa el timer por `stopId`; `cancelTimer()` cancela todos los timers del mapa |
| **Qué se corrigió (simple)** | Si el comprador hacía dos solicitudes de parada seguidas, el segundo `createStopRequest` cancelaba el timer de la primera solicitud, dejando la primera sin expirar nunca; ahora cada solicitud tiene su propio timer |
| **Clase / Método / Módulo** | `StopRequestModule._startTimer / cancelTimer` → `stop_request_module.dart` (`ubisafe_app/lib/features/dispatching/services/stop_request_module.dart`) |
| **Justificación** | Un solo `Timer?` en la clase sólo puede apuntar a un callback pendiente; la segunda llamada a `_startTimer` hacía `_timeoutTimer?.cancel()` sobre el timer de la primera solicitud |
| **Problema que resolvía** | Primera solicitud de parada nunca expiraba si se enviaba una segunda antes de que la primera llegara a 60 s |

---

### C-29 · expireRide silenciaba todos los errores de red (BUG-006)

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | `catch (_) {}` reemplazado por `on DioException catch (e) { if (e.response?.statusCode == 409) return; rethrow; }` en `RideRequestModule.expireRide` |
| **Qué se corrigió (simple)** | Al expirar un raite, ahora sólo se ignoran los conflictos 409 (raite ya procesado en paralelo); cualquier otro error de red se propaga para que quien llame pueda manejarlo |
| **Clase / Método / Módulo** | `RideRequestModule.expireRide()` → `ride_request_module.dart` (`ubisafe_app/lib/features/dispatching/services/ride_request_module.dart`) |
| **Justificación** | `catch (_) {}` ocultaba errores de autenticación, timeout y fallas del servidor; el raite podía quedar en estado `pending` indefinidamente sin que ningún código lo supiera |
| **Problema que resolvía** | Raites expirados silenciosamente en error quedaban bloqueados en estado `pending`; el vendedor seguía viendo la solicitud activa |

---

### C-30 · _confirmCancel no notificaba error de red al usuario (BUG-007)

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Bloque `catch (_) {}` reemplazado por `catch (e) { showSnackBar(...); return; }` en `_TrackingScreenState._confirmCancel`; la pantalla ya no cierra si `expireStopRequest` lanza excepción |
| **Qué se corrigió (simple)** | Si la cancelación de una parada falla por error de red, ahora se muestra un aviso al usuario y la pantalla permanece abierta; antes la pantalla se cerraba igual, dejando la parada en estado `pending` en el servidor |
| **Clase / Método / Módulo** | `_TrackingScreenState._confirmCancel()` → `tracking_screen.dart` (`ubisafe_app/lib/features/dispatching/screens/tracking_screen.dart`) |
| **Justificación** | Cerrar la pantalla aunque la cancelación fallara dejaba al vendedor con una solicitud activa que el comprador creía cancelada; el comprador no podía reintentar porque ya no estaba en la pantalla |
| **Problema que resolvía** | Parada quedaba en `pending` indefinidamente cuando el cancel fallaba por red; el vendedor seguía siendo interrumpido por la solicitud |

---

### C-31 · Timer de parada podía disparar PATCH /expired sobre parada ya aceptada (BUG-017)

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | (1) `_startTimer` ahora atrapa `statusCode == 400` además de 409; (2) `TrackingScreen.initState` llama `cancelTimer()` via `addPostFrameCallback` cuando `stopRequestId != null` |
| **Qué se corrigió (simple)** | Si el vendedor acepta la parada justo antes de que el timer de 60 s dispare, el timer aún podía intentar expirar una parada ya aceptada causando un error 400 sin capturar; ahora ese caso es silenciado y la pantalla también cancela el timer como protección adicional |
| **Clase / Método / Módulo** | `StopRequestModule._startTimer` + `_TrackingScreenState.initState` → `stop_request_module.dart` y `tracking_screen.dart` |
| **Justificación** | `map_screen_buyer.dart` ya llama `cancelTimer()` al recibir el evento FCM de `accepted`, pero existe una ventana de carrera donde el timer dispara antes de que el FCM llegue; el catch de 400 y el cancel en `initState` cierran esa ventana |
| **Problema que resolvía** | Excepción no capturada en el callback del timer cuando la parada ya estaba en estado `accepted` al momento en que el timer intentaba expirarla |

---

### C-32 · FIREBASE_PROJECT_ID faltante en API causaba 401 en todos los endpoints

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se añadió `FIREBASE_PROJECT_ID=ubisafe-ca262` al archivo `ubisafe_api/.env` |
| **Qué se corrigió (simple)** | El API usaba `demo-ubisafe` como project ID por defecto; tras cambiar `.firebaserc` a `ubisafe-ca262`, el emulador Auth emitía tokens con `aud: ubisafe-ca262`, pero el Admin SDK seguía verificando contra `demo-ubisafe` → todos los endpoints respondían 401 |
| **Clase / Módulo** | `FirebaseAdminInit.initialize()` → `firebase_admin_init.py` línea 41; `ubisafe_api/.env` |
| **Justificación** | `os.environ.get("FIREBASE_PROJECT_ID", "demo-ubisafe")` tenía `demo-ubisafe` como valor por defecto hardcodeado; el fallback nunca fue actualizado cuando se alineó `.firebaserc` al proyecto real |
| **Problema que resolvía** | Login: `signInWithEmailAndPassword` exitoso pero `POST /auth/sync-profile` → 401; Splash: `GET /auth/me` → 401 → catch → signOut → /welcome. El usuario quedaba atrapado en el bucle login→welcome aunque las credenciales fueran correctas |

> **Acción requerida:** Reiniciar el API (`uvicorn main:app --reload`) después de cambiar `.env`.

---

### C-33 · firebase_url apuntaba al namespace incorrecto del emulador RTDB

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | `firebase_url` en `google-services.json` cambiado de `https://ubisafe-ca262-default-rtdb.firebaseio.com` a `https://ubisafe-ca262.firebaseio.com` |
| **Qué se corrigió (simple)** | El SDK de Firebase extrae el namespace RTDB del `firebase_url`; la URL anterior producía namespace `ubisafe-ca262-default-rtdb`, pero el emulador Firebase usa el project ID como namespace por defecto (`ubisafe-ca262`). Todas las escrituras del vendedor iban al namespace incorrecto y el emulador las ignoraba silenciosamente |
| **Clase / Módulo** | `google-services.json` → `project_info.firebase_url`; `FirebaseDatabase.instance` en `gps_service.dart` y `vendor_tracker.dart` |
| **Justificación** | El Firebase RTDB Emulator, al iniciarse con `--project ubisafe-ca262`, crea la instancia bajo el namespace `ubisafe-ca262` (project ID), NO `ubisafe-ca262-default-rtdb`. La URL de producción estándar usa el sufijo `-default-rtdb`, pero en el emulador el namespace es el project ID directo. Confirmado en Emulator UI: `http://127.0.0.1:9000/?ns=ubisafe-ca262` |
| **Problema que resolvía** | `GPSService._subscribe` → `RTDB.ref(...).set({...})` no era `await`ed, el error se descartaba silenciosamente; Emulator UI siempre mostraba `null`; vendedor nunca aparecía en el mapa del comprador |

> **Acción requerida:** Hacer `flutter run` completo (NO hot-reload) — `google-services.json` se compila al APK en build time.

---

### C-34 · RTDB set() sin callback de error ocultaba fallos de escritura

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se añadió `.then((_) { debugPrint OK }, onError: (e) { debugPrint FAILED })` al `_rtdbRefFactory(vendorUid).set({...})` en `GPSService._subscribe` |
| **Qué se corrigió (simple)** | La escritura RTDB retorna un Future que no estaba siendo observado; si fallaba (namespace incorrecto, auth inválida, ADB reverse expirado), el error desaparecía sin dejar rastro en los logs. Ahora el error aparece en los logs de Flutter |
| **Clase / Módulo** | `GPSService._subscribe` → `gps_service.dart` líneas 153-163 |
| **Justificación** | En Dart, Futures no observados descartan sus errores silenciosamente. Para una operación crítica como la escritura RTDB que es el núcleo de la funcionalidad F3, el error debe ser visible en debug mode |
| **Problema que resolvía** | Imposibilidad de diagnosticar por qué las escrituras RTDB fallaban; el vendedor activaba el radar y no ocurría nada visible en logs ni en la base de datos |

---

### C-35 · StopRequestModule._startTimer silenciaba errores no-409/400

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-35 · StopRequestModule rethrow en timer |
| **Qué se corrigió (técnico)** | Se añadió `rethrow` al final del bloque `on DioException catch (e)` en `_startTimer`, después de la guardia `if (statusCode == 409 || statusCode == 400) return` |
| **Qué se corrigió (simple)** | Errores de red distintos de 409/400 (p. ej. timeout, 500) ya no se silencian: ahora se propagan para que el caller los pueda observar |
| **Clase / Método / Módulo** | `StopRequestModule._startTimer()` → `stop_request_module.dart` (`ubisafe_app/lib/features/dispatching/services/stop_request_module.dart`) |
| **Justificación** | C-29 aplicó este mismo patrón a `RideRequestModule.expireRide()` pero no se replicó en `_startTimer`; sin `rethrow`, un error 500 o de red terminaba el bloque catch sin relanzar la excepción, ocultando el fallo |
| **Problema que resolvía** | Solicitudes de parada podían quedar en estado `pending` indefinidamente cuando el servidor devolvía 5xx o había error de conectividad; el timer las descartaba silenciosamente |

---

### C-36 · RideRequestModule.startExpiryTimer — onExpired nunca se llamaba si expireRide lanzaba

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-36 · RideRequestModule callback onExpired garantizado |
| **Qué se corrigió (técnico)** | El callback del `Timer` ahora envuelve `expireRide` en `try/on DioException catch`; `onExpired()` se llama **después del try-catch**, asegurando que siempre se ejecuta independientemente del resultado de red |
| **Qué se corrigió (simple)** | Si la petición de expiración de un raite falla por error de red (no-409), el comprador ahora recibe la notificación de tiempo agotado igualmente, en lugar de quedarse en pantalla esperando indefinidamente |
| **Clase / Método / Módulo** | `RideRequestModule.startExpiryTimer()` → `ride_request_module.dart` (`ubisafe_app/lib/features/dispatching/services/ride_request_module.dart`) |
| **Justificación** | `Timer` no awaita su callback; una excepción en `expireRide` se convertía en un Future error perdido y `onExpired()` nunca se ejecutaba. El UI del comprador quedaba bloqueado en estado `pending` pasados los 60 s |
| **Problema que resolvía** | Pantalla del comprador bloqueada en solicitud de raite activa cuando la expiración fallaba por error de red |

---

### C-37 · RideRequestModule — timer único reemplazado por Map de timers

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-37 · RideRequestModule Map de timers por rideId |
| **Qué se corrigió (técnico)** | `Timer? _expiryTimer` reemplazado por `Map<String, Timer> _expiryTimers`; `startExpiryTimer` indexa por `rideId`; `cancelExpiryTimer` cancela e itera el mapa |
| **Qué se corrigió (simple)** | Si se inicia un segundo timer para un raite diferente, ya no cancela el timer del raite anterior; cada raite tiene su propio timer |
| **Clase / Método / Módulo** | `RideRequestModule.startExpiryTimer / cancelExpiryTimer` → `ride_request_module.dart` |
| **Justificación** | Mismo patrón que motivó C-28 en `StopRequestModule`; la asimetría representaba una trampa si en el futuro se permiten raites concurrentes o retries rápidos |
| **Problema que resolvía** | En retry rápido, el segundo `startExpiryTimer` cancelaba el timer del primer raite, dejándolo sin expirar |

---

### C-38 · TrackingScreen — context.mounted faltante antes de Snackbar/Navigator en ref.listen

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-38 · TrackingScreen context.mounted guard |
| **Qué se corrigió (técnico)** | Se añadió `if (!context.mounted) return;` en el callback de `ref.listen<StopEvent?>`, inmediatamente antes de `ScaffoldMessenger.of(context)` y `Navigator.of(context).pop()` |
| **Qué se corrigió (simple)** | Si el widget se desmonta justo cuando llega el evento de "solicitud completada", ya no intenta mostrar un snackbar ni navegar usando un contexto inválido |
| **Clase / Método / Módulo** | `_TrackingScreenState.build()` → `tracking_screen.dart` (`ubisafe_app/lib/features/dispatching/screens/tracking_screen.dart`) |
| **Justificación** | Riverpod dispone el listener al desmontarse el widget, pero existe una ventana mínima donde el callback puede disparar con el contexto ya marcado como unmounted; `context.mounted` cierra esa ventana |
| **Problema que resolvía** | Crash raro: `ScaffoldMessenger.of(context)` / `Navigator.of(context)` con contexto unmounted si el evento FCM llegaba en el instante exacto del desmontaje |

---

### C-39 · GPSService — onDisconnect().remove() sin manejo de error

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-39 · GPSService onDisconnect catchError |
| **Qué se corrigió (técnico)** | Se añadió `.catchError((Object e) { if (kDebugMode) debugPrint(...) })` a `_rtdbRefFactory(vendorUid).onDisconnect().remove()` en `_subscribe` |
| **Qué se corrigió (simple)** | Si el registro del handler de desconexión falla (sin conexión, permiso denegado), el error ahora aparece en los logs de debug en lugar de perderse silenciosamente |
| **Clase / Método / Módulo** | `GPSService._subscribe()` → `gps_service.dart` (`ubisafe_app/lib/features/presence/services/gps_service.dart`) |
| **Justificación** | Mismo principio que C-34 aplicó al `.set()`; los Futures no observados descartan sus errores en Dart; el registro del disconnect handler es crítico para la limpieza del nodo RTDB |
| **Problema que resolvía** | Imposibilidad de diagnosticar fallos en el registro del handler de desconexión; nodos RTDB podían quedar huérfanos si el handler nunca se registró |

---

### C-40 · VendorTracker.fromStream — stream inyectado no convertido a broadcast

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-40 · VendorTracker.fromStream asBroadcastStream |
| **Qué se corrigió (técnico)** | En el constructor `VendorTracker.fromStream`, el stream inyectado ahora se convierte con `rawStream.isBroadcast ? rawStream : rawStream.asBroadcastStream()` antes de pasarse a `_init` |
| **Qué se corrigió (simple)** | Los tests que inyectan un stream single-subscription ya no lanzan `StateError: Stream already listened to` cuando el provider o el test intentan suscribirse más de una vez |
| **Clase / Método / Módulo** | `VendorTracker.fromStream()` → `vendor_tracker.dart` (`ubisafe_app/lib/features/presence/services/vendor_tracker.dart`) |
| **Justificación** | C-24 añadió `.asBroadcastStream()` al constructor de producción pero no al constructor de pruebas; la asimetría causaba `StateError` al reutilizar el stream en tests |
| **Problema que resolvía** | Tests de `VendorTracker` podían fallar con `StateError` al suscribirse dos veces al stream inyectado |

---

### C-41 · login() — sync-profile es best-effort y no debe tumbar la sesión

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se envolvió `await _dio.post('/auth/sync-profile', ...)` en un bloque `try { } catch (_) {}` dentro de `AuthModule.login()` |
| **Qué se corrigió (simple)** | Si el backend (Render) está en cold start y la llamada de sincronización del perfil falla, el login ya no lanza excepción; el usuario queda autenticado en Firebase Auth y puede continuar |
| **Clase / Método / Módulo** | `AuthModule.login()` → `auth_module.dart` (`ubisafe_app/lib/features/identity/auth/auth_module.dart`) |
| **Justificación** | `sync-profile` en login sólo actualiza `updated_at`; es puramente best-effort. Si Render tiene un cold start de ~30-60 s, esta llamada falla pero `signInWithEmailAndPassword` ya completó exitosamente. Lanzar excepción aquí invalida una sesión Firebase completamente válida |
| **Problema que resolvía** | Al hacer login con Render en cold start, `POST /auth/sync-profile` lanzaba una excepción que propagaba a `_submit()`, mostrando snackbar de error aunque Firebase Auth había autenticado al usuario correctamente |

---

### C-42 · _checkSession() no debe hacer signOut en errores de red — solo en 404

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se reemplazó `ref.read(userProfileProvider.future).timeout(5s)` por una llamada directa a `dio.get('/auth/me')` con `Options(extra: {'_retryCount': 2})`; `signOut()` ahora solo se ejecuta cuando `e.response?.statusCode == 404`; para cualquier otro `DioException` (red, 5xx, timeout) se navega a `/welcome` sin cerrar sesión |
| **Qué se corrigió (simple)** | Si Render no responde a tiempo en el Splash, el usuario ya no es deslogueado; la sesión de Firebase Auth se conserva. Al tocar "Iniciar sesión" de nuevo, el router lo lleva directo a Splash sin pedirle credenciales, y cuando Render ya está despierto la sesión se restaura |
| **Clase / Método / Módulo** | `_SplashScreenState._checkSession()` → `splash_screen.dart` (`ubisafe_app/lib/features/identity/auth/screens/splash_screen.dart`) |
| **Justificación** | `userProfileProvider` devuelve `null` para CUALQUIER `DioException` (incluyendo errores de red y timeouts de Render cold start). `_checkSession()` interpretaba ese `null` como "no hay perfil → signOut → /welcome". El ciclo se repetía 4-5 veces hasta que Render despertaba (~30-60 s). Ahora solo se cierra sesión ante un 404 confirmado (registro parcial sin perfil en Firestore). El `_retryCount: 2` limita al `_RetryInterceptor` a un solo reintento adicional, evitando bloquear el Splash hasta 40 s |
| **Problema que resolvía** | Al iniciar sesión, la app regresaba al usuario a la pantalla de login/bienvenida entre 4 y 5 veces antes de funcionar, obligándolo a reingresar sus credenciales en cada intento |

---

### C-43 · POST a rutas raíz — 307 redirect por trailing slash en FastAPI

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se cambió `@router.post("/")` y `@router.get("/")` a `@router.post("")` y `@router.get("")` en `dispatching/router.py`, `safety/router.py` y `community/report_router.py` |
| **Qué se corrigió (simple)** | Al hacer `POST /stops`, `/risk-zones` o `/community-reports`, FastAPI ya no redirige con 307 a la versión con slash (`/stops/`, etc.); los endpoints responden directamente en la ruta sin trailing slash |
| **Clase / Módulo** | `dispatching/router.py` · `safety/router.py` · `community/report_router.py` (todos en `ubisafe_api/modules/`) |
| **Justificación** | FastAPI con `redirect_slashes=True` (default) redirige `POST /stops` → `POST /stops/` con 307. Dio no sigue automáticamente redirects de POST/PATCH/DELETE, por lo que lanza `DioException [bad response] 307`. `ride_router.py` ya usaba el patrón correcto `@router.post("")` sin trailing slash; se unificó el resto de routers con ese mismo patrón |
| **Problema que resolvía** | `Error al solicitar parada: DioException [bad response]: status code of 307` — ninguna solicitud de parada, zona de riesgo ni reporte comunitario llegaba al backend |

---

### C-44 · Pantalla del comprador se congela tras rechazo o expiración de parada

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | (1) `StopRequestModule._startTimer` refactorizado a `startTimer(stopId, {required onExpired})` con callback que se llama siempre al finalizar, incluso si el PATCH falla. (2) `map_screen_buyer.dart._requestStop` llama explícitamente a `startTimer` con `onExpired` que resetea `_mapState` y muestra snackbar. (3) Backend: `notification_service.py` añade `send_stop_expired`; `dispatching/router.py` dispara FCM al comprador cuando `status = expired`. (4) `notification_handler.dart` añade `case 'stop_request_expired'` que emite `StopEvent(..., StopRequestStatus.expired)` a `stopRequestEventProvider` |
| **Qué se corrigió (simple)** | La pantalla de espera del comprador ahora se cierra automáticamente en dos escenarios: (a) cuando el timer de 60 s vence localmente sin respuesta del vendedor; (b) cuando el backend marca la parada como expirada o rechazada y envía la notificación FCM |
| **Clase / Módulo** | `StopRequestModule.startTimer` · `_MapScreenBuyerState._requestStop` · `NotificationHandler._dispatchData` · `notification_service.py:send_stop_expired` · `dispatching/router.py:update_stop_status` |
| **Justificación** | `_startTimer` privado solo hacía PATCH sin callback de UI; el backend nunca enviaba FCM para `expired`; `notification_handler.dart` no tenía el case `stop_request_expired`. Sin el callback, la `_WaitingOverlay` permanecía visible indefinidamente tras el timeout de 60 s o el rechazo del vendedor |
| **Problema que resolvía** | Comprador veía el spinner de "Esperando respuesta..." para siempre después de que el vendedor rechazaba o pasaban 60 s sin respuesta |

---

### C-45 · 500 al aceptar/rechazar/expirar parada — `SERVER_TIMESTAMP` no serializable como `str`

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Se añadió `FirestoreService._doc_to_stop_request(doc)` que convierte todos los campos de timestamp (`created_at`, `updated_at`, `expires_at`) a `str` vía `.isoformat()` antes de construir el objeto `StopRequest`. Se reemplazaron todos los `StopRequest(id=doc.id, **doc.to_dict())` del módulo de stops por llamadas a este helper |
| **Qué se corrigió (simple)** | Al aceptar/rechazar/expirar una parada, el backend guardaba la fecha de actualización como un objeto `DatetimeWithNanoseconds` de Firestore y al leerla de vuelta, Pydantic v2 no podía convertirla a `str` → error 500. Ahora siempre se convierte a string ISO antes de pasarla al schema |
| **Clase / Módulo** | `FirestoreService._doc_to_stop_request` · `list_stop_requests` · `create_stop_request` · `get_stop_request` · `update_stop_status` · `update_stop_status_if_pending` → `firestore_service.py` (`ubisafe_api/modules/shared/firestore_service.py`) |
| **Justificación** | `SERVER_TIMESTAMP` es un centinela que Firestore reemplaza por su timestamp de servidor. Al leer el documento inmediatamente después, el SDK de Python devuelve un `DatetimeWithNanoseconds` (subclase de `datetime`). Pydantic v2 no coerciona `datetime → str` en modo lax, a diferencia de Pydantic v1. El patrón correcto ya existía en `_doc_to_ride` y `_doc_to_community_report` pero no se había aplicado a stops |
| **Problema que resolvía** | `DioException [bad response]: status code of 500` al intentar aceptar una solicitud de parada (el vendedor hacía PATCH y el servidor crasheaba al serializar la respuesta) |

### C-46 · Limpieza de warnings e infos de flutter analyze

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | (1) Eliminados imports huérfanos de `auth_providers.dart` en `map_screen_vendor.dart` y `app_router.dart`; (2) añadidas llaves `{}` a for-each sin bloque en `ride_request_module.dart` y `stop_request_module.dart`; (3) Futures fire-and-forget en `gps_service.dart` envueltos con `unawaited()` (`stopTransmission` y `_subscribe`) |
| **Qué se corrigió (simple)** | Se limpiaron los avisos que dejaron como residuo las correcciones C-01, C-17, C-18, C-19, C-28, C-34, C-37 y C-39; el CI de Flutter vuelve a pasar |
| **Clase / Método / Módulo** | `map_screen_vendor.dart`, `app_router.dart`, `ride_request_module.dart:cancelExpiryTimer`, `stop_request_module.dart:cancelTimer`, `gps_service.dart:stopTransmission + _subscribe` |
| **Justificación** | `flutter analyze` sale con código 1 ante cualquier `warning`; los `info` de `curly_braces_in_flow_control_structures` y `unawaited_futures` también aportan al conteo; `unawaited()` comunica explícitamente la intención fire-and-forget sin cambiar el comportamiento |
| **Problema que resolvía** | CI bloqueado: job "Flutter — analyze & test" fallaba con 6 issues en cada push |

---

### C-47 · Tests FastAPI con trailing slash causaban HTTP 307

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Eliminado trailing slash de las URLs en `test_stops.py` (3 llamadas), `test_risk_zones.py` (6 llamadas) y `test_community_reports.py` (7 llamadas): `/stops/` → `/stops`, `/risk-zones/` → `/risk-zones`, `/community-reports/` → `/community-reports` |
| **Qué se corrigió (simple)** | Los tests usaban URLs con `/` al final; Starlette registra las rutas raíz sin ese `/` y con `redirect_slashes=True` (default) redirige con 307; `httpx.AsyncClient` no sigue redirecciones por defecto, así los tests recibían 307 en lugar del código esperado |
| **Clase / Módulo** | `ubisafe_api/tests/test_stops.py`, `test_risk_zones.py`, `test_community_reports.py` — solo URLs de llamadas al cliente de prueba |
| **Justificación** | Corrección mínima que no toca routers ni lógica de producción; los routers ya tenían sus rutas correctamente definidas con `@router.post("/")`, Starlette las registra como `/prefix` (sin trailing slash) |
| **Problema que resolvía** | CI bloqueado: 16 tests fallaban con `assert 307 == <expected>` en el job FastAPI |

---

### C-48 · Revertir C-47: rutas registradas con trailing slash requieren URLs con trailing slash en tests async

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | Revertido el cambio de C-47: devuelto trailing slash a las URLs raíz en `test_stops.py` (3 llamadas), `test_risk_zones.py` (6 llamadas) y `test_community_reports.py` (7 llamadas): `/stops` → `/stops/`, `/risk-zones` → `/risk-zones/`, `/community-reports` → `/community-reports/` |
| **Qué se corrigió (simple)** | C-47 tenía el diagnóstico invertido. Las rutas raíz están registradas CON trailing slash (`/stops/`, `/risk-zones/`, `/community-reports/`) porque `prefix="/stops"` + `@router.post("/")` → Starlette registra `/stops/`. Los tests nuevos usan `AsyncClient` que no sigue redirects, por lo que `/stops` (sin slash) recibía un 307 hacia `/stops/` en lugar de la respuesta esperada. `test_api.py` usa `TestClient` (síncrono) que sí sigue redirects, por eso esos tests pasaban con cualquiera de las dos formas. |
| **Clase / Módulo** | `ubisafe_api/tests/test_stops.py`, `test_risk_zones.py`, `test_community_reports.py` — solo URLs de llamadas al cliente de prueba |
| **Justificación** | Verificado inspeccionando las rutas registradas en el app: `GET /stops/`, `POST /stops/`, `GET /risk-zones/`, `POST /risk-zones/`, `POST /community-reports/`, `GET /community-reports/` (todas con slash). `AsyncClient` necesita la URL exacta registrada. |
| **Problema que resolvía** | 16 tests seguían fallando con `assert 307 == <expected>` después de C-47 porque la corrección era en la dirección equivocada. |


### C-49 · _WaitingOverlay de parada no cancelaba el timer local al cancelar manualmente `2026-05-15 11:33`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-49 · cancelTimer() en onCancel del overlay de parada |
| **Qué se corrigió (técnico)** | Se añadió `ref.read(stopRequestModuleProvider).cancelTimer()` al inicio del callback `onCancel` del `_WaitingOverlay` de parada (estado `_BuyerMapState.waiting`) en `map_screen_buyer.dart`, antes de `setState` |
| **Qué se corrigió (simple)** | Cuando el comprador tocaba "Cancelar" en la pantalla de espera de parada, el timer de 60 s seguía corriendo. Al disparar, siempre llamaba `onExpired()` aunque la parada ya estaba cancelada, mostrando "Tiempo de espera agotado" de forma fantasma |
| **Clase / Método / Módulo** | `_MapScreenBuyerState.build()` → `_WaitingOverlay.onCancel` → `map_screen_buyer.dart` (`ubisafe_app/lib/features/dispatching/screens/map_screen_buyer.dart`) |
| **Justificación** | `StopRequestModule.startTimer` siempre llama `onExpired()` al finalizar, independientemente de si la petición PATCH devuelve 409. El overlay de raite (`_BuyerMapState.waitingRide`) ya cancelaba el timer correctamente con `cancelExpiryTimer()` — se aplicó el mismo patrón a la parada |
| **Problema que resolvía** | El comprador veía "Tiempo de espera agotado" segundos después de haber cancelado manualmente la parada, lo cual era confuso e incorrecto |

---

### C-50 · ref.listen sin context.mounted en MapScreenBuyer y MapScreenVendor `2026-05-15 11:33`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-50 · context.mounted en ref.listen de pantallas del mapa |
| **Qué se corrigió (técnico)** | Se añadió `if (!context.mounted) return;` inmediatamente antes de cada llamada a `ScaffoldMessenger.of(context)`, `context.push()` y `showDialog`/`_showIncomingDialog`/`_showIncomingRideDialog`/`_showRideTooFarDialog` en los callbacks de `ref.listen` de `MapScreenBuyer` y `MapScreenVendor`. En `MapScreenBuyer`: listeners de `stopRequestEventProvider` (3 ramas: accepted, rejected, expired) y `rideEventProvider` (4 ramas: rejected/expired, vendorArrived, completed). En `MapScreenVendor`: listeners de `incomingStopRequestProvider`, `incomingRideProvider` (2 ramas) y `rideEventProvider` (cancelledByBuyer). Adicionalmente en `accepted` de `stopRequestEventProvider` se movió `ref.read(...).state = null` antes del guard para limpiar el provider antes de salir. |
| **Qué se corrigió (simple)** | Si el usuario navegaba fuera de la pantalla del mapa en el instante exacto en que llegaba una notificación FCM, el callback del listener intentaba usar un contexto ya desmontado, produciendo un crash. Ahora todos los accesos al contexto verifican primero que el widget siga montado |
| **Clase / Método / Módulo** | `_MapScreenBuyerState.build()` → `ref.listen` (stopRequestEventProvider + rideEventProvider) · `_MapScreenVendorState.build()` → `ref.listen` (incomingStopRequestProvider + incomingRideProvider + rideEventProvider) |
| **Justificación** | C-38 documentó y aplicó este mismo patrón en `TrackingScreen`. Las dos pantallas del mapa tenían el mismo problema pero no habían sido corregidas. Riverpod dispone los listeners al desmontarse el widget, pero existe una ventana de carrera mínima donde el callback puede disparar con el contexto ya marcado como unmounted |
| **Problema que resolvía** | Crash raro del tipo `ScaffoldMessenger.of(context)` con contexto unmounted, reproducible cuando un evento FCM llegaba mientras el usuario navegaba hacia otra pantalla |

---

### C-51 · Guard innecesario de userProfileProvider en _requestStop bloqueaba paradas silenciosamente `2026-05-15 12:10`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-51 · Eliminar guard userProfileProvider en _requestStop |
| **Qué se corrigió (técnico)** | Se eliminaron las líneas `final profile = ref.read(userProfileProvider).valueOrNull;` e `if (profile == null) return;` al inicio de `_requestStop` en `map_screen_buyer.dart`. También se eliminó el import huérfano de `auth_providers.dart` que quedó sin usar |
| **Qué se corrigió (simple)** | Si el provider del perfil estaba re-evaluando (ej. justo después del login, cuando authStateProvider emite un nuevo valor), `valueOrNull` devolvía null y la solicitud de parada era descartada silenciosamente sin ningún feedback al usuario |
| **Clase / Método / Módulo** | `_MapScreenBuyerState._requestStop()` → `map_screen_buyer.dart` |
| **Justificación** | El backend infiere el `uid` del comprador a partir del JWT en el header — nunca necesita los datos del perfil local. La guardia era residual y no cumplía ninguna función defensiva real. El mismo patrón fue corregido en C-18 para el toggle de visibilidad del vendedor |
| **Problema que resolvía** | El comprador tocaba un vendedor para pedir una parada y nada ocurría — sin error, sin cambio de estado, sin snackbar — si el profileProvider estaba en estado loading durante una re-evaluación |

---

### C-52 · VendorTracker._emit() emitía todos los vendedores sin filtrar cuando GPS es null `2026-05-15 12:10`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-52 · VendorTracker emite [] cuando buyerLat/Lng son null |
| **Qué se corrigió (técnico)** | En `vendor_tracker.dart`, la rama `if (lat == null \|\| lng == null)` de `_emit()` cambia de `_controller.add(List.unmodifiable(_vendors.values))` a `_controller.add(const [])`. El test unitario `vendor_tracker_test.dart` se actualizó: el caso `'emits all vendors when buyer position is unknown'` pasó a llamarse `'emits empty list when buyer position is unknown'` con `expect(result, isEmpty)` |
| **Qué se corrigió (simple)** | Mientras el GPS no entregaba la primera posición, el mapa del comprador mostraba todos los vendedores activos de la ciudad sin filtrar por distancia. Ahora muestra ninguno hasta que la posición esté disponible |
| **Clase / Método / Módulo** | `VendorTracker._emit()` → `vendor_tracker.dart` (`ubisafe_app/lib/features/presence/services/vendor_tracker.dart`) |
| **Justificación** | C-06 documentó que la corrección correcta era emitir `[]` en este caso. C-20 mitigó el síntoma sembrando la posición GPS inicial, pero la ventana de carrera persistía. Esta corrección cierra el bug definitivamente |
| **Problema que resolvía** | Durante los primeros instantes del arranque de la app, antes de que el GPS devolviera la primera posición, el comprador podía ver marcadores de vendedores a cualquier distancia de la ciudad sin restricción de radio |

---

### C-53 · Cancelar parada devolvía 400 — faltaba la transición `cancelled` en VALID_TRANSITIONS `2026-05-15 12:10`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-53 · Cancelación de parada por comprador — estado `cancelled` |
| **Qué se corrigió (técnico)** | **Backend:** Se añadieron `("pending", "cancelled"): "BUYER"` y `("accepted", "cancelled"): "BUYER"` a `VALID_TRANSITIONS` en `schemas.py`. Se añadió `send_stop_cancelled(vendor_uid, stop_id)` en `notification_service.py` y se disparó en `router.py` cuando `body.status == "cancelled"`. **Flutter:** Se añadió `cancelled` al enum `StopRequestStatus` en `models/stop_request.dart`. Se añadió `cancelStopRequest()` en `stop_request_module.dart`. `map_screen_buyer.dart` (`_WaitingOverlay.onCancel`) y `tracking_screen.dart` (`_confirmCancel`) cambiaron de `expireStopRequest` a `cancelStopRequest`. Se añadió el case `stop_request_cancelled` en `notification_handler.dart`. Se añadió listener de `stopRequestEventProvider` en `map_screen_vendor.dart` para mostrar snackbar "El comprador canceló la parada." |
| **Qué se corrigió (simple)** | Cuando el comprador tocaba "Cancelar solicitud" (desde el overlay de espera antes de que el vendedor acepte, o desde la pantalla de seguimiento después de aceptar), el backend devolvía 400 porque la transición `expired` no era válida para el estado `accepted`. Ahora se usa el estado semántico correcto `cancelled` |
| **Clase / Método / Módulo** | `TrackingScreen._confirmCancel()`, `_WaitingOverlay.onCancel`, `StopRequestModule`, `VALID_TRANSITIONS`, `NotificationService`, `NotificationHandler` |
| **Justificación** | El módulo de raites ya tenía `cancelled_by_buyer` como estado explícito. El módulo de paradas solo tenía `expired` (para timeout del timer), que el backend rechaza correctamente en estado `accepted` porque no es una transición válida |
| **Problema que resolvía** | El comprador veía "Error al cancelar: DioException [bad response] status 400" al intentar cancelar la parada en cualquier momento del flujo |

---

### C-54 · Diálogo y sheet del vendedor no se cerraban al cancelar el comprador `2026-05-15 12:10`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-54 · Limpieza de UI y estado del vendedor al cancelar parada |
| **Qué se corrigió (técnico)** | Se añadió el campo `_pendingDialogStopId` a `_MapScreenVendorState`. `_showIncomingDialog` lo asigna al abrir el diálogo y los callbacks `onAccept`/`onReject` lo limpian antes de cerrar. El listener de `stopRequestEventProvider` fue expandido: si `_pendingDialogStopId == event.stopId` llama `Navigator.of(context).pop()` para cerrar el diálogo; si `_activeStopId == event.stopId` resetea `_activeStopId`, `_isNavigating` y `_routePolyline` para ocultar el `_ConfirmDeliverySheet` |
| **Qué se corrigió (simple)** | Cuando el comprador cancelaba la parada: (1) el diálogo de "aceptar/rechazar" en el mapa del vendedor seguía abierto — el vendedor podía tocar "Aceptar" o "Rechazar" en una parada ya cancelada causando errores 400; (2) si la parada ya había sido aceptada, el botón de "Confirmar Entrega" seguía visible — el vendedor podía confirmar una entrega de una parada ya cancelada |
| **Clase / Método / Módulo** | `_MapScreenVendorState` → `map_screen_vendor.dart` |
| **Justificación** | El patrón de `_activeRideId`/`_ridePhase` ya existía para raites (limpieza al cancelar). Se replicó la misma estrategia para paradas con `_pendingDialogStopId` y `_activeStopId` |
| **Problema que resolvía** | Vendor quedaba con UI obsoleta que podía generar errores 400 adicionales al interactuar con una parada que el comprador ya había cancelado |

---

### C-55 · Diálogo del vendedor no se cerraba al expirar el timer de 60 s `2026-05-15 12:10`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-55 · Notificación de expiración al vendedor + cierre de diálogo |
| **Qué se corrigió (técnico)** | **Backend:** Se añadió `send_stop_expired_vendor(vendor_uid, stop_id)` en `notification_service.py` (FCM type `stop_request_expired`, mensaje "La solicitud de parada expiró"). En `router.py`, el branch de `expired` llama a este nuevo método si `updated_doc.vendor_uid` está presente. **Flutter:** El listener de `stopRequestEventProvider` en `map_screen_vendor.dart` fue refactorizado para manejar tanto `cancelled` como `expired` con la misma lógica: cierra el diálogo si `_pendingDialogStopId == event.stopId`, limpia `_activeStopId`/`_isNavigating`/`_routePolyline` si corresponde, y muestra snackbar con mensaje diferenciado según el evento |
| **Qué se corrigió (simple)** | Al expirar el timer de 60 s, el comprador recibía la notificación y regresaba a estado idle correctamente, pero el vendedor seguía con el diálogo de "Aceptar / Rechazar" abierto indefinidamente. El vendedor podía tocar "Aceptar" en una parada ya expirada, generando un error 400 |
| **Clase / Método / Módulo** | `router.py` (expired branch) · `NotificationService.send_stop_expired_vendor` · `_MapScreenVendorState` listener de `stopRequestEventProvider` |
| **Justificación** | `send_stop_expired` solo notificaba al comprador. El vendedor nunca recibía señal de que la parada había expirado, dejando su UI en estado inconsistente. Se aplicó el mismo patrón que C-54 (cancelled) para el caso expired |
| **Problema que resolvía** | Diálogo zombie en el mapa del vendedor tras expirar el timer, con riesgo de 400 al intentar aceptar/rechazar una parada ya cerrada |

---

### C-56 · Ruta en mapa del vendedor no se trazaba — API key de Maps no disponible en release `2026-05-15 13:45`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-56 · MethodChannel para leer Maps API Key en runtime |
| **Qué se corrigió (técnico)** | Se eliminó `const _kMapsApiKey = String.fromEnvironment('MAPS_API_KEY')` del top-level de `map_screen_vendor.dart`. Se añadió el campo de estado `String _mapsApiKey = ''`, `initState()` con llamada a `_initMapsKey()`, y el método `_initMapsKey()` que lee `com.google.android.geo.API_KEY` desde el `ApplicationInfo.metaData` del `AndroidManifest.xml` vía `MethodChannel('ubisafe/config').invokeMethod('getMapsApiKey')`. `_fetchRoute()` pasó a usar `_mapsApiKey` en lugar de la constante. `MainActivity.kt` fue reescrito para exponer ese MethodChannel: recibe la llamada `getMapsApiKey` y retorna el valor de la meta-data del manifiesto |
| **Qué se corrigió (simple)** | La ruta del vendedor hacia el comprador nunca se trazaba: `_fetchRoute()` usaba `String.fromEnvironment('MAPS_API_KEY')` que solo se inyecta con `--dart-define=MAPS_API_KEY=...` en tiempo de compilación, pero el comando de build estándar del proyecto solo define `API_BASE_URL`. La key ya existía correctamente en el `AndroidManifest.xml` (vía `manifestPlaceholders` de `local.properties`), pero no era accesible en Dart. Ahora se lee en runtime sin necesidad de cambiar el comando de build |
| **Clase / Método / Módulo** | `_MapScreenVendorState.initState()` + `_initMapsKey()` + `_fetchRoute()` → `map_screen_vendor.dart` · `MainActivity.configureFlutterEngine()` → `MainActivity.kt` (`android/app/src/main/kotlin/com/borbotones/ubisafe/`) |
| **Justificación** | `String.fromEnvironment` es una constante de compilación; sin `--dart-define=MAPS_API_KEY=...` su valor es siempre `''`. La Directions API con clave vacía devuelve `REQUEST_DENIED` y `_fetchRoute()` salta silenciosamente, dejando `_routePolyline` vacío. El canal nativo lee directamente desde los meta-data que Android ya tiene disponibles en el apk |
| **Problema que resolvía** | La polilínea de ruta del vendedor al comprador nunca aparecía en el mapa, aunque la lógica de `_fetchRoute()` y `_decodePolyline()` era correcta |

---

### C-57 · Vendedor podía confirmar entrega sin estar cerca del comprador `2026-05-15 14:20`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-57 · Verificación de proximidad (15 m) al confirmar entrega |
| **Qué se corrigió (técnico)** | Se añadieron los campos de estado `double? _buyerLat` y `double? _buyerLng` a `_MapScreenVendorState`. `_acceptStop` los rellena con `destLat`/`destLng` en el último `setState`. `_confirmDelivery` ahora: (1) verifica que el GPS esté disponible; (2) calcula la distancia Haversine entre la posición actual del vendedor y `_buyerLat`/`_buyerLng`; (3) si la distancia es > 15 m muestra un `SnackBar` con la distancia actual y retorna sin llamar `completeStopRequest`. Los campos se limpian (`null`) tanto en el path de éxito de `_confirmDelivery` como en el listener de eventos `cancelled`/`expired`. Se añadió la función pura `_distanceMeters(lat1, lng1, lat2, lng2)` usando la fórmula Haversine con `dart:math` (ya importado) |
| **Qué se corrigió (simple)** | El botón "Confirmar Entrega" podía ser pulsado desde cualquier lugar. Ahora solo funciona si el vendedor está a 15 metros o menos del comprador; de lo contrario se muestra "Debes estar a menos de 15 m del comprador. Distancia actual: X m." |
| **Clase / Método / Módulo** | `_MapScreenVendorState._confirmDelivery()` + `_acceptStop()` → `map_screen_vendor.dart` (`ubisafe_app/lib/features/dispatching/screens/map_screen_vendor.dart`) |
| **Justificación** | Sin la verificación, el vendedor podía marcar la entrega como completada sin haberse desplazado hasta el comprador, completando la transacción de forma fraudulenta o accidental |
| **Problema que resolvía** | El vendedor podía confirmar la entrega estando a cualquier distancia del comprador que la solicitó |

---

### C-58 · Formulario de zona de riesgo: tipo de amenaza libre y ubicación fija del usuario `2026-05-15 15:05`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-58 · Safety — tipo de amenaza fijo (jauría) + selección de punto en mapa |
| **Qué se corrigió (técnico)** | **`risk_form_bottom_sheet.dart`**: Eliminados `_formKey`, `_threatCtrl` (TextEditingController), método `dispose()`, widget `Form` y `TextFormField` de tipo de amenaza. El cuerpo del POST ahora envía `'threat_type': 'jauría'` hardcodeado. Parámetro renombrado de `currentLocation` a `selectedLocation`. El subtítulo muestra las coordenadas del punto elegido y el texto fijo "Tipo de amenaza: Jauría". **`map_screen_vendor.dart`** y **`map_screen_buyer.dart`**: Añadido estado `bool _selectingRiskPoint`. `_onFabPressed` ya no abre el formulario directamente — activa `_selectingRiskPoint = true`. Nuevo método `_onMapTap(LatLng)`: si `_selectingRiskPoint`, lo desactiva y abre `RiskFormBottomSheet.show(context, point)` con el punto tocado. `GoogleMap` recibe `onTap: _onMapTap`. Nuevo widget privado `_RiskPointSelectionBanner` (banner naranja en la parte superior del mapa) que muestra la instrucción "Toca el mapa para marcar la zona de riesgo" y un botón "Cancelar" |
| **Qué se corrigió (simple)** | Antes el formulario pedía un texto libre de "Tipo de amenaza" (debería ser siempre jauría) y reportaba en las coordenadas actuales del usuario. Ahora: (1) el tipo de amenaza es siempre "Jauría" y no aparece campo editable; (2) al pulsar "Zona de riesgo" en el FAB, aparece un banner naranja pidiendo que el usuario toque el punto del mapa donde está la amenaza; luego se abre el formulario solo con la selección de nivel de riesgo |
| **Clase / Método / Módulo** | `RiskFormBottomSheet` · `_MapScreenVendorState._onFabPressed + _onMapTap` · `_MapScreenBuyerState._onFabPressed + _onMapTap` |
| **Justificación** | El único tipo de amenaza reportable en UbiSafe es una jauría de perros en situación activa; no tiene sentido un campo de texto libre. La ubicación del riesgo puede no coincidir con la posición del usuario (el usuario puede ver la jauría a distancia), por lo que debe poder señalar el punto exacto en el mapa |
| **Problema que resolvía** | El formulario mostraba un campo de texto innecesario para el tipo de amenaza, y el reporte siempre se creaba en las coordenadas actuales del usuario en lugar del lugar real del peligro |

---

### C-59 · 500 en GET /risk-zones y GET /community-reports — índice compuesto faltante en Firestore `2026-05-15 15:30`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-59 · Eliminar filtro Firestore de location.lat — filtrar en Python |
| **Qué se corrigió (técnico)** | En `firestore_service.py`, se eliminaron los `.where("location.lat", ">=", ...)` y `.where("location.lat", "<=", ...)` de las funciones `get_active_risk_zones` y `get_community_reports_in_bbox`. Las queries de Firestore ahora usan únicamente el filtro de campo simple (`active == True` o `status in [...]`), que usa índices automáticos. El filtrado de proximidad (radio en km) se hace completamente en Python con `_haversine_km` |
| **Qué se corrigió (simple)** | Al añadir un filtro de rango (`>=`, `<=`) sobre `location.lat` combinado con otro filtro de igualdad, Firestore exige un índice compuesto que no estaba creado en el proyecto de producción. Ambos endpoints devolvían 500 al cargar el mapa. Ahora Firestore sólo filtra por el campo simple y Python hace el cálculo de distancia |
| **Clase / Método / Módulo** | `FirestoreService.get_active_risk_zones()` + `FirestoreService.get_community_reports_in_bbox()` → `firestore_service.py` (`ubisafe_api/modules/shared/firestore_service.py`) |
| **Justificación** | Firestore requiere índice compuesto para cualquier query que combine una desigualdad en un campo con cualquier otro filtro en campo distinto. `query_active_risk_zones_bbox` ya usaba el patrón correcto (filtro simple + Python); se unificaron las dos funciones afectadas con el mismo patrón. Para el volumen esperado del proyecto (<1000 documentos activos) la diferencia de rendimiento es despreciable |
| **Problema que resolvía** | `GET /risk-zones` y `GET /community-reports` → 500 Internal Server Error con `google.api_core.exceptions.FailedPrecondition: 400 The query requires an index` |

---

### C-60 · 500 en GET /risk-zones — DatetimeWithNanoseconds no serializable como str en RiskZone `2026-05-15 15:45`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-60 · _doc_to_risk_zone helper — conversión de timestamps |
| **Qué se corrigió (técnico)** | Se añadió el método de clase `_doc_to_risk_zone(doc)` a `FirestoreService`, aplicando el mismo patrón que `_doc_to_stop_request` de C-45: convierte los campos `created_at`, `expires_at` y `expired_at` de `DatetimeWithNanoseconds` a string ISO antes de construir el modelo Pydantic `RiskZone`. Se reemplazaron los cuatro sitios que usaban `RiskZone(id=doc.id, **raw)` directamente: `get_risk_zone`, `get_active_risk_zones` (x2), `create_risk_zone` y `expire_risk_zone` |
| **Qué se corrigió (simple)** | Al leer una zona de riesgo de Firestore, el campo `created_at` (guardado con `SERVER_TIMESTAMP`) llega como objeto `DatetimeWithNanoseconds`. Pydantic v2 espera un `str` y lanzaba `ValidationError`, provocando 500 en todos los endpoints de `/risk-zones` |
| **Clase / Método / Módulo** | `FirestoreService._doc_to_risk_zone()` + `get_risk_zone` + `get_active_risk_zones` + `create_risk_zone` + `expire_risk_zone` → `firestore_service.py` |
| **Justificación** | Mismo root cause que C-45 (stops) y el mismo patrón de corrección. `SERVER_TIMESTAMP` es un centinela que Firestore reemplaza con su timestamp de servidor; al leer de vuelta el SDK de Python devuelve `DatetimeWithNanoseconds`, no `str`. El helper normaliza todos los campos de timestamp antes de pasarlos a Pydantic |
| **Problema que resolvía** | `GET /risk-zones` → 500 con `pydantic_core.ValidationError: created_at — Input should be a valid string`. Los reportes se creaban en Firestore (el POST funcionaba) pero no se podían listar, lo que hacía que el mapa no mostrara ninguna zona y que el sistema de duplicados detectara zonas invisibles |

---

### C-61 · Zona de riesgo reportada no aparecía en el mapa hasta recibir FCM `2026-05-15 16:10`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-61 · Invalidar activeRiskZonesProvider inmediatamente tras reporte exitoso |
| **Qué se corrigió (técnico)** | `_onMapTap` en `map_screen_vendor.dart` y `map_screen_buyer.dart` cambió de `void` a `Future<void>`. Ahora awaita `RiskFormBottomSheet.show(context, point)` y si el resultado es `true` (reporte exitoso) llama `ref.invalidate(activeRiskZonesProvider)` antes de que llegue la notificación FCM |
| **Qué se corrigió (simple)** | Al crear una zona de riesgo, el círculo no aparecía en el mapa inmediatamente. El mapa solo se actualizaba cuando llegaba la notificación FCM del backend (demora de varios segundos) o, si la notificación no llegaba, nunca. Ahora el círculo aparece en cuanto se cierra el formulario |
| **Clase / Método / Módulo** | `_MapScreenVendorState._onMapTap()` + `_MapScreenBuyerState._onMapTap()` → `map_screen_vendor.dart` + `map_screen_buyer.dart` |
| **Justificación** | `RiskFormBottomSheet.show()` devuelve `Future<bool>` pero no se awaiteaba. La notificación FCM llega después del redeploy del backend (Render cold-start o latencia de red), por lo que confiar solo en FCM para el refresco es insuficiente para dar feedback visual inmediato al reportador |
| **Problema que resolvía** | El usuario reportaba una zona de riesgo, el formulario confirmaba éxito, pero el círculo en el mapa no aparecía hasta segundos después (o no aparecía si FCM fallaba) |

---

### C-62 · FABs "Zona de riesgo" y "Foco de infección" bloqueaban la pantalla al primer toque `2026-05-15 17:00`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-62 · Eliminar check de `gpsStatusProvider` en `_onFabPressed` / `_onCommunityFabPressed` |
| **Qué se corrigió (técnico)** | `_onFabPressed` y `_onCommunityFabPressed` en ambas pantallas leían `ref.read(gpsStatusProvider).valueOrNull` y comparaban con `GpsStatus.ready`. Al primer press, `gpsStatusProvider` (un `StreamProvider`) aún no había emitido valor → `.valueOrNull == null` → `null != GpsStatus.ready` evaluaba `true` → se abría `showModalBottomSheet(GpsRequiredEmptyState)` sin contenido visible pero con su scrim oscureciendo la pantalla. La condición se reemplazó por `position == null` usando la posición ya disponible del `gpsServiceProvider` |
| **Qué se corrigió (simple)** | Al presionar "Zona de riesgo" o "Foco de infección" por primera vez, la pantalla se oscurecía sin mostrar nada, dando apariencia de congelamiento. Al segundo intento ya funcionaba. Se eliminó la comprobación redundante de estado GPS que causaba la apertura de un modal vacío |
| **Clase / Método / Módulo** | `_MapScreenVendorState._onFabPressed()`, `_MapScreenVendorState._onCommunityFabPressed()`, `_MapScreenBuyerState._onFabPressed()`, `_MapScreenBuyerState._onCommunityFabPressed()` → `map_screen_vendor.dart` + `map_screen_buyer.dart` |
| **Justificación** | `gpsServiceProvider` ya garantiza que la pantalla del mapa solo se renderiza cuando `position != null`. El `gpsStatusProvider` es redundante una vez que el mapa está visible y su naturaleza asíncrona (stream) causaba un falso negativo en el primer frame |
| **Problema que resolvía** | Al presionar cualquier FAB de reporte por primera vez, el fondo se oscurecía (scrim del `showModalBottomSheet`) pero no aparecía ningún diálogo. La pantalla parecía congelada hasta que el usuario tocaba el fondo para descartar el modal invisible |

---

### C-63 · Toggle "Solicitar Raite" aparecía activo pero no funcionaba; se desactivaba al navegar `2026-05-15 17:30`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-63 · ride_enabled borrado por cada write de posición GPS |
| **Qué se corrigió (técnico)** | `GPSService._subscribe` usaba `_rtdbRefFactory(vendorUid).set({lat, lng, timestamp, activo})`. Cada actualización de posición (cada segundo) sobreescribía el nodo RTDB completo con `.set()`, borrando el campo `ride_enabled` que `updateRideEnabled()` había escrito con `.update()`. Además, `startTransmission()` no incluía `ride_enabled` en la escritura inicial, por lo que `VendorMarker.rideEnabled` siempre leía `false` (default) al activar visibilidad aunque el perfil tuviera `ride_enabled: true`. Solución: (1) agregar campo `_rideEnabled` al `GPSService`; (2) incluirlo en cada `.set()`; (3) `updateRideEnabled` actualiza `_rideEnabled` antes de llamar a RTDB; (4) `startTransmission` acepta parámetro `rideEnabled` y lo inicializa; (5) `_onToggle` en vendor map lee `userProfileProvider` y pasa el valor a `startTransmission` |
| **Qué se corrigió (simple)** | El toggle "Solicitar Raite" en el cajón lateral aparecía prendido (por el perfil de Firestore) pero los compradores no veían la opción porque el RTDB no tenía el campo. Al activar/desactivar el toggle funcionaba, pero en la siguiente actualización de GPS el campo se borraba solo. Ahora el valor de `ride_enabled` se preserva en cada escritura de posición y se inicializa correctamente al activar visibilidad |
| **Clase / Método / Módulo** | `GPSService._subscribe()` + `GPSService.startTransmission()` + `GPSService.updateRideEnabled()` → `gps_service.dart`; `_MapScreenVendorState._onToggle()` → `map_screen_vendor.dart` |
| **Justificación** | `.set()` reemplaza el nodo completo en RTDB; `.update()` hace patch parcial. Usar `.set()` para posición y `.update()` separado para `ride_enabled` crea una race condition donde el `.set()` siempre gana y borra el campo |
| **Problema que resolvía** | Toggle mostraba ON pero compradores no veían "Solicitar Raite". Después de apagar/prender el toggle funcionaba, pero al siguiente tick de GPS (≈1 s) se volvía a perder |

---

### C-64 · Comprador no podía cancelar un raite pendiente; el raite quedaba huérfano en Firestore `2026-05-15 18:00`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-64 · Transición `pending→cancelled` faltante para BUYER en rides |
| **Qué se corrigió (técnico)** | `RIDE_VALID_TRANSITIONS` en `ride_schemas.py` solo tenía `("pending", "rejected"): "VENDOR"`. El buyer map enviaba `PATCH /rides/{id}/status` con `status=rejected, rejected_reason=buyer_cancelled` al cancelar un raite pendiente, pero el backend requería rol VENDOR para esa transición → 403. El error era tragado silenciosamente (`catch (_) {}`), dejando el raite en `pending` en Firestore indefinidamente. El vendor seguía viendo el diálogo de solicitud entrante sin saber que el comprador se fue. Solución: (1) añadir `cancelled` a `RideStatus` enum; (2) añadir `("pending", "cancelled"): "BUYER"` a `RIDE_VALID_TRANSITIONS`; (3) manejar notificación `send_ride_cancelled_by_buyer` al vendor en el router; (4) buyer map cambia de `updateStatus('rejected')` → `updateStatus('cancelled')`; (5) vendor map añade `_pendingDialogRideId` para cerrar el diálogo automáticamente al recibir el FCM de cancelación |
| **Qué se corrigió (simple)** | Cuando el comprador presionaba "Cancelar" mientras esperaba respuesta del vendor, la UI volvía a idle pero el raite seguía vivo en la base de datos y el vendor seguía viendo la solicitud. Al aceptar, el vendor obtenía un error. Ahora el raite se cancela correctamente, el vendor recibe una notificación, y el diálogo del vendor se cierra automáticamente |
| **Clase / Método / Módulo** | `RideStatus` + `RIDE_VALID_TRANSITIONS` → `ride_schemas.py`; `update_ride_status()` → `ride_router.py`; `_WaitingOverlay.onCancel` → `map_screen_buyer.dart`; `_showIncomingRideDialog()` + `rideEventProvider listener` → `map_screen_vendor.dart` |
| **Justificación** | La máquina de estados del raite no contemplaba cancelación por comprador mientras el raite estaba pendiente. El `("accepted", "rejected")` existente solo cubre cancelación post-aceptación |
| **Problema que resolvía** | Raites huérfanos en Firestore; vendor aceptaba solicitudes de compradores que ya se fueron; datos inconsistentes entre UI y backend |

---

### C-65 · Toggle "Solicitar Raite" requería dos toques para funcionar; estado visual no coincidía con lo que veía el comprador `2026-05-15 18:30`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-65 · `startTransmission` sobreescribía `ride_enabled` con valor stale del perfil |
| **Qué se corrigió (técnico)** | `GPSService.startTransmission(uid, rideEnabled: ...)` siempre sobreescribía `_rideEnabled` con el valor leído de `userProfileProvider`. Como `userProfileProvider` es un `FutureProvider` que NO se invalida tras el toggle del cajón, su valor era stale (el anterior). Cuando el vendor desactivaba y reactivaba la visibilidad GPS, `startTransmission` restauraba el valor antiguo en `_rideEnabled`, lo que hacía que cada write de posición al RTDB escribiera el valor incorrecto. Solución: añadir flag `_rideEnabledSet` en `GPSService`. `startTransmission` solo usa el parámetro `rideEnabled` en la primera llamada de la sesión; después, si `updateRideEnabled` ya fue llamado (toggle explícito), el valor se preserva a través de ciclos de activación/desactivación. `updateRideEnabled` también setea `_rideEnabledSet = true`. |
| **Qué se corrigió (simple)** | El toggle "Solicitar Raite" mostraba el estado correcto visualmente, pero para que el comprador viera la opción se necesitaban dos toques (apagar-prender o prender-apagar), porque al reactivar la visibilidad GPS se restauraba el valor viejo. Ahora un solo toque es suficiente y el estado del RTDB siempre coincide con el toggle |
| **Clase / Método / Módulo** | `GPSService.startTransmission()` + `GPSService.updateRideEnabled()` → `gps_service.dart` |
| **Justificación** | `userProfileProvider` es un `FutureProvider` que no se auto-refresca tras un PATCH a la API. Leer `profile?.rideEnabled` en `startTransmission` producía un read de dato stale después del primer toggle del cajón |
| **Problema que resolvía** | Para activar el toggle había que apagarlo y prenderlo; para desactivarlo había que prenderlo y apagarlo. El estado visual del toggle no era consistente con lo que el comprador veía al seleccionar al vendor |

---

### C-66 · Toggle "Solicitar Raite" se reiniciaba a ON cada vez que el vendedor volvía al mapa `2026-05-15 19:00`

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | `appRouterProvider` usaba `ref.watch(authStateProvider)` dentro de `Provider<GoRouter>`, lo que recreaba el GoRouter completo en cada emisión de Firebase Auth (incluyendo token refresh silencioso), reiniciando la pila de navegación a `/splash` y destruyendo el estado de `DrawerModule` (incluido `_rideEnabled`) |
| **Qué se corrigió (simple)** | El router de la app ya no se re-crea cuando Firebase renueva el token de sesión; el toggle de "Solicitar Raite" conserva su estado al navegar entre pantallas |
| **Clase / Módulo** | `appRouterProvider` → `app_router.dart`, nueva clase `_AuthChangeNotifier extends ChangeNotifier` |
| **Justificación** | `ref.watch` dentro de `Provider<GoRouter>` invalida y recrea el `Provider` cada vez que `authStateProvider` emite, lo que destruye el árbol de widgets completo. Reemplazado por patrón `refreshListenable`: el router se crea una sola vez; los cambios de auth solo disparan re-evaluación del redirect sin resetear la pila |
| **Problema que resolvía** | El toggle aparecía siempre como ON al regresar a `MapScreenVendor`, independientemente del valor real; la opción de raite se activaba sola para el comprador al seleccionar al vendedor por segunda vez |

---

### C-67 · Reporte de zona de riesgo se guardaba aunque el punto estuviera fuera del radio de 4 km `2026-05-15 19:30`

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | `_onMapTap` en `MapScreenBuyer` no validaba la distancia entre el punto seleccionado y la posición actual del usuario antes de abrir `RiskFormBottomSheet`; el formulario se abría y la petición POST llegaba al backend independientemente de la distancia |
| **Qué se corrigió (simple)** | Si el comprador toca un punto en el mapa que está a más de 4 km de su ubicación real, la app bloquea el reporte con un mensaje de error antes de abrir el formulario; nada se guarda en la base de datos |
| **Clase / Módulo** | `_MapScreenBuyerState._onMapTap` → `map_screen_buyer.dart` |
| **Justificación** | La validación de 4 km existía solo en el backend para filtrar zonas al mostrarlas en el mapa, pero no había ninguna guarda en el cliente que impidiera enviar el reporte; `Geolocator.distanceBetween()` calcula la distancia geodésica y corta el flujo en la UI |
| **Problema que resolvía** | Al reportar fuera del radio de 4 km, la zona se guardaba en Firestore, se enviaba notificación FCM de éxito al reportante, pero no aparecía en el mapa porque el filtro de visualización sí aplicaba el radio |

---

### C-68 · Login quedaba cargando indefinidamente tras el fix C-66; navegación post-autenticación no ocurría `2026-05-16 10:00`

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | `ref.listen(authStateProvider, ...)` dentro de `Provider<GoRouter>` introducía una condición de carrera: GoRouter evaluaba el redirect antes de que Riverpod procesara el nuevo valor del stream, por lo que `ref.read(authStateProvider).valueOrNull` devolvía `null` y el redirect no redirigía a `/splash`. La pantalla de login quedaba con el spinner activo indefinidamente |
| **Qué se corrigió (simple)** | Al iniciar sesión, la app ahora navega correctamente a la pantalla de mapa en lugar de quedarse bloqueada en el formulario de login |
| **Clase / Módulo** | `appRouterProvider` + `_AuthChangeNotifier` → `app_router.dart` |
| **Justificación** | `_AuthChangeNotifier` ahora se suscribe directamente a `FirebaseAuth.instance.authStateChanges()` sin pasar por Riverpod. `notifyListeners()` se llama en el mismo microtask que el evento de Firebase Auth, antes de que Riverpod lo procese. El redirect usa `FirebaseAuth.instance.currentUser` (propiedad sincrónica, siempre correcta post-signIn) en lugar de `ref.read(authStateProvider).valueOrNull` para evitar cualquier desfase entre el stream de Firebase y el estado de Riverpod |
| **Problema que resolvía** | Primera sesión: spinner de carga infinito en la pantalla de login; segunda vez al intentar iniciar sesión: la app saltaba directo al mapa (porque el usuario ya estaba autenticado pero sin haberlo notado) |

---

### C-69 · Error 409 al solicitar raite mostraba excepción cruda; `vendor_ride_disabled` falso positivo para cuentas sin campo explícito `2026-05-16`

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | (1) `_requestRide` en `MapScreenBuyer` capturaba `DioException` con status 409 pero mostraba `$e` crudo al usuario. (2) `create_ride` en `ride_router.py` usaba `if not vendor.ride_enabled` que evalúa `None` como falsy, rechazando cuentas de vendedor cuyo Firestore nunca tuvo el campo `ride_enabled` explícitamente escrito |
| **Qué se corrigió (simple)** | Al solicitar un raite y el vendedor no puede atender, la app muestra un mensaje claro ("El vendedor está atendiendo otra solicitud" / "El vendedor tiene el raite desactivado") en lugar de un error técnico; además, cuentas de vendedor sin el campo `ride_enabled` ya no son rechazadas como si tuvieran raite desactivado |
| **Clase / Módulo** | `_MapScreenBuyerState._requestRide` → `map_screen_buyer.dart`; `create_ride` → `ride_router.py` |
| **Justificación** | `bool \| None = None` en el schema de usuario implica que cuentas creadas antes de agregar el campo tienen `ride_enabled = None`; `not None` es `True` en Python, generando un falso positivo. El catch block sin parsear el detail devolvía el objeto `DioException` completo que el usuario veía como un error críptico |
| **Problema que resolvía** | Al tocar "Solicitar Raite" y confirmar destino, la app mostraba "Error al solicitar raite: DioException [bad response]..." en lugar de un mensaje legible; en algunos casos el error era un falso positivo por el campo ausente en Firestore |

---

### C-70 · Login nunca navegaba al mapa — `authStateChanges()` no emite tras Pigeon bug de firebase_auth 4.16.0 `2026-05-16`

| Campo | Detalle |
|---|---|
| **Qué se corrigió (técnico)** | El fix C-66 introdujo el patrón `refreshListenable` con `_AuthChangeNotifier` suscrito a `FirebaseAuth.instance.authStateChanges()`. En Android con `firebase_auth 4.16.0`, `signInWithEmailAndPassword` lanza una excepción de serialización Pigeon durante el procesamiento de la respuesta del canal de plataforma, interrumpiéndolo antes de que `authStateChanges()` alcance a emitir. `currentUser` SÍ se actualiza (por eso el catch-and-continue en C-41 funciona), pero el stream nunca dispara, `notifyListeners()` nunca se llama y GoRouter nunca evalúa el redirect. Adicionalmente, `login()` awaaitaba `POST /auth/sync-profile` y `_syncDeviceToken()` bloqueando el retorno incluso después del sign-in |
| **Qué se corrigió (simple)** | Al presionar "Entrar", la app navega al mapa inmediatamente después de que Firebase confirma la autenticación, sin depender del stream `authStateChanges()` |
| **Clase / Módulo** | `AuthModule.login()` → `auth_module.dart`; `_LoginScreenState._submit()` → `login_screen.dart` |
| **Justificación** | `sync-profile` y `_syncDeviceToken` son best-effort; se cambiaron a `unawaited()` para que `login()` retorne en cuanto Firebase confirma el sign-in. Se añadió `if (mounted) context.go('/splash')` en `_submit()` como navegación primaria que no depende del stream: `SplashScreen._checkSession()` lee `FirebaseAuth.instance.currentUser` directamente (no el stream), y como `currentUser` sí se actualiza incluso con el Pigeon bug, navega al mapa correctamente. El redirect de GoRouter sigue actuando si `authStateChanges()` llega a emitir; si ya navegó, `mounted = false` y el `context.go` es no-op |
| **Problema que resolvía** | Spinner en la pantalla de login que nunca desaparecía; al volver a la pantalla de bienvenida y presionar "Iniciar sesión" de nuevo la app iba directo al mapa (el usuario ya estaba autenticado sin saberlo). El bug fue introducido en C-66 (commit `c9c1128`) al reemplazar `ref.watch(authStateProvider)` — que recreaba el router y accidentalmente navegaba a `/splash` — con el patrón `refreshListenable` que depende del stream |

---

### C-71 · Validación de radio 4 km faltante en `_onMapTap` del vendedor `2026-05-16`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-71 · Validación 4 km en `_onMapTap` del vendedor |
| **Qué se corrigió (técnico)** | Se añadió `import 'package:geolocator/geolocator.dart'` a `map_screen_vendor.dart`. Se expandió `_onMapTap` del vendedor para replicar exactamente la misma guardia de distancia que ya existía en el buyer: lee `gpsServiceProvider.valueOrNull`, calcula `Geolocator.distanceBetween` entre la posición actual y el punto tocado, y si `distanceMeters > 4000` muestra un `SnackBar` y retorna sin abrir `RiskFormBottomSheet` |
| **Qué se corrigió (simple)** | El vendedor podía tocar cualquier punto del mapa y reportar una zona de riesgo aunque estuviera a más de 4 km de su ubicación real; ahora recibe el aviso "Solo puedes reportar zonas dentro de un radio de 4 km desde tu ubicación." y el formulario no se abre |
| **Clase / Método / Módulo** | `_MapScreenVendorState._onMapTap()` → `map_screen_vendor.dart` (`ubisafe_app/lib/features/dispatching/screens/map_screen_vendor.dart`) |
| **Justificación** | C-58 introdujo `_onMapTap` en ambas pantallas (buyer y vendor). C-67 añadió la validación de radio solo en el buyer; el vendor quedó sin el guard. La regresión pasó desapercibida porque C-67 fue registrado como corrección del buyer únicamente |
| **Problema que resolvía** | El vendedor podía crear zonas de riesgo en coordenadas arbitrarias del mapa; los reportes se guardaban en Firestore y se enviaban notificaciones FCM aunque el punto estuviera fuera del radio permitido de 4 km |

---

### C-72 · Primera solicitud de parada no notificaba al vendedor — token FCM no registrado en cold start `2026-05-16`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-72 · Re-sync FCM token en SplashScreen tras sesión verificada |
| **Qué se corrigió (técnico)** | (1) Se añadió el método público `syncTokenIfNeeded()` a `NotificationHandler`: llama a `_messaging.getToken()` con timeout de 5 s y luego a `_syncToken()` exactamente igual que `init()`. (2) En `SplashScreen._checkSession()`, inmediatamente después de un `GET /auth/me` exitoso y antes de `_go()`, se llama `unawaited(ref.read(notificationHandlerProvider).syncTokenIfNeeded())`. Se añadió el import de `notification_handler.dart` a `splash_screen.dart`. |
| **Qué se corrigió (simple)** | En el primer arranque tras un despliegue, `NotificationHandler.init()` se ejecuta antes de que Firebase Auth haya restaurado la sesión persistida, por lo que el `PATCH /auth/device-token` falla con 401 y el token FCM del vendedor no queda registrado en Firestore. Cuando el comprador hace la primera solicitud de parada, el backend no encuentra el token del vendedor y descarta la notificación silenciosamente. Al reiniciar la app ya funciona porque Firebase Auth restaura la sesión más rápido en el segundo arranque. Ahora el token se re-sincroniza en el único punto donde se garantiza que el usuario está autenticado y el backend está activo. |
| **Clase / Método / Módulo** | `NotificationHandler.syncTokenIfNeeded()` → `notification_handler.dart` (`ubisafe_app/lib/features/shared/notifications/notification_handler.dart`); `_SplashScreenState._checkSession()` → `splash_screen.dart` (`ubisafe_app/lib/features/identity/auth/screens/splash_screen.dart`) |
| **Justificación** | `init()` corre en `main.dart` `initState` sin `await`. Firebase Auth puede tardar entre 200-800 ms en restaurar la sesión persistida desde disco; en ese margen el interceptor Dio no tiene Bearer token → 401 swallowed. Render además puede estar en cold start en ese instante → segundo fallo silencioso. El único punto determinístico donde (a) `currentUser != null` y (b) Render ya respondió es justo después de `GET /auth/me` exitoso en `_checkSession()`. El `unawaited()` evita bloquear la navegación; el resultado es best-effort idéntico al existente en `init()`. |
| **Problema que resolvía** | En el primer uso tras un despliegue, al solicitar parada el vendedor no recibía ninguna notificación; en el segundo intento (app reiniciada) sí funcionaba. |

---

### C-73 · `_fetchRoute` silenciaba todos los errores y no reintentaba sin waypoints `2026-05-16`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-73 · `_fetchRoute` refactor: logging + fallback sin waypoints |
| **Qué se corrigió (técnico)** | Se dividió `_fetchRoute` en dos métodos: (1) `_fetchRoute` (orquestador) que primero intenta con `avoidWaypoints` y, si `_requestRoute` devuelve `null`, reintenta sin ellos; (2) `_requestRoute` (single-attempt) que devuelve `List<LatLng>?` en éxito o `null` en fallo, y en ambos casos emite `debugPrint` con el status de la API o la excepción. El `setState` del resultado solo se llama desde `_fetchRoute` cuando `points != null && mounted`. |
| **Qué se corrigió (simple)** | Si las zonas de riesgo HIGH generaban waypoints en ubicaciones sin calles, la Directions API devolvía `ZERO_RESULTS` y la ruta no aparecía sin ningún aviso. Ahora: (a) el error se registra en logs para diagnóstico; (b) si el intento con waypoints falla, se reintenta con la ruta directa sin desvíos, garantizando que siempre aparezca una polilínea cuando la key y la red son válidas. |
| **Clase / Método / Módulo** | `_MapScreenVendorState._fetchRoute()` + nuevo `_MapScreenVendorState._requestRoute()` → `map_screen_vendor.dart` |
| **Justificación** | `catch (_) {}` hacía imposible diagnosticar si el fallo era por key vacía, network, quota o ZERO_RESULTS. El fallback sin waypoints es el comportamiento correcto cuando los waypoints generados caen fuera de la red vial (situación frecuente en entornos urbanos densos) |
| **Problema que resolvía** | La ruta del vendedor hacia el comprador no aparecía en el mapa al aceptar una parada cuando había zonas de riesgo HIGH activas cerca; la polilínea tampoco aparecía en otros fallos de la API porque ningún error era visible |

---

### C-74 · `_fetchRoute` no esperaba la carga de `_mapsApiKey` si el dialog llegaba antes que el MethodChannel `2026-05-16`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-74 · Retry de `_initMapsKey()` en `_fetchRoute` |
| **Qué se corrigió (técnico)** | Al inicio de `_fetchRoute`, si `_mapsApiKey.isEmpty`, se llama `await _initMapsKey()` antes de continuar. Si tras el retry sigue vacío, se emite `debugPrint` y se retorna. |
| **Qué se corrigió (simple)** | `_initMapsKey()` se lanza en `initState()` sin `await`. En el caso improbable de que el vendedor acepte la solicitud antes de que el MethodChannel responda, `_mapsApiKey` sería `''` y `_fetchRoute` retornaba silenciosamente. Ahora se espera a que el channel responda antes de declarar la key ausente. |
| **Clase / Método / Módulo** | `_MapScreenVendorState._fetchRoute()` → `map_screen_vendor.dart` |
| **Justificación** | El MethodChannel es sub-milisegundo en producción, pero en condiciones de cold start o DevTools activo puede tardar más. El retry es idempotente porque `_initMapsKey` ya guarda el resultado en `_mapsApiKey` |
| **Problema que resolvía** | Ruta no trazada en arranques lentos si la solicitud de parada llegaba antes de que `_initMapsKey` completara |

---

### C-75 · `_buildAvoidWaypoints` calculaba la perpendicular en espacio de grados, no métrico `2026-05-16`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-75 · `_buildAvoidWaypoints` cálculo métrico correcto |
| **Qué se corrigió (técnico)** | Se reemplazó el cálculo en espacio de grados por uno en espacio métrico: (1) se calcula `metersPerDegLng = 111000 * cos(midLat_rad)` usando la latitud media del trayecto; (2) el vector dirección, la longitud, el vector perpendicular y el producto cruzado se calculan todos en metros; (3) el offset se aplica en metros y luego se convierte de vuelta a grados de forma separada para latitud (`/ metersPerDegLat`) y longitud (`/ metersPerDegLng`). La constante única `degPerMeter = 1/111000` fue eliminada. |
| **Qué se corrigió (simple)** | El código anterior usaba la misma escala (`1/111000 deg/m`) para desplazar tanto latitud como longitud, ignorando que los grados de longitud son más cortos que los de latitud (a ~20° lat, solo ~104 km/°). Esto hacía que el vector perpendicular apuntara en la dirección incorrecta y que el waypoint de desvío cayera sistemáticamente desplazado hacia el este u oeste respecto del punto correcto, con alta probabilidad de aterrizar fuera de la red vial. |
| **Clase / Método / Módulo** | `_buildAvoidWaypoints()` → `map_screen_vendor.dart` (función top-level) |
| **Justificación** | La fórmula de Haversine no es necesaria para desplazamientos pequeños (< 1 km), pero la distinción entre `metersPerDegLat` y `metersPerDegLng` sí es crítica: sin ella el waypoint puede quedar hasta ~60 m desplazado en dirección equivocada a latitudes mexicanas, lo que con frecuencia lo pone dentro de un edificio o zona sin calles y provoca `ZERO_RESULTS` en la Directions API |
| **Problema que resolvía** | Waypoints de desvío generados en ubicaciones sin calles → Directions API devolvía `ZERO_RESULTS` → la polilínea de ruta no aparecía cuando había zonas HIGH activas cerca del trayecto |

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
