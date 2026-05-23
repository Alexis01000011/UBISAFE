# Registro de Correcciones — UBISAFE

**Proyecto:** Los Borbotones · TSP · ITESM  
**Rama activa:** `Rama-Miguel`  
**Dispositivo de prueba:** Físico Android (depuración inalámbrica ADB, NO emulador de computadora)  
**Última actualización:** 2026-05-22 (C-161)

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

### C-76 · Auto-login sin credenciales al reabrir la app sin cerrar sesión `2026-05-16`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-76 · signOut en `paused` + `currentUser` en Splash (reescritura) |
| **Qué se corrigió (técnico)** | **Dos cambios coordinados:** (1) `main.dart` — `didChangeAppLifecycleState` ahora llama `stopTransmission` + `FirebaseAuth.instance.signOut()` cuando el estado es `AppLifecycleState.paused` O `AppLifecycleState.detached` (antes solo era `detached`). (2) `splash_screen.dart` — `initState` usa `WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession())` para renderizar el primer frame antes de hacer trabajo asíncrono. `_checkSession` lee `FirebaseAuth.instance.currentUser` directamente (sync), sin awaitar ningún stream. Si `currentUser == null` → `/welcome`; si `!= null` → `GET /auth/me` → navega al rol correcto. Se eliminó el campo `Timer? _timer` que existía de versiones anteriores. |
| **Qué se corrigió (simple)** | El comportamiento esperado es que cerrar la app (sin logout explícito) cierre la sesión automáticamente. Al reabrir, el usuario siempre debe pasar por el login. Con la corrección anterior (C-76 v1), `authStateChanges().first` no era confiable en este flujo. La solución definitiva es más simple: cerrar sesión al momento en que la app va a segundo plano (`paused`), de forma que al regresar `currentUser` siempre sea `null`. |
| **Clase / Módulo** | `_UbiSafeAppState.didChangeAppLifecycleState()` → `main.dart`; `_SplashScreenState._checkSession()` + `initState()` → `splash_screen.dart` |
| **Justificación** | `AppLifecycleState.paused` es el evento más confiable en Android cuando el usuario presiona Home o cambia de app. `currentUser` es una propiedad síncrona de Firebase Auth que refleja el estado actual sin depender de streams. Combinados, estos dos puntos garantizan que la sesión siempre esté limpia en un arranque fresco sin necesidad de timeouts ni fallbacks. |
| **Problema que resolvía** | El usuario cerraba la app sin cerrar sesión, la volvía a abrir, llegaba a `/welcome` y al tocar "Iniciar sesión" era enviado al mapa sin validar correo ni contraseña. |

---

### C-77 · `VendorTracker` cancelaba la suscripción RTDB en errores transitorios + falta de posición inicial `2026-05-16`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-77 · cancelOnError:false en VendorTracker + getLastKnownPosition fallback |
| **Qué se corrigió (técnico)** | (1) Se añadió `cancelOnError: false` al `stream.listen(...)` en `VendorTracker._init()`. (2) En `_vendorTrackerInstanceProvider`, cuando `ref.read(gpsServiceProvider).valueOrNull` es null (stream aún no emitió), se llama `Geolocator.getLastKnownPosition().then((pos) { if (pos != null) tracker.updateBuyerPosition(...); }).catchError((_) {})` como semilla inmediata. |
| **Qué se corrigió (simple)** | (1) Si RTDB enviaba un error transitorio (permission_denied durante reconexión, caída de red breve), Dart cancelaba la suscripción automáticamente porque `cancelOnError` era `true` por defecto. A partir de ese momento el comprador nunca más recibía actualizaciones de vendedores, aunque RTDB los mostrara como activos. Con `cancelOnError: false`, la suscripción sobrevive al error y recibe el siguiente evento. (2) Si el GPS no había emitido la primera posición cuando RTDB disparaba el snapshot inicial con vendedores activos, `_emit()` filtraba con lat/lng=null y emitía lista vacía; los vendedores no aparecían hasta el próximo evento RTDB o GPS. El `getLastKnownPosition()` da la posición del último fix conocido del SO como semilla inmediata. |
| **Clase / Módulo** | `VendorTracker._init()` → `vendor_tracker.dart`; `_vendorTrackerInstanceProvider` → `vendor_tracker.dart` |
| **Justificación** | `stream.listen` en Dart cancela la suscripción en el primer error cuando `cancelOnError=true` (valor por defecto). Firebase RTDB SDK auto-reconecta la conexión WebSocket, pero si la suscripción Dart ya fue cancelada, los eventos de la reconexión no llegan al listener. `cancelOnError: false` mantiene el listener activo y permite que el SDK entregue el siguiente snapshot tras reconectar. |
| **Problema que resolvía** | El vendedor activaba el radar y aparecía como activo en RTDB, pero el comprador no veía el marcador en el mapa; en particular si había habido un error RTDB previo en la sesión. |

---

### C-78 · RTDB no se limpiaba al cerrar sesión ni al cerrar la app `2026-05-16`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-78 · stopTransmission antes de signOut en drawer y lifecycle |
| **Qué se corrigió (técnico)** | (1) Se añadió `String? get activeUid => _activeUid` a `GPSService`. (2) En `DrawerModule`, el `onPressed` del botón "Cerrar Sesión" (en el drawer normal y en `_buildFallbackDrawer`) ahora llama `await ref.read(gpsServiceInstanceProvider).stopTransmission(uid)` antes de `signOut()`, solo si `gps.activeUid != null`. (3) En `main.dart` se añadieron `import 'dart:async'` e `import 'features/presence/services/gps_service.dart'`. En `didChangeAppLifecycleState`, si `state == AppLifecycleState.detached`, se llama `unawaited(gps.stopTransmission(uid))` antes de `FirebaseAuth.instance.signOut()`, solo si `gps.activeUid != null`. |
| **Qué se corrigió (simple)** | Al cerrar sesión, `signOut()` revocaba el token de Firebase Auth antes de que el nodo RTDB se eliminara. Las llamadas de `stopTransmission` posteriores (o el handler `onDisconnect().remove()`) fallaban con 401 porque el token ya no era válido. El nodo quedaba con `activo: true` en RTDB aunque el vendedor hubiera cerrado sesión. Al cerrar la app abruptamente (`detached`), igual: `signOut()` se ejecutaba antes de intentar limpiar RTDB. Ahora en ambos flujos se elimina el nodo primero y se revoca el token después. |
| **Clase / Módulo** | `GPSService.activeUid` getter → `gps_service.dart`; `DrawerModule` botón logout → `drawer_module.dart`; `_UbiSafeAppState.didChangeAppLifecycleState` → `main.dart` |
| **Justificación** | El handler `onDisconnect().remove()` en `GPSService._subscribe()` cubre cierres abruptos donde el proceso muere sin ejecutar ningún código Dart. Sin embargo, para cierres normales (logout desde UI, `detached` lifecycle) el código sí se ejecuta, y el orden correcto es eliminar el nodo RTDB primero (con el token válido) y revocar el token después. |
| **Problema que resolvía** | El nodo del vendedor permanecía como activo en Firebase RTDB después de cerrar sesión o cerrar la app, causando que el comprador viera vendedores "fantasma" que ya no estaban disponibles. |

---

### C-79 · `VendorTracker` ignoraba silenciosamente nodos RTDB por casteo incorrecto de `Map` `2026-05-16`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-79 · VendorTracker casteo seguro `is Map` en lugar de `as Map<dynamic,dynamic>` |
| **Qué se corrigió (técnico)** | (1) En `VendorTracker()`, la expresión `.map((event) => event.snapshot.value as Map<dynamic, dynamic>? ?? {})` se reemplazó por `.map((event) { final v = event.snapshot.value; return v is Map ? v : const <Object?, Object?>{}; })`. (2) La firma `_init(Stream<Map<dynamic, dynamic>> stream)` se cambió a `_init(Stream<Map> stream)`. (3) El body del listener deja de usar `e.key as String` y `e.value as Map<dynamic, dynamic>`: ahora extrae `final key = e.key?.toString()` y verifica `if (key == null \|\| value is! Map) continue` antes de llamar `VendorMarker.fromMap(key, value)`. (4) `VendorTracker.fromStream` actualizado a `Stream<Map>`. (5) `VendorMarker.fromMap` cambia su parámetro de `Map<dynamic, dynamic>` a `Map`. |
| **Qué se corrigió (simple)** | El Firebase RTDB SDK a veces devuelve el nodo raíz como `Map<Object?,Object?>` en lugar de `Map<dynamic,dynamic>`. El casteo explícito `as Map<dynamic,dynamic>` lanzaba un `TypeError` en tiempo de ejecución; aunque el `try-catch` interior lo atrapaba, el efecto era que todos los nodos de vendedores se ignoraban silenciosamente. El comprador no veía marcadores aunque el vendedor estuviera activo en la base de datos. |
| **Clase / Módulo** | `VendorTracker._init()` + `VendorTracker()` + `VendorTracker.fromStream()` → `vendor_tracker.dart`; `VendorMarker.fromMap()` → `vendor_marker.dart` |
| **Justificación** | En Dart, `is Map` acepta cualquier instancia de `Map` independientemente de sus parámetros de tipo; el casteo con `as Map<T,U>` es estricto en runtime si el objeto real tiene tipos diferentes. El Firebase RTDB SDK usa internamente `LinkedHashMap<Object?,Object?>` cuando deserializa JSON anidado con claves secuenciales o mixtas, por lo que el casteo explícito era frágil. |
| **Problema que resolvía** | El vendedor activaba el radar, RTDB lo mostraba con `activo: true`, pero el mapa del comprador nunca mostraba el marcador. |

---

### C-80 · `onDisconnect().remove()` cancelado por cada `.set()` en `GPSService` — vendor fantasma al perder conexión `2026-05-16`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-80 · Re-registro de `onDisconnect` después de cada `set()` exitoso en GPSService |
| **Qué se corrigió (técnico)** | Se eliminó el `unawaited(_rtdbRefFactory(vendorUid).onDisconnect().remove()...)` que estaba al inicio de `GPSService._subscribe()`, antes de que el stream GPS emitiera. Ahora ese mismo handler se re-registra dentro del callback `.then(_)` que sigue a cada `ref.set({...})` exitoso, usando la referencia local `final ref = _rtdbRefFactory(vendorUid)` para evitar crear objetos redundantes. El `catchError` de debug se preserva. |
| **Qué se corrigió (simple)** | El protocolo de Firebase RTDB cancela cualquier handler `onDisconnect` registrado previamente cuando se llama `.set()` sobre la misma referencia. El handler se registraba una sola vez al inicio, antes del primer GPS write; en cuanto llegaba la primera coordenada y se ejecutaba `.set()`, el handler quedaba cancelado para siempre. Si el vendedor perdía la conexión a internet después de eso, su nodo permanecía en RTDB con `activo: true` indefinidamente (vendor fantasma). Al re-registrar el handler después de cada `set()` exitoso, el handler siempre está activo justo después de la última escritura conocida. |
| **Clase / Módulo** | `GPSService._subscribe()` → `gps_service.dart` (`ubisafe_app/lib/features/presence/services/gps_service.dart`) |
| **Justificación** | Documentado en la documentación interna de Firebase RTDB: cualquier `.set()`, `.update()`, o `.remove()` en una referencia cancela los `onDisconnect` handlers registrados en esa referencia o en rutas padre. El patrón correcto es re-registrar el handler inmediatamente después de cada write. |
| **Problema que resolvía** | Al perder conexión de golpe (sin código Dart ejecutándose), el nodo del vendedor quedaba activo en RTDB indefinidamente; el comprador veía un vendedor fantasma que no podía ser contactado. |

---

### C-81 · `vendor_has_active_requests` bloqueaba nuevas solicitudes por rides expirados sin limpiar `2026-05-16`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-81 · Filtro de `expires_at` en `vendor_has_active_requests` para rides/stops en estado `pending` vencidos |
| **Qué se corrigió (técnico)** | Se reemplazó el cuerpo de `FirestoreService.vendor_has_active_requests()`. Antes: `limit(1).stream()` seguido de `any(True for _ in docs)` — devolvía `True` al primer documento con status en `["pending","accepted","in_progress"]` sin importar su TTL. Ahora: `limit(10).stream()` con iteración manual; para cada documento con `status == "pending"` se extrae `expires_at` (manejando tanto `Firestore Timestamp` como ISO string), se convierte a `datetime` con zona UTC y se compara con `datetime.now(tz=UTC)`; si `expires_at < now` el documento se omite (`continue`). Los estados `"accepted"` e `"in_progress"` no tienen TTL automático y siempre bloquean. La misma lógica aplica al bloque de `stop_requests`. El helper `_is_expired_pending(data: dict) -> bool` encapsula la lógica de decisión. |
| **Qué se corrigió (simple)** | Cuando un ride de 60 segundos no se cerraba correctamente en el cliente (app cerrada abruptamente, fallo de red durante `expireRide()`), el documento en Firestore quedaba con `status: "pending"` pasada su fecha de expiración. En el siguiente intento del comprador de solicitar un raite al mismo vendedor, el backend encontraba ese documento "fantasma" y respondía 409 `vendor_not_available`, aunque el vendedor en realidad estuviera disponible. |
| **Clase / Módulo** | `FirestoreService.vendor_has_active_requests()` → `ubisafe_api/modules/shared/firestore_service.py` |
| **Justificación** | El único responsable de expirar rides es el timer de 60 segundos en Flutter (`RideRequestModule.startExpiryTimer()`). Si ese timer no se ejecuta (crash, red caída con error no-409), el documento `pending` queda en Firestore indefinidamente. El backend debe ignorar documentos `pending` cuyo `expires_at` ya pasó en lugar de depender exclusivamente del cliente para la limpieza. |
| **Problema que resolvía** | Al solicitar un raite, aparecía la notificación "el vendedor ya tiene otra solicitud activa" (HTTP 409 `vendor_not_available`) aunque el vendedor no tuviera ningún ride activo en curso. |

---

### C-82 · `create_stop_request` no escribía `created_at` en Firestore `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-82 · `created_at` y `updated_at` en `create_stop_request` |
| **Qué se corrigió (técnico)** | Se añadieron `data["created_at"] = SERVER_TIMESTAMP` y `data["updated_at"] = SERVER_TIMESTAMP` al diccionario que se pasa a `cls._db().collection("stop_requests").add(data)` en `FirestoreService.create_stop_request()` |
| **Qué se corrigió (simple)** | Al crear una solicitud de parada, el campo de fecha de creación ahora se guarda correctamente en Firestore; antes ese campo siempre llegaba como `null` al modelo Flutter y a cualquier historial |
| **Clase / Módulo** | `FirestoreService.create_stop_request()` → `ubisafe_api/modules/shared/firestore_service.py` |
| **Justificación** | El campo `created_at` está definido en el esquema Pydantic (`StopRequest`) y en el modelo Flutter (`StopRequest.createdAt`), pero nunca se escribía. El documento CU-01 §3.1 lo lista como obligatorio |
| **Problema que resolvía** | `StopRequest.createdAt` siempre era `null` en la app; imposible auditar cuándo se creó una solicitud o calcular tiempos de respuesta del vendedor |

---

### C-83 · `update_stop_status` no escribía `accepted_at` ni `completed_at` `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-83 · `accepted_at` / `completed_at` en transiciones de stop request |
| **Qué se corrigió (técnico)** | Se añadió lógica de `extra` en `stop_router.py`: `extra = {"accepted_at": True}` cuando `body.status == "accepted"` y `extra = {"completed_at": True}` cuando `body.status == "completed"`. Se extendió `FirestoreService.update_stop_status()` para aceptar un parámetro `extra: dict | None = None` y convertir sus valores `True` a `SERVER_TIMESTAMP` antes de llamar `ref.update()` |
| **Qué se corrigió (simple)** | Las marcas de tiempo de cuándo el vendedor aceptó la parada y cuándo la confirmó como entregada ahora se guardan en Firestore. Antes esos campos siempre eran `null` |
| **Clase / Módulo** | `update_stop_status()` en `PATCH /stops/{id}/status` → `ubisafe_api/modules/dispatching/router.py` · `FirestoreService.update_stop_status()` → `ubisafe_api/modules/shared/firestore_service.py` |
| **Justificación** | El flujo de raites ya hacía esto correctamente (`accepted_at`, `completed_at`); el flujo de paradas carecía del mismo mecanismo. Referencia: CU-01 §3.1 |
| **Problema que resolvía** | `StopRequest.acceptedAt` y `StopRequest.completedAt` siempre eran `null`; el historial no podía mostrar tiempos de aceptación ni de entrega |

---

### C-84 · `_doc_to_stop_request` no convertía `accepted_at` ni `completed_at` desde Timestamp `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-84 · Conversión de timestamps en `_doc_to_stop_request` |
| **Qué se corrigió (técnico)** | Se añadieron `"accepted_at"` y `"completed_at"` al loop de conversión de timestamps en `FirestoreService._doc_to_stop_request()`: `for field in ("created_at", "updated_at", "expires_at", "accepted_at", "completed_at")` |
| **Qué se corrigió (simple)** | Al leer un stop request de Firestore, los campos de tiempo de aceptación y de entrega ahora se convierten correctamente a strings ISO-8601 que el modelo Pydantic puede deserializar. Sin esta corrección, C-83 habría causado un `ValidationError` HTTP 500 en el primer stop aceptado o completado |
| **Clase / Módulo** | `FirestoreService._doc_to_stop_request()` → `ubisafe_api/modules/shared/firestore_service.py` |
| **Justificación** | Corrección bloqueante dependiente de C-83: sin ella, los `Timestamp` de Firestore de `accepted_at`/`completed_at` llegaban al constructor Pydantic como objetos nativos de Firestore, no como strings, causando un error de validación en producción |
| **Problema que resolvía** | Sin esta corrección, el endpoint `PATCH /stops/{id}/status` habría devuelto HTTP 500 al intentar serializar los nuevos timestamps introducidos por C-83 |

---

### C-85 · `_requestRoute` usaba `Dio()` sin timeout — `_acceptStop` podía colgarse indefinidamente `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-85 · Timeout en `Dio` de `_requestRoute` |
| **Qué se corrigió (técnico)** | Se reemplazó `final dio = Dio()` por `final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 10)))` en `_MapScreenVendorState._requestRoute()` |
| **Qué se corrigió (simple)** | La llamada a Google Directions API ahora tiene límite de tiempo. Antes, si la API no respondía, la función podía quedar esperando indefinidamente y el vendedor nunca veía el botón de "Confirmar entrega" aunque ya había aceptado la parada |
| **Clase / Método / Módulo** | `_MapScreenVendorState._requestRoute()` → `ubisafe_app/lib/features/dispatching/screens/map_screen_vendor.dart` |
| **Justificación** | El stop ya había sido marcado como `accepted` en el backend antes de llamar `_fetchRoute`. Si `_requestRoute` colgaba sin timeout, `_isNavigating` nunca se establecía en `true` y `_ConfirmDeliverySheet` nunca aparecía, dejando al comprador esperando indefinidamente en `TrackingScreen` |
| **Problema que resolvía** | Vendedor aceptaba la parada pero nunca veía el sheet de confirmar entrega; la app del comprador quedaba bloqueada en seguimiento sin que el flujo pudiera completarse |

---

### C-86 · FCM `ride_cancelled_by_buyer` stale reseteaba `_isNavigating` durante parada activa `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-86 · Guarda del listener `rideEventProvider` en `MapScreenVendor` |
| **Qué se corrigió (técnico)** | Se reemplazó la guarda `if (_activeRideId != null && event.rideId != _activeRideId) return;` por dos condiciones: `if (_activeRideId == null && event.rideId != _pendingDialogRideId) return;` seguida de `if (_activeRideId != null && event.rideId != _activeRideId) return;` en el `ref.listen<RideEvent?>` de `MapScreenVendor.build()` |
| **Qué se corrigió (simple)** | Un mensaje FCM tardío de cancelación de raite (de una operación anterior) ya no puede apagar el indicador de navegación de una parada activa. La guarda anterior permitía pasar el evento cuando no había raite activo (`_activeRideId == null`), haciendo que `_isNavigating = false` y eliminando el sheet de confirmar entrega |
| **Clase / Método / Módulo** | `ref.listen<RideEvent?>` en `_MapScreenVendorState.build()` → `ubisafe_app/lib/features/dispatching/screens/map_screen_vendor.dart` |
| **Justificación** | FCM puede llegar con retraso de segundos a minutos por condiciones de red. La guarda correcta es: si no hay raite activo NI un diálogo de raite abierto, ignorar cualquier evento de raite. Solo se procesa el evento si coincide con el raite o diálogo actualmente en curso |
| **Problema que resolvía** | Secuencia: vendor completa raite → acepta parada → FCM tardío de `ride_cancelled_by_buyer` del raite anterior llega → `_ConfirmDeliverySheet` desaparece → vendor no puede confirmar la entrega |

---

### C-87 · `historyProvider` excluía stop requests — solo consultaba la colección `rides` `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-87 · Stop requests incluidos en el historial de viajes |
| **Qué se corrigió (técnico)** | Se reemplazó la consulta única a `FirebaseFirestore.instance.collection('rides')` por dos consultas paralelas (`Future.wait`): una a `rides` (statuses: `completed`, `rejected`, `expired`) y otra a `stop_requests` (statuses: `completed`, `rejected`, `expired`, `cancelled`). Ambas usan el mismo `fieldToFilter` (`buyer_uid` para BUYER, `vendor_uid` para VENDOR). Los resultados se mezclan en una sola lista y se ordenan por `updated_at` en cliente. Se añadió el campo discriminador `'_type': 'ride'` / `'_type': 'stop'` a cada entrada para que el widget sepa qué etiqueta e ícono mostrar. El `itemBuilder` de `HistoryScreen` fue actualizado para manejar ambos tipos: paradas usan ícono `storefront_outlined` / `block_outlined` y etiquetas "Parada Completada", "Parada Rechazada", "Parada Expirada", "Parada Cancelada"; raites mantienen el comportamiento anterior. |
| **Qué se corrigió (simple)** | El historial de viajes ahora muestra tanto raites como solicitudes de parada. Antes solo aparecían raites porque el provider nunca consultaba la colección `stop_requests` |
| **Clase / Módulo** | `historyProvider` (FutureProvider) · `HistoryScreen` (itemBuilder) → `ubisafe_app/lib/features/identity/profile/screens/history_screen.dart` |
| **Justificación** | Las solicitudes de parada se almacenan en la colección `stop_requests`, separada de `rides`. El provider original consultaba únicamente `rides`, lo que hacía invisible cualquier interacción de parada. La consulta paralela con `Future.wait` evita latencia adicional. Se mantiene el ordenamiento en cliente para no requerir índices compuestos de Firestore (patrón establecido en C-04) |
| **Problema que resolvía** | Los usuarios (compradores y vendedores) no veían ningún registro de solicitudes de parada en su historial, aunque hubieran completado, rechazado o cancelado paradas |

---

### C-88 · Doble SnackBar "Tiempo de espera agotado" cuando timer y FCM `expired` coinciden `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-88 · Guard early-return en handler FCM `expired` del comprador |
| **Qué se corrigió (técnico)** | En el `ref.listen<StopEvent?>` de `MapScreenBuyer.build()`, el bloque `StopRequestStatus.expired` fue reorganizado: (1) se limpia el provider (`stopRequestEventProvider.state = null`) antes de cualquier otra acción; (2) se añadió `if (_mapState == _BuyerMapState.idle) return;` inmediatamente después, de modo que si el callback `onExpired()` del timer local ya procesó el evento (poniendo `_mapState` en `idle` y mostrando el primer SnackBar), el handler del FCM salga sin ejecutar `setState` ni mostrar un segundo SnackBar |
| **Qué se corrigió (simple)** | Cuando el timer de 60 s y el FCM `expired` llegaban en rápida sucesión, el comprador veía el mensaje "Tiempo de espera agotado" dos veces. Ahora solo aparece una vez |
| **Clase / Módulo** | `ref.listen<StopEvent?>` en `_MapScreenBuyerState.build()` → `ubisafe_app/lib/features/dispatching/screens/map_screen_buyer.dart` |
| **Justificación** | El timer local ejecuta `onExpired()` → `_mapState = idle`. Cuando el FCM llega después, la guarda `_activeStopId != null && ...` ya no filtra porque `_activeStopId` fue limpiado. El chequeo de `_mapState == idle` es la señal definitiva de que el evento ya fue procesado localmente |
| **Problema que resolvía** | El comprador veía el SnackBar "Tiempo de espera agotado" dos veces en rápida sucesión |

---

### C-89 · `_activeStopId` no se limpiaba al recibir FCM `accepted` en `MapScreenBuyer` `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-89 · Limpiar `_activeStopId` en transición `accepted` |
| **Qué se corrigió (técnico)** | Se reemplazó `setState(() => _mapState = _BuyerMapState.idle)` por `setState(() { _mapState = _BuyerMapState.idle; _activeStopId = null; })` en la rama `StopRequestStatus.accepted` del listener `stopRequestEventProvider` en `MapScreenBuyer` |
| **Qué se corrigió (simple)** | Al aceptar una parada, el ID de la solicitud activa ahora se limpia correctamente. Antes se dejaba el valor antiguo, lo que podía hacer que FCM stale del stop anterior filtraran incorrectamente al volver de `TrackingScreen` |
| **Clase / Módulo** | `ref.listen<StopEvent?>` en `_MapScreenBuyerState.build()` → `ubisafe_app/lib/features/dispatching/screens/map_screen_buyer.dart` |
| **Justificación** | Aunque en la práctica no producía un crash (la nueva solicitud sobreescribía `_activeStopId`), dejaba una ventana temporal donde FCM tardíos del stop aceptado podrían ser procesados de nuevo por `MapScreenBuyer` mientras `TrackingScreen` todavía está activa en el stack |
| **Problema que resolvía** | `_activeStopId` quedaba con el ID de la parada aceptada mientras el comprador estaba en `TrackingScreen`, exponiendo al listener a procesar eventos stale de ese mismo stop |

---

### C-90 · `onExpired()` no garantizado si `expireStopRequest` lanza excepción no-`DioException` `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-90 · `finally` en timer de expiración de stop request |
| **Qué se corrigió (técnico)** | Se movió `onExpired()` de fuera del bloque `try/catch` a un bloque `finally`, de modo que se ejecute siempre, independientemente de si `expireStopRequest` lanza `DioException` u cualquier otra excepción |
| **Qué se corrigió (simple)** | Si la llamada de expiración al backend fallaba con un error inesperado (no de red), la UI del comprador quedaba bloqueada permanentemente en estado "esperando". Ahora `onExpired()` se garantiza siempre |
| **Clase / Módulo** | `StopRequestModule.startTimer()` → `ubisafe_app/lib/features/dispatching/services/stop_request_module.dart` |
| **Justificación** | El `catch` solo capturaba `DioException`. Cualquier otro error (serialización, error de Dart runtime) se propagaba sin ejecutar `onExpired()`, dejando `_mapState` en `waiting` indefinidamente. Con `finally` se garantiza la limpieza de la UI en cualquier escenario |
| **Problema que resolvía** | En el escenario (muy poco probable) de error no-Dio, el comprador no podía solicitar ninguna parada más porque `_mapState` quedaba atascado en `waiting` |

---

### C-91 · Verificación de proximidad 15 m se saltaba si `_buyerLat`/`_buyerLng` eran `null` `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-91 · Guard fail-fast para coordenadas nulas en `_confirmDelivery` |
| **Qué se corrigió (técnico)** | Se reemplazó `if (_buyerLat != null && _buyerLng != null) { ... check de 15 m ... }` por `if (_buyerLat == null \|\| _buyerLng == null) { SnackBar + return; }` seguido del check de distancia sin envoltura condicional. Con el nuevo código, si las coordenadas son `null`, se muestra "Error: coordenadas del comprador no disponibles." y se cancela la operación; si no son `null`, el check de 15 m siempre se ejecuta antes de llamar `completeStopRequest` |
| **Qué se corrigió (simple)** | Si por algún motivo las coordenadas del comprador no estaban disponibles, el vendedor podía confirmar la entrega sin validación de distancia. Ahora esa situación es un error explícito que bloquea la confirmación |
| **Clase / Módulo** | `_MapScreenVendorState._confirmDelivery()` → `ubisafe_app/lib/features/dispatching/screens/map_screen_vendor.dart` |
| **Justificación** | En el flujo normal `_buyerLat`/`_buyerLng` nunca son `null` al llegar a `_confirmDelivery` (se establecen junto con `_isNavigating = true`). Sin embargo, tratarlos como opcionales con la guarda anterior los convertía en efectivamente ignorables. El estado inválido debe bloquear, no pasar silencioso |
| **Problema que resolvía** | Estado inválido (`_buyerLat == null` mientras `_isNavigating == true`) podía causar que `completeStopRequest` se llamara sin verificar la distancia de 15 m |

---

### C-92 · `update_stop_status_if_pending` no era atómico — race condition entre `expired` y `accepted` `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-92 · Transacción Firestore en `update_stop_status_if_pending` |
| **Qué se corrigió (técnico)** | Se reemplazó el patrón check-then-act (`ref.get()` + `ref.update()`) por una función `_txn` decorada con `@fs_transactional` de `google.cloud.firestore`. La transacción lee el documento, verifica que `status == "pending"` y escribe el nuevo status — todo de forma atómica en el servidor. Si la transacción detecta que ya no es `pending`, retorna `(doc, False)` sin escribir. El documento actualizado se lee en una segunda operación fuera de la transacción (las transacciones de Firestore Python no permiten leer después de escribir en el mismo scope) |
| **Qué se corrigió (simple)** | Existía una ventana de tiempo en la que el timer del comprador y el PATCH del vendedor podían leer simultáneamente `status: "pending"` y ambos creer que ganaban la carrera, resultando en que `expired` sobreescribía `accepted`. Con la transacción, solo una operación puede ganar |
| **Clase / Módulo** | `FirestoreService.update_stop_status_if_pending()` → `ubisafe_api/modules/shared/firestore_service.py` |
| **Justificación** | El documento CU-01 §5.1 describe esta función como "transacción atómica", pero el código original era un read-then-write no atómico. La misma función `vote_community_report` ya usaba `@fs_transactional` como referencia de patrón correcto en el proyecto |
| **Problema que resolvía** | En el escenario de race condition (vendor acepta en el último segundo mientras el timer del buyer dispara), `expired` podía sobreescribir `accepted` en Firestore, dejando al comprador en `TrackingScreen` con un stop ya expirado del que no podía salir |

---

### C-93 · Diálogo de parada se cerraba antes de verificar GPS — vendedor no podía reintentar `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-93 · Verificación de GPS antes de cerrar el diálogo en `onAccept` de parada |
| **Qué se corrigió (técnico)** | En el callback `onAccept` dentro de `_showIncomingDialog`, se añadió un check `ref.read(gpsServiceProvider).valueOrNull` al inicio, antes de `setState` y `Navigator.pop()`. Si `position == null`, se muestra el SnackBar "GPS no disponible" y se hace `return` sin cerrar el diálogo, dejándolo abierto. Solo si el GPS está disponible se procede con `setState`, `Navigator.pop()` y `_acceptStop`. El check de GPS que ya existía en `_acceptStop` se mantiene como defensa secundaria ante la pequeña ventana en que el GPS podría apagarse entre el check del callback y la ejecución de `_acceptStop` |
| **Qué se corrigió (simple)** | Antes, cuando el vendedor presionaba "Aceptar" sin GPS, el diálogo se cerraba y mostraba el error — pero la solicitud seguía en estado `pending` sin que el vendedor pudiera volver a aceptarla. Ahora el diálogo permanece abierto y el vendedor puede activar el GPS y volver a intentarlo |
| **Clase / Módulo** | `_MapScreenVendorState._showIncomingDialog()` — callback `onAccept` → `ubisafe_app/lib/features/dispatching/screens/map_screen_vendor.dart` |
| **Justificación** | El patrón correcto es validar las precondiciones antes de ejecutar acciones irreversibles como cerrar un diálogo. `Navigator.pop()` antes del check de GPS hacía que el vendedor perdiera la ventana de 60 s para aceptar si el GPS tardaba en inicializarse |
| **Problema que resolvía** | El vendedor veía el error "GPS no disponible" con el diálogo ya cerrado y sin posibilidad de reintentar; debía esperar los 60 s a que el stop expirara para poder atender la siguiente solicitud |

---

### C-94 · FCM enviaba mensajes con `notification` body en lugar de data-only `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-94 · Mensajes FCM convertidos a data-only en `NotificationService.send()` |
| **Qué se corrigió (técnico)** | Se eliminó `notification=messaging.Notification(title=title, body=body)` del constructor `fcm.Message()` en `NotificationService.send()`. El `Message` ahora solo contiene el campo `data`, convirtiéndose en un mensaje data-only. Los parámetros `title` y `body` se conservan en la firma del método para no romper los call-sites (`send_async`, `send_to_user` y todos los `send_stop_*` / `send_ride_*`), pero ya no se incluyen en el mensaje enviado a FCM |
| **Qué se corrigió (simple)** | Los mensajes FCM que llegaban con `notification` body hacían que Android/iOS mostraran una notificación del SO. Si el usuario abría la app por otra vía (sin tocar la notificación), el evento ya no disparaba los providers de Riverpod; si luego tocaba la notificación guardada en la barra, se abría un diálogo para un stop ya expirado. Con mensajes data-only Flutter siempre procesa el payload en `onMessage` (foreground) y de forma idéntica en ambos casos |
| **Clase / Módulo** | `NotificationService.send()` → `ubisafe_api/modules/shared/notification_service.py` |
| **Justificación** | El documento CU-01 §5.3 especifica mensajes data-only. La discrepancia causaba notificaciones del SO que podían redirigir al usuario a un diálogo stale vía `onMessageOpenedApp`. Los multicast (`send_community_report_nearby`, `notify_risk_zone_alert`) ya eran data-only; este cambio homogeniza el comportamiento de todos los mensajes unicast |
| **Problema que resolvía** | Posible doble UI (notificación del SO + diálogo in-app en foreground) y eventos stale procesados al tocar notificaciones antiguas en la barra del SO |

---

### C-95 · Transiciones no-`expired` del stop request no eran atómicas — `accepted` podía sobrescribir `expired` `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-95 · Atomic update para todas las transiciones de stop request con `update_stop_status_if_in_state` |
| **Qué se corrigió (técnico)** | Se agregó `FirestoreService.update_stop_status_if_in_state(stop_id, from_status, new_status, extra)` en `firestore_service.py`. Este método ejecuta en una transacción Firestore: lee el documento, verifica que el estado actual sea `from_status`, y solo entonces aplica la escritura atómica. El router (`router.py`) se actualizó para usar esta función en todas las transiciones no-`expired` (`accepted`, `rejected`, `completed`, `cancelled`) en lugar del antiguo `update_stop_status` que era un read-then-write sin transacción. La función `update_stop_status_if_pending` se refactorizó como un thin-wrapper sobre la nueva función genérica. |
| **Qué se corrigió (simple)** | Antes, cuando el comprador enviaba el PATCH `expired` y el vendedor enviaba el PATCH `accepted` casi al mismo tiempo (ventana de milisegundos), el `accepted` podía sobrescribir el `expired` ya comprometido por la transacción, porque `update_stop_status` escribía sin verificar el estado actual. Ahora cada transición verifica atómicamente que el estado en Firestore aún sea el estado origen esperado antes de escribir; si no coincide, retorna 409. |
| **Clase / Módulo** | `FirestoreService.update_stop_status_if_in_state()` → `ubisafe_api/modules/shared/firestore_service.py`; `update_stop_status()` en router → `ubisafe_api/modules/dispatching/router.py` |
| **Justificación** | La corrección C-92 hizo atómica la transición `pending → expired` pero dejó las demás transiciones vulnerables al mismo TOCTOU entre el check de `VALID_TRANSITIONS` y la escritura a Firestore. El síntoma reportado era que el vendedor podía "aceptar" una parada ya expirada si tocaba el botón en el intervalo exacto en que la transacción de expiración estaba en vuelo. |
| **Problema que resolvía** | El vendedor podía aceptar una parada cuyo estado ya era `expired` en Firestore, lo que generaba inconsistencia de estado y llevaba a ambos lados a la pantalla de entrega aunque la parada había expirado. |

---

### C-96 · `stop_request_accepted` FCM tardío navegaba al comprador a `/tracking` después de que el timer local ya expiró `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-96 · Guard `_mapState == waiting` en handler `stop_request_accepted` del comprador |
| **Qué se corrigió (técnico)** | En `map_screen_buyer.dart`, el listener de `stopRequestEventProvider` para `StopRequestStatus.accepted` ahora verifica `_mapState == _BuyerMapState.waiting` antes de procesar el evento. Si `_mapState != waiting` (porque `onExpired()` del timer local ya ejecutó y llevó el estado a `idle`), el evento se descarta con un clear del provider. |
| **Qué se corrigió (simple)** | Cuando el timer local del comprador disparaba `onExpired()`, `_activeStopId` quedaba en `null`. La guarda original (`if (_activeStopId != null && event.stopId != _activeStopId) return`) dejaba de funcionar con `_activeStopId == null` porque la condición siempre evaluaba `false`. Un FCM `stop_request_accepted` llegado después de que el timer expiró pasaba la guarda y enviaba al comprador a `/tracking` aunque el stop ya había sido expirado localmente. |
| **Clase / Módulo** | `_MapScreenBuyerState` — listener de `stopRequestEventProvider` → `ubisafe_app/lib/features/dispatching/screens/map_screen_buyer.dart` |
| **Justificación** | El estado `_mapState` es la fuente de verdad del estado de la UI del comprador. Si ya es `idle` cuando llega el `accepted`, significa que el comprador ya resolvió el stop (sea por timer o por FCM `expired`); cualquier `accepted` posterior es stale y debe descartarse. |
| **Problema que resolvía** | Cuando el vendedor aceptaba una parada cuyo estado en el comprador ya era `idle` (post-timer), el comprador navegaba a la pantalla de tracking y el vendedor al panel de entrega, generando un estado inconsistente de "entrega activa" en una parada ya expirada. |

---

### C-97 · `_buildAvoidWaypoints` generaba waypoints para zonas HIGH fuera de la ruta `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-97 · Filtro de intersección ruta–zona en `_buildAvoidWaypoints` |
| **Qué se corrigió (técnico)** | Se reemplazó `return highZones.map((z) { ... }).toList()` por un bucle `for` con filtro previo. Antes de generar un waypoint para una zona HIGH, se proyecta el centro de la zona sobre el segmento origen→destino (parámetro `t ∈ [0,1]` mediante producto punto), se calcula la distancia perpendicular del centro al segmento en espacio métrico, y solo si esa distancia `≤ z.radiusMeters` (la zona intersecta el trayecto) se genera el waypoint de desvío. Zonas fuera del trayecto son ignoradas con `continue`. |
| **Qué se corrigió (simple)** | Cuando había una zona de riesgo HIGH activa en cualquier punto dentro del radio de 5 km (aunque estuviera a kilómetros del trayecto real), la ruta del vendedor se desviaba hasta esa zona antes de llegar al comprador. Ahora solo se generan desvíos para las zonas que realmente cruzan el camino origen→destino. |
| **Clase / Método / Módulo** | `_buildAvoidWaypoints()` (función top-level) → `ubisafe_app/lib/features/dispatching/screens/map_screen_vendor.dart` |
| **Justificación** | El parámetro `waypoints` de Google Directions API fuerza la ruta a pasar POR esos puntos, no a evitarlos. El waypoint se coloca cerca del centro de la zona (desplazado perpendicularmente `radiusMeters + 50 m`). Si la zona está fuera del trayecto, el waypoint queda en una ubicación aleatoria respecto a la ruta real, causando que Google enrute a esa zona antes de seguir al destino. El filtro de intersección evita generar waypoints para zonas que no bloquean el trayecto. |
| **Problema que resolvía** | Con una o más zonas HIGH activas en el área, la ruta trazada en el mapa del vendedor se desviaba hasta esas zonas en lugar de ir directamente al comprador. |

---

### C-98 · Comprador podía solicitar parada o raite estando dentro de una zona de alto riesgo `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-98 · Bloqueo de solicitudes desde zona HIGH en `_onVendorTap` |
| **Qué se corrigió (técnico)** | Se añadió el import `../../safety/models/risk_zone.dart` a `map_screen_buyer.dart`. En `_MapScreenBuyerState._onVendorTap`, antes de abrir el `_VendorBottomSheet`, se lee el valor en caché de `activeRiskZonesProvider(LatLng(buyerLat, buyerLng)).valueOrNull`. Si las zonas están disponibles y alguna tiene `riskLevel == 'HIGH'` con `Geolocator.distanceBetween(buyerLat, buyerLng, z.latitude, z.longitude) ≤ z.radiusMeters`, se muestra un SnackBar "No puedes solicitar desde una zona de alto riesgo." y se retorna sin abrir el bottom sheet. Si el provider aún no ha cargado las zonas (`valueOrNull == null`), el bloqueo se omite para no penalizar el arranque frío. |
| **Qué se corrigió (simple)** | El comprador podía tocar un vendedor y solicitar parada o raite aunque estuviera parado dentro del círculo rojo de una zona de alto riesgo. Ahora el tap queda bloqueado con un mensaje de error antes de que se abra el menú de opciones. |
| **Clase / Método / Módulo** | `_MapScreenBuyerState._onVendorTap()` → `ubisafe_app/lib/features/dispatching/screens/map_screen_buyer.dart` |
| **Justificación** | Enviar al vendedor hacia una zona HIGH activa es el escenario exacto que el sistema de zonas de riesgo pretende evitar. El bloqueo en `_onVendorTap` (antes del bottom sheet) da retroalimentación inmediata al comprador sin necesitar una ida-vuelta al backend. Se usa `valueOrNull` sobre el provider ya watcheado en `build()`, que en condiciones normales ya tiene el valor cacheado al momento del tap. |
| **Problema que resolvía** | Un comprador dentro de una zona de alto riesgo podía solicitar parada o raite normalmente; el flujo completo llegaba al vendedor, quien navegaba hacia la zona de peligro sin advertencia. |

### C-99 · `_buildFallbackDrawer` cerraba sesión sin detener transmisión RTDB `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-99 · `stopTransmission` antes de `signOut` en `_buildFallbackDrawer` |
| **Qué se corrigió (técnico)** | En `_buildFallbackDrawer` el `onPressed` del botón "Cerrar Sesión" solo llamaba `await ref.read(authModuleProvider).signOut()`. Se añadió el mismo patrón que el drawer normal: `ref.read(gpsServiceInstanceProvider)` → verificar `activeUid != null` → `await gps.stopTransmission(uid)` → `signOut()`. |
| **Qué se corrigió (simple)** | Cuando el perfil no cargaba (sin red, API caída) y el vendor cerraba sesión desde el drawer de error, el nodo `vendedores_activos/{uid}` quedaba activo en RTDB indefinidamente porque el token se invalidaba antes de que se pudiera eliminar el nodo. |
| **Clase / Método / Módulo** | `_DrawerModuleState._buildFallbackDrawer()` → `ubisafe_app/lib/features/identity/profile/widgets/drawer_module.dart` |
| **Justificación** | `stopTransmission` usa un timeout de 2 s con fire-and-forget, y el `onDisconnect().remove()` limpia el nodo cuando se recupera la conexión. Hacer el stop antes del signOut garantiza que el token aún es válido cuando se intenta la eliminación del nodo, maximizando la probabilidad de éxito. |
| **Problema que resolvía** | Un vendor sin red que cerrara sesión dejaba su marcador visible en el mapa de los compradores hasta que la RTDB detectara la desconexión, que podía tardar minutos. |

---

### C-100 · `_toggleRideEnabled` no actualizaba `_rideEnabledSet` cuando GPS estaba inactivo `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-100 · Condición incorrecta en `_toggleRideEnabled` para llamar `updateRideEnabled` |
| **Qué se corrigió (técnico)** | Se eliminó la guardia `if (ref.read(gpsServiceProvider).valueOrNull != null)` que envolvía la llamada a `ref.read(gpsServiceInstanceProvider).updateRideEnabled(uid, value)`. Ahora se llama incondicionalmente. `updateRideEnabled` ya tiene su propia guardia interna (`if (_activeUid != vendorUid) return`) que omite la escritura RTDB cuando no hay transmisión activa, pero siempre asigna `_rideEnabled = value` y `_rideEnabledSet = true`. |
| **Qué se corrigió (simple)** | Si el vendor cambiaba el switch "Ofrecer Raites" con el GPS desactivado, el toggle no se persistía en el objeto `GPSService`. Cuando después activaba el GPS, `startTransmission` veía `_rideEnabledSet == false` y sobreescribía el valor del switch con el valor del perfil de Firestore, deshaciendo la elección explícita del vendor. |
| **Clase / Método / Módulo** | `_DrawerModuleState._toggleRideEnabled()` → `ubisafe_app/lib/features/identity/profile/widgets/drawer_module.dart` |
| **Justificación** | `gpsServiceProvider` es un `StreamProvider<Position?>` que emite null mientras no hay GPS activo. La condición original verificaba la disponibilidad de posición, no si la transmisión RTDB estaba activa. Llamar `updateRideEnabled` siempre es seguro porque la guardia interna de GPSService ya maneja el caso sin transmisión. |
| **Problema que resolvía** | El vendor ajustaba su disponibilidad para raites con GPS apagado, pero al encender el GPS el valor se revertía al último leído desde Firestore. |

---

### C-101 · `last_location` nunca escrito → notificaciones FCM de proximidad nunca enviadas `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-101 · Endpoint `PATCH /auth/location` + `locationSyncProvider` (B15) |
| **Qué se corrigió (técnico)** | **Backend:** Se añadió `UpdateLocationBody(lat, lng)` a `identity/schemas.py`. Se añadió el endpoint `PATCH /auth/location` (HTTP 204) a `identity/router.py`. Se añadió `FirestoreService.update_user_location(uid, lat, lng)` que escribe `{"last_location": {"lat": ..., "lng": ...}, "last_location_at": SERVER_TIMESTAMP, "updated_at": SERVER_TIMESTAMP}` con `merge=True`. **Flutter:** Se añadió `locationSyncProvider` (`Provider.autoDispose`) a `gps_service.dart`. Usa `ref.listen` sobre `gpsServiceProvider` y llama al endpoint con throttle (≥100 m **o** ≥60 s entre llamadas). Se activó con `ref.watch(locationSyncProvider)` en los métodos `build` de `MapScreenVendor` y `MapScreenBuyer`. |
| **Qué se corrigió (simple)** | `FirestoreService.get_nearby_user_fcm_tokens()` filtraba usuarios por `last_location` pero ese campo nunca se escribía en Firestore (el GPS del vendor va a RTDB, no a Firestore). Resultado: la función siempre retornaba `[]` y ningún usuario recibía notificaciones FCM de proximidad para zonas de riesgo ni reportes comunitarios. |
| **Clase / Método / Módulo** | `PATCH /auth/location` → `ubisafe_api/modules/identity/router.py` · `FirestoreService.update_user_location` → `firestore_service.py` · `locationSyncProvider` → `ubisafe_app/lib/features/presence/services/gps_service.dart` · `MapScreenVendor.build` + `MapScreenBuyer.build` |
| **Justificación** | La opción elegida (nuevo endpoint API en lugar de escritura directa a Firestore desde Flutter) mantiene todas las escrituras a Firestore en la capa de API, consistente con el ADR #2. El throttle (100 m / 60 s) minimiza tráfico sin sacrificar precisión para notificaciones de proximidad al radio estándar de 5 km. El provider es `autoDispose` para que se inactive cuando ningún map screen está en pantalla. |
| **Problema que resolvía** | Reportes comunitarios y zonas de riesgo no enviaban notificaciones FCM a ningún usuario, independientemente de su distancia al evento. |

### C-102 · `upsert_user` guardaba `role` en minúsculas — check de rol en backend era case-sensitive `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-102 · Normalización de `role` a mayúsculas en `upsert_user` (B16) |
| **Qué se corrigió (técnico)** | En `FirestoreService.upsert_user`, tras `body.model_dump(exclude_none=True)`, se añadió: `if "role" in data and isinstance(data["role"], str): data["role"] = data["role"].upper()`. La normalización ocurre antes de la escritura a Firestore, por lo que todos los documentos nuevos y actualizados quedan con `role` en mayúsculas. |
| **Qué se corrigió (simple)** | Si el cliente enviaba `role: "vendor"` (minúsculas), Firestore lo guardaba en minúsculas. `DrawerModule` mostraba el switch "Ofrecer Raites" porque acepta ambos casos, pero `PATCH /auth/ride-enabled` respondía 403 porque solo comparaba con `"VENDOR"` en mayúsculas. El vendor veía el toggle revertirse sin explicación. |
| **Clase / Método / Módulo** | `FirestoreService.upsert_user()` → `ubisafe_api/modules/shared/firestore_service.py` |
| **Justificación** | Normalizar en escritura es más robusto que normalizar en cada comparación: garantiza consistencia en Firestore independientemente de cuántos endpoints lean el campo. |
| **Problema que resolvía** | Vendors con `role: "vendor"` en minúsculas no podían activar la visibilidad de raites; el toggle se revertía con un 403 silencioso. |

---

### C-103 · `_toggleRideEnabled` silenciaba el error sin feedback al vendor `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-103 · SnackBar de error en `_toggleRideEnabled` (B17) |
| **Qué se corrigió (técnico)** | Se capturó `ScaffoldMessenger.of(context)` en `messenger` antes del `await` (patrón correcto para evitar `use_build_context_synchronously`). En el bloque `catch`, tras el rollback visual `setState(() => _rideEnabled = !value)`, se añadió `messenger.showSnackBar(const SnackBar(content: Text('No se pudo actualizar. Intenta de nuevo.')))`. |
| **Qué se corrigió (simple)** | Al fallar el PATCH (sin red, 403, 5xx), el switch se revertía visualmente pero el vendor no recibía ningún mensaje. Ahora aparece un SnackBar explicando que el cambio no se aplicó. |
| **Clase / Método / Módulo** | `_DrawerModuleState._toggleRideEnabled()` → `ubisafe_app/lib/features/identity/profile/widgets/drawer_module.dart` |
| **Justificación** | Capturar `ScaffoldMessengerState` antes del gap asíncrono es el patrón recomendado por el linter (`use_build_context_synchronously`): el objeto capturado sigue siendo válido tras el await sin necesitar verificar `context.mounted`. |
| **Problema que resolvía** | El vendor veía el toggle regresar a su posición anterior sin saber si fue un problema de red o un rechazo del servidor, llevándolo a reintentar repetidamente. |

### C-104 · `create_risk_zone` notificaba a todos los usuarios en lugar de los cercanos (B18) `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-104 · `get_all_fcm_tokens` → `get_nearby_user_fcm_tokens` en `POST /risk-zones` (B18) |
| **Qué se corrigió (técnico)** | En `safety/router.py`, `create_risk_zone()`: se reordenó `loc = zone.location` para quedar antes de la llamada a tokens, y se reemplazó `await FirestoreService.get_all_fcm_tokens()` por `await FirestoreService.get_nearby_user_fcm_tokens(loc.lat, loc.lng, radius_km=5.0)`. En `tests/test_risk_zones.py` se actualizó la constante `_GET_TOKENS` de `FirestoreService.get_all_fcm_tokens` a `FirestoreService.get_nearby_user_fcm_tokens` para que el mock intercepte la llamada correcta. |
| **Qué se corrigió (simple)** | Al crear una zona de riesgo, el backend enviaba la notificación FCM a todos los usuarios del sistema sin importar su distancia. La corrección C-10 documentada en el REGISTRO_CORRECCIONES había sido implementada en `FirestoreService` pero nunca aplicada en el endpoint que la invoca. Ahora solo los usuarios dentro de 5 km del punto reportado reciben la alerta. |
| **Clase / Método / Módulo** | `create_risk_zone()` → `ubisafe_api/modules/safety/router.py` · `test_create_zone_success` → `tests/test_risk_zones.py` |
| **Justificación** | `get_nearby_user_fcm_tokens` ya existía (implementada para C-10) pero nunca se llamaba desde el único endpoint que debía usarla. El test también apuntaba al mock antiguo, lo que ocultaba el bug en el suite de pruebas. Ambos se corrigen juntos para que el test sea un indicador real de regresión. |
| **Problema que resolvía** | Todos los usuarios con token FCM recibían alertas de zonas de riesgo independientemente de su proximidad, generando spam de notificaciones. |

### C-105 · `activeRiskZonesProvider` disparaba GET /risk-zones en cada fix GPS (B19) `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-105 · Opción B — `activeRiskZonesProvider` sin `family<LatLng>` (B19) |
| **Qué se corrigió (técnico)** | Se rediseñó `activeRiskZonesProvider` en `risk_zone_service.dart`: de `FutureProvider.autoDispose.family<List<RiskZone>, LatLng>` a `FutureProvider.autoDispose<List<RiskZone>>`. Internamente usa `ref.read(gpsServiceProvider).valueOrNull` (no `watch`) para leer la posición una sola vez en cada ejecución. El import de `google_maps_flutter` se eliminó y se añadió `gps_service.dart`. En `map_screen_buyer.dart`: `ref.watch(activeRiskZonesProvider(LatLng(...)))` → `ref.watch(activeRiskZonesProvider)` (render de círculos) y `ref.read(activeRiskZonesProvider(LatLng(buyerLat, buyerLng))).valueOrNull` → `ref.read(activeRiskZonesProvider).valueOrNull` (bloqueo C-98). En `map_screen_vendor.dart`: mismo cambio en el render de círculos y en `ref.read(activeRiskZonesProvider.future)` para la lógica de waypoints. Los `ref.invalidate(activeRiskZonesProvider)` en ambas pantallas y en `notification_handler.dart` no requirieron cambios. |
| **Qué se corrigió (simple)** | `GPSService` emite una posición cada ~1 s con `distanceFilter: 0`. Como la clave del `family` era el `LatLng` exacto, cada posición nueva creaba una instancia nueva del provider y disparaba un `GET /risk-zones`. Resultado: ~60 requests/minuto por usuario con GPS activo. Ahora el provider solo se recarga en dos casos: al abrir la pantalla por primera vez, o al recibir un FCM `risk_zone_alert`. |
| **Clase / Método / Módulo** | `activeRiskZonesProvider` → `ubisafe_app/lib/features/safety/services/risk_zone_service.dart` · call sites en `map_screen_buyer.dart` · `map_screen_vendor.dart` |
| **Justificación** | Opción B elegida: eliminar el parámetro `LatLng` del family y leer la posición con `ref.read` (no `ref.watch`) dentro del provider. Esto rompe la dependencia reactiva con el stream GPS y hace que el provider sea controlado únicamente por `riskZoneRefreshProvider` (señal de eventos explícitos). El comportamiento funcional es idéntico — las zonas se actualizan al abrir la pantalla y al recibir FCM — sin el bucle de polling accidental. |
| **Problema que resolvía** | En demostración con la API de Render, el endpoint `GET /risk-zones` recibía ~60 requests/minuto por usuario activo, saturando el plan gratuito y consumiendo batería del dispositivo innecesariamente. |

### C-106 · `_bbox_delta()` usaba el mismo factor m/° para latitud y longitud (B20) `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-106 · `_bbox_delta` con corrección coseno para longitud (B20) |
| **Qué se corrigió (técnico)** | En `safety/router.py`: `_bbox_delta(radius_meters)` pasó a `_bbox_delta(radius_meters, lat) → tuple[float, float]`. Calcula `lat_delta = radius_meters / 111_000` y `lng_delta = radius_meters / (111_000 * math.cos(math.radians(lat)))`. En `create_risk_zone` se desempaca la tupla: `lat_delta, lng_delta = _bbox_delta(body.radius_meters, body.location.lat)` y se pasan ambos valores a `FirestoreService.query_active_risk_zones_bbox(lat, lng, lat_delta, lng_delta)`. En `firestore_service.py`: `query_active_risk_zones_bbox(cls, lat, lng, delta)` → `(cls, lat, lng, lat_delta, lng_delta)`, y el filtro usa `abs(zone_lat - lat) <= lat_delta and abs(zone_lng - lng) <= lng_delta`. |
| **Qué se corrigió (simple)** | El bounding box de deduplicación usaba el mismo delta en grados para latitud y longitud. Como un grado de longitud equivale a menos metros conforme aumenta la latitud (`m/° = 111 000 × cos(lat)`), el bbox era ~10% más estrecho en sentido este-oeste en Monterrey (~25°N). Una zona a 96 m al este podía quedar fuera del bbox, saltar la verificación Haversine y crear una zona duplicada. |
| **Clase / Método / Módulo** | `_bbox_delta()` + `create_risk_zone()` → `ubisafe_api/modules/safety/router.py` · `query_active_risk_zones_bbox()` → `firestore_service.py` |
| **Justificación** | El factor de corrección `cos(lat)` es el estándar para convertir distancia en metros a grados de longitud. No afecta la latitud (cuya escala es constante). El único llamador de `_bbox_delta` es `create_risk_zone`, por lo que el cambio de firma no rompe ningún otro código. |
| **Problema que resolvía** | Zonas duplicadas podían crearse cerca del borde este-oeste del radio de deduplicación a latitudes distintas de 0°. |

---

### C-107 · `DELETE /risk-zones/{id}` sobreescribía `expired_at` si la zona ya estaba inactiva (B21) `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-107 · Guard `zone.active` en `expire_risk_zone` (B21) |
| **Qué se corrigió (técnico)** | En `expire_risk_zone()` de `safety/router.py`, tras el check de propietario se añadió: `if not zone.active: raise HTTPException(status_code=HTTP_409_CONFLICT, detail="Risk zone is already expired")`. Se añadió el test `test_expire_zone_already_expired_returns_409` en `tests/test_risk_zones.py` que verifica el 409 cuando la zona tiene `active=False`. |
| **Qué se corrigió (simple)** | Llamar `DELETE /risk-zones/{id}` dos veces (doble tap o retry automático) sobreescribía el campo `expired_at` original con la hora de la segunda llamada, corrompiendo el registro histórico de cuándo se expiró la zona. Ahora la segunda llamada devuelve 409 y no modifica Firestore. |
| **Clase / Método / Módulo** | `expire_risk_zone()` → `ubisafe_api/modules/safety/router.py` · `test_expire_zone_already_expired_returns_409` → `tests/test_risk_zones.py` |
| **Justificación** | El patrón estándar para operaciones idempotentes que no deben ejecutarse dos veces es 409 Conflict. Retornar 204 en la segunda llamada daría la falsa impresión de éxito mientras corrompe datos de auditoría silenciosamente. |
| **Problema que resolvía** | Un doble tap o un retry automático en red lenta corrompía el `expired_at` original de la zona, perdiendo información de auditoría sobre cuándo fue desactivada. |

---

### C-108 · `RideStatus` Flutter sin `cancelled` → estado del vendedor no se limpiaba (B22) `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-108 · Añadir `RideStatus.cancelled` al enum y al listener `_rideSub` (B22) |
| **Qué se corrigió (técnico)** | En `ride.dart`: se añadió `cancelled` al `enum RideStatus`; en `_statusFromString` se añadió `case 'cancelled': return RideStatus.cancelled;` antes del `default`; en `_statusToString` se añadió `case RideStatus.cancelled: return 'cancelled';`. En `map_screen_vendor.dart`, en el listener `_rideSub` dentro de `_acceptRide()`, se añadió `ride.status == RideStatus.cancelled` a la condición de estados terminales que cancela la suscripción y limpia `_activeRideId`, `_ridePhase` y `_routePolyline`. |
| **Qué se corrigió (simple)** | Si el comprador cancelaba el raite desde su app, el backend actualizaba el documento Firestore a `status: "cancelled"`. Flutter recibía esa cadena pero no tenía `cancelled` en el enum, por lo que `_statusFromString` lo mapeaba silenciosamente a `RideStatus.pending`. El listener `_rideSub` nunca detectaba el estado terminal, `_activeRideId` permanecía seteado y la UI del vendedor quedaba congelada en el estado de raite activo hasta reiniciar la app. |
| **Clase / Método / Módulo** | `enum RideStatus`, `_statusFromString()`, `_statusToString()` → `ride.dart` · listener `_rideSub` dentro de `_acceptRide()` → `map_screen_vendor.dart` |
| **Justificación** | El backend ya tenía `cancelled` como estado válido en `RIDE_VALID_TRANSITIONS` (Python `ride_schemas.py`). Flutter simplemente no lo contemplaba. La discrepancia entre el enum de Dart y el enum del backend hacía que cualquier transición `→ cancelled` fuera invisible para el cliente. |
| **Problema que resolvía** | Tras la cancelación del comprador, la pantalla del vendedor quedaba bloqueada mostrando el raite como activo, impidiéndole recibir nuevas solicitudes hasta reiniciar la app. |

---

### C-109 · Dialog de raite se cerraba antes de verificar GPS → sin opción de reintentar (B23) `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-109 · GPS check antes de `Navigator.pop()` en `_showIncomingRideDialog` (B23) |
| **Qué se corrigió (técnico)** | En `_showIncomingRideDialog()` → `onAccept` callback: se movió el check `ref.read(gpsServiceProvider).valueOrNull` al inicio del callback, antes de `setState` y `Navigator.pop()`. Si `position == null`, se muestra un `SnackBar` con mensaje de GPS no disponible y se hace `return` sin cerrar el dialog. Solo si el GPS está disponible se procede con `setState(() => _pendingDialogRideId = null)`, `Navigator.of(context).pop()` y `_acceptRide()`. |
| **Qué se corrigió (simple)** | Al tocar "Aceptar" en el dialog de raite, el dialog se cerraba inmediatamente aunque el GPS no estuviera disponible aún. `_acceptRide()` detectaba la falta de GPS y mostraba un SnackBar, pero el dialog ya estaba cerrado. El vendedor no tenía forma de reintentar la aceptación sin esperar otra notificación FCM. Ahora, si el GPS falla, el dialog permanece abierto y el vendedor puede tocar "Aceptar" de nuevo cuando el GPS esté listo. |
| **Clase / Método / Módulo** | `_showIncomingRideDialog()` → `onAccept` callback → `map_screen_vendor.dart` |
| **Justificación** | El patrón correcto ya estaba implementado para las paradas en `_showIncomingDialog()` (corrección B11 / C-93). Se aplicó el mismo patrón simétricamente para los raites. Adicionalmente, `_acceptRide()` ya no necesita repetir el check de GPS porque `onAccept` lo garantiza antes de llamarla, eliminando así la lógica duplicada de validación. |
| **Problema que resolvía** | El vendedor perdía la oportunidad de aceptar el raite si el GPS tardaba unos segundos en fijar posición al arrancar, sin posibilidad de reintentar hasta que el comprador hiciera otra solicitud. |

---

### C-110 · `_signalVendorArrived` — FCM y PATCH no atómicos + falta `mounted` en `setState` (B24) `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-110 · Separar try-catch FCM/PATCH y añadir `mounted` en `_signalVendorArrived` (B24) |
| **Qué se corrigió (técnico)** | En `_signalVendorArrived()`: se separó el bloque `try-catch` único en dos bloques independientes. El primero cubre exclusivamente `vendorArrived(rideId)` (FCM): si falla, muestra SnackBar con mensaje específico "Error al notificar llegada" y hace `return` sin intentar el PATCH. El segundo cubre exclusivamente `updateStatus(rideId, 'in_progress')` (PATCH): si falla, muestra SnackBar con "Error al actualizar estado" y hace `return`. El `setState(() => _ridePhase = 2)` al final del camino exitoso se cambió a `if (mounted) setState(() => _ridePhase = 2)`. |
| **Qué se corrigió (simple)** | Antes, FCM (`vendorArrived`) y PATCH (`updateStatus`) estaban en el mismo `try-catch`. Si el FCM tenía éxito pero el PATCH fallaba, el vendedor podía reintentar el botón "Llegué". En el reintento, el FCM volvía a enviarse: el comprador recibía dos notificaciones "El vendedor llegó". Ahora el primer bloque solo cubre el FCM: si ya tuvo éxito, el reintento solo reintenta el PATCH. Adicionalmente, el `setState` al final del camino exitoso podía lanzar una excepción si el widget fue desmontado mientras esperaba los `await`; el guard `if (mounted)` previene eso. |
| **Clase / Método / Módulo** | `_signalVendorArrived()` → `map_screen_vendor.dart` |
| **Justificación** | El patrón de separar operaciones no atómicas en bloques try-catch independientes es estándar cuando la primera operación no debe repetirse (notificación push idempotente solo en primera ejecución exitosa). El guard `mounted` antes de `setState` es una buena práctica obligatoria en Flutter tras cualquier `await` en un `State`. |
| **Problema que resolvía** | En red inestable, un retry del botón "Llegué" enviaba al comprador una segunda notificación push "El vendedor llegó", creando confusión sobre el estado del raite. |

---

### C-111 · `RiskZone.fromFirestore` — modelo sin factory para leer snapshots en tiempo real `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-111 · Añadir `RiskZone.fromFirestore` para snapshots de Firestore |
| **Qué se corrigió (técnico)** | En `risk_zone.dart`: se añadió `import 'package:cloud_firestore/cloud_firestore.dart'` y el factory `RiskZone.fromFirestore(String id, Map<String, dynamic> data)`. La función interna `parseDate(dynamic v)` maneja tres casos: `Timestamp` nativo de Firestore (para `created_at` y `expired_at`, escritos con `SERVER_TIMESTAMP`), `String` ISO 8601 (para `expires_at`, escrito por el backend Python como `.isoformat()`), y fallback a `DateTime.now()`. El campo `location` usa el mismo acceso de mapa que `fromJson`. |
| **Qué se corrigió (simple)** | El modelo `RiskZone` solo tenía `fromJson` (para respuestas REST). Al migrar el provider a un stream directo de Firestore, los snapshots llegan con `Timestamp` nativos de Firestore en vez de strings ISO. Sin `fromFirestore`, el stream no podría construir instancias de `RiskZone` a partir de los documentos de la colección. |
| **Clase / Método / Módulo** | `RiskZone.fromFirestore()` → `ubisafe_app/lib/features/safety/models/risk_zone.dart` |
| **Justificación** | Firestore almacena `SERVER_TIMESTAMP` como un objeto `Timestamp`, no como string. El backend Python convierte esos timestamps a ISO al servir la REST API (`_doc_to_risk_zone`), pero el cliente Firestore de Flutter recibe el tipo nativo. Es necesario un factory dedicado que los maneje. |
| **Problema que resolvía** | Sin `fromFirestore`, el `StreamProvider` habría lanzado `TypeError` al intentar parsear un `Timestamp` como `String` al construir `RiskZone`. |

---

### C-112 · `activeRiskZonesProvider` — `FutureProvider` REST reemplazado por `StreamProvider` Firestore `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-112 · `activeRiskZonesProvider` como `StreamProvider.autoDispose` con stream de Firestore |
| **Qué se corrigió (técnico)** | En `risk_zone_service.dart`: se eliminaron los imports de `api_client` y `flutter_riverpod FutureProvider`; se añadieron `dart:math` y `cloud_firestore`. Se eliminó `riskZoneRefreshProvider` (ya no necesario). `activeRiskZonesProvider` pasó de `FutureProvider.autoDispose<List<RiskZone>>` a `StreamProvider.autoDispose<List<RiskZone>>`. El nuevo provider suscribe a `FirebaseFirestore.instance.collection('risk_zones').where('active', isEqualTo: true).snapshots()` y filtra por proximidad (<5 km) en cliente usando Haversine. Los documentos se mapean con `RiskZone.fromFirestore`. Se actualizó el test file (`risk_zone_service_test.dart`) para eliminar los grupos obsoletos basados en REST y `riskZoneRefreshProvider`, y añadir tests de `fromFirestore` con fixtures que ejercitan tanto `String` ISO como `Timestamp` nativo. |
| **Qué se corrigió (simple)** | El provider anterior usaba `GET /risk-zones` (REST) y solo se actualizaba cuando llegaba un FCM `risk_zone_alert` o se llamaba `ref.invalidate`. Esto significaba que si una zona expiraba automáticamente, se eliminaba manualmente desde la consola de Firebase, o expiraba por el endpoint `DELETE`, el mapa del vendedor y del comprador no se actualizaban hasta el próximo evento externo. El nuevo `StreamProvider` tiene una conexión persistente con Firestore: cualquier cambio en la colección `risk_zones` (de cualquier fuente) se refleja en el mapa en ~1 segundo. |
| **Clase / Método / Módulo** | `activeRiskZonesProvider`, `_haversineKm()` → `ubisafe_app/lib/features/safety/services/risk_zone_service.dart` · `risk_zone_service_test.dart` |
| **Justificación** | El patrón de stream directo a Firestore elimina la dependencia de FCM para actualizaciones en primer plano y hace el sistema resiliente a cualquier origen de cambio (job automático, API, consola). `ref.invalidate(activeRiskZonesProvider)` sigue funcionando con `StreamProvider` (cancela y re-suscribe el stream), por lo que el `notification_handler.dart` no requiere cambios estructurales. |
| **Problema que resolvía** | Al expirar una zona de riesgo (por cualquier mecanismo), los círculos de zona permanecían en el mapa del vendedor y comprador indefinidamente hasta que el usuario recibía un FCM no relacionado o reiniciaba la app. |

---

### C-113 · Handler FCM sin `case 'risk_zone_expired'` — zonas no se refrescaban en background `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-113 · Añadir `case 'risk_zone_expired'` en `notification_handler.dart` |
| **Qué se corrigió (técnico)** | En `_dispatchData()` de `notification_handler.dart`, se añadió `case 'risk_zone_expired': _invalidateRiskZones();` inmediatamente después del `case 'risk_zone_alert'` existente. El FCM `risk_zone_expired` es enviado por la Cloud Function `on_risk_zone_write` (C-114) cuando detecta que una zona transiciona a inactiva. |
| **Qué se corrigió (simple)** | El `StreamProvider` de Firestore cubre actualizaciones en tiempo real cuando la app está en primer plano. Cuando la app está en background o killed, el stream no está activo. Al volver al primer plano, el stream se re-suscribe automáticamente y obtiene el estado actual. Sin embargo, si el usuario tenía la app en segundo plano y recibía el FCM `risk_zone_expired`, el sistema lo ignoraba (caía al `default: debugPrint`), perdiendo la oportunidad de forzar un refresco limpio. Con este `case`, al volver al primer plano el provider se invalida y el stream re-emite la lista actualizada. |
| **Clase / Método / Módulo** | `_dispatchData()` → `ubisafe_app/lib/features/shared/notifications/notification_handler.dart` |
| **Justificación** | El `case 'risk_zone_alert'` ya existía y llamaba `_invalidateRiskZones()`. La corrección es simétrica: el FCM de creación y el de expiración tienen el mismo efecto desde el punto de vista del cliente — invalidar el provider para que re-sincronice con Firestore. |
| **Problema que resolvía** | FCM `risk_zone_expired` llegaba al dispositivo pero era ignorado por el handler (`default: debugPrint`). El mapa no se actualizaba al reabrir la app tras recibir la notificación de zona expirada en background. |

---

### C-114 · Sin mecanismo de expiración automática de zonas de riesgo a las 24h `2026-05-17`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-114 · Cloud Functions `expire_risk_zones` (scheduled) + `on_risk_zone_write` (Firestore trigger) |
| **Qué se corrigió (técnico)** | En `functions/main.py` se añadieron dos Cloud Functions gen2 en Python. (1) `expire_risk_zones`: decorada con `@scheduler_fn.on_schedule(schedule="every 30 minutes")`. Consulta todas las zonas con `active == True`, parsea `expires_at` (string ISO del backend Python) con `datetime.fromisoformat`, y llama a `doc.reference.update({"active": False, "expired_at": SERVER_TIMESTAMP})` para cada zona vencida. (2) `on_risk_zone_write`: decorada con `@firestore_fn.on_document_written(document="risk_zones/{zone_id}")`. Evalúa si la transición es `active: True → False` (o borrado total del documento). Si es así, obtiene tokens FCM de usuarios a <5 km usando `_get_nearby_fcm_tokens()` (Haversine) y envía `messaging.MulticastMessage` con `type: "risk_zone_expired"`. Se añadieron `math`, `datetime`, `scheduler_fn` y `messaging` a los imports. Se añadió la función utilitaria `_haversine_km()` y `_get_nearby_fcm_tokens()` reutilizadas por ambas funciones. |
| **Qué se corrigió (simple)** | El campo `expires_at` se calculaba y guardaba correctamente al crear una zona (24h en el futuro), pero nadie lo verificaba. Las zonas permanecían `active: True` en Firestore indefinidamente aunque hubieran pasado las 24h. Ahora: (a) cada 30 minutos se revisan y expiran las zonas vencidas; (b) cuando cualquier zona pasa a inactiva — por el job, por el endpoint `DELETE /risk-zones/{id}`, o por edición/borrado manual en la consola de Firebase — se envía FCM `risk_zone_expired` a los usuarios cercanos. El `on_risk_zone_write` cubre el borrado manual porque el trigger `onWrite` se dispara también cuando `change.after.exists == False` (documento eliminado). |
| **Clase / Método / Módulo** | `expire_risk_zones()`, `on_risk_zone_write()`, `_haversine_km()`, `_get_nearby_fcm_tokens()` → `functions/main.py` |
| **Justificación** | La función `expire_risk_zones` no puede usar `where('expires_at', '<=', now)` directamente en Firestore porque `expires_at` está almacenado como string ISO (no como Timestamp nativo), lo que haría la comparación lexicográfica en lugar de temporal. La solución es descargar el conjunto completo de zonas activas (siempre pequeño) y filtrar en Python. El trigger `on_risk_zone_write` centraliza el envío de FCM independientemente del origen del cambio, evitando duplicar lógica de notificación en el API y en el job. |
| **Problema que resolvía** | Zonas de riesgo reportadas hace más de 24 horas seguían apareciendo en el mapa como activas. No existía ningún proceso que hiciera cumplir el TTL de 24h establecido en `_RISK_ZONE_TTL_HOURS = 24`. |

---

### C-115 · `locationSyncProvider` seteaba throttle antes del `await` → cold-start bloqueaba sync por 60 s (B15 suplemento) `2026-05-18`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-115 · Reset de `lastSync = null` en el `catch` de `locationSyncProvider` |
| **Qué se corrigió (técnico)** | En `locationSyncProvider` (`gps_service.dart`), `lastSync = now` se asignaba antes de `await apiClient.patch('/auth/location', ...)`. Si el servidor respondía con timeout (~10 s en cold start de Render), el `catch (_) {}` swallowaba el error pero el throttle quedaba activo (`lastSync != null`). Los 60 s de throttle transcurrían con `last_location` null en Firestore. Se añadió `lastSync = null;` dentro del bloque `catch` para resetear el throttle y permitir el retry en el siguiente fix GPS. |
| **Qué se corrigió (simple)** | Al abrir la app por primera vez (con la API de Render en cold start), el primer intento de sync de ubicación fallaba con timeout. Como el throttle ya estaba activo, los siguientes 60 segundos de posiciones GPS no reintentaban el sync. Todos los usuarios que abrieran la app menos de 60 s antes de que alguien reportara un foco o zona permanecían invisibles para `get_nearby_user_fcm_tokens` → no recibían la notificación FCM. |
| **Clase / Método / Módulo** | `locationSyncProvider` → `ubisafe_app/lib/features/presence/services/gps_service.dart` |
| **Justificación** | El throttle se aplica antes del `await` para que disparos simultáneos del GPS (cada ~1 s) no apilen requests concurrentes. El reset en `catch` garantiza que un solo fallo no bloquee el sync por 60 s: el siguiente GPS tick (≥1 s después) reintenta, aún protegiendo contra floods porque el fallo no actualiza `lastLat`/`lastLng`. |
| **Problema que resolvía** | Reportes comunitarios y zonas de riesgo no generaban notificaciones FCM a usuarios que hubieran abierto la app menos de 60 s antes del reporte, especialmente en el primer lanzamiento del día cuando Render realiza un cold start. |

---

### C-116 · `vote_community_report` — checks de negocio fuera de la transacción Firestore → race condition de doble voto (B25, B26) `2026-05-18`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-116 · `VoteConflictError` + re-verificación dentro de `_txn` (B25, B26) |
| **Qué se corrigió (técnico)** | En `firestore_service.py` se añadió la clase `VoteConflictError(Exception)` con campo `detail: str`. Dentro de `_txn` en `vote_community_report`, antes del append, se añadieron dos guards atómicos: `if data.get("status") != "pending_validation": raise VoteConflictError(f"report_status_is_{...}")` y `if any(v.get("user_uid") == voter_uid ...): raise VoteConflictError("already_voted")`. En `validation_router.py` se añadió `from modules.shared.firestore_service import VoteConflictError` y el bloque `try/except VoteConflictError as exc: raise HTTPException(409, exc.detail)` que envuelve la llamada a `vote_community_report`. |
| **Qué se corrigió (simple)** | El router verificaba "¿ya votó?" y "¿sigue en pending?" sobre un snapshot estale antes de entrar a la transacción. Si dos requests del mismo usuario llegaban simultáneamente (doble tap), ambos pasaban los checks y ambas transacciones se completaban, insertando dos votos del mismo usuario. Ahora los checks críticos se re-ejecutan dentro de la transacción Firestore: si la primera transacción ganó, la segunda lanza `VoteConflictError` que el router convierte en 409. |
| **Clase / Método / Módulo** | `VoteConflictError`, `vote_community_report._txn()` → `firestore_service.py` · `validate_report()` → `validation_router.py` |
| **Justificación** | Los pre-checks del router siguen siendo útiles como fast-exit para el caso común (evitan una escritura innecesaria). Los checks dentro de `_txn` son los guards autoritativos: Firestore garantiza que la lectura y escritura dentro de la transacción son atómicas, eliminando la ventana de race condition que existía entre el snapshot del router y la escritura. |
| **Problema que resolvía** | Un usuario podía insertar dos votos en el mismo reporte con doble tap en conexión lenta, llevando `confirm_count` de 2 a 4 sin el consenso de tres usuarios distintos e invalidando el historial de auditoría de validaciones. |

---

### C-117 · `_CommunityReportsNotifier.load()` emitía `loading` en cada refresh → marcadores desaparecían del mapa (B27) `2026-05-18`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-117 · `load()` solo emite `AsyncValue.loading()` si no hay datos previos (B27) |
| **Qué se corrigió (técnico)** | En `_CommunityReportsNotifier.load()` (`community_report_module.dart`) se reemplazó la asignación incondicional `state = const AsyncValue.loading()` por `if (state is! AsyncData<List<CommunityReport>>) { state = const AsyncValue.loading(); }`. |
| **Qué se corrigió (simple)** | Cada vez que llegaba un FCM `community_report_nearby` o el usuario publicaba un nuevo reporte, el provider llamaba `refresh()` → `load()` → emitía `loading` mientras hacía el GET (2–5 s en Render free). Durante ese tiempo, `valueOrNull` retornaba `null`, los marcadores del mapa se limpiaban y el usuario veía el mapa vacío de reportes comunitarios momentáneamente. Ahora el refresh actualiza los datos en silencio y los marcadores permanecen visibles. |
| **Clase / Método / Módulo** | `_CommunityReportsNotifier.load()` → `ubisafe_app/lib/features/community/services/community_report_module.dart` |
| **Justificación** | El spinner de carga solo tiene sentido en la carga inicial (cuando no hay datos que mostrar). En refreshes subsecuentes, mantener los datos anteriores evita el parpadeo y es el comportamiento estándar de "stale-while-revalidate". |
| **Problema que resolvía** | Los marcadores de reportes comunitarios desaparecían del mapa por 2–5 segundos cada vez que se recibía un FCM de nuevo reporte o el usuario enviaba uno propio. |

---

### C-118 · `CommunityFormBottomSheet` dismissable durante retry → reporte creado sin feedback (B28) `2026-05-18`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-118 · `isDismissible: false` + `enableDrag: false` en `CommunityFormBottomSheet.show()` (B28) |
| **Qué se corrigió (técnico)** | En `CommunityFormBottomSheet.show()` (`community_form_bottom_sheet.dart`) se añadieron `isDismissible: false` y `enableDrag: false` a la llamada `showModalBottomSheet`. |
| **Qué se corrigió (simple)** | El usuario podía deslizar el bottom sheet hacia abajo para cerrarlo mientras el retry backoff (hasta 14 s) estaba en progreso. Si el reporte se creaba exitosamente en el backend durante ese tiempo, el guard `if (mounted)` impedía mostrar el SnackBar de confirmación. El usuario, sin feedback, podía abrir el formulario de nuevo y enviar un reporte duplicado. Ahora el sheet no puede cerrarse hasta que la operación concluya (éxito o fallo). |
| **Clase / Método / Módulo** | `CommunityFormBottomSheet.show()` → `ubisafe_app/lib/features/community/screens/community_form_bottom_sheet.dart` |
| **Justificación** | El mismo patrón (`isDismissible: false`, `enableDrag: false`) ya estaba aplicado en `DestinationPicker.show()` del mismo proyecto. |
| **Problema que resolvía** | Reportes de focos de infección duplicados creados silenciosamente cuando el usuario cerraba el formulario durante el periodo de retry backoff. |

---

### C-119 · Botón "Actualizar" en `ActiveReportsScreen` era no-op si GPS no disponible al cargar (B29) `2026-05-18`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-119 · Botón refresh replica lógica de `_loadIfNeeded()` cuando `_lat == null` (B29) |
| **Qué se corrigió (técnico)** | En el `IconButton` de refresh del `AppBar` de `ActiveReportsScreen`, se reemplazó `ref.read(activeCommunityReportsProvider.notifier).refresh()` por lógica condicional: si `notifier.hasCoordinates` → `refresh()`; si no y GPS disponible → `notifier.load(lat, lng)`; si no y GPS no disponible → `notifier.setGpsUnavailable()`. |
| **Qué se corrigió (simple)** | Si el usuario abría la pantalla sin GPS y luego lo activaba, el botón "Actualizar" era inútil: `refresh()` es no-op cuando `_lat == null` (nunca se llamó `load()`). El usuario debía navegar fuera y volver para que `initState` se ejecutara de nuevo. Ahora el botón detecta la situación y llama `load()` directamente con la posición GPS actual. |
| **Clase / Método / Módulo** | `AppBar` → `IconButton` refresh → `_ActiveReportsScreenState.build()` → `ubisafe_app/lib/features/community/screens/active_reports_screen.dart` |
| **Justificación** | El botón de actualizar debe ser el equivalente manual de `_loadIfNeeded()`; si las coordenadas no están cargadas, debe iniciarlas. |
| **Problema que resolvía** | El usuario activaba GPS, tocaba "Actualizar" y la pantalla seguía mostrando "Activa el GPS para ver reportes cercanos." sin respuesta aparente. |

---

### C-120 · `validate_report` no enviaba FCM al alcanzar umbral → reportador y lista nunca actualizados (B30) `2026-05-18`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-120 · FCM `report_status_changed` al reportador + `case` en `NotificationHandler` (B30) |
| **Qué se corrigió (técnico)** | En `validation_router.py`: se añadieron `import asyncio` y `from modules.shared.notification_service import NotificationService`. Tras un voto exitoso, si `updated.status.value in ("confirmed", "dismissed")` se despacha `asyncio.ensure_future(NotificationService.send_to_user(uid=updated.reporter_uid, title="Reporte actualizado", body=f"Tu reporte fue {status_label} por la comunidad.", data={"type": "report_status_changed", ...}))` (fire-and-forget). En `notification_handler.dart` se añadió `case 'report_status_changed': _onCommunityReportNearby();` reutilizando el callback que ya llama a `activeCommunityReportsProvider.notifier.refresh()`. |
| **Qué se corrigió (simple)** | Cuando la comunidad alcanzaba 3 votos y el reporte pasaba a `confirmed` o `dismissed`, nadie recibía ninguna notificación. El reportador no se enteraba del resultado. Otros usuarios con la lista abierta seguían viendo el reporte como `pending_validation`. Ahora el reportador recibe un FCM que refresca su lista automáticamente. |
| **Clase / Método / Módulo** | `validate_report()` → `ubisafe_api/modules/community/validation_router.py` · `_dispatchData()` → `ubisafe_app/lib/features/shared/notifications/notification_handler.dart` |
| **Justificación** | Se usó `send_to_user` (ya existente, envía a un UID específico) en lugar de multicast por proximidad porque la notificación de resultado es personal al reportador. El multicast de vecinos cercanos fue omitido intencionalmente ya que depende de `last_location` (interacción con B15) y es una mejora separada. |
| **Problema que resolvía** | El reportador nunca sabía si su reporte fue validado o descartado por la comunidad sin abrir la app y refrescar manualmente. |

---

### C-121 · Cast `state.extra as CommunityReport` incondicional → crash en restauración de proceso Android (B31) `2026-05-18`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-121 · Cast seguro `is!` con fallback a `ActiveReportsScreen` (B31) |
| **Qué se corrigió (técnico)** | En el builder de la ruta `/community/reports/detail` en `app_router.dart`, se reemplazó `final report = state.extra as CommunityReport` por `final extra = state.extra; if (extra is! CommunityReport) return const ActiveReportsScreen(); return ReportDetailScreen(report: extra);`. |
| **Qué se corrigió (simple)** | Cuando Android mataba el proceso de la app y el usuario regresaba, GoRouter intentaba reconstruir la ruta `/community/reports/detail` pero `state.extra` no sobrevive la muerte del proceso. El cast incondicional lanzaba `TypeError` y Flutter mostraba la pantalla de error roja del framework. Ahora se redirige silenciosamente a la lista de reportes. |
| **Clase / Método / Módulo** | Ruta `/community/reports/detail` → `ubisafe_app/lib/router/app_router.dart` |
| **Justificación** | El patrón `is!` con fallback controlado es preferible a `try/catch` porque no oculta el tipo de excepción y el fallback a `ActiveReportsScreen` da continuidad al flujo del usuario. |
| **Problema que resolvía** | La app mostraba la pantalla de error roja de Flutter al navegar al detalle de reporte después de que Android reciclara el proceso. |

---

### C-122 · `_vote()` mostraba DioException raw + lista no refrescada tras voto (B32, B33) `2026-05-18`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-122 · Parseo de `detail` en `_vote()` + `refresh()` tras voto exitoso (B32, B33) |
| **Qué se corrigió (técnico)** | En `report_detail_screen.dart`: (1) Se añadieron imports de `package:dio/dio.dart` y `community_report_module.dart`. (2) En `_vote()`, el `on Exception catch (e)` único se separó en `on DioException catch (e)` (que parsea `(e.response?.data as Map?)?['detail']` y usa `switch(detail)` para mapear `already_voted`, `reporter_cannot_vote`, `report_status_is_*` a mensajes en español) y `on Exception catch (_)` (mensaje genérico de conexión). (3) En el path exitoso, tras `setState(() => _current = updated)`, se añadió `ref.read(activeCommunityReportsProvider.notifier).refresh()`. (4) El `if (!mounted) return` se movió antes de todos los `setState` y `showSnackBar` del path exitoso. |
| **Qué se corrigió (simple)** | (B32) Al votar en un reporte que ya fue cerrado por otro usuario en paralelo, el backend respondía 409. El usuario veía "Error al votar: DioException [bad response]: …" en lugar de "Este reporte ya no está disponible para votar." (B33) Tras votar exitosamente y regresar a la lista, el reporte seguía mostrando el conteo antiguo y los botones de voto aparecían habilitados de nuevo. Al tocar el botón una segunda vez se producía el error B32 anterior con 409 `already_voted`. Ahora el `refresh()` actualiza la lista inmediatamente y el error 409 muestra un mensaje legible. |
| **Clase / Método / Módulo** | `_ReportDetailScreenState._vote()` → `ubisafe_app/lib/features/community/screens/report_detail_screen.dart` |
| **Justificación** | Parsear el `detail` del JSON de error es el mismo patrón ya aplicado en `_requestRide` (C-69). El `refresh()` tras voto exitoso crea un rebrief de red (~1 GET) que es aceptable dado que el voto ya causó una escritura en Firestore de todos modos. |
| **Problema que resolvía** | El usuario que votaba en un reporte en estado de race condition veía el texto técnico del objeto Dio en lugar de un mensaje de usuario. Adicionalmente, volver a la lista y re-entrar al detalle del mismo reporte mostraba botones de voto activos aunque el usuario ya había votado. |

---

### C-161 · Tests Flutter fallaban por `FirebaseException` al construir `MapScreenBuyer` y `MapScreenVendor` `2026-05-22`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-161 · `groupStayModuleProvider` no mockeado en tests de pantallas del mapa |
| **Qué se corrigió (técnico)** | En `map_screen_buyer_test.dart` y `map_screen_vendor_test.dart`: se añadió `import` de `group_stay_module.dart`, clase `_MockGroupStayModule extends Mock implements GroupStayModule`, y override `groupStayModuleProvider.overrideWith((ref) => _MockGroupStayModule())` en todas las listas de overrides (función helper + `ProviderScope` inline del primer test de cada archivo). |
| **Qué se corrigió (simple)** | Los tests de las pantallas del mapa lanzaban `FirebaseException: [core/no-app] No Firebase App '[DEFAULT]'` al construirse, porque `activeGroupStaysProvider` (usado en el `build()` de ambas pantallas) intentaba acceder a `FirebaseAuth.instance` a través de la cadena `groupStayModuleProvider → apiClientProvider → JwtInterceptor`. Al no tener Firebase inicializado en el entorno de test, la suite entera fallaba. El override de `groupStayModuleProvider` con un mock corta esa cadena. |
| **Clase / Método / Módulo** | `overrides()` y `ProviderScope` inline en `map_screen_buyer_test.dart` · `_buildVendorScreen()` y `ProviderScope` inline en `map_screen_vendor_test.dart` (`ubisafe_app/test/features/dispatching/screens/`) |
| **Justificación** | `activeCommunityReportsProvider` ya estaba mockeado vía `communityReportModuleProvider`, pero `activeGroupStaysProvider` seguía la misma ruta (`groupStayModuleProvider → apiClientProvider → JwtInterceptor`) y no tenía override. El fallo no era un test de negocio sino de infraestructura de test: la cadena de dependencias Riverpod llegaba hasta Firebase antes de que ningún widget fuera relevante. |
| **Problema que resolvía** | `MapScreenBuyer — GPS guard shows GpsRequiredEmptyState` fallaba con `FlutterError.onError had unexpected additional errors` (encubriendo el `FirebaseException` subyacente). `MapScreenVendor — estado inicial muestra CircularProgressIndicator` fallaba directamente con `FirebaseException`. Resultado: 2 tests fallidos en la suite Flutter (93 tests totales). |

---

### C-123 · Diálogo de raite entrante no se descartaba al expirar la solicitud (60 s) `2026-05-18`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-123 · `RideEventType.expired` no manejado en listener del vendedor |
| **Qué se corrigió (técnico)** | En `map_screen_vendor.dart`, el listener `ref.listen<RideEvent?>(rideEventProvider, …)` solo manejaba `RideEventType.cancelledByBuyer` para descartar el diálogo entrante y limpiar estado. Se añadió un bloque paralelo para `RideEventType.expired` que: (1) llama `Navigator.of(context).pop()` si `_pendingDialogRideId == event.rideId`, (2) pone `_pendingDialogRideId = null`, (3) cancela `_rideSub`, (4) limpia `_activeRideId / _ridePhase / _routePolyline / _isNavigating`, (5) resetea `rideEventProvider` a `null`, (6) muestra SnackBar "La solicitud de raite expiró." |
| **Qué se corrigió (simple)** | Cuando el comprador esperaba 60 s sin respuesta del vendedor, el comprador recibía la notificación correcta de que la solicitud expiró, pero el vendedor seguía viendo el diálogo de "Aceptar / Rechazar". Si el vendedor pulsaba "Aceptar" en ese estado, el backend respondía 409 (ride ya expirado). Ahora el diálogo se descarta automáticamente en el lado del vendedor cuando llega el evento de expiración. |
| **Clase / Método / Módulo** | `_MapScreenVendorState` → `ref.listen<RideEvent?>` en `map_screen_vendor.dart` (`ubisafe_app/lib/features/dispatching/screens/map_screen_vendor.dart`) |
| **Justificación** | El evento `RideEventType.expired` ya llegaba correctamente desde `notification_handler.dart` al `rideEventProvider`, y el guard `if (_activeRideId == null && event.rideId != _pendingDialogRideId) return` ya permitía el paso del evento cuando el diálogo estaba abierto. Faltaba únicamente el handler que actuara sobre él, análogo al ya existente para `cancelledByBuyer`. |
| **Problema que resolvía** | El vendedor conservaba el diálogo de aceptar/rechazar después de que la solicitud expiraba. Aceptar la solicitud expirada producía un error 409 sin feedback claro al vendedor. |

---

### C-162 · `ScheduleGroupStayScreen` usaba posición GPS como ubicación fija sin selector de mapa + coordenadas crudas visibles `2026-05-23`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-162 · `GroupStayLocationPickerSheet` + eliminación de coordenadas crudas en CU-09 |
| **Qué se corrigió (técnico)** | (1) Creado `group_stay_location_picker_sheet.dart`: bottom sheet 75% de pantalla con `GoogleMap` embebido, pin central fijo `Icons.storefront_outlined` (color `secondary700`), callback `onCameraMove` captura el `target` como ubicación seleccionada. Sin restricción de radio (a diferencia del `LotLocationPickerSheet` que limita a 1 km). Retorna `LatLng?`. (2) `ScheduleGroupStayScreen` reescrito: campo `LatLng? _selectedLocation`, método `_pickLocation()` que abre el picker con la posición GPS como centro inicial, card visual con estado "no seleccionado" / "seleccionado ✓", botón "Programar estancia" deshabilitado si `_selectedLocation == null`. `_submit()` usa `_selectedLocation` en lugar de la posición GPS en tiempo real. (3) `GroupStayDetailScreen`: el `_InfoRow` de Ubicación (que mostraba lat/lng crudas) se reemplazó por un `GoogleMap` no interactivo de 150 px de alto con un marker cyan en la posición de la estancia. |
| **Qué se corrigió (simple)** | La pantalla "Programar estancia" asignaba automáticamente la posición GPS actual como ubicación sin darle al vendedor ninguna forma de elegir un punto diferente. El vendedor solo veía coordenadas numéricas. Ahora al tocar la card de ubicación se abre un mapa donde puede mover el pin a cualquier punto; el botón de programar no se habilita hasta que confirme. En la pantalla de detalle, las coordenadas crudas fueron reemplazadas por un mini-mapa que muestra exactamente dónde está la estancia. |
| **Clase / Método / Módulo** | `ScheduleGroupStayScreen._submit()` + nuevo `GroupStayLocationPickerSheet` → `ubisafe_app/lib/features/dispatching/group_stays/screens/` · `GroupStayDetailScreen` info card → `group_stay_detail_screen.dart` |
| **Justificación** | El plan §5.1.2 item 8 especifica explícitamente "Mapa con pin draggable o tap-to-set para `location`". El patrón de picker (bottom sheet con mapa + pin central fijo) ya existe para lotes baldíos (`LotLocationPickerSheet`) y se replicó aquí sin la restricción de radio ya que las estancias no tienen límite de distancia. El mini-mapa en el detalle sigue la especificación §5.2.2 ("punto en mini-mapa"). |
| **Problema que resolvía** | El vendedor no podía elegir el punto de su estancia — siempre se programaba donde estaba parado físicamente en ese momento. Tampoco había retroalimentación visual de dónde quedaría la estancia antes de confirmar. |

---

### C-163 · `ref.invalidate(activeGroupStaysProvider)` reseteaba a lista vacía sin recargar + estancia nueva no aparecía en mapa `2026-05-23`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-163 · `_GroupStaysNotifier.reload()` para P2 y P3 de CU-09 |
| **Qué se corrigió (técnico)** | (1) `_GroupStaysNotifier` en `group_stay_module.dart`: añadidos campos `double? _lastLat` y `double? _lastLng` que se almacenan en cada llamada a `load(lat, lng)`. Nuevo método `Future<void> reload()` que llama `load(_lastLat!, _lastLng!)` si los valores están disponibles (no-op seguro si `load` nunca fue llamado). (2) `notificationHandlerProvider` en `notification_handler.dart`: el callback `onGroupStayCancelled` cambió de `ref.invalidate(activeGroupStaysProvider)` a `ref.read(activeGroupStaysProvider.notifier).reload()`. (3) `ScheduleGroupStayScreen._submit()`: tras crear la estancia exitosamente, se dispara `unawaited(ref.read(activeGroupStaysProvider.notifier).reload())` antes del `context.pop()`. |
| **Qué se corrigió (simple)** | (P2) Cuando llegaba un FCM `group_stay_cancelled`, el código llamaba `ref.invalidate(activeGroupStaysProvider)`. Esto descartaba el `StateNotifier` y lo recreaba con su estado inicial `AsyncData([])` (lista vacía), pero nunca llamaba `.load()`. Los mapas quedaban con cero marcadores de estancia en lugar de la lista actualizada sin la estancia cancelada. (P3) Al crear una estancia exitosamente y regresar al mapa, la estancia nueva no aparecía como pin porque el flag `_groupStaysLoaded = true` evitaba que el mapa disparara un nuevo `.load()`. Ahora ambos casos llaman `reload()` que usa las últimas coordenadas conocidas para hacer una recarga real. |
| **Clase / Método / Módulo** | `_GroupStaysNotifier` + `groupStayModuleProvider` → `group_stay_module.dart` · `notificationHandlerProvider.onGroupStayCancelled` → `notification_handler.dart` · `ScheduleGroupStayScreen._submit()` → `schedule_group_stay_screen.dart` |
| **Justificación** | `ref.invalidate()` destruye y recrea el notifier desde cero — el estado inicial es `AsyncData([])`, no el resultado de un fetch. Para un `StateNotifier` que depende de parámetros externos (lat/lng) que no están en el provider graph, el patrón correcto es almacenar esos parámetros en el notifier y exponer un método `reload()`. Este patrón evita duplicar la lógica de fetching y mantiene la única fuente de verdad de coordenadas en el propio notifier. |
| **Problema que resolvía** | Los marcadores de estancias grupales desaparecían del mapa al recibir FCM `group_stay_cancelled` (lista se reseteaba a vacía). Las estancias recién creadas no aparecían en el mapa hasta que el usuario reiniciaba la app. |

---

### C-164 · Marcadores de estancia grupal usaban el mismo color (`hueCyan`) para los estados `scheduled` y `active` `2026-05-23`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-164 · `hueAzure` (scheduled) vs `hueBlue` (active) en `_groupStayToMarker` |
| **Qué se corrigió (técnico)** | En `_groupStayToMarker` de `map_screen_buyer.dart` y `map_screen_vendor.dart`: la llamada `BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan)` se reemplazó por una expresión condicional: `stay.status == 'active' ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueAzure`. |
| **Qué se corrigió (simple)** | Todos los marcadores de estancias grupales aparecían del mismo color (cian) en el mapa, sin distinción entre una estancia programada (futura) y una activa (en curso). El plan especifica colores diferentes para cada estado. Ahora los marcadores `scheduled` son azul claro (azure, 210°) y los `active` son azul intenso (blue, 240°). |
| **Clase / Método / Módulo** | `_MapScreenBuyerState._groupStayToMarker()` → `map_screen_buyer.dart` · `_MapScreenVendorState._groupStayToMarker()` → `map_screen_vendor.dart` |
| **Justificación** | El SDD3 Fase 5'' especifica `#5C6BC0` para scheduled y `#3F51B5` para active. Ambos tonos tienen el mismo hue HSV (~231°), imposible de diferenciar con `defaultMarkerWithHue`. `hueAzure` (210°) y `hueBlue` (240°) son los valores predefinidos de Google Maps Flutter más cercanos a esa familia de azules y se distinguen claramente a escala de mapa. |
| **Problema que resolvía** | El usuario no podía distinguir visualmente en el mapa si una estancia era futura o estaba ocurriendo en ese momento. |

---

### C-165 · Tests faltantes de CU-09: idempotencia de asistencia, conteo de args y FCM en cancelación `2026-05-23`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-165 · Tres tests nuevos en `test_group_stays.py` (P5 del audit CU-09) |
| **Qué se corrigió (técnico)** | Añadidos tres tests a `tests/test_group_stays.py`: (1) `test_confirm_attendance_calls_firestore_with_correct_args`: verifica que `POST /group-stays/{id}/attendances` llama `FirestoreService.confirm_attendance(stay_id, buyer_uid)` con los argumentos exactos usando `assert_awaited_once_with`. (2) `test_double_confirm_is_idempotent`: llama el endpoint de asistencia dos veces consecutivas en el mismo `AsyncClient` y verifica que ambas retornan 204 (la idempotencia real la garantiza la capa FS, pero el endpoint no debe fallar en el segundo intento). (3) `test_vendor_cancel_notifies_attendees`: mockea `get_confirmed_attendance_uids` para retornar `[BUYER_UID]`, mockea `NotificationService.send_group_stay_cancelled`, llama `PATCH /cancel` y tras `await asyncio.sleep(0)` (para vaciar el `asyncio.ensure_future` del router) verifica que el mock de FCM fue llamado con `([BUYER_UID], STAY_ID, "vendor_cancelled")`. |
| **Qué se corrigió (simple)** | El plan §5.2.1 item 5 especificaba tres tests que no estaban implementados: que el endpoint de asistencia pasa los argumentos correctos a Firestore, que llamarlo dos veces no falla, y que cancelar una estancia con asistentes efectivamente dispara la notificación FCM. Sin estos tests, un refactor del router o del servicio podría romper silenciosamente estas garantías. |
| **Clase / Método / Módulo** | `tests/test_group_stays.py` → `ubisafe_api/tests/test_group_stays.py` (suite sube de 9 a 12 tests, todos pasan) |
| **Justificación** | `asyncio.sleep(0)` en el test de cancelación es el patrón estándar para vaciar tareas pendientes creadas con `asyncio.ensure_future` dentro del mismo loop del test. El mock de `NotificationService.send_group_stay_cancelled` se parchea por su path completo de módulo (`modules.shared.notification_service.NotificationService...`) para asegurar que el parche intercepta exactamente la llamada que hace el router. |
| **Problema que resolvía** | Los tres casos de negocio (argumentos correctos en asistencia, idempotencia, FCM en cancelación) no tenían cobertura de test. Un cambio inadvertido en la firma de `confirm_attendance` o en la lógica de notificación de cancelación habría pasado desapercibido en CI. |

---

### C-166 · `lotResolvedProvider` no escuchado en mapas — pin no desaparecía al recibir FCM `lot_resolved` `2026-05-23`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-166 · `ref.listen(lotResolvedProvider)` + `_resolvedLotIds` en ambos mapas (P1 audit CU-07) |
| **Qué se corrigió (técnico)** | Añadido `final Set<String> _resolvedLotIds = {}` al estado de `_MapScreenBuyerState` y `_MapScreenVendorState`. Añadido `ref.listen<Map<String, dynamic>?>(lotResolvedProvider, ...)` en el `build()` de cada mapa: extrae `data['report_id']` y lo agrega a `_resolvedLotIds` mediante `setState()`. El filtro de `communityMarkers` pasa de 4 condiciones a 5: añade `&& !_resolvedLotIds.contains(r.id)`. |
| **Qué se corrigió (simple)** | El `notification_handler.dart` ya tenía `lotResolvedProvider` y `onLotResolved`, pero ningún mapa lo escuchaba. Cuando un lote baldío se resolvía, el `notification_handler` llamaba `refresh()` en `activeCommunityReportsProvider`, pero el pin amarillo no desaparecía hasta que el refetch completaba (100–500 ms de delay y posible parpadeo). Ahora al recibir el FCM `lot_resolved`, el pin se elimina del mapa de forma inmediata (0 ms) sin esperar la respuesta de la API. |
| **Clase / Método / Módulo** | `_MapScreenBuyerState.build()` → `map_screen_buyer.dart` · `_MapScreenVendorState.build()` → `map_screen_vendor.dart` |
| **Justificación** | El plan (§4.2.1) exige explícitamente `ref.listen(lotResolvedProvider)` en las pantallas del mapa para remover el marker. Sin esto el provider estaba "wired" en el handler pero desconectado de los widgets consumidores. |
| **Problema que resolvía** | Al resolver un lote baldío desde otro dispositivo, el pin amarillo tardaba en desaparecer (o no desaparecía si el refetch fallaba) del mapa del observador. |

---

### C-167 · `_resolve()` sin optimistic update ni rollback (R-F9) `2026-05-23`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-167 · Optimistic update + rollback en `_resolve()` de `ReportDetailScreen` (P2 audit CU-07) |
| **Qué se corrigió (técnico)** | En `_ReportDetailScreenState._resolve()`: antes de llamar a la API, se guarda `snapshot = _current!` y se actualiza optimistamente `_current` a una copia con `status: ReportStatus.resolved`. Si la llamada API falla (`DioException` o `Exception`), se revierte `setState(() => _current = snapshot)`. En éxito, se actualiza con la respuesta del servidor. |
| **Qué se corrigió (simple)** | Al tocar "Marcar como resuelto", el botón mostraba spinner pero el UI no reflejaba el cambio hasta que llegaba la respuesta del servidor. Si había un error de red, el estado quedaba en `_resolving = true` sin volver al estado anterior. Ahora el UI cambia inmediatamente al estado "Resuelto" al tocar el botón, y revierte si falla. |
| **Clase / Método / Módulo** | `_ReportDetailScreenState._resolve()` → `report_detail_screen.dart` |
| **Justificación** | El plan checklist §4.1.4 exige R-F9 (optimistic update + rollback) explícitamente para `_support()` y `_resolve()`. Solo `_support()` lo implementaba; `_resolve()` carecía del snapshot y del `setState(() => _current = snapshot)` en los bloques `catch`. |
| **Problema que resolvía** | La pantalla de detalle no reflejaba el cambio de estado de forma inmediata, lo que generaba la falsa impresión de que el botón no funcionó. |

---

### C-168 · Test faltante `test_resolve_sends_fcm` en CU-07 `2026-05-23`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-168 · `test_resolve_sends_fcm` en `test_lot_support.py` (P3 audit CU-07) |
| **Qué se corrigió (técnico)** | Añadido `test_resolve_sends_fcm` a `tests/test_lot_support.py`. El test mockea `FirestoreService.get_community_report` (retorna lote con 3 supporters), `FirestoreService.resolve_community_report` (retorna lote resuelto) y `NotificationService.send_lot_resolved`. Llama `PATCH /community-reports/{id}/resolve`, hace `await asyncio.sleep(0)` para vaciar el `asyncio.ensure_future`, y aserta `mock_notify.assert_awaited_once_with(reporter_uid=REPORTER_UID, supporter_uids=[...], report_id=REPORT_ID, resolved_by_uid=SUPPORTER_3)`. |
| **Qué se corrigió (simple)** | El test `test_resolve_marks_status_resolved` parchaba `send_lot_resolved` pero no verificaba que se llamó ni con qué argumentos. Un cambio en la firma de `send_lot_resolved` o en el `asyncio.ensure_future` del router habría pasado desapercibido. Ahora existe un test dedicado que valida el contrato completo de la notificación FCM al resolver un lote. |
| **Clase / Método / Módulo** | `tests/test_lot_support.py` → suite sube de 8 a 9 tests, todos pasan |
| **Justificación** | El plan §4.1.1 ítem 6 lista explícitamente `test_resolve_sends_fcm (mock NotificationService)`. El patrón `asyncio.sleep(0)` es el mismo usado en `test_vendor_cancel_notifies_attendees` (CU-09). |
| **Problema que resolvía** | La garantía de que PATCH /resolve dispara FCM a reporter + supporters no tenía cobertura de test. |

---

### C-169 · Check de duplicado por radio 50 m bloqueaba lotes baldíos en ubicaciones distintas `2026-05-23`

| Campo | Detalle |
|---|---|
| **Nombre clave** | C-169 · Skip de `has_pending_report_within` para `lote_baldio` en `report_router.py` (P4 reportado por el usuario) |
| **Qué se corrigió (técnico)** | En `create_community_report` de `report_router.py`, la llamada a `has_pending_report_within` se envolvió con `if body.threat_type != ThreatType.lote_baldio`. La condición compuesta queda: `if body.threat_type != ThreatType.lote_baldio and await FirestoreService.has_pending_report_within(...)`. |
| **Qué se corrigió (simple)** | Si ya existía un lote baldío reportado, el backend bloqueaba cualquier nuevo reporte de lote baldío dentro de 50 m de la ubicación seleccionada. Esto impedía reportar dos lotes distintos en la misma manzana (pueden estar a 20–40 m uno del otro). El check de duplicado por 50 m tiene sentido para focos de infección (un mismo montón de basura o animal muerto no debe reportarse dos veces), pero no para lotes baldíos: dos terrenos abandonados adyacentes son entidades separadas. La validación de "¿es real?" la aporta el mecanismo de 3 apoyos, no la proximidad. |
| **Clase / Método / Módulo** | `create_community_report()` → `modules/community/report_router.py` |
| **Justificación** | El check de 50 m se basa en la premisa de que dos reportes cercanos del mismo tipo son del mismo incidente. Para `lote_baldio` esa premisa es falsa: dos propiedades colindantes son instancias diferentes. El check de `location_out_of_range` (1 km de GPS) sigue activo para ambos tipos. |
| **Problema que resolvía** | El usuario no podía reportar un segundo lote baldío en ninguna ubicación dentro de 50 m del primero, lo que en áreas urbanas densas bloqueaba reportes legítimos de terrenos distintos. |

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
