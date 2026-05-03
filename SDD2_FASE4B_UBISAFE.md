# SDD2_FASE4B_UBISAFE.md
## Fase 4.B' — Diagramas de Secuencia CU-05 + CU-06
## Los Borbotones · UBISAFE · Iteración 2 · Sección §9 del SDD
### Interaction Viewpoint (IEEE 1016-2009)

> **Nota de uso:** Cada flujo del SRS (flujo normal, flujo alternativo, flujo de excepción) tiene su propio diagrama Mermaid. Exportar cada diagrama como imagen (Mermaid Live Editor, Miro, o extensión VS Code) e insertar en §9 del .docx. Los textos descriptivos van inmediatamente antes de cada diagrama.
>
> **Convención de nombres canónicos:** `CommunityReportModule`, `ReportValidationModule`, `MapScreenBuyer`, `MapScreenVendor`, `NotificationHandler`, `GPSService` (Flutter); `CommunityReportRouter`, `ReportValidationRouter`, `FirestoreService`, `NotificationService` (FastAPI); `aggregateDuplicateReports` (Cloud Function); `community_reports` (Firestore).
>
> **Base:** `SRS v2.1` (flujos CU-05, CU-06) · `SDD_FASE4_UBISAFE.md` (estilo iter. 1) · `SDD2_FASE2_UBISAFE.md` · `SDD2_FASE3B_UBISAFE.md`

---

## Índice

**§9.6 — CU-05: Reportar Foco de Infección**

1. [9.6.A — Flujo Normal](#96a)
2. [9.6.B — Condición 5A: Usuario fuera del radio](#96b)
3. [9.6.C — Condición 7A: Alta densidad → agrupación](#96c)
4. [9.6.D — E1: Pérdida de conexión](#96d)
5. [9.6.E — E2: Error en geolocalización (GPS apagado)](#96e)

**§9.7 — CU-06: Verificar Reportes Comunitarios**

6. [9.7.A — Flujo Normal (umbral no alcanzado)](#97a)
7. [9.7.B — Condición 4A: Usuario ya validó previamente](#97b)
8. [9.7.C — Condición 8A: Reporte confirmado por alta confiabilidad](#97c)
9. [9.7.D — Condición 8B: Reporte descartado por baja confiabilidad](#97d)
10. [9.7.E — E1: Pérdida de conexión](#97e)
11. [9.7.F — E2: Reporte ya no disponible](#97f)

---

> **⚠ Precondiciones globales CU-05 y CU-06 (SRS v2.1)**
>
> - **Cuenta activa:** el usuario (Comprador o Vendedor) debe estar autenticado. `AuthMiddleware` rechaza con `401` si el JWT es inválido o expiró.
> - **GPS activo y permiso concedido:** CU-05 requiere ubicación actual para autocapturar la posición del reporte. Si el GPS no está disponible, `GPSService` emite estado de error y `CommunityReportModule` bloquea el formulario (ver E2 → Diagrama 9.6.E).
> - **Radio de proximidad CU-05:** la posición del usuario debe estar a ≤ 4 km del punto a reportar (mismo punto GPS). Validación en FastAPI con Haversine.
> - **Radio de proximidad CU-06:** el usuario debe estar a ≤ 4 km del reporte que desea validar. FastAPI valida con Haversine.
> - **Reporte no verificado (CU-06):** el usuario no debe haber validado previamente el mismo reporte (ver Condición 4A → Diagrama 9.7.B).

---

## §9.6 — CU-05: Reportar Foco de Infección

### Descripción

El CU-05 permite que cualquier usuario autenticado reporte un foco de infección sanitaria (`animal_muerto` / `zona_sucia`) desde su posición GPS actual. El reporte inicia con estado `pending_validation` y requiere validación colectiva antes de confirmarse (ver CU-06). No bloquea rutas de vendedores — es puramente informativo.

El flujo involucra: App Flutter, API FastAPI, Cloud Firestore, FCM, y de forma asíncrona post-respuesta, Cloud Functions para detección de duplicados.

**Flujos cubiertos (5 diagramas):**

| Diagrama | Tipo | Trigger |
|---|---|---|
| 9.6.A | Flujo Normal | Reporte válido, ubicación dentro del radio, GPS activo |
| 9.6.B | Alternativo — Cond. 5A | Usuario intenta reportar fuera del radio de 4 km |
| 9.6.C | Alternativo — Cond. 7A | Reporte duplicado del mismo tipo a ≤ 100 m |
| 9.6.D | Excepción — E1 | Pérdida de conexión durante el envío |
| 9.6.E | Excepción — E2 | GPS no disponible o permiso no concedido |

---

### Diagrama 9.6.A — Flujo Normal {#96a}

El usuario reporta un foco de infección con GPS activo y dentro del radio de 4 km. FastAPI registra el reporte con estado `pending_validation`, notifica a usuarios cercanos vía FCM, y Cloud Functions se dispara asincrónicamente para verificar si hay duplicados. Al no encontrar duplicados, el reporte queda como canónico y se muestra en todos los mapas.

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario<br/>(Comprador o Vendedor)
    participant HS as HomeScreen<br/>(MapScreenBuyer / MapScreenVendor)
    participant CRM as CommunityReportModule
    participant GPS as GPSService
    participant API as CommunityReportRouter<br/>(FastAPI)
    participant FS as Firestore
    participant NS as NotificationService
    participant FCM as FCM
    participant NH as NotificationHandler<br/>(otros usuarios)
    participant MS as MapScreen<br/>(todos los usuarios)
    participant CF as aggregateDuplicateReports<br/>(Cloud Function)

    Note over U,HS: Pre: GPS activo, usuario autenticado, a ≤ 4 km del área
    U->>HS: Selecciona opción de reportes<br/>(FAB "+" → SpeedDial → "Reportar foco de infección")
    HS->>CRM: openReportForm()
    CRM->>GPS: getCurrentLocation()
    GPS-->>CRM: userLocation: GeoPoint (lat, lng)
    CRM->>U: Muestra formulario:<br/>selector threat_type (animal_muerto / zona_sucia)<br/>coordenadas auto-detectadas (solo lectura)
    U->>CRM: Selecciona threat_type → toca "Confirmar envío"

    CRM->>API: POST /community-reports + JWT<br/>{ threat_type: "animal_muerto",<br/>location: GeoPoint (auto-GPS),<br/>radius_meters: 15 }
    API->>API: Verifica JWT → extrae reporter_uid
    API->>API: Valida threat_type ∈ { animal_muerto, zona_sucia }
    API->>API: Valida Haversine(userLocation, location) ≤ 4 km ✓
    API->>FS: Crea community_reports/{id}<br/>{ reporter_uid, threat_type: "animal_muerto",<br/>location, radius_meters: 15,<br/>status: "pending_validation",<br/>validations: [], confirm_count: 0, dismiss_count: 0,<br/>is_duplicate: false, canonical_report_id: null,<br/>created_at: now, updated_at: now,<br/>expires_at: now + 24h }
    FS-->>API: report_id

    API->>NS: notify_community_report_nearby(<br/>usuarios_cercanos_uids[], report_data)
    Note over NS,FCM: Fan-out a tokens FCM de usuarios con<br/>last_location a ≤ 4 km del reporte
    NS->>FCM: send_each(tokens[])<br/>{ type: "community_report_nearby",<br/>report_id, threat_type, lat, lng }
    FCM-->>NH: Push notification a usuarios cercanos
    NH->>MS: Despacha evento community_report_nearby

    API-->>CRM: 201 Created { report_id, status: "pending_validation" }
    CRM->>HS: Cierra formulario
    HS->>U: Snackbar "Reporte registrado correctamente"

    MS->>MS: Renderiza marcador en mapa:<br/>negro (animal_muerto) / café (zona_sucia)<br/>leyenda "Pendiente"

    Note over FS,CF: Trigger asíncrono (post-respuesta al cliente)
    FS->>CF: onCreate trigger<br/>/community_reports/{report_id}
    CF->>FS: Consulta reportes activos:<br/>threat_type = "animal_muerto", is_duplicate = false,<br/>status ∈ [pending_validation, confirmed]
    FS-->>CF: Lista de candidatos (bounding box)
    CF->>CF: Haversine vs. nuevo reporte → ninguno a ≤ 100 m
    Note over CF: Reporte es canónico — sin acción
```

---

### Diagrama 9.6.B — Condición 5A: Usuario fuera del radio {#96b}

El usuario intenta reportar desde una ubicación a más de 4 km del área del foco. FastAPI detecta la violación de radio con Haversine y rechaza el registro con `400 Bad Request`. El sistema notifica al usuario del motivo del fallo. El reporte no se registra.

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario<br/>(Comprador o Vendedor)
    participant HS as HomeScreen<br/>(MapScreenBuyer / MapScreenVendor)
    participant CRM as CommunityReportModule
    participant GPS as GPSService
    participant API as CommunityReportRouter<br/>(FastAPI)

    Note over U,HS: Pre: GPS activo, usuario autenticado<br/>⚠ Usuario a > 4 km del punto del foco
    U->>HS: Selecciona "Reportar foco de infección"
    HS->>CRM: openReportForm()
    CRM->>GPS: getCurrentLocation()
    GPS-->>CRM: userLocation: GeoPoint (lejana al área)
    CRM->>U: Muestra formulario con coordenadas auto-detectadas
    U->>CRM: Selecciona threat_type → toca "Confirmar envío"

    CRM->>API: POST /community-reports + JWT<br/>{ threat_type: "zona_sucia",<br/>location: GeoPoint (posición GPS del usuario),<br/>radius_meters: 15 }
    API->>API: Verifica JWT ✓
    API->>API: Calcula Haversine(userLocation, location)<br/>= 5.8 km > 4 km → FUERA DEL RADIO

    Note over API: El radio es la distancia entre el usuario<br/>y el punto que está reportando.<br/>En CU-05 la ubicación del reporte ES la posición<br/>del usuario — si el GPS ubica al usuario lejos<br/>del área afectada, FastAPI lo rechaza.
    API-->>CRM: 400 Bad Request<br/>{ error: "location_out_of_range",<br/>message: "Debes estar a ≤ 4 km del área para reportar" }

    CRM->>CRM: Maneja error 400
    CRM->>U: Muestra error en formulario:<br/>"Debes estar en la zona para reportar este foco"
    Note over CRM: Formulario permanece abierto<br/>El usuario puede cancelar
    U->>CRM: Cancela el reporte
    CRM->>HS: Cierra formulario sin guardar
```

---

### Diagrama 9.6.C — Condición 7A: Alta densidad de reportes similares (agrupación) {#96c}

El usuario reporta un foco del mismo tipo que otro reporte activo a menos de 100 m. FastAPI crea el documento normalmente (el cliente recibe `201 Created`). Asincrónicamente, `aggregateDuplicateReports` detecta el reporte canónico y marca el nuevo como duplicado. Flutter agrupa visualmente el reporte duplicado bajo el pin canónico, mostrando un contador de reportes cercanos.

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario<br/>(Comprador o Vendedor)
    participant HS as HomeScreen
    participant CRM as CommunityReportModule
    participant API as CommunityReportRouter<br/>(FastAPI)
    participant FS as Firestore
    participant CF as aggregateDuplicateReports<br/>(Cloud Function)
    participant MS as MapScreen<br/>(todos los usuarios)

    Note over U,HS: Pre: Ya existe un reporte canónico activo<br/>del mismo threat_type a ≤ 100 m
    Note over U,CRM: Mismo inicio que Flujo Normal (pasos 1–6)
    U->>CRM: Selecciona threat_type: "animal_muerto" → "Confirmar envío"

    CRM->>API: POST /community-reports + JWT<br/>{ threat_type: "animal_muerto", location, radius_meters: 15 }
    API->>API: Verifica JWT ✓ · Radio 4 km ✓ · threat_type válido ✓
    API->>FS: Crea community_reports/{nuevo_id}<br/>{ status: "pending_validation",<br/>is_duplicate: false, ... }
    FS-->>API: nuevo_id
    API-->>CRM: 201 Created { report_id: nuevo_id, status: "pending_validation" }
    CRM->>U: Snackbar "Reporte registrado correctamente"

    Note over FS,CF: Trigger asíncrono — Cloud Function detecta duplicado
    FS->>CF: onCreate trigger /community_reports/{nuevo_id}
    CF->>FS: Consulta reportes activos del mismo threat_type<br/>is_duplicate = false, status ∈ [pending_validation, confirmed]
    FS-->>CF: Retorna reporte canónico existente (id_canónico)
    CF->>CF: Haversine(nuevo_lat, nuevo_lng,<br/>canónico_lat, canónico_lng) = 47 m ≤ 100 m
    Note over CF: Duplicado detectado
    CF->>FS: Update community_reports/{nuevo_id}<br/>{ is_duplicate: true,<br/>canonical_report_id: "id_canónico",<br/>updated_at: now }

    Note over CRM,MS: Flutter reacciona al cambio en Firestore
    MS->>MS: Oculta marcador del duplicado
    MS->>MS: Actualiza pin canónico:<br/>"× 2 reportes similares en esta zona"
    Note over MS: El usuario ve los reportes agrupados<br/>bajo el marcador del reporte original
```

---

### Diagrama 9.6.D — E1: Pérdida de conexión {#96d}

El usuario intenta enviar el reporte pero la conexión falla. UBISAFE almacena temporalmente el payload en memoria y reintenta el envío automáticamente con backoff exponencial (hasta 3 intentos). Si se recupera la conexión, el flujo continúa como el Flujo Normal. Si los 3 intentos fallan, el sistema notifica al usuario del fallo y descarta el payload.

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario<br/>(Comprador o Vendedor)
    participant HS as HomeScreen
    participant CRM as CommunityReportModule
    participant API as CommunityReportRouter<br/>(FastAPI)

    Note over U,HS: Pre: GPS activo, usuario autenticado<br/>⚠ Señal de datos no disponible
    Note over U,CRM: Mismo inicio que Flujo Normal (pasos 1–6)
    U->>CRM: Selecciona threat_type → "Confirmar envío"

    CRM->>API: POST /community-reports + JWT { threat_type, location, ... }
    API--xCRM: Timeout / ConnectionException (sin respuesta de red)

    CRM->>CRM: Detecta falla de conexión
    CRM->>CRM: Almacena payload en memoria<br/>Intento 1 fallido → inicia backoff (2 s)
    CRM->>U: Notifica al usuario: "Error de conexión. Reintentando..."

    loop Retry automático — máx. 3 intentos (backoff: 2 s → 4 s → 8 s)
        CRM->>API: POST /community-reports (reintento N)
        alt Conexión recuperada
            API-->>CRM: 201 Created { report_id, status: "pending_validation" }
            CRM->>HS: Cierra formulario
            HS->>U: Snackbar "Reporte registrado correctamente"
            Note over CRM: Flujo continúa como Normal:<br/>FCM fan-out + Cloud Function async
        else Sin señal — timeout nuevamente
            API--xCRM: ConnectionException
            CRM->>CRM: Incrementa contador de intentos<br/>Backoff exponencial antes del siguiente intento
        end
    end

    Note over CRM: Tras 3 intentos fallidos sin éxito
    CRM->>U: Error persistente:<br/>"No se pudo enviar el reporte.<br/>Inténtalo cuando tengas señal."
    Note over CRM: Payload descartado de memoria<br/>(no hay persistencia offline en iter. 2)
    CRM->>HS: Cierra formulario sin guardar
```

---

### Diagrama 9.6.E — E2: Error en geolocalización (GPS apagado) {#96e}

El usuario intenta reportar un foco pero el GPS del dispositivo no está activo o el permiso de ubicación no fue concedido. UBISAFE detecta la falla de geolocalización, bloquea el formulario, y solicita al usuario que active su GPS. El sistema espera reactivamente a que el GPS se active antes de permitir continuar.

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario<br/>(Comprador o Vendedor)
    participant HS as HomeScreen<br/>(MapScreenBuyer / MapScreenVendor)
    participant CRM as CommunityReportModule
    participant GPS as GPSService

    Note over U,HS: ⚠ GPS del dispositivo apagado o permiso no concedido
    U->>HS: Selecciona "Reportar foco de infección"
    HS->>CRM: openReportForm()
    CRM->>GPS: getCurrentLocation()
    GPS-->>CRM: Error: GPS_UNAVAILABLE / PERMISSION_DENIED

    CRM->>CRM: Detecta falla de geolocalización
    CRM->>U: Muestra estado de error:<br/>"Activa tu GPS para poder reportar un foco"
    Note over CRM: El formulario de selección de tipo NO se muestra<br/>El botón "Confirmar envío" está deshabilitado<br/>UBISAFE no permite avanzar hasta tener ubicación válida

    CRM->>GPS: Suscribe a gpsStatusProvider<br/>(escucha reactiva)

    alt Usuario activa el GPS (o concede permiso)
        GPS-->>CRM: gpsStatusProvider emite: GPS_ACTIVE
        CRM->>GPS: getCurrentLocation() [reintento]
        GPS-->>CRM: userLocation: GeoPoint (lat, lng) válida
        CRM->>U: Muestra formulario de reporte con<br/>coordenadas auto-detectadas
        Note over CRM: Flujo continúa como Flujo Normal (9.6.A)
    else Usuario cancela sin activar GPS
        U->>HS: Cierra el panel de reporte
        Note over CRM: Formulario descartado<br/>El reporte no se envía
    end
```

---

## §9.7 — CU-06: Verificar Reportes Comunitarios

### Descripción

El CU-06 permite que cualquier usuario autenticado valide (confirme o refute) un reporte comunitario de foco de infección creado por otra persona mediante CU-05. El sistema usa votación simple binaria con umbral de 3 votos en cualquier dirección para cambiar el estado del reporte (ADR #6).

**Reglas de negocio clave:** (1) el usuario no puede validar su propio reporte, (2) solo puede votar una vez por reporte, (3) el reporte debe estar en estado `pending_validation`, (4) el usuario debe estar a ≤ 4 km del reporte.

**Flujos cubiertos (6 diagramas):**

| Diagrama | Tipo | Trigger |
|---|---|---|
| 9.7.A | Flujo Normal | Voto registrado, umbral NOT alcanzado → sigue `pending_validation` |
| 9.7.B | Alternativo — Cond. 4A | Usuario ya participó previamente en la validación |
| 9.7.C | Alternativo — Cond. 8A | `confirm_count` alcanza umbral → estado `confirmed` |
| 9.7.D | Alternativo — Cond. 8B | `dismiss_count` alcanza umbral → estado `dismissed` |
| 9.7.E | Excepción — E1 | Pérdida de conexión al enviar el voto |
| 9.7.F | Excepción — E2 | Reporte ya no disponible (eliminado o cambiado de estado) |

---

### Diagrama 9.7.A — Flujo Normal (umbral no alcanzado) {#97a}

El usuario selecciona un reporte activo, ve sus detalles y emite su voto. FastAPI registra la validación y actualiza los contadores. El umbral de 3 votos **no** se alcanza, por lo que el estado permanece en `pending_validation`. UBISAFE notifica a los usuarios cercanos sobre la actualización del reporte.

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario<br/>(Comprador o Vendedor)
    participant MS as MapScreen<br/>(MapScreenBuyer / MapScreenVendor)
    participant CRM as CommunityReportModule
    participant RVM as ReportValidationModule
    participant API as ReportValidationRouter<br/>(FastAPI)
    participant FS as Firestore
    participant NS as NotificationService
    participant FCM as FCM
    participant NH as NotificationHandler<br/>(usuarios cercanos)

    Note over U,MS: Pre: Reporte en pending_validation,<br/>usuario a ≤ 4 km, no ha votado antes
    U->>MS: Selecciona marcador de reporte comunitario en el mapa
    MS->>CRM: Abre panel de detalle del reporte<br/>{ report_id, threat_type, status: "pending_validation",<br/>confirm_count: 1, dismiss_count: 0, reporter_uid,<br/>validations: [], created_at }
    CRM->>RVM: openValidationPanel(context, report)

    RVM->>U: Muestra información del reporte:<br/>descripción · localización · confirm_count: 1 · dismiss_count: 0<br/>[ "Confirmar reporte" ] [ "Es falso / Desmentir" ]

    U->>RVM: Toca "Confirmar reporte"
    RVM->>API: PATCH /community-reports/{id}/validations + JWT<br/>{ vote: "confirm" }

    API->>API: Verifica JWT → extrae validator_uid
    API->>API: Anti-doble-voto:<br/>validator_uid ∉ report.validations[] ✓
    API->>API: Estado del reporte:<br/>status == "pending_validation" ✓
    API->>FS: Añade a validations[]:<br/>{ user_uid: validator_uid, verdict: "confirm", timestamp: now }<br/>confirm_count++ → 2<br/>updated_at: now
    API->>API: Evalúa umbral: confirm_count (2) < 3<br/>→ status permanece "pending_validation"
    FS-->>API: Documento actualizado { confirm_count: 2, status: "pending_validation" }

    API->>NS: notify_community_report_updated(<br/>usuarios_cercanos_uids[], report_id, confirm_count: 2)
    NS->>FCM: send_each(tokens[])<br/>{ type: "community_report_updated", report_id }
    FCM-->>NH: Push a usuarios cercanos

    API-->>RVM: 200 OK { status: "pending_validation",<br/>confirm_count: 2, dismiss_count: 0 }
    RVM->>CRM: Actualiza stream del reporte (confirm_count: 2)
    CRM->>MS: Refresca panel — sin cambio de color ni leyenda<br/>(estado sigue pending_validation)
    RVM->>U: Feedback "Tu confirmación fue registrada"
```

---

### Diagrama 9.7.B — Condición 4A: Usuario ya validó previamente {#97b}

UBISAFE detecta que el usuario ya participó en la validación del reporte (ya emitió un voto anteriormente). El sistema bloquea una nueva interacción en el cliente y notifica al usuario que ya participó. Si por condición de carrera el voto llega al servidor, FastAPI también lo rechaza con `409 Conflict`.

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario<br/>(Comprador o Vendedor)
    participant MS as MapScreen
    participant CRM as CommunityReportModule
    participant RVM as ReportValidationModule
    participant API as ReportValidationRouter<br/>(FastAPI)

    Note over U,MS: Pre: Usuario ya votó antes en este reporte
    U->>MS: Selecciona marcador de reporte comunitario
    MS->>CRM: Abre panel de detalle<br/>{ report_id, validations: [{user_uid: currentUser.uid,<br/>verdict: "confirm", timestamp: ...}], ... }
    CRM->>RVM: openValidationPanel(context, report)

    Note over RVM: Validación local (client-side) al abrir el panel
    RVM->>RVM: ¿currentUser.uid ∈ report.validations[]?
    Note over RVM: SÍ → usuario ya participó → BLOQUEO INMEDIATO
    RVM->>RVM: Oculta botones "Confirmar" y "Desmentir"
    RVM->>U: Muestra mensaje informativo:<br/>"Ya participaste en la validación de este reporte"

    Note over API: Si por condición de carrera (datos locales desactualizados)<br/>el PATCH llegara al servidor...
    RVM-->>API: PATCH /community-reports/{id}/validations + JWT { vote: "confirm" }
    API->>API: Anti-doble-voto:<br/>validator_uid ∈ report.validations[] → RECHAZA
    API-->>RVM: 409 Conflict<br/>{ error: "already_voted",<br/>message: "Ya validaste este reporte" }
    RVM->>U: Snackbar de error (fallback server-side)
    Note over RVM: UBISAFE bloquea la nueva interacción<br/>La validación previa se mantiene sin cambios
```

---

### Diagrama 9.7.C — Condición 8A: Reporte confirmado por alta confiabilidad {#97c}

UBISAFE detecta que el reporte ha alcanzado el umbral mínimo de confirmaciones (`confirm_count ≥ 3`). El sistema actualiza el estado del reporte a `confirmed`, notifica a los compradores/vendedores cercanos, y actualiza el marcador en todos los mapas con el indicador visual de "Validado".

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario<br/>(Comprador o Vendedor)
    participant MS as MapScreen
    participant CRM as CommunityReportModule
    participant RVM as ReportValidationModule
    participant API as ReportValidationRouter<br/>(FastAPI)
    participant FS as Firestore
    participant NS as NotificationService
    participant FCM as FCM
    participant NH as NotificationHandler<br/>(usuarios cercanos)

    Note over U,MS: Pre: Reporte en pending_validation con confirm_count = 2<br/>(un voto más alcanza el umbral de 3)
    U->>MS: Selecciona marcador de reporte comunitario
    MS->>CRM: Abre panel de detalle<br/>{ report_id, status: "pending_validation",<br/>confirm_count: 2, dismiss_count: 0, ... }
    CRM->>RVM: openValidationPanel(context, report)
    RVM->>U: Muestra detalle del reporte + botones de validación
    U->>RVM: Toca "Confirmar reporte"

    RVM->>API: PATCH /community-reports/{id}/validations + JWT<br/>{ vote: "confirm" }
    API->>API: Verifica JWT ✓ · Anti-doble-voto ✓ · Estado pending ✓
    API->>FS: Añade a validations[]:<br/>{ user_uid, verdict: "confirm", timestamp: now }<br/>confirm_count++ → 3
    API->>API: Evalúa umbral: confirm_count (3) ≥ 3<br/>→ UMBRAL DE CONFIRMACIÓN ALCANZADO
    API->>FS: Update community_reports/{id}<br/>{ status: "confirmed", updated_at: now }
    FS-->>API: Documento actualizado { confirm_count: 3, status: "confirmed" }

    Note over NS,FCM: UBISAFE detecta múltiples confirmaciones<br/>→ notifica a compradores/vendedores cercanos
    API->>NS: notify_community_report_confirmed(<br/>usuarios_cercanos_uids[], report_id, threat_type)
    NS->>FCM: send_each(tokens[])<br/>{ type: "community_report_confirmed",<br/>report_id, threat_type, lat, lng }
    FCM-->>NH: Push "Reporte comunitario confirmado por la comunidad"

    API-->>RVM: 200 OK { status: "confirmed",<br/>confirm_count: 3, dismiss_count: 0 }
    RVM->>CRM: Actualiza stream → status: "confirmed"
    CRM->>MS: Actualiza marcador en mapa:<br/>color saturado (negro oscuro / café oscuro)<br/>leyenda "Validado"
    RVM->>U: Feedback:<br/>"Tu confirmación fue registrada<br/>· Reporte confirmado por la comunidad"
```

---

### Diagrama 9.7.D — Condición 8B: Reporte descartado por baja confiabilidad {#97d}

UBISAFE detecta que el reporte ha recibido suficientes rechazos (`dismiss_count ≥ 3`). El sistema actualiza el estado a `dismissed`, va atenuando la visibilidad del marcador en el mapa y notifica a los compradores/vendedores cercanos sobre el descarte.

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario<br/>(Comprador o Vendedor)
    participant MS as MapScreen
    participant CRM as CommunityReportModule
    participant RVM as ReportValidationModule
    participant API as ReportValidationRouter<br/>(FastAPI)
    participant FS as Firestore
    participant NS as NotificationService
    participant FCM as FCM
    participant NH as NotificationHandler<br/>(usuarios cercanos)

    Note over U,MS: Pre: Reporte en pending_validation con dismiss_count = 2<br/>(un rechazo más alcanza el umbral de 3)
    U->>MS: Selecciona marcador de reporte comunitario
    MS->>CRM: Abre panel de detalle<br/>{ report_id, status: "pending_validation",<br/>confirm_count: 0, dismiss_count: 2, ... }
    CRM->>RVM: openValidationPanel(context, report)
    RVM->>U: Muestra detalle del reporte + botones de validación
    U->>RVM: Toca "Es falso / Desmentir"

    RVM->>API: PATCH /community-reports/{id}/validations + JWT<br/>{ vote: "dismiss" }
    API->>API: Verifica JWT ✓ · Anti-doble-voto ✓ · Estado pending ✓
    API->>FS: Añade a validations[]:<br/>{ user_uid, verdict: "dismiss", timestamp: now }<br/>dismiss_count++ → 3
    API->>API: Evalúa umbral: dismiss_count (3) ≥ 3<br/>→ UMBRAL DE RECHAZO ALCANZADO
    API->>FS: Update community_reports/{id}<br/>{ status: "dismissed", updated_at: now }
    FS-->>API: Documento actualizado { dismiss_count: 3, status: "dismissed" }

    Note over NS,FCM: UBISAFE detecta múltiples rechazos<br/>→ notifica a compradores/vendedores cercanos
    API->>NS: notify_community_report_dismissed(<br/>usuarios_cercanos_uids[], report_id)
    NS->>FCM: send_each(tokens[])<br/>{ type: "community_report_dismissed", report_id }
    FCM-->>NH: Push "Reporte descartado por la comunidad"

    API-->>RVM: 200 OK { status: "dismissed",<br/>confirm_count: 0, dismiss_count: 3 }
    RVM->>CRM: Actualiza stream → status: "dismissed"
    CRM->>MS: Atenúa visibilidad del marcador en mapa<br/>(color gris, opacidad reducida)
    Note over MS: El marcador permanece atenuado<br/>hasta que expires_at se alcance (24h),<br/>momento en que desaparece del mapa
    RVM->>U: Feedback:<br/>"Tu rechazo fue registrado<br/>· Reporte descartado por la comunidad"
```

---

### Diagrama 9.7.E — E1: Pérdida de conexión {#97e}

El usuario intenta votar sobre un reporte pero la conexión falla. UBISAFE almacena temporalmente la acción, notifica al usuario del fallo y reintenta la sincronización automáticamente.

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario<br/>(Comprador o Vendedor)
    participant MS as MapScreen
    participant CRM as CommunityReportModule
    participant RVM as ReportValidationModule
    participant API as ReportValidationRouter<br/>(FastAPI)

    Note over U,MS: ⚠ Señal de datos no disponible al intentar votar
    U->>MS: Selecciona marcador de reporte
    MS->>CRM: Abre panel de detalle del reporte
    CRM->>RVM: openValidationPanel(context, report)
    RVM->>U: Muestra información y botones de validación
    U->>RVM: Toca "Confirmar reporte"

    RVM->>API: PATCH /community-reports/{id}/validations + JWT<br/>{ vote: "confirm" }
    API--xRVM: Timeout / ConnectionException (sin respuesta de red)

    RVM->>RVM: Detecta falla de conexión
    RVM->>RVM: Almacena acción temporalmente en memoria<br/>{ report_id, vote: "confirm" }
    RVM->>U: Notifica fallo al usuario:<br/>"Error de conexión. Tu voto se sincronizará automáticamente"

    loop Retry automático — máx. 3 intentos
        RVM->>API: PATCH /community-reports/{id}/validations (reintento)
        alt Conexión recuperada
            API-->>RVM: 200 OK { status, confirm_count, dismiss_count }
            RVM->>CRM: Actualiza stream del reporte
            CRM->>MS: Refresca marcador en mapa
            RVM->>U: Feedback "Tu confirmación fue registrada"
            Note over RVM: Flujo continúa según corresponda<br/>(Normal, 8A o 8B según el umbral)
        else Sin señal — timeout nuevamente
            API--xRVM: ConnectionException
            RVM->>RVM: Reintento fallido — espera antes del siguiente
        end
    end

    Note over RVM: Tras 3 intentos fallidos sin éxito
    RVM->>U: Error persistente:<br/>"No se pudo registrar tu voto.<br/>Inténtalo de nuevo cuando tengas señal."
    Note over RVM: Acción descartada de memoria
```

---

### Diagrama 9.7.F — E2: Reporte ya no disponible {#97f}

El reporte que el usuario quiere validar ha sido eliminado o cambió de estado durante la interacción (otro usuario lo confirmó/descartó mientras tanto). UBISAFE cancela la acción, notifica al usuario y actualiza el marcador al estado real del reporte.

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario<br/>(Comprador o Vendedor)
    participant MS as MapScreen
    participant CRM as CommunityReportModule
    participant RVM as ReportValidationModule
    participant API as ReportValidationRouter<br/>(FastAPI)
    participant FS as Firestore

    Note over U,MS: Pre: La caché local muestra status: "pending_validation"<br/>⚠ El reporte fue confirmado/descartado por otro usuario mientras tanto
    U->>MS: Selecciona marcador de reporte
    MS->>CRM: Abre panel de detalle<br/>(datos cacheados localmente — status: "pending_validation")
    CRM->>RVM: openValidationPanel(context, report)
    RVM->>U: Muestra botones de validación (basado en caché local)
    U->>RVM: Toca "Confirmar reporte"

    RVM->>API: PATCH /community-reports/{id}/validations + JWT<br/>{ vote: "confirm" }
    API->>FS: Lee community_reports/{id}.status actual
    FS-->>API: status: "confirmed" (cambió server-side)
    API->>API: Verifica status == "pending_validation" → FALLA<br/>(reporte ya no está disponible para validación)

    API-->>RVM: 409 Conflict<br/>{ error: "report_not_in_validation",<br/>message: "Este reporte ya no está disponible para validar" }

    Note over RVM: UBISAFE cancela la acción
    RVM->>CRM: Solicita refresco del reporte desde servidor
    CRM->>MS: Actualiza marcador al estado real:<br/>"confirmed" → color saturado / leyenda "Validado"
    RVM->>RVM: Oculta botones de validación (status ≠ pending_validation)
    RVM->>U: Notifica al usuario:<br/>"Este reporte ya fue validado por la comunidad<br/>y no está disponible para nuevas validaciones"
```

---

## Notas de implementación

### Métodos nuevos de NotificationService implícitos en iter. 2

Los Diagramas 9.7.A, 9.7.C y 9.7.D incluyen llamadas a `NotificationService` para eventos de validación que **no estaban en el diseño de Fase 2'**. Deben añadirse a `NotificationService` y `ReportValidationRouter`:

| Método nuevo | Diagrama | Evento FCM |
|---|---|---|
| `notify_community_report_updated(uids, report_id)` | 9.7.A | `community_report_updated` |
| `notify_community_report_confirmed(uids, report_id, threat_type)` | 9.7.C | `community_report_confirmed` |
| `notify_community_report_dismissed(uids, report_id)` | 9.7.D | `community_report_dismissed` |

**Total de métodos en NotificationService tras este ajuste:** 11 (4 iter.1 + 4 raite iter.2 + 3 validación iter.2)

### GPS reactivo en CU-05 E2

`CommunityReportModule` suscribe a `gpsStatusProvider` (Riverpod) al detectar GPS no disponible. Cuando el stream emite `GPS_ACTIVE`, el módulo reintenta `getCurrentLocation()` y habilita el formulario automáticamente sin que el usuario tenga que hacer nada adicional. Este comportamiento es consistente con `GpsRequiredEmptyState` (ya implementado en iter. 1).

### Bloqueo de voto propio (regla de negocio — no en SRS CU-06)

Además de la Condición 4A, la arquitectura (ADR #6) impide que el reportante vote su propio reporte. `ReportValidationModule` verifica `report.reporter_uid === currentUser.uid` antes de mostrar los botones. Si llega al servidor, `ReportValidationRouter` responde `403 Forbidden`. Esta restricción no tiene diagrama propio porque no es un flujo explícito en el SRS — es una precondición de negocio documentada en ADR #6 y en las reglas de validación de `ReportValidationRouter` (§5.3.5.4).

---

## Cobertura completa de flujos SRS v2.1

### CU-05

| Flujo SRS | Diagrama | Cubierto |
|---|---|---|
| Flujo Normal | 9.6.A | ✅ |
| Condición 5A: usuario fuera del radio | 9.6.B | ✅ |
| Condición 7A: alta densidad → agrupación | 9.6.C | ✅ |
| E1: Pérdida de conexión | 9.6.D | ✅ |
| E2: Error en geolocalización | 9.6.E | ✅ |

**Criterios de aceptación:**

| CA | Verificación | Diagrama | ✅ |
|---|---|---|---|
| CA-05.1: registro en ≤ 10 s | POST → Firestore write sin bloqueos | 9.6.A | ✅ |
| CA-05.2: rechazo fuera del radio | FastAPI Haversine > 4 km → 400 | 9.6.B | ✅ |
| CA-05.3: agrupación visual de duplicados | Cloud Function marca is_duplicate, Flutter agrupa | 9.6.C | ✅ |
| CA-05.4: almacenamiento + retry ante pérdida | Payload en memoria + backoff exponencial | 9.6.D | ✅ |

### CU-06

| Flujo SRS | Diagrama | Cubierto |
|---|---|---|
| Flujo Normal | 9.7.A | ✅ |
| Condición 4A: usuario ya validó | 9.7.B | ✅ |
| Condición 8A: confirmado por alta confiabilidad | 9.7.C | ✅ |
| Condición 8B: descartado por baja confiabilidad | 9.7.D | ✅ |
| E1: Pérdida de conexión | 9.7.E | ✅ |
| E2: Reporte ya no disponible | 9.7.F | ✅ |

**Criterios de aceptación:**

| CA | Verificación | Diagrama | ✅ |
|---|---|---|---|
| CA-06.1: registro en ≤ 10 s | PATCH → Firestore update sin bloqueos | 9.7.A | ✅ |
| CA-06.2: confirm_count ≥ 3 → confirmed | FastAPI evalúa umbral → actualiza status | 9.7.C | ✅ |
| CA-06.3: dismiss_count ≥ 3 → dismissed | FastAPI evalúa umbral → actualiza status | 9.7.D | ✅ |

---

## Handoff a Alexis / Miguel (integración al .docx)

1. Cada diagrama va en su propia subsección de §9 del SDD: exportar de Mermaid Live Editor como PNG o SVG.
2. El texto descriptivo encima de cada diagrama va en el .docx antes de la imagen.
3. **Nueva entrada en §9 del SDD:** §9.6 (CU-05, 5 diagramas) y §9.7 (CU-06, 6 diagramas).
4. **Actualización a SDD2_FASE2 (nota para Miguel):** `ReportValidationRouter` ahora también llama a `NotificationService` con 3 métodos nuevos. Incluir en la descripción de §5.3.5.4.
5. **En §13 Historial:** entrada V3.0 debe mencionar: "§9.6 (CU-05: 5 flujos) y §9.7 (CU-06: 6 flujos) — Interaction Viewpoint iter. 2. 11 diagramas total."

---

## Historial del archivo

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| V1.0 | 24/04/2026 | Alexis Córdova (con Claude) | Fase 4.B' inicial: 4 diagramas (flujos combinados) |
| V2.0 | 25/04/2026 | Alexis Córdova (con Claude) | Revisión completa con SRS v2.1: 11 diagramas, un diagrama por flujo. CU-05: +9.6.B (Cond5A), +9.6.C (Cond7A), +9.6.D (E1), +9.6.E (E2). CU-06: +9.7.B (Cond4A), +9.7.C (Cond8A), +9.7.D (Cond8B), +9.7.E (E1), +9.7.F (E2). Separados 9.7.A (normal) de condiciones 8A/8B. Añadidos 3 métodos FCM a NotificationService. |

---

*Fase 4.B' — V2.0 completada. Output: `SDD2_FASE4B_UBISAFE.md`.*  
*Compartir con Miguel para revisión cruzada y coherencia con Fase 4.A' (CU-04).*  
*Generado: 25/04/2026 — Los Borbotones / UBISAFE Iteración 2*
