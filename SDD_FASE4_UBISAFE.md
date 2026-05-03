# SDD UBISAFE — Fase 4: Diagramas de Secuencia
## Los Borbotones · Iteración 1
### Sección 8 del SDD — Interaction Viewpoint (IEEE 1016-2009)

> **Nota de uso:** Este archivo contiene los diagramas de secuencia en formato Mermaid. Cada diagrama debe exportarse como imagen (Mermaid Live Editor, Miro, o extensión VS Code) y pegarse en la sección §8 del .docx final. Los textos descriptivos van inmediatamente antes de cada diagrama en el documento.
>
> **Convención de nombres:** Se usan exactamente los nombres canónicos del Apéndice de Consistencia (definidos en Fase 2): `AuthModule`, `GPSService`, `VendorTracker`, `MapScreenBuyer`, `MapScreenVendor`, `StopRequestModule`, `RiskReportModule`, `NotificationHandler`, `StopRequestRouter`, `RiskZoneRouter`, `AuthRouter`, `FirestoreService`, `NotificationService`.

---

## Índice

1. [§8.1 — CU-01: Solicitar Parada a Puerta](#cu-01)
   - [8.1.A — Flujo Normal (Vendedor acepta) — *corregido*](#diagrama-81a)
   - [8.1.B — Flujo Alternativo (Vendedor rechaza)](#diagrama-81b)
   - [8.1.B2 — Flujo Alternativo 2A (Vendedor en zona bloqueada) — *nuevo*](#diagrama-81b2)
   - [8.1.C — Excepción (Timeout 60 s)](#diagrama-81c)
   - [8.1.D — Excepción E1 (Pérdida de conexión durante tracking) — *nuevo*](#diagrama-81d)
2. [§8.2 — CU-02: Activar Radar de Visibilidad](#cu-02)
   - [8.2.A — Flujo Normal (Radar activo)](#diagrama-82a)
   - [8.2.B — Flujo Alternativo (Señal GPS débil) — *corregido*](#diagrama-82b)
   - [8.2.C — Excepción E1 (Conexión perdida) — *corregido*](#diagrama-82c)
   - [8.2.D — Excepción E2 (Batería baja) — *nuevo*](#diagrama-82d)
3. [§8.3 — CU-03: Bloquear zonas por riesgo activo](#cu-03)
   - [8.3.A — Flujo Normal (Nivel HIGH) — *corregido*](#diagrama-83a)
   - [8.3.B — Flujo Alternativo (MEDIUM / LOW) — *corregido*](#diagrama-83b)
   - [8.3.C — Excepción (Reporte duplicado)](#diagrama-83c)
   - [8.3.E — Cruce de zona de riesgo durante CU-01 — *nuevo*](#diagrama-83e)
4. [§8.4 — Auth: Registro y Login](#auth)

---

> **⚠ Precondición global de GPS.** Todos los casos de uso documentados en esta sección (CU-01, CU-02, CU-03) asumen que el dispositivo tiene el permiso de ubicación concedido y el GPS activo. Si cualquiera de estas dos condiciones falla al intentar acceder a una pantalla GPS-dependiente, la pantalla renderiza el componente `GpsRequiredEmptyState` (descrito en §5.3.6.5) en lugar del flujo normal, y el caso de uso no se ejecuta hasta que la precondición se resuelva. Esta verificación es reactiva: si el usuario activa el GPS sin salir de la pantalla, el componente se auto-resuelve. **Excepción:** los flujos accesibles desde el Drawer (Perfil, Historial, Cerrar Sesión) no requieren esta precondición y son accesibles en modo limitado.

---

## §8.1 — CU-01: Solicitar Parada a Puerta {#cu-01}

### Descripción

El caso de uso CU-01 involucra dos actores simultáneos (Comprador y Vendedor) y tres contenedores intermedios: la API FastAPI, Firestore, y FCM. El flujo crea un documento `stop_requests` con tiempo de expiración de 60 segundos y coordina la respuesta del Vendedor mediante notificación push. Una vez aceptada, el Comprador visualiza la posición del Vendedor en tiempo real desde RTDB a través del componente `VendorTracker`.

Los tres flujos documentados son:
- **Normal:** Vendedor acepta → seguimiento en tiempo real → entrega confirmada
- **Alternativo:** Vendedor rechaza → Comprador regresa al mapa
- **Excepción:** Timeout de 60 s sin respuesta → solicitud expirada

---

### Diagrama 8.1.A — Flujo Normal (Vendedor acepta) {#diagrama-81a}

> **Correcciones aplicadas (H-02, H-05):** Se agregó validación de zona de riesgo del comprador antes del `POST /stops` y el cálculo de ruta óptima tras la aceptación del vendedor.

```mermaid
sequenceDiagram
    autonumber
    participant C as Comprador
    participant MSB as MapScreenBuyer
    participant SRM as StopRequestModule
    participant API as StopRequestRouter<br/>(FastAPI)
    participant FS as Firestore
    participant DIR as Directions API
    participant NS as NotificationService
    participant FCM as FCM
    participant NHV as NotificationHandler<br/>(Vendedor)
    participant MSV as MapScreenVendor
    participant RTDB as RTDB<br/>/vendedores_activos

    Note over C,MSB: El Comprador ve vendedores activos en el mapa (radio 4 km)
    C->>MSB: Toca marcador del Vendedor
    MSB->>MSB: Muestra bottom sheet con datos del vendedor
    C->>MSB: Confirma "Solicitar Parada"
    MSB->>SRM: solicitar(vendor_uid, buyer_location: GeoPoint)

    Note over SRM,FS: Validación previa — ¿La ubicación del comprador está en zona HIGH activa?
    SRM->>API: GET /risk-zones/check?location={buyer_location}
    API->>FS: Query risk_zones WHERE active==true AND risk_level=="HIGH"<br/>AND buyer_location dentro del polígono
    FS-->>API: Resultado de zonas activas

    alt Comprador dentro de zona de riesgo HIGH activa
        API-->>SRM: 403 Forbidden { error: "buyer_in_risk_zone" }
        SRM->>MSB: Muestra error:<br/>"No puedes solicitar una parada desde una zona de riesgo activo"
        MSB->>MSB: Descarta solicitud — permanece en mapa
    else Ubicación segura — continúa flujo normal
        SRM->>API: POST /stops<br/>{ vendor_uid, buyer_location, buyer_uid (JWT) }
        API->>API: Verifica JWT → extrae buyer_uid, rol=BUYER
        API->>FS: Crear stop_requests/{id}<br/>{ status: "pending", expires_at: now+60s,<br/>buyer_uid, vendor_uid, buyer_location }
        FS-->>API: stop_request_id
        API->>NS: notify_stop_request_incoming(vendor_uid, stop_request_id)
        NS->>FCM: POST /send { token: vendor_fcm_token,<br/>data: { type: "stop_request_incoming", stop_request_id } }
        FCM-->>NHV: Entrega push notification
        NHV->>MSV: despacha evento stop_request_incoming

        API-->>SRM: 201 Created { stop_request_id, status: "pending" }
        SRM->>MSB: Muestra "Esperando respuesta del vendedor..."

        Note over MSV: Vendedor ve dialog de solicitud entrante
        MSV->>MSV: Muestra Dialog "Solicitud de Parada entrante"
        C->>MSV: (Vendedor) toca "Aceptar"
        MSV->>API: PATCH /stops/{id}/status<br/>{ status: "accepted" } + JWT (vendor)
        API->>API: Verifica JWT → extrae vendor_uid, rol=VENDOR
        API->>FS: Update stop_requests/{id}<br/>{ status: "accepted", accepted_at: now }

        Note over API,DIR: Cálculo de ruta óptima evitando zonas de riesgo activas
        API->>FS: Query risk_zones WHERE active==true (todas las zonas)
        FS-->>API: Lista de zonas activas con polígonos y niveles
        API->>DIR: GET /directions { origin: vendor_location,<br/>destination: buyer_location,<br/>avoid_polygons: high_zone_polygons }
        DIR-->>API: Ruta óptima (waypoints evitando zonas HIGH)
        API->>FS: Update stop_requests/{id}.route = waypoints
        Note over API: Zonas MEDIUM y LOW se manejan en diagrama 8.3.E

        API->>NS: notify_stop_request_accepted(buyer_uid, stop_request_id)
        NS->>FCM: POST /send { token: buyer_fcm_token,<br/>data: { type: "stop_request_accepted", stop_request_id } }
        FCM-->>NHV: (Comprador) push notification
        NHV->>MSB: despacha evento stop_request_accepted

        MSB->>MSB: Navega a TrackingScreen (ruta óptima superpuesta)
        Note over MSB,RTDB: Seguimiento en tiempo real via RTDB
        loop Cada 3 s ó ≥ 10 m de desplazamiento
            RTDB-->>MSB: /vendedores_activos/{vendor_uid}<br/>{ lat, lng, timestamp }
        end
        MSB->>MSB: Actualiza marcador del vendedor sobre la ruta calculada

        Note over MSV: Vendedor llega al domicilio del comprador
        MSV->>API: PATCH /stops/{id}/status<br/>{ status: "completed" } + JWT (vendor)
        API->>FS: Update stop_requests/{id}<br/>{ status: "completed", completed_at: now }
        API->>NS: notify_stop_request_completed(buyer_uid)
        NS->>FCM: POST /send { token: buyer_fcm_token,<br/>data: { type: "stop_request_completed" } }
        FCM-->>NHV: (Comprador) notificación "¡El vendedor llegó!"
        MSB->>MSB: Muestra pantalla de confirmación de llegada
    end
```

---

### Diagrama 8.1.B — Flujo Alternativo (Vendedor rechaza) {#diagrama-81b}

```mermaid
sequenceDiagram
    autonumber
    participant C as Comprador
    participant MSB as MapScreenBuyer
    participant SRM as StopRequestModule
    participant API as StopRequestRouter<br/>(FastAPI)
    participant FS as Firestore
    participant NS as NotificationService
    participant FCM as FCM
    participant NHV as NotificationHandler<br/>(Vendedor)
    participant MSV as MapScreenVendor

    Note over C,MSB: Comprador confirma solicitud (igual que flujo normal, pasos 1–14)
    C->>MSB: Solicitar parada → vendedor notificado
    MSB->>MSB: Muestra "Esperando respuesta..."

    Note over MSV: Vendedor decide rechazar
    MSV->>API: PATCH /stops/{id}/status<br/>{ status: "rejected" } + JWT (vendor)
    API->>FS: Update stop_requests/{id}<br/>{ status: "rejected", updated_at: now }
    API->>NS: notify_stop_request_rejected(buyer_uid)
    NS->>FCM: POST /send { token: buyer_fcm_token,<br/>data: { type: "stop_request_rejected" } }
    FCM-->>NHV: (Comprador) push notification
    NHV->>MSB: despacha evento stop_request_rejected

    MSB->>MSB: Descarta pantalla de espera
    MSB->>C: Muestra snackbar "El vendedor no pudo atenderte"
    MSB->>MSB: Regresa al mapa con vendedores activos
```

---

### Diagrama 8.1.C — Excepción (Timeout: 60 s sin respuesta) {#diagrama-81c}

```mermaid
sequenceDiagram
    autonumber
    participant C as Comprador
    participant MSB as MapScreenBuyer
    participant SRM as StopRequestModule
    participant API as StopRequestRouter<br/>(FastAPI)
    participant FS as Firestore
    participant NS as NotificationService
    participant FCM as FCM
    participant NHB as NotificationHandler<br/>(Comprador)

    Note over C,MSB: Comprador confirma solicitud → status: "pending" (igual que flujo normal)
    C->>MSB: Solicitar parada → vendedor notificado
    MSB->>MSB: Muestra "Esperando respuesta..."
    SRM->>SRM: Inicia timer local de 60 s

    Note over API,FS: El Vendedor no responde en 60 s
    SRM->>SRM: Timer expira
    SRM->>API: PATCH /stops/{id}/status<br/>{ status: "expired" } + JWT (buyer)

    alt Si el servidor aún no expiró el documento
        API->>FS: Update stop_requests/{id}<br/>{ status: "expired", updated_at: now }
        API->>NS: notify_stop_request_expired(buyer_uid)
        NS->>FCM: POST /send { token: buyer_fcm_token,<br/>data: { type: "stop_request_expired" } }
        FCM-->>NHB: push notification "Tiempo de espera agotado"
    else Si el servidor ya expiró el documento (race condition)
        API-->>SRM: 409 Conflict (ya expirado server-side)
    end

    NHB->>MSB: despacha evento stop_request_expired
    MSB->>C: Muestra snackbar "El vendedor no respondió a tiempo"
    MSB->>MSB: Regresa al mapa con vendedores activos
```

---

### Diagrama 8.1.B2 — Flujo Alternativo 2A (Vendedor en zona bloqueada) {#diagrama-81b2}

> **Nuevo (H-04):** El comprador toca el marcador de un vendedor que se encuentra dentro de una zona HIGH activa. El sistema bloquea la opción "Solicitar Parada" antes de enviar cualquier request al backend. Flujo distinto al rechazo voluntario (8.1.B).

```mermaid
sequenceDiagram
    autonumber
    participant C as Comprador
    participant MSB as MapScreenBuyer
    participant SRM as StopRequestModule
    participant API as StopRequestRouter<br/>(FastAPI)
    participant FS as Firestore

    Note over C,MSB: Comprador ve mapa con vendedores activos
    C->>MSB: Toca marcador de Vendedor activo
    MSB->>SRM: verificarElegibilidadVendedor(vendor_uid, vendor_location)

    Note over SRM,FS: ¿La ubicación del vendedor está en zona HIGH activa?
    SRM->>API: GET /risk-zones/check?location={vendor_location}&level=HIGH
    API->>FS: Query risk_zones WHERE active==true AND risk_level=="HIGH"<br/>AND vendor_location dentro del polígono
    FS-->>API: Zona HIGH activa en ubicación del vendedor

    API-->>SRM: 200 OK { in_risk_zone: true, risk_level: "HIGH" }
    SRM->>MSB: Renderiza bottom sheet con opción "Solicitar Parada" deshabilitada
    MSB->>C: Muestra mensaje en bottom sheet:<br/>"Parada no disponible: el vendedor se encuentra<br/>en una zona de riesgo activo."
    Note over MSB: El bottom sheet permanece abierto.<br/>El comprador puede cerrarlo y seleccionar otro vendedor.

    alt Vendedor fuera de zona de riesgo (caso normal)
        API-->>SRM: 200 OK { in_risk_zone: false }
        SRM->>MSB: Renderiza bottom sheet con "Solicitar Parada" habilitada
        Note over MSB: Continúa flujo normal 8.1.A
    end
```

---

### Diagrama 8.1.D — Excepción E1 (Pérdida de conexión durante tracking) {#diagrama-81d}

> **Nuevo (H-12):** El vendedor pierde la conexión mientras el comprador está en TrackingScreen con una solicitud en estado `accepted`. El stream RTDB se interrumpe, el sistema muestra la última ubicación conocida y pausa el seguimiento sin cancelar la solicitud.

```mermaid
sequenceDiagram
    autonumber
    participant C as Comprador
    participant MSB as MapScreenBuyer
    participant RTDB as RTDB<br/>/vendedores_activos

    Note over C,MSB: Solicitud aceptada — Comprador en TrackingScreen<br/>stop_requests/{id}.status == "accepted"<br/>Seguimiento activo via stream RTDB

    Note over RTDB,MSB: El vendedor pierde conexión a internet durante el trayecto.<br/>RTDB ejecuta onDisconnect().remove() del nodo del vendedor.

    RTDB-xMSB: Stream RTDB interrumpido — nodo del vendedor eliminado
    MSB->>MSB: Detecta eliminación del nodo (stream emite lista vacía)
    MSB->>C: Banner en TrackingScreen:<br/>"Seguimiento pausado. El vendedor perdió la conexión.<br/>Última ubicación conocida: [timestamp]"
    MSB->>MSB: Mantiene último marcador del vendedor en pantalla<br/>(posición congelada — icono diferenciado)

    Note over MSB: La solicitud permanece en estado "accepted".<br/>El comprador NO regresa al mapa — espera en TrackingScreen.

    alt El vendedor recupera la conexión (re-ingresa al radar en RTDB)
        RTDB-->>MSB: onValue stream: nodo /vendedores_activos/{vendor_uid} re-creado
        MSB->>MSB: Banner de "Seguimiento pausado" desaparece
        MSB->>MSB: Tracking se reanuda con posición actualizada
        MSB->>C: Snackbar: "Seguimiento reanudado"
    else Sin recuperación (timeout prolongado)
        Note over MSB: Iter. 2: si el stream está inactivo más de X minutos,<br/>cancelar la solicitud y notificar al comprador.
    end
```

---

## §8.2 — CU-02: Activar Radar de Visibilidad {#cu-02}

### Descripción

El CU-02 es el único caso de uso de iteración 1 en el que la App Flutter escribe **directamente** en Firebase RTDB sin pasar por la API FastAPI (decisión documentada en ADR #2). El `GPSService` se encarga de iniciar el stream GPS del dispositivo, publicar la posición cada 3 segundos o cuando el desplazamiento es ≥10 metros, y registrar un `onDisconnect().remove()` para garantizar que el nodo se elimine si la aplicación se cierra inesperadamente.

Los cuatro flujos documentados son:
- **Normal:** Vendedor activa radar → GPS transmite → Comprador ve marcador en mapa
- **Alternativo:** Señal GPS débil → estado de error → retry automático cada 40 s → recuperación
- **Excepción E1:** Conexión a internet cae → alerta local al vendedor → RTDB ejecuta `onDisconnect()` → nodo eliminado
- **Excepción E2:** Batería baja → frecuencia reducida a 60 s → indicador de baja precisión en mapa del comprador

---

### Diagrama 8.2.A — Flujo Normal (Radar activo) {#diagrama-82a}

```mermaid
sequenceDiagram
    autonumber
    participant V as Vendedor
    participant MSV as MapScreenVendor
    participant GPS as GPSService
    participant RTDB as RTDB<br/>/vendedores_activos
    participant VT as VendorTracker<br/>(Comprador)
    participant MSB as MapScreenBuyer

    Note over V,MSV: Vendedor en HomeV (mapa con navegación)
    V->>MSV: Toca toggle "Activar Visibilidad"
    MSV->>MSV: Muestra PopupConfirm<br/>"¿Desea iniciar transmisión?"
    V->>MSV: Confirma "Sí"

    MSV->>GPS: startTransmission(vendorUid)
    GPS->>RTDB: onDisconnect().remove()<br/>/vendedores_activos/{vendorUid}
    Note over GPS,RTDB: Registro de limpieza automática ante desconexión
    GPS->>GPS: Inicia stream GPS (geolocator)<br/>umbral: 3 s ó ≥ 10 m
    GPS-->>MSV: stateStream → GPSServiceState.active

    MSV->>MSV: Muestra feedback<br/>"Ahora eres Visible"

    loop Cada 3 s ó cuando desplazamiento ≥ 10 m
        GPS->>GPS: Lee posición del dispositivo
        GPS->>RTDB: set /vendedores_activos/{vendorUid}<br/>{ lat, lng, timestamp, activo: true }
        RTDB-->>VT: onValue stream update
        VT->>VT: Filtra radio 4 km (Haversine client-side)
        VT-->>MSB: Stream<List<VendorMarker>> emite nueva posición
        MSB->>MSB: Actualiza marcador verde del vendedor en el mapa
    end

    Note over V,MSV: Vendedor desactiva radar
    V->>MSV: Toca toggle "Desactivar Visibilidad"
    MSV->>GPS: stopTransmission(vendorUid)
    GPS->>GPS: Cancela stream GPS
    GPS->>RTDB: remove /vendedores_activos/{vendorUid}
    GPS-->>MSV: stateStream → GPSServiceState.inactive
    MSV->>MSV: Actualiza UI → toggle inactivo
    RTDB-->>VT: nodo eliminado → lista de vendedores actualizada
    VT-->>MSB: Stream emite lista sin este vendedor
    MSB->>MSB: Elimina marcador del mapa
```

---

### Diagrama 8.2.B — Flujo Alternativo (Señal GPS débil) {#diagrama-82b}

> **Correcciones aplicadas (H-09, H-10):** Intervalo de retry corregido de 5 s a **40 s**. Se agrega representación del lado del comprador: etiqueta "Última ubicación conocida" cuando el timestamp supera 40 s sin actualización.

```mermaid
sequenceDiagram
    autonumber
    participant V as Vendedor
    participant MSV as MapScreenVendor
    participant GPS as GPSService
    participant RTDB as RTDB<br/>/vendedores_activos
    participant VT as VendorTracker<br/>(Comprador)
    participant MSB as MapScreenBuyer

    Note over V,MSV: Radar ya activo (pasos 1–9 del flujo normal completados)

    GPS->>GPS: Intento de lectura GPS → timeout / precisión baja
    GPS-->>MSV: stateStream → GPSServiceState.error_no_signal
    MSV->>V: Snackbar: "Señal GPS débil. Reintentando en 40 s..."

    Note over RTDB: RTDB mantiene la última posición conocida del vendedor.<br/>No se elimina hasta stopTransmission() o desconexión.

    RTDB-->>VT: onValue stream: nodo con timestamp antiguo (> 40 s sin actualización)
    VT->>VT: Detecta timestamp desactualizado
    VT-->>MSB: Stream emite VendorMarker con stale=true
    MSB->>MSB: Muestra marcador con etiqueta<br/>"Última ubicación conocida" (icono ⚠)

    Note over GPS: GPSService entra en modo retry automático — intervalo: 40 s
    loop Retry hasta recuperar señal (cada 40 s)
        GPS->>GPS: Espera 40 s → nuevo intento de lectura GPS
        alt Señal recuperada
            GPS->>RTDB: set /vendedores_activos/{vendorUid}<br/>{ lat, lng, timestamp, activo: true }
            GPS-->>MSV: stateStream → GPSServiceState.active
            MSV->>V: Snackbar: "Señal GPS recuperada"
            RTDB-->>VT: onValue stream: timestamp fresco
            VT->>VT: Limpia flag stale
            VT-->>MSB: Stream emite VendorMarker con stale=false
            MSB->>MSB: Etiqueta "Última ubicación conocida" desaparece
        else Sin señal
            GPS->>GPS: Continúa en modo retry (40 s)
        end
    end
```

---

### Diagrama 8.2.C — Excepción E1 (Conexión perdida / App cerrada inesperadamente) {#diagrama-82c}

> **Correcciones aplicadas (H-06):** Se agrega alerta local al vendedor antes de que `onDisconnect` ejecute el `remove`. Se diferencia el comportamiento según si la app sigue activa (solo cayó la red) o si la app fue cerrada.

```mermaid
sequenceDiagram
    autonumber
    participant V as Vendedor
    participant MSV as MapScreenVendor
    participant GPS as GPSService
    participant RTDB as RTDB<br/>/vendedores_activos
    participant VT as VendorTracker<br/>(Comprador)
    participant MSB as MapScreenBuyer

    Note over V,GPS: Radar activo, onDisconnect().remove() ya registrado

    Note over GPS,RTDB: La conexión de red cae abruptamente<br/>O la app se cierra inesperadamente

    alt App activa — solo cayó la red
        GPS-->>MSV: stateStream → GPSServiceState.error_no_connection
        MSV->>V: Banner persistente (alerta local):<br/>"Conexión perdida.<br/>Tu ubicación no es visible para los compradores."
    end

    GPS-xRTDB: Conexión WebSocket cortada
    Note over RTDB: RTDB detecta pérdida de conexión persistente.<br/>Ejecuta la operación onDisconnect() registrada.
    RTDB->>RTDB: remove /vendedores_activos/{vendorUid}

    RTDB-->>VT: onValue stream emite: nodo eliminado
    VT->>VT: Remueve vendedor de la lista activa
    VT-->>MSB: Stream emite lista actualizada (sin el vendedor)
    MSB->>MSB: Elimina marcador del mapa automáticamente

    Note over MSV: Si la app sigue activa y la red se recupera,<br/>el vendedor debe reactivar el radar manualmente.<br/>El radar NO se reactiva automáticamente.
    Note over MSB: El Comprador no ve vendedores desconectados.<br/>No se requiere intervención del comprador.
```

---

### Diagrama 8.2.D — Excepción E2 (Batería baja) {#diagrama-82d}

> **Nuevo (H-07):** Cuando el dispositivo entra en modo de ahorro de energía crítico, `GPSService` reduce la frecuencia de 3 s a 60 s, notifica al vendedor y propaga el flag `low_battery: true` hasta el marcador del comprador. Si el dispositivo se apaga, aplica el flujo 8.2.C.

```mermaid
sequenceDiagram
    autonumber
    participant V as Vendedor
    participant MSV as MapScreenVendor
    participant GPS as GPSService
    participant RTDB as RTDB<br/>/vendedores_activos
    participant VT as VendorTracker<br/>(Comprador)
    participant MSB as MapScreenBuyer

    Note over V,GPS: Radar activo — transmisión normal (3 s / ≥10 m)

    GPS->>GPS: Detecta batería crítica del dispositivo<br/>(modo de ahorro de energía activado)
    GPS-->>MSV: stateStream → GPSServiceState.low_battery
    MSV->>V: Snackbar de advertencia:<br/>"Batería baja. La precisión del radar ha disminuido.<br/>La ubicación se actualizará cada 60 segundos."

    GPS->>GPS: Reduce frecuencia de actualización: 3 s → 60 s

    loop Cada 60 s (modo ahorro energético)
        GPS->>GPS: Lee posición del dispositivo
        GPS->>RTDB: set /vendedores_activos/{vendorUid}<br/>{ lat, lng, timestamp, activo: true, low_battery: true }
        RTDB-->>VT: onValue stream update con flag low_battery
        VT->>VT: Detecta flag low_battery==true
        VT-->>MSB: Stream emite VendorMarker con lowBattery=true
        MSB->>MSB: Muestra marcador con icono de batería baja<br/>(tooltip: "Baja precisión — actualización cada 60 s")
    end

    Note over GPS: Si el dispositivo se apaga por batería agotada,<br/>aplica el flujo de Excepción 8.2.C (onDisconnect).
```

---

## §8.3 — CU-03: Bloquear zonas por riesgo activo {#cu-03}

### Descripción

El CU-03 es **transversal**: tanto el Comprador como el Vendedor pueden reportar desde sus respectivos HomeScreens mediante el FAB naranja (+). El `RiskReportModule` presenta un bottom sheet, captura los datos (tipo de amenaza, nivel de riesgo, coordenadas auto-detectadas) y hace `POST /risk-zones`. La API calcula `expires_at = now + 24h`, persiste en Firestore y notifica a todos los usuarios activos vía FCM. La zona aparece como polígono coloreado en los mapas de todos los usuarios.

Los tres flujos documentados son:
- **Normal:** Reporte HIGH → persiste → alerta FCM masiva → polígono en todos los mapas
- **Alternativo:** Reporte MEDIUM o LOW → mismo flujo, diferente color de polígono
- **Excepción:** Reporte duplicado en zona ya activa → 409 Conflict → usuario corrige

---

### Diagrama 8.3.A — Flujo Normal (Nivel HIGH) {#diagrama-83a}

> **Correcciones aplicadas (H-03 parcial):** Se agrega validación geográfica del reportante (radio 4 km) antes de crear el documento en Firestore, cubriendo la pre-condición del SRS y el criterio CA-03.3.

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario<br/>(Comprador o Vendedor)
    participant HS as HomeScreen<br/>(MapScreenBuyer / MapScreenVendor)
    participant RRM as RiskReportModule
    participant API as RiskZoneRouter<br/>(FastAPI)
    participant FS as Firestore
    participant NS as NotificationService
    participant FCM as FCM
    participant NH as NotificationHandler<br/>(otros usuarios)
    participant MS as MapScreen<br/>(todos los usuarios)

    Note over U,HS: Usuario en HomeScreen (Comprador o Vendedor)
    U->>HS: Toca FAB "+" (naranja, warning-700)
    HS->>RRM: openRiskReportBottomSheet()
    RRM->>RRM: Muestra bottom sheet (radio 24dp):<br/>campo tipo amenaza (texto libre),<br/>selector nivel riesgo (HIGH/MEDIUM/LOW),<br/>coordenadas auto-detectadas del dispositivo
    U->>RRM: Completa formulario → toca "Reportar"

    RRM->>API: POST /risk-zones + JWT<br/>{ threat_type: "robo", risk_level: "HIGH",<br/>location: GeoPoint, radius_meters: 100 }
    API->>API: Verifica JWT → extrae reporter_uid

    Note over API: Validación geográfica — ¿El reportante está dentro del radio de 4 km del área?
    API->>API: Calcula distancia(reporter_location, report_location) — Haversine

    alt Distancia > 4 km — fuera del alcance geográfico
        API-->>RRM: 403 Forbidden { error: "out_of_range",<br/>message: "Solo puedes reportar zonas dentro de un radio de 4 km" }
        RRM->>U: Muestra error en bottom sheet:<br/>"No puedes reportar una zona fuera de tu alcance geográfico (4 km)"
        Note over RRM: Bottom sheet permanece abierto.<br/>El usuario puede ajustar las coordenadas o cancelar.
    else Dentro del radio de 4 km — continúa flujo normal
        API->>FS: Crear risk_zones/{id}<br/>{ reporter_uid, threat_type: "robo",<br/>risk_level: "HIGH", location, radius_meters: 100,<br/>active: true, created_at: now,<br/>expires_at: now + 24h }
        FS-->>API: risk_zone_id

        Note over NS,FCM: Nivel HIGH → notifica a TODOS los usuarios con fcm_token registrado
        API->>NS: notify_risk_zone_alert(all_active_user_uids[], risk_zone_data)
        NS->>FCM: POST /send (multicast a todos)<br/>{ tokens: [...], data: { type: "risk_zone_alert",<br/>risk_zone_id, risk_level: "HIGH",<br/>threat_type: "robo", lat, lng } }
        FCM-->>NH: push notification a todos los usuarios

        API-->>RRM: 201 Created { risk_zone_id }
        RRM->>HS: Cierra bottom sheet
        HS->>U: Muestra snackbar "Zona de riesgo reportada"

        NH->>MS: despacha evento risk_zone_alert
        Note over MS: MapScreen renderiza polígono HIGH
        MS->>MS: Dibuja polígono en mapa:<br/>fill #C62828 (35% opacidad), borde #C62828 (100%)
        MS->>MS: Muestra banner "Zona de riesgo HIGH reportada"
    end
```

---

### Diagrama 8.3.B — Flujo Alternativo (Nivel MEDIUM o LOW) {#diagrama-83b}

> **Correcciones aplicadas (H-03, H-11):** FCM diferenciado por nivel — MEDIUM notifica a todos los usuarios; LOW notifica solo a usuarios en radio ≤ 5 km. Se elimina la nota incorrecta de "ruta evita polígono" para ambos niveles. El comportamiento de cruce de zona (MEDIUM: confirmación / LOW: informativo) se modela en el diagrama 8.3.E.

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario<br/>(Comprador o Vendedor)
    participant RRM as RiskReportModule
    participant API as RiskZoneRouter<br/>(FastAPI)
    participant FS as Firestore
    participant NS as NotificationService
    participant FCM as FCM
    participant NH as NotificationHandler<br/>(otros usuarios)
    participant MS as MapScreen<br/>(todos los usuarios)

    Note over U,RRM: Mismo inicio que flujo normal<br/>(FAB → bottom sheet → validación 4 km → OK)

    alt risk_level == "MEDIUM"
        U->>RRM: Completa formulario con risk_level: "MEDIUM"
        RRM->>API: POST /risk-zones + JWT<br/>{ threat_type, risk_level: "MEDIUM", location, radius_meters: 100 }
        API->>FS: Crear risk_zones/{id}<br/>{ risk_level: "MEDIUM", active: true,<br/>expires_at: now + 24h, ... }
        FS-->>API: risk_zone_id

        Note over NS,FCM: Nivel MEDIUM → notifica a TODOS los usuarios activos
        API->>NS: notify_risk_zone_alert(all_active_user_uids[], data)
        NS->>FCM: POST /send (multicast a todos)<br/>{ data: { type: "risk_zone_alert", risk_level: "MEDIUM", ... } }
        FCM-->>NH: push notification a todos los usuarios
        NH->>MS: despacha evento risk_zone_alert
        MS->>MS: Dibuja polígono MEDIUM:<br/>fill #F57C00 (naranja, 30% opacidad)
        Note over MS: Cuando una ruta cruce esta zona durante CU-01,<br/>ver Diagrama 8.3.E — confirmación explícita obligatoria.

    else risk_level == "LOW"
        U->>RRM: Completa formulario con risk_level: "LOW"
        RRM->>API: POST /risk-zones + JWT<br/>{ threat_type, risk_level: "LOW", location, radius_meters: 100 }
        API->>FS: Crear risk_zones/{id}<br/>{ risk_level: "LOW", active: true,<br/>expires_at: now + 24h, ... }
        FS-->>API: risk_zone_id

        Note over NS,FCM: Nivel LOW → notifica SOLO a usuarios en radio ≤ 4 km (dispositivos cercanos)
        API->>FS: Query users WHERE last_known_location<br/>dentro de 4 km del report_location (Haversine)
        FS-->>API: Lista de fcm_tokens de usuarios cercanos
        API->>NS: notify_risk_zone_alert(nearby_user_uids[], data)
        NS->>FCM: POST /send (multicast restringido a cercanos)<br/>{ tokens: [...cercanos...], data: { type: "risk_zone_alert",<br/>risk_level: "LOW", ... } }
        FCM-->>NH: push notification solo a usuarios cercanos
        NH->>MS: despacha evento risk_zone_alert
        MS->>MS: Dibuja polígono LOW:<br/>fill #0277BD (azul, 25% opacidad)
        Note over MS: Zonas LOW son informativas.<br/>No bloquean rutas ni solicitan confirmación en CU-01.
    end

    API-->>RRM: 201 Created
    RRM->>U: Snackbar "Zona de riesgo reportada"
```

---

### Diagrama 8.3.C — Excepción (Reporte duplicado en zona activa) {#diagrama-83c}

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario
    participant RRM as RiskReportModule
    participant API as RiskZoneRouter<br/>(FastAPI)
    participant FS as Firestore

    Note over U,RRM: Mismo inicio que flujo normal
    U->>RRM: Completa formulario → toca "Reportar"
    RRM->>API: POST /risk-zones + JWT<br/>{ threat_type, risk_level, location, radius_meters }

    API->>FS: Query risk_zones donde:<br/>active == true<br/>AND location dentro de radius_meters (bounding box + Haversine)
    FS-->>API: Retorna zona existente activa en la misma área

    Note over API: Zona duplicada detectada (mismas coords ± radio solapado)
    API-->>RRM: 409 Conflict<br/>{ error: "duplicate_risk_zone",<br/>existing_zone_id, message: "Ya existe una zona activa en esta área" }

    RRM->>RRM: Maneja error 409
    RRM->>U: Muestra error en bottom sheet:<br/>"Ya existe un reporte activo en esta zona"
    Note over RRM: Bottom sheet permanece abierto<br/>El usuario puede ajustar la ubicación o cancelar
    U->>RRM: Cancela o ajusta ubicación y reintenta
```

---

### Diagrama 8.3.E — Cruce de zona de riesgo durante CU-01 {#diagrama-83e}

> **Nuevo (H-08, H-11):** Diagrama transversal CU-01 / CU-03. Modela qué hace el sistema cuando la ruta del vendedor cruza una zona activa. Punto de entrada: inmediatamente después del cálculo de ruta en 8.1.A (tras el `PATCH accepted`). HIGH → rerouting automático; MEDIUM → confirmación explícita del vendedor; LOW → snackbar informativo.

```mermaid
sequenceDiagram
    autonumber
    participant MSV as MapScreenVendor
    participant API as StopRequestRouter<br/>(FastAPI)
    participant FS as Firestore
    participant DIR as Directions API
    participant NS as NotificationService
    participant FCM as FCM
    participant NHV as NotificationHandler<br/>(Vendedor)

    Note over MSV,API: Contexto: Vendedor aceptó la solicitud (status: "accepted").<br/>API tiene la ruta base y la lista de zonas activas de Firestore.

    API->>API: Intersecta ruta base con polígonos de zonas activas

    alt Ruta cruza zona HIGH — rerouting automático sin confirmación
        API->>DIR: GET /directions { origin: vendor_location,<br/>destination: buyer_location,<br/>avoid_polygon: high_zone_polygon }
        DIR-->>API: Ruta alternativa evitando zona HIGH
        API->>FS: Update stop_requests/{id}.route = ruta_alternativa
        API->>NS: notify_route_ready(vendor_uid, ruta_alternativa)
        NS->>FCM: POST /send { token: vendor_fcm_token,<br/>data: { type: "route_ready", route: waypoints,<br/>avoided_zone: "HIGH" } }
        FCM-->>NHV: notificación con ruta alternativa
        NHV->>MSV: Muestra ruta en mapa con nota:<br/>"Ruta ajustada para evitar zona de riesgo alto"

    else Ruta cruza zona MEDIUM — advertencia obligatoria con confirmación explícita
        API->>NS: notify_route_crosses_medium_zone(vendor_uid, zone_data)
        NS->>FCM: POST /send { token: vendor_fcm_token,<br/>data: { type: "route_medium_zone_warning",<br/>zone_id, threat_type, zone_polygon } }
        FCM-->>NHV: push notification de advertencia
        NHV->>MSV: despacha evento route_medium_zone_warning
        MSV->>MSV: Muestra dialog obligatorio:<br/>"Tu ruta cruza una zona de riesgo MEDIO: [threat_type].<br/>¿Cómo deseas proceder?"

        alt Vendedor elige "Continuar por esa ruta"
            MSV->>API: PATCH /stops/{id}/route_decision { decision: "accept_risk" }
            API->>DIR: GET /directions (ruta original, incluye zona MEDIUM)
            DIR-->>API: Ruta con cruce de zona MEDIUM
            API->>FS: Update stop_requests/{id}.route = ruta_con_zona
            NHV->>MSV: Muestra ruta con zona MEDIUM marcada en naranja
        else Vendedor elige "Evitar zona"
            MSV->>API: PATCH /stops/{id}/route_decision { decision: "avoid_risk" }
            API->>DIR: GET /directions { avoid_polygon: medium_zone_polygon }
            DIR-->>API: Ruta alternativa evitando zona MEDIUM
            API->>FS: Update stop_requests/{id}.route = ruta_alternativa
            NHV->>MSV: Muestra ruta alternativa
        end

    else Ruta cruza solo zona LOW — snackbar informativo, sin bloqueo
        API->>DIR: GET /directions (ruta sin restricciones)
        DIR-->>API: Ruta normal
        API->>FS: Update stop_requests/{id}.route = ruta_normal
        API->>NS: notify_route_low_zone_info(vendor_uid, zone_data)
        NS->>FCM: POST /send { data: { type: "route_low_zone_info",<br/>threat_type, zone_location } }
        FCM-->>NHV: notificación informativa (no modal)
        NHV->>MSV: Snackbar: "Zona de riesgo bajo en tu ruta: [threat_type]"
        Note over MSV: El vendedor continúa normalmente. Sin dialog ni desvío.

    else Sin zonas en la ruta
        Note over API: Ruta limpia. Continúa flujo normal 8.1.A sin interrupciones.
    end
```

---

## §8.4 — Auth: Registro y Login {#auth}

### Descripción

El flujo de autenticación combina Firebase Auth (para credenciales y emisión de JWT) con la API FastAPI (para persistir el perfil en Firestore y registrar el token FCM). El `AuthModule` es el componente Flutter responsable del ciclo completo. Hay dos sub-flujos: **Registro** (nuevo usuario) y **Login** (usuario existente). En ambos casos, al terminar, `go_router` redirige al Home correspondiente según el rol (`BUYER` → MapScreenBuyer, `VENDOR` → MapScreenVendor).

---

### Diagrama 8.4.A — Sub-flujo: Registro (Sign Up)

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario nuevo
    participant AM as AuthModule
    participant FBA as Firebase Auth
    participant API as AuthRouter FastAPI
    participant FS as Firestore
    participant Router as go_router

    Note over U,AM: App abre → Splash → sin sesión → Bienvenida → "No tengo cuenta"
    U->>AM: Navega a pantalla SignUp - Datos
    U->>AM: Ingresa nombre y teléfono
    AM->>AM: Valida campos (no vacíos, teléfono con formato)
    U->>AM: Toca "Continuar"
    AM->>AM: Navega a SignUp - Selección de Rol
    U->>AM: Selecciona rol: BUYER o VENDOR
    U->>AM: Toca "Registrarme"

    AM->>FBA: createUserWithEmailAndPassword(email, password)
    Note over AM,FBA: UBISAFE usa teléfono como identificador. Firebase Auth recibe email sintético + password
    FBA-->>AM: User uid + ID Token JWT válido 1h

    AM->>API: POST /auth/sync-profile + JWT { name, phone, role }
    API->>API: verify_id_token(JWT) → extrae uid
    API->>FS: upsert users/{uid} { uid, name, phone, role, fcm_token: null, created_at: now }
    FS-->>API: OK
    API-->>AM: 200 OK { uid, role }

    AM->>FBA: getToken() → fcm_token
    AM->>API: PATCH /auth/device-token + JWT { fcm_token }
    API->>FS: update users/{uid}.fcm_token
    FS-->>API: OK
    API-->>AM: 200 OK

    AM->>Router: Navega según rol: BUYER a /home/buyer o VENDOR a /home/vendor
```

---

### Diagrama 8.4.B — Sub-flujo: Login

```mermaid
sequenceDiagram
    autonumber
    participant U as Usuario (existente)
    participant AM as AuthModule
    participant FBA as Firebase Auth
    participant API as AuthRouter<br/>(FastAPI)
    participant FS as Firestore
    participant Router as go_router

    Note over U,AM: App abre → Splash → ¿Sesión activa?
    AM->>FBA: authStateChanges().first
    alt Sesión activa (token vigente)
        FBA-->>AM: User existente (no expirado)
        AM->>FS: Leer users/{uid}.role
        FS-->>AM: role: "BUYER" | "VENDOR"
        AM->>Router: Navega directo al Home según rol
        Note over Router: No pasa por pantalla de Login
    else Sin sesión activa
        FBA-->>AM: null
        AM->>Router: Navega a Bienvenida
    end

    Note over U,AM: Usuario tiene cuenta → toca "Iniciar Sesión"
    U->>AM: Navega a pantalla Login
    U->>AM: Ingresa credenciales (teléfono/email + password)
    U->>AM: Toca "Entrar"

    AM->>FBA: signInWithEmailAndPassword(email, password)
    alt Credenciales válidas
        FBA-->>AM: User { uid } + ID Token (JWT, válido 1h)

        AM->>API: POST /auth/sync-profile + JWT (sync actualiza updated_at)
        API->>API: verify_id_token(JWT) → extrae uid
        API->>FS: upsert users/{uid}.updated_at = now
        FS-->>API: OK
        API-->>AM: 200 OK { uid, role }

        AM->>FBA: getToken() → fcm_token
        AM->>API: PATCH /auth/device-token + JWT { fcm_token }
        API->>FS: update users/{uid}.fcm_token
        API-->>AM: 200 OK

        AM->>Router: Navega según role: BUYER → /home/buyer | VENDOR → /home/vendor

    else Credenciales inválidas
        FBA-->>AM: FirebaseAuthException (wrong-password / user-not-found)
        AM->>U: Muestra error inline: "Credenciales incorrectas. Inténtalo de nuevo."
        Note over AM: Pantalla de Login permanece visible
    end
```

---

## Notas de implementación para el equipo

> Esta sección va al pie de §8 en el SDD final.

### Manejo de JWT expirado durante una sesión activa

El JWT de Firebase Auth tiene vigencia de **1 hora**. El cliente Flutter (a través de `dio` + interceptor configurado en `core/api_client.dart`) debe refrescar el token automáticamente antes de cada request usando `user.getIdToken(forceRefresh: false)`. Si el token expiró, Firebase Auth SDK lo renueva en background sin que el usuario lo note. Solo se requiere re-autenticación explícita si la sesión fue revocada manualmente.

### Consistencia de `fcm_token`

El token FCM puede rotar (Firebase lo renueva periódicamente). `NotificationHandler` debe escuchar el callback `FirebaseMessaging.onTokenRefresh` y llamar a `PATCH /auth/device-token` cada vez que ocurra una rotación.

### Timeout del lado del servidor (CU-01)

La expiración de `stop_requests` a los 60 s no está implementada con un job programado en iter. 1. El cliente inicia el PATCH con `status: expired`. En iter. 2 se evaluará agregar una Cloud Function con trigger por tiempo para expirar documentos server-side sin depender del cliente.

---

*Fase 4 generada el 18/04/2026 — Los Borbotones / UBISAFE Iteración 1.*
