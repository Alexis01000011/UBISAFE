# 01 — Arquitectura C4 (Niveles 1 a 3)

Diagramas C4 de UBISAFE centrados en **CU-07 (lotes baldíos)**, **CU-08 (suscripción a
vendedor)** y **CU-09 (estancia grupal)**. Se incluyen los niveles 1 (Contexto),
2 (Contenedores) y 3 (Componentes), según lo solicitado.

---

## Nivel 1 — Diagrama de Contexto

Muestra a UBISAFE como un único sistema, sus usuarios y los servicios externos de los que
depende.

```mermaid
C4Context
    title Nivel 1 - Contexto del sistema UBISAFE (CU-07, CU-08, CU-09)

    Person(comprador, "Comprador", "Reporta y apoya lotes baldios (CU-07), se suscribe a vendedores (CU-08) y confirma asistencia a estancias (CU-09).")
    Person(vendedor, "Vendedor", "Reporta lotes baldios (CU-07), activa su radar de visibilidad (CU-08) y programa estancias grupales (CU-09).")

    System(ubisafe, "UBISAFE", "App de seguridad y logistica comunitaria: mapa en tiempo real, reportes comunitarios, suscripciones y estancias grupales.")

    System_Ext(firebase, "Firebase Platform", "Auth, Firestore, Realtime Database, Cloud Messaging (FCM) y Cloud Functions.")
    System_Ext(maps, "Google Maps Platform", "Mapas, geolocalizacion y renderizado de marcadores.")

    Rel(comprador, ubisafe, "Usa la app movil", "HTTPS / Firebase SDK")
    Rel(vendedor, ubisafe, "Usa la app movil", "HTTPS / Firebase SDK")
    Rel(ubisafe, firebase, "Autentica, persiste datos y envia notificaciones", "HTTPS / SDK")
    Rel(ubisafe, maps, "Muestra mapas y posiciones", "HTTPS")
    Rel(firebase, comprador, "Envia push de proximidad y de estancias", "FCM")
    Rel(firebase, vendedor, "Envia push de cancelacion / solicitudes", "FCM")
```

---

## Nivel 2 — Diagrama de Contenedores

Descompone UBISAFE en sus contenedores ejecutables y de datos. El backend FastAPI atiende
la lógica de CU-07/08/09; Firestore es la base de datos principal; las Cloud Functions
ejecutan las notificaciones reactivas y las transiciones programadas.

```mermaid
C4Container
    title Nivel 2 - Contenedores de UBISAFE

    Person(comprador, "Comprador", "")
    Person(vendedor, "Vendedor", "")

    System_Boundary(ubisafe, "UBISAFE") {
        Container(app, "App movil", "Flutter, Riverpod, GoRouter", "UI de mapa, formularios de reporte de lote, pantalla de suscripciones y de estancias grupales.")
        Container(api, "API UBISAFE", "FastAPI (Python) en Render", "Endpoints REST de /community-reports, /subscriptions y /group-stays; reglas de negocio y validaciones.")
        Container(functions, "Cloud Functions", "Python (Firebase gen2)", "Triggers de Firestore y jobs programados: alertas de proximidad, notificacion de estancias, transiciones de estado y autocancelacion por zona de riesgo.")
    }

    ContainerDb(firestore, "Cloud Firestore", "NoSQL documental", "Colecciones users, community_reports, subscriptions, group_stays (+ attendances), risk_zones.")
    ContainerDb(rtdb, "Realtime Database", "Firebase RTDB", "vendedores_activos: presencia y radar de visibilidad del vendedor en tiempo real.")
    Container_Ext(auth, "Firebase Auth", "", "Identidad y emision de tokens (Bearer).")
    Container_Ext(fcm, "Firebase Cloud Messaging", "", "Entrega de notificaciones push data-only.")
    System_Ext(maps, "Google Maps Platform", "", "Mapas y geolocalizacion.")

    Rel(comprador, app, "Interactua", "")
    Rel(vendedor, app, "Interactua", "")

    Rel(app, auth, "Inicia sesion / obtiene ID token", "HTTPS")
    Rel(app, api, "Llama endpoints REST con Bearer", "HTTPS / Dio")
    Rel(app, firestore, "Lee reportes y estancias en vivo", "Firebase SDK")
    Rel(app, rtdb, "Publica/lee presencia del vendedor", "Firebase SDK")
    Rel(app, maps, "Renderiza mapa y marcadores", "HTTPS")
    Rel(app, fcm, "Recibe push", "FCM")

    Rel(api, auth, "Verifica ID token", "Admin SDK")
    Rel(api, firestore, "CRUD de colecciones", "Admin SDK")
    Rel(api, fcm, "Envia push fire-and-forget", "Admin SDK")

    Rel(functions, firestore, "Triggers onCreate/onUpdate y queries", "Admin SDK")
    Rel(functions, fcm, "Multicast de notificaciones", "Admin SDK")
```

> **Notas de implementación**
> - El registro de routers de la API está en `ubisafe_api/main.py`.
> - El acceso HTTP de la app se centraliza en `ubisafe_app/lib/core/api/api_client.dart` (Dio + interceptor de token).
> - Despliegue de la API: `render.yaml` + `ubisafe_api/Dockerfile`.
> - Cloud Functions: `functions/main.py`.

---

## Nivel 3 — Diagrama de Componentes (CU-07, CU-08, CU-09)

Detalla los componentes internos relevantes a los tres casos de uso, distribuidos entre la
API FastAPI, las Cloud Functions y la app Flutter.

### 3.1 — API FastAPI + Cloud Functions

```mermaid
C4Component
    title Nivel 3 - Componentes backend (API + Functions) para CU-07/08/09

    Container_Boundary(api, "API UBISAFE (FastAPI)") {
        Component(reportRouter, "report_router", "APIRouter", "POST/GET /community-reports (crear y listar reportes). CU-07")
        Component(lotRouter, "lot_router", "APIRouter", "POST /community-reports/{id}/support y PATCH /{id}/resolve. CU-07")
        Component(subsRouter, "subscription_router", "APIRouter", "POST/GET/DELETE /subscriptions. CU-08")
        Component(stayRouter, "group_stay_router", "APIRouter", "POST/GET /group-stays, PATCH /{id}/cancel, POST /{id}/attendances. CU-09")
        Component(firestoreSvc, "FirestoreService", "Servicio", "CRUD y transacciones sobre Firestore; filtro Haversine por proximidad.")
        Component(notifSvc, "NotificationService", "Servicio", "Envio de FCM data-only (lote resuelto, estancia cancelada).")
        Component(deps, "get_current_user", "Dependencia", "Valida el Bearer (Firebase ID token).")
    }

    Container_Boundary(cf, "Cloud Functions") {
        Component(fnProximity, "notify_vendor_proximity_to_subscribers", "Trigger onUpdate users/{uid}", "Al activarse is_active_radar, notifica a suscriptores activos dentro de 4 km. CU-08")
        Component(fnNotifyStay, "notify_group_stay_in_radius", "Trigger onCreate group_stays", "Notifica a compradores BUYER dentro de 500 m. CU-09")
        Component(fnExpire, "expire_group_stays", "Scheduler 5 min", "Transiciones scheduled to active to ended. CU-09")
        Component(fnCancelZone, "cancel_stay_on_risk_zone_change", "Trigger onUpdate risk_zones", "Cancela estancias cuando la zona pasa a HIGH. CU-09")
    }

    ContainerDb(firestore, "Cloud Firestore", "", "")
    Container_Ext(fcm, "FCM", "", "")

    Rel(reportRouter, deps, "Usa", "")
    Rel(lotRouter, deps, "Usa", "")
    Rel(subsRouter, deps, "Usa", "")
    Rel(stayRouter, deps, "Usa", "")

    Rel(reportRouter, firestoreSvc, "Crea/lista reportes", "")
    Rel(lotRouter, firestoreSvc, "support_/resolve_community_report", "")
    Rel(lotRouter, notifSvc, "send_lot_resolved", "")
    Rel(subsRouter, firestoreSvc, "create/list/cancel_subscription", "")
    Rel(stayRouter, firestoreSvc, "create/list/cancel_group_stay, confirm_attendance", "")
    Rel(stayRouter, notifSvc, "send_group_stay_cancelled", "")

    Rel(firestoreSvc, firestore, "Lee/escribe", "Admin SDK")
    Rel(notifSvc, fcm, "Envia push", "Admin SDK")

    Rel(fnProximity, firestore, "Query subscriptions + users", "")
    Rel(fnNotifyStay, firestore, "Query users (BUYER)", "")
    Rel(fnExpire, firestore, "Batch update group_stays", "")
    Rel(fnCancelZone, firestore, "Update group_stays + attendances", "")
    Rel(fnProximity, fcm, "Multicast vendor_proximity_alert", "")
    Rel(fnNotifyStay, fcm, "Multicast rsvp_group_stay", "")
    Rel(fnCancelZone, fcm, "Multicast group_stay_cancelled", "")
```

### 3.2 — App Flutter

```mermaid
C4Component
    title Nivel 3 - Componentes de la app Flutter para CU-07/08/09

    Container_Boundary(app, "App movil (Flutter + Riverpod)") {
        Component(router, "app_router", "GoRouter", "Rutas y guard de autenticacion.")
        Component(apiClient, "api_client", "Dio", "Cliente HTTP con Bearer token hacia la API.")
        Component(notifHandler, "notification_handler", "FCM + Riverpod", "Recibe push y los enruta a providers (proximidad, estancia, lote resuelto).")

        Component(mapBuyer, "MapScreenBuyer", "Pantalla", "Mapa del comprador; marcadores de vendedor, lotes y estancias; SpeedDial de reportes.")
        Component(mapVendor, "MapScreenVendor", "Pantalla", "Mapa del vendedor; toggle de visibilidad; SpeedDial con 'Programar estancia'.")

        Component(communityFeat, "feature community", "Pantallas + servicios", "lot_form / lot_location_picker, active_reports, report_detail; community_report_module. CU-07")
        Component(subsFeat, "feature subscriptions", "Pantalla + servicio", "subscriptions_screen + subscription_module. CU-08")
        Component(stayFeat, "feature group_stays", "Pantallas + servicio", "schedule_group_stay, group_stay_detail + group_stay_module. CU-09")
    }

    Container(api, "API UBISAFE", "FastAPI", "")
    ContainerDb(firestore, "Cloud Firestore", "", "")
    Container_Ext(fcm, "FCM", "", "")

    Rel(router, mapBuyer, "Ruta /home/buyer", "")
    Rel(router, mapVendor, "Ruta /home/vendor", "")
    Rel(router, communityFeat, "Rutas /community/reports*", "")
    Rel(router, subsFeat, "Ruta /subscriptions", "")
    Rel(router, stayFeat, "Rutas /group-stays/*", "")

    Rel(communityFeat, apiClient, "createReport/support/resolve", "")
    Rel(subsFeat, apiClient, "subscribe/list/unsubscribe", "")
    Rel(stayFeat, apiClient, "createStay/cancel/confirmAttendance", "")
    Rel(apiClient, api, "REST + Bearer", "HTTPS")

    Rel(mapBuyer, firestore, "Stream de reportes/estancias", "SDK")
    Rel(notifHandler, fcm, "Recibe push", "FCM")
    Rel(notifHandler, mapBuyer, "Notifica eventos (proximidad, estancias)", "")
```

> **Mapa rápido de componentes ↔ archivos**
> - `report_router` → `ubisafe_api/modules/community/report_router.py`
> - `lot_router` → `ubisafe_api/modules/community/lot_router.py`
> - `subscription_router` → `ubisafe_api/modules/shared/subscription_router.py`
> - `group_stay_router` → `ubisafe_api/modules/dispatching/group_stay_router.py`
> - `FirestoreService` / `NotificationService` → `ubisafe_api/modules/shared/`
> - Cloud Functions → `functions/main.py`
> - App: `ubisafe_app/lib/features/{community,shared/subscriptions,dispatching/group_stays}/`
