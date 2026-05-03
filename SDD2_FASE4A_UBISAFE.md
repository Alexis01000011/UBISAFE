# SDD2 — Fase 4.A': Diagramas de Secuencia CU-04 (Solicitar Raite)
## Los Borbotones · Iteración 2 · **[iter. 2]**
### Sección 9 del SDD — Interaction Viewpoint (IEEE 1016-2009)
#### Actualizado: 24/04/2026

> **Nota de uso:** Este archivo contiene los diagramas de secuencia de CU-04 en formato Mermaid, siguiendo exactamente el mismo estilo y convenciones de `SDD_FASE4_UBISAFE.md`. Cada diagrama debe exportarse como imagen (Mermaid Live Editor, VS Code o similar) y pegarse en la sección §9 del .docx final, inmediatamente después de §8.4 (Auth).
>
> **Convención de nombres:** Se usan exactamente los nombres canónicos definidos en `SDD2_FASE2_UBISAFE.md`: `MapScreenBuyer`, `MapScreenVendor`, `RideRequestModule`, `DestinationPicker`, `RideRouter`, `NotificationService`, `NotificationHandler`, `FirestoreService`, `VendorTracker`, `GPSService`.
>
> **Archivos base leídos:** `SDD_FASE4_UBISAFE.md` (estilo y convenciones iter. 1) · `SDD2_FASE2_UBISAFE.md` (componentes y arquitectura iter. 2) · `SDD2_FASE3A_UBISAFE.md` (modelo `rides`, endpoints, ciclo de vida, handoff de Alexis).

---

## Índice

1. [§9.5 — CU-04: Solicitar Raite](#cu-04)
   - [9.5.A — Flujo Normal](#diagrama-95a)
   - [9.5.B — Condición 3A: Vendedor no disponible / zona peligrosa](#diagrama-95b)
   - [9.5.C — Condición 4A: Destino demasiado lejos](#diagrama-95c)
   - [9.5.D — Condición 6A: Vendedor rechaza la solicitud](#diagrama-95d)
   - [9.5.E — E1: Pérdida de conexión](#diagrama-95e)
   - [9.5.F — E2: Cancelación por el comprador](#diagrama-95f)
   - [9.5.G — E3: Tiempo de respuesta agotado (CA-04.3)](#diagrama-95g)

---

> **⚠ Precondición global de GPS.** CU-04 requiere GPS activo en ambos actores. Si el GPS no está disponible al iniciar el flujo del Comprador (selección de destino) o durante el tracking, aplica el mismo mecanismo `GpsRequiredEmptyState` descrito en §8 para CU-01/02/03. Esta verificación es reactiva y no interrumpe la sesión del usuario.

> **Nota de decisión de equipo — Timeout:** El SRS v2.1 (CA-04.3) establece 60 s. Este valor es uniforme con CU-01. Decisión registrada en `SDD2_FASE0_UBISAFE.md §A-P1` y reflejada en el campo `expires_at = created_at + 60s` del modelo `rides` (`SDD2_FASE3A_UBISAFE.md §3.A'.1`).

> **Nota de arquitectura — Cálculo de ruta:** En CU-01, el cálculo de ruta lo realizaba FastAPI server-side (Directions API llamado desde `StopRequestRouter`). En CU-04, esta responsabilidad se delega al **cliente Flutter** (`RideRequestModule`): consulta Directions API directamente usando las zonas de riesgo ya cargadas en `MapScreenBuyer`, y envía la `route_polyline` resultante en el `POST /rides`. FastAPI almacena la ruta recibida sin recalcularla. Esta diferencia es intencional y está documentada en `SDD2_FASE2_UBISAFE.md §5.3.3.6`.

---

## §9.5 — CU-04: Solicitar Raite {#cu-04}

### Descripción

CU-04 extiende el dominio **Dispatching** de iteración 1 con el flujo de acompañamiento de persona en vehículo. Involucra dos actores simultáneos (Comprador y Vendedor) y cuatro capas técnicas: la App Flutter, la API FastAPI (`RideRouter`), Cloud Firestore (colección `rides`) y FCM. La navegación en tiempo real reutiliza el stream RTDB ya disponible del radar de visibilidad (CU-02), lo que evita duplicar infraestructura de localización.

**Diferencias clave respecto a CU-01 (Parada a Puerta):**

| Aspecto | CU-01 Parada | CU-04 Raite |
|---|---|---|
| Selección de destino | No aplica (el comprador indica dónde está) | Comprador elige un destino en el mapa (`DestinationPicker`) |
| Cálculo de ruta | Server-side por FastAPI | **Client-side** por `RideRequestModule` vía Directions API |
| Pre-condición extra | — | `users.ride_enabled == true` en el Vendedor |
| Fases del viaje | 1 fase (vendor → buyer) | 2 fases: vendor → pickup, luego vendor+buyer → destino |
| Estados del ciclo | `pending / accepted / rejected / completed / expired` | `pending / accepted / in_progress / completed / rejected / expired` |
| Colección Firestore | `stop_requests` | `rides` |

Los siete diagramas documentados cubren:
- **9.5.A — Flujo Normal:** Solicitud → Vendedor acepta → navega al pickup → Comprador aborda → viaje → confirmación.
- **9.5.B — Condición 3A:** Vendedor no disponible (raite o parada activa) o zona de solicitud peligrosa.
- **9.5.C — Condición 4A:** Destino a más de 4 km del pickup → UBISAFE notifica al Vendedor → Vendedor rechaza.
- **9.5.D — Condición 6A:** Vendedor rechaza manualmente la solicitud.
- **9.5.E — E1:** Pérdida de conexión GPS/internet durante el raite activo.
- **9.5.F — E2:** Cancelación por el Comprador antes del encuentro.
- **9.5.G — E3:** Tiempo de espera agotado (60 s sin respuesta del Vendedor).

---

### Diagrama 9.5.A — Flujo Normal {#diagrama-95a}

> Cubre el camino exitoso completo: desde que el Comprador toca el marcador del Vendedor hasta la confirmación de llegada al destino. Incluye la separación explícita entre la llegada del Vendedor al punto de recogida (`POST /rides/{id}/vendor_arrived`) y el inicio del viaje propiamente dicho (`PATCH → in_progress`), en coherencia con el SRS v2.1 paso 10 del Flujo Normal: *"Al subir el comprador, el vendedor inicia el viaje"*.

```mermaid
sequenceDiagram
    autonumber
    participant C as Comprador
    participant MSB as MapScreenBuyer
    participant RRM as RideRequestModule
    participant DP as DestinationPicker
    participant DIR as Directions API
    participant API as RideRouter<br/>(FastAPI)
    participant FS as Firestore
    participant NS as NotificationService
    participant FCM as FCM
    participant NHV as NotificationHandler<br/>(Vendedor)
    participant MSV as MapScreenVendor
    participant RTDB as RTDB<br/>/vendedores_activos
    participant NHB as NotificationHandler<br/>(Comprador)

    Note over C,MSB: Comprador ve el mapa con vendedores activos (radio 4 km).<br/>El VendorMarker incluye ride_enabled=true → bottom sheet con dos opciones.
    C->>MSB: Toca marcador del Vendedor (ride_enabled: true)
    MSB->>MSB: Muestra bottom sheet:<br/>"Solicitar parada" / "Solicitar raite"
    C->>MSB: Elige "Solicitar raite"
    MSB->>RRM: iniciarRaite(vendor_uid, vendor_location, pickup_location: GeoPoint)

    Note over RRM,DP: RideRequestModule abre el selector de destino como pantalla modal
    RRM->>DP: abrirDestinationPicker(pickup_location)
    DP->>DP: Renderiza mapa centrado en pickup_location<br/>con pin draggable + indicador de distancia en tiempo real
    C->>DP: Arrastra pin al destino deseado
    DP->>DP: Calcula y muestra distancia estimada al destino
    C->>DP: Toca "Confirmar destino"
    DP-->>RRM: destination: GeoPoint

    Note over RRM: Validación local de distancia (Haversine) antes de llamar al API
    RRM->>RRM: Haversine(pickup_location, destination) → distancia_km ≤ 4 — continúa

    Note over RRM,DIR: Cálculo de ruta segura client-side<br/>evitando zonas HIGH y MEDIUM (ya cargadas en MapScreenBuyer)
    RRM->>DIR: GET /directions<br/>{ origin: pickup_location, destination,<br/>avoid_polygons: risk_zones_HIGH_MEDIUM[] }
    DIR-->>RRM: route_polyline + duración + distancia

    RRM->>MSB: Muestra bottom sheet de confirmación<br/>(destino, ruta en mapa, distancia, tiempo estimado)
    C->>MSB: Confirma "Solicitar raite"

    RRM->>API: POST /rides + JWT (buyer)<br/>{ vendor_uid, pickup_location, destination, route_polyline }
    API->>API: AuthMiddleware: verifica JWT → buyer_uid, rol=BUYER

    Note over API,FS: FastAPI valida precondiciones del vendedor
    API->>FS: GET users/{vendor_uid} → { ride_enabled, fcm_token }
    FS-->>API: { ride_enabled: true, fcm_token: "vendor_token_..." }
    API->>FS: Query rides WHERE vendor_uid=={vendor_uid}<br/>AND status IN [pending, accepted, in_progress]
    FS-->>API: lista vacía — vendedor disponible para raite
    API->>FS: Query stop_requests WHERE vendor_uid=={vendor_uid}<br/>AND status IN [pending, accepted]
    FS-->>API: lista vacía — sin paradas activas

    Note over API,FS: Validación de zona de riesgo del comprador (simetría con CU-01)
    API->>FS: Query risk_zones WHERE active==true AND risk_level=="HIGH"<br/>AND pickup_location dentro del polígono
    FS-->>API: sin coincidencias — comprador en zona segura

    API->>FS: Crear rides/{id}<br/>{ buyer_uid, vendor_uid, pickup_location,<br/>destination, route_polyline,<br/>status: "pending", created_at: now,<br/>expires_at: now+60s, updated_at: now }
    FS-->>API: ride_id

    API->>NS: notify_ride_request_incoming(vendor_uid, ride_id, pickup_location, destination)
    NS->>FCM: POST /send { token: vendor_fcm_token,<br/>data: { type: "ride_request_incoming",<br/>ride_id, pickup_location, destination, buyer_name } }
    FCM-->>NHV: Entrega push notification al Vendedor

    API-->>RRM: 201 Created { ride_id, status: "pending" }
    RRM->>RRM: Inicia timer local de 60 s
    RRM->>MSB: Muestra "Esperando respuesta del vendedor..." (contador regresivo)

    NHV->>MSV: despacha evento ride_request_incoming
    Note over MSV: Vendedor ve Dialog "Solicitud de raite entrante"<br/>(nombre del comprador, punto de recogida, destino, distancia estimada)
    MSV->>MSV: Muestra Dialog con botones "Aceptar" / "Rechazar"
    C->>MSV: (Vendedor) toca "Aceptar"
    MSV->>API: PATCH /rides/{id}/status<br/>{ status: "accepted" } + JWT (vendor)
    API->>API: AuthMiddleware: verifica JWT → vendor_uid, rol=VENDOR
    API->>FS: Update rides/{id}<br/>{ status: "accepted", accepted_at: now, updated_at: now }
    FS-->>API: OK

    API->>NS: notify_ride_request_accepted(buyer_uid, ride_id)
    NS->>FCM: POST /send { token: buyer_fcm_token,<br/>data: { type: "ride_request_accepted", ride_id } }
    FCM-->>NHB: push notification al Comprador
    NHB->>RRM: despacha ride_request_accepted
    RRM->>MSB: Navega a TrackingScreen<br/>(modo raite: ruta superpuesta + marcador del vendedor via RTDB)

    Note over MSB,RTDB: Fase 1 — Vendedor navegando hacia el punto de recogida
    loop Cada 3 s ó ≥ 10 m de desplazamiento
        RTDB-->>MSB: /vendedores_activos/{vendor_uid} { lat, lng, timestamp }
    end
    MSB->>MSB: Actualiza marcador del Vendedor sobre la ruta hasta el pickup

    Note over MSV: Vendedor llega al punto de encuentro del Comprador.<br/>Toca "Llegué al punto de recogida".
    MSV->>API: POST /rides/{id}/vendor_arrived + JWT (vendor)
    API->>NS: notify_ride_vendor_arrived(buyer_uid, ride_id)
    NS->>FCM: POST /send { token: buyer_fcm_token,<br/>data: { type: "ride_vendor_arrived", ride_id } }
    FCM-->>NHB: push notification "¡El vendedor llegó a tu ubicación!"
    NHB->>MSB: Banner en TrackingScreen:<br/>"El vendedor llegó — sube al vehículo"

    Note over C,MSV: Comprador aborda el vehículo del Vendedor.<br/>El Vendedor confirma el abordaje y toca "Iniciar viaje".
    MSV->>API: PATCH /rides/{id}/status<br/>{ status: "in_progress" } + JWT (vendor)
    API->>FS: Update rides/{id}<br/>{ status: "in_progress", started_at: now, updated_at: now }
    FS-->>API: OK
    Note over MSB: TrackingScreen detecta cambio a "in_progress" vía listener Firestore<br/>→ cambia a Fase 2: ruta pickup → destino.

    Note over MSB,RTDB: Fase 2 — Vendedor y Comprador viajan hacia el destino
    loop Cada 3 s ó ≥ 10 m de desplazamiento
        RTDB-->>MSB: /vendedores_activos/{vendor_uid} { lat, lng, timestamp }
    end
    MSB->>MSB: Actualiza marcador del Vendedor a lo largo de la ruta al destino

    Note over MSV: Vendedor y Comprador llegan al destino
    MSV->>API: PATCH /rides/{id}/status<br/>{ status: "completed" } + JWT (vendor)
    API->>FS: Update rides/{id}<br/>{ status: "completed", completed_at: now, updated_at: now }
    FS-->>API: OK
    API->>NS: notify_ride_completed(buyer_uid, vendor_uid, ride_id)
    NS->>FCM: POST /send (multicast: buyer_fcm_token + vendor_fcm_token)<br/>{ data: { type: "ride_completed", ride_id } }
    FCM-->>NHB: push notification "Raite completado"
    MSB->>MSB: Muestra pantalla de confirmación de llegada al destino
```

---

### Diagrama 9.5.B — Condición 3A: Vendedor no disponible / zona peligrosa {#diagrama-95b}

> Cubre los dos escenarios definidos por el SRS v2.1 bajo Condición 3A: (a) el Vendedor tiene una solicitud activa (parada o raite en curso), y (b) la ubicación del Comprador está dentro de una zona de riesgo HIGH activa. En ambos casos UBISAFE detecta la condición server-side y notifica al Comprador con el motivo específico.
>
> **Pre-estado:** El Comprador ha seleccionado destino, la ruta fue calculada y confirmó "Solicitar raite". `RideRequestModule` envía `POST /rides`.

```mermaid
sequenceDiagram
    autonumber
    participant C as Comprador
    participant MSB as MapScreenBuyer
    participant RRM as RideRequestModule
    participant API as RideRouter<br/>(FastAPI)
    participant FS as Firestore

    alt Condición 3A-a — Vendedor tiene solicitud activa (parada o raite)
        RRM->>API: POST /rides + JWT (buyer)<br/>{ vendor_uid, pickup_location, destination, route_polyline }
        API->>API: AuthMiddleware: verifica JWT → buyer_uid, rol=BUYER
        API->>FS: Query rides WHERE vendor_uid=={vendor_uid}<br/>AND status IN [pending, accepted, in_progress]
        FS-->>API: 1 documento activo — vendedor ocupado con raite
        API-->>RRM: 409 Conflict<br/>{ error: "vendor_not_available",<br/>message: "El vendedor tiene una solicitud activa" }
        RRM->>MSB: Muestra error:<br/>"El vendedor no está disponible ahora.<br/>Por favor, elige otro vendedor."
        MSB->>MSB: Regresa al mapa con vendedores activos

    else Condición 3A-b — Comprador en zona de riesgo HIGH activa
        RRM->>API: POST /rides + JWT (buyer)<br/>{ vendor_uid, pickup_location, destination, route_polyline }
        API->>API: AuthMiddleware: verifica JWT → buyer_uid, rol=BUYER
        API->>FS: Query risk_zones WHERE active==true AND risk_level=="HIGH"<br/>AND pickup_location dentro del polígono
        FS-->>API: Zona HIGH activa en ubicación del Comprador
        API-->>RRM: 403 Forbidden<br/>{ error: "buyer_in_risk_zone",<br/>message: "No puedes solicitar un raite desde una zona de riesgo alto" }
        RRM->>MSB: Muestra error:<br/>"Tu ubicación está dentro de una zona de riesgo activo.<br/>Desplázate a una zona segura para solicitar el raite."
        MSB->>MSB: Permanece en el mapa
    end
```

---

### Diagrama 9.5.C — Condición 4A: Destino demasiado lejos {#diagrama-95c}

> El SRS v2.1 especifica: *"UBISAFE detecta que el destino tentativo está a una distancia considerable (más de 4 km desde el punto de recogida hasta el destino) y notifica de esto al vendedor. El vendedor rechaza. UBISAFE notifica al comprador que el vendedor rechazó."* La solicitud alcanza el servidor; FastAPI detecta la distancia, crea el `ride` en estado `pending` y notifica al Vendedor con la distancia excedida. El Vendedor rechaza explícitamente. El Comprador recibe notificación del rechazo con motivo `destination_too_far`.
>
> **Pre-estado:** El Comprador confirmó un destino a más de 4 km del punto de recogida. `RideRequestModule` envía `POST /rides`.

```mermaid
sequenceDiagram
    autonumber
    participant C as Comprador
    participant MSB as MapScreenBuyer
    participant RRM as RideRequestModule
    participant API as RideRouter<br/>(FastAPI)
    participant FS as Firestore
    participant NS as NotificationService
    participant FCM as FCM
    participant NHV as NotificationHandler<br/>(Vendedor)
    participant MSV as MapScreenVendor
    participant NHB as NotificationHandler<br/>(Comprador)

    RRM->>API: POST /rides + JWT (buyer)<br/>{ vendor_uid, pickup_location, destination, route_polyline }
    API->>API: AuthMiddleware: verifica JWT → buyer_uid, rol=BUYER
    API->>API: Haversine(pickup_location, destination) → distancia_km > 4

    Note over API,FS: FastAPI crea el ride en estado pending<br/>e informa al Vendedor sobre la distancia excedida.
    API->>FS: Crear rides/{id}<br/>{ buyer_uid, vendor_uid, pickup_location, destination,<br/>status: "pending", distancia_km,<br/>created_at: now, expires_at: now+60s }
    FS-->>API: ride_id

    API->>NS: notify_ride_destination_too_far(vendor_uid, ride_id, distancia_km)
    NS->>FCM: POST /send { token: vendor_fcm_token,<br/>data: { type: "ride_destination_too_far",<br/>ride_id, distancia_km } }
    FCM-->>NHV: push notification al Vendedor

    NHV->>MSV: despacha evento ride_destination_too_far
    MSV->>MSV: Muestra Dialog:<br/>"Destino demasiado lejano (X km — máx. 4 km permitido).<br/>Debes rechazar esta solicitud."
    C->>MSV: (Vendedor) toca "Rechazar solicitud"

    MSV->>API: PATCH /rides/{id}/status<br/>{ status: "rejected", rejected_reason: "destination_too_far" } + JWT (vendor)
    API->>API: AuthMiddleware: verifica JWT → vendor_uid, rol=VENDOR
    API->>FS: Update rides/{id}<br/>{ status: "rejected", rejected_reason: "destination_too_far", updated_at: now }
    FS-->>API: OK

    API->>NS: notify_ride_request_rejected(buyer_uid, ride_id, "destination_too_far")
    NS->>FCM: POST /send { token: buyer_fcm_token,<br/>data: { type: "ride_request_rejected",<br/>ride_id, reason: "destination_too_far" } }
    FCM-->>NHB: push notification al Comprador
    NHB->>RRM: despacha ride_request_rejected
    RRM->>MSB: Snackbar:<br/>"El vendedor rechazó: el destino supera el radio máximo de 4 km."
    MSB->>MSB: Regresa al mapa con vendedores activos
```

---

### Diagrama 9.5.D — Condición 6A: Vendedor rechaza la solicitud {#diagrama-95d}

> El Vendedor recibe la solicitud de raite en estado normal (`ride_request_incoming`) y decide rechazarla manualmente. UBISAFE notifica al Comprador que la solicitud fue rechazada.
>
> **Pre-estado:** `POST /rides` fue exitoso. `rides/{id}.status == "pending"`. El Vendedor recibió el push notification `ride_request_incoming`.

```mermaid
sequenceDiagram
    autonumber
    participant C as Comprador
    participant MSB as MapScreenBuyer
    participant RRM as RideRequestModule
    participant API as RideRouter<br/>(FastAPI)
    participant FS as Firestore
    participant NS as NotificationService
    participant FCM as FCM
    participant NHV as NotificationHandler<br/>(Vendedor)
    participant MSV as MapScreenVendor
    participant NHB as NotificationHandler<br/>(Comprador)

    NHV->>MSV: despacha evento ride_request_incoming
    Note over MSV: Vendedor ve Dialog "Solicitud de raite entrante"<br/>(nombre del comprador, punto de recogida, destino, distancia estimada)
    MSV->>MSV: Muestra Dialog con botones "Aceptar" / "Rechazar"
    C->>MSV: (Vendedor) toca "Rechazar"

    MSV->>API: PATCH /rides/{id}/status<br/>{ status: "rejected", rejected_reason: "vendor_rejected" } + JWT (vendor)
    API->>API: AuthMiddleware: verifica JWT → vendor_uid, rol=VENDOR
    API->>FS: Update rides/{id}<br/>{ status: "rejected", rejected_reason: "vendor_rejected", updated_at: now }
    FS-->>API: OK

    API->>NS: notify_ride_request_rejected(buyer_uid, ride_id, reason)
    NS->>FCM: POST /send { token: buyer_fcm_token,<br/>data: { type: "ride_request_rejected",<br/>ride_id, reason: "vendor_rejected" } }
    FCM-->>NHB: push notification al Comprador
    NHB->>RRM: despacha ride_request_rejected
    RRM->>MSB: Descarta pantalla de espera
    MSB->>C: Snackbar: "El vendedor no pudo atenderte en este momento"
    MSB->>MSB: Regresa al mapa con vendedores activos
```

---

### Diagrama 9.5.E — E1: Pérdida de conexión {#diagrama-95e}

> El SRS v2.1 E1 establece: *"UBISAFE muestra la última ubicación conocida. Se notifica a ambos usuarios. El sistema intenta reconectar automáticamente."* El modelo reutiliza la infraestructura RTDB con `onDisconnect().remove()` ya presente en CU-01/02 para detectar la pérdida y congelar el marcador del Vendedor en la última posición conocida.
>
> **Pre-estado:** `rides/{id}.status == "accepted"` o `"in_progress"`. Comprador en `TrackingScreen` con stream RTDB activo. El Vendedor pierde señal GPS o conexión a internet.

```mermaid
sequenceDiagram
    autonumber
    participant C as Comprador
    participant MSB as MapScreenBuyer
    participant MSV as MapScreenVendor
    participant GPS as GPSService<br/>(Vendedor)
    participant RTDB as RTDB<br/>/vendedores_activos

    Note over GPS,RTDB: El Vendedor pierde señal GPS o conexión a internet durante el trayecto.<br/>GPSService ejecuta onDisconnect().remove() del nodo en RTDB.

    RTDB-xMSB: Stream RTDB interrumpido — nodo del Vendedor eliminado o sin actualización
    MSB->>MSB: Detecta pérdida del stream<br/>(nodo eliminado o timestamp desactualizado > umbral)
    MSB->>C: Banner persistente en TrackingScreen:<br/>"Seguimiento pausado. El vendedor perdió la señal GPS.<br/>Última ubicación conocida: [timestamp]"
    MSB->>MSB: Mantiene último marcador del Vendedor congelado<br/>(ícono diferenciado — señal perdida)

    GPS-->>MSV: stateStream → GPSServiceState.error_no_signal
    MSV->>MSV: Banner: "Señal GPS perdida.<br/>Tu ubicación no es visible para el comprador."

    Note over MSB,MSV: El raite permanece en estado activo en Firestore.<br/>UBISAFE muestra la última ubicación conocida a ambos usuarios.<br/>El sistema intenta reconectar automáticamente sin intervención manual.

    alt El Vendedor recupera la señal GPS (reconexión automática)
        GPS->>GPS: Señal recuperada — reanuda transmisión
        GPS->>RTDB: set /vendedores_activos/{vendor_uid}<br/>{ lat, lng, timestamp, activo: true }
        RTDB-->>MSB: onValue stream: nodo re-creado con posición actualizada
        MSB->>MSB: Banner "Seguimiento pausado" desaparece
        MSB->>MSB: Tracking se reanuda con posición actualizada del Vendedor
        MSB->>C: Snackbar: "Seguimiento reanudado"
        Note over MSB: Flujo normal continúa hacia la finalización del raite.
    else Sin recuperación prolongada (mecanismo iter. futura)
        Note over MSB: Si el stream permanece inactivo más de N minutos sin<br/>actualización de rides/{id}, se considerará cancelación asistida.<br/>Mecanismo exacto postergado a iter. 3 (Cloud Function + timer).
    end
```

---

### Diagrama 9.5.F — E2: Cancelación por el comprador {#diagrama-95f}

> El SRS v2.1 E2 establece: *"El comprador cancela antes del encuentro. UBISAFE notifica al vendedor. El vendedor vuelve al estado de 'disponible'."* El Comprador inicia el `PATCH` a `rejected` con `rejected_reason: "buyer_cancelled"`. El Vendedor es notificado y queda disponible para nuevas solicitudes.
>
> **Pre-estado:** `rides/{id}.status == "accepted"`. El Vendedor está navegando hacia el punto de recogida. El Comprador decide cancelar antes del encuentro.

```mermaid
sequenceDiagram
    autonumber
    participant C as Comprador
    participant MSB as MapScreenBuyer
    participant RRM as RideRequestModule
    participant API as RideRouter<br/>(FastAPI)
    participant FS as Firestore
    participant NS as NotificationService
    participant FCM as FCM
    participant NHV as NotificationHandler<br/>(Vendedor)
    participant MSV as MapScreenVendor

    C->>MSB: Toca "Cancelar raite" en TrackingScreen
    MSB->>RRM: solicitar cancelación
    RRM->>API: PATCH /rides/{id}/status<br/>{ status: "rejected", rejected_reason: "buyer_cancelled" } + JWT (buyer)
    API->>API: AuthMiddleware: verifica JWT → buyer_uid, rol=BUYER
    API->>FS: Update rides/{id}<br/>{ status: "rejected", rejected_reason: "buyer_cancelled", updated_at: now }
    FS-->>API: OK

    API->>NS: notify_ride_cancelled_by_buyer(vendor_uid, ride_id)
    NS->>FCM: POST /send { token: vendor_fcm_token,<br/>data: { type: "ride_cancelled_by_buyer", ride_id } }
    FCM-->>NHV: push notification al Vendedor
    NHV->>MSV: Dialog: "El comprador canceló el raite"
    MSV->>MSV: Descarta la navegación activa.<br/>Vendedor vuelve al estado disponible (sin raite en curso).

    RRM->>MSB: Muestra confirmación de cancelación
    MSB->>C: Snackbar: "Raite cancelado exitosamente"
    MSB->>MSB: Regresa al mapa con vendedores activos
```

---

### Diagrama 9.5.G — E3: Tiempo de respuesta agotado (CA-04.3) {#diagrama-95g}

> El SRS v2.1 CA-04.3 establece: *"Dado que el vendedor no responde, cuando transcurran 60 segundos desde la solicitud, entonces UBISAFE cancela automáticamente la petición y notifica al comprador."* El cliente inicia el `PATCH` de expiración al vencer el timer local. Se incluye el manejo de race condition por si el servidor ya marcó el documento antes de recibir el `PATCH` del cliente.
>
> **Pre-estado:** `POST /rides` fue exitoso. `rides/{id}.status == "pending"`. `expires_at = created_at + 60s`. El Vendedor no responde.

```mermaid
sequenceDiagram
    autonumber
    participant C as Comprador
    participant MSB as MapScreenBuyer
    participant RRM as RideRequestModule
    participant API as RideRouter<br/>(FastAPI)
    participant FS as Firestore
    participant NS as NotificationService
    participant FCM as FCM
    participant NHB as NotificationHandler<br/>(Comprador)

    RRM->>RRM: Timer local de 60 s activo
    MSB->>C: Muestra "Esperando respuesta del vendedor..." (contador regresivo visible)

    Note over RRM: Timer local expira sin recibir ride_request_accepted<br/>ni ride_request_rejected del Vendedor.
    RRM->>RRM: Timer expira (60 s)
    RRM->>API: PATCH /rides/{id}/status<br/>{ status: "expired", rejected_reason: "timeout" } + JWT (buyer)

    alt El servidor aún no expiró el documento (caso normal)
        API->>FS: Update rides/{id}<br/>{ status: "expired", rejected_reason: "timeout", updated_at: now }
        FS-->>API: OK
        API->>NS: notify_ride_request_expired(buyer_uid, ride_id)
        NS->>FCM: POST /send { token: buyer_fcm_token,<br/>data: { type: "ride_request_expired", ride_id } }
        FCM-->>NHB: push notification "Tiempo de espera agotado"
        NHB->>RRM: despacha ride_request_expired
    else Race condition: servidor ya marcó el documento como expired
        API-->>RRM: 409 Conflict (documento ya expirado server-side)
        Note over RRM: RRM trata el 409 como expiración confirmada — mismo resultado para el Comprador.
    end

    RRM->>MSB: Descarta pantalla de espera
    MSB->>C: Snackbar: "El vendedor no respondió a tiempo.<br/>Intenta con otro vendedor."
    MSB->>MSB: Regresa al mapa con vendedores activos
```

---

## Notas de implementación [iter. 2]

> Esta sección va al pie de §9 en el SDD final, como complemento a las notas de §8.

### Eventos FCM de CU-04 — Tabla de resumen

Los 8 eventos FCM de CU-04 amplían el `NotificationHandler` (que tenía 3 eventos en iter. 1). Con iter. 2, el total sube a **11 eventos** (3 iter. 1 + 8 iter. 2):

| Evento FCM | Dirección | Disparado en | Receptor | Acción en la app |
|---|---|---|---|---|
| `ride_request_incoming` | FastAPI → Vendedor | `POST /rides` (buyer crea) | `NotificationHandler` (Vendedor) | `MapScreenVendor` muestra Dialog de raite entrante |
| `ride_request_accepted` | FastAPI → Comprador | `PATCH /rides/{id}/status → accepted` | `NotificationHandler` (Comprador) | `RideRequestModule` navega a `TrackingScreen` |
| `ride_request_rejected` | FastAPI → Comprador | `PATCH /rides/{id}/status → rejected` (Cond. 4A, 6A) | `NotificationHandler` (Comprador) | `RideRequestModule` descarta pantalla, vuelve al mapa |
| `ride_request_expired` | FastAPI → Comprador | `PATCH /rides/{id}/status → expired` (E3) | `NotificationHandler` (Comprador) | `RideRequestModule` descarta pantalla, vuelve al mapa |
| `ride_destination_too_far` | FastAPI → Vendedor | `POST /rides` con distancia > 4 km (Cond. 4A) | `NotificationHandler` (Vendedor) | `MapScreenVendor` muestra Dialog de rechazo por distancia |
| `ride_vendor_arrived` | FastAPI → Comprador | `POST /rides/{id}/vendor_arrived` | `NotificationHandler` (Comprador) | Banner en `TrackingScreen`: "El vendedor llegó" |
| `ride_cancelled_by_buyer` | FastAPI → Vendedor | `PATCH /rides/{id}/status → rejected` por buyer (E2) | `NotificationHandler` (Vendedor) | Dialog: "El comprador canceló el raite" |
| `ride_completed` | FastAPI → Buyer + Vendor | `PATCH /rides/{id}/status → completed` | `NotificationHandler` (ambos) | Pantalla de confirmación de llegada al destino |

> **Nota para Alexis:** El endpoint `POST /rides/{id}/vendor_arrived` es nuevo en esta fase — no cambia el `status` en Firestore, solo dispara el FCM `ride_vendor_arrived` al Comprador. Debe agregarse al `RideRouter` con validación JWT (rol=VENDOR) y verificación de que `rides/{id}.status == "accepted"`.

### Reutilización de TrackingScreen

La pantalla `TrackingScreen` (originalmente de CU-01) se reutiliza para el seguimiento del raite sin cambio estructural, tal como se indica en `SDD2_FASE2_UBISAFE.md §11.1`. La pantalla recibe un parámetro `mode: "stop" | "ride"` que ajusta el texto del encabezado y el comportamiento de los botones de confirmación. En modo `ride`:
- **Fase 1** (`accepted`): ruta hasta el pickup + marcador del Vendedor en movimiento.
- **Fase 2** (`in_progress`): ruta hasta el destino del Comprador. El cambio de fase es detectado por un **listener Firestore** sobre `rides/{id}.status`, no por FCM, garantizando consistencia ante fallos de entrega push.

### Consistencia con el modelo de datos (SDD2_FASE3A)

| Diagrama | Campos `rides` usados | Transición de estado |
|---|---|---|
| 9.5.A | `status`, `accepted_at`, `started_at`, `completed_at` | `pending → accepted → in_progress → completed` |
| 9.5.B | `status` | Ninguna (error antes de crear el documento) |
| 9.5.C | `status`, `rejected_reason: "destination_too_far"` | `pending → rejected` |
| 9.5.D | `status`, `rejected_reason: "vendor_rejected"` | `pending → rejected` |
| 9.5.E | `status: "accepted" / "in_progress"` — sin cambio durante pérdida GPS | — |
| 9.5.F | `status`, `rejected_reason: "buyer_cancelled"` | `accepted → rejected` |
| 9.5.G | `status`, `rejected_reason: "timeout"`, `expires_at` | `pending → expired` |

---

## Checklist de cobertura CU-04 — Fase 4.A'

| Criterio SRS | Diagrama que lo cubre | ✅/⚠️ |
|---|---|---|
| CA-04.1: Notificación al vendedor < 5 s | 9.5.A — FCM `ride_request_incoming` tras `POST /rides` | ✅ |
| CA-04.2: Ruta segura evitando zonas de riesgo alto | 9.5.A — Directions API client-side con `avoid_polygons` | ✅ |
| CA-04.3: Timeout 60 s → cancela y notifica al comprador | 9.5.G — timer local + `PATCH expired` + FCM | ✅ |
| CA-04.4: Pérdida de conexión → última ubicación conocida | 9.5.E — TrackingScreen congela último marcador, reconexión automática | ✅ |
| Flujo Normal paso 10: comprador aborda → vendedor inicia viaje | 9.5.A — `POST /vendor_arrived` (llegada) separado de `PATCH in_progress` (inicio del viaje tras abordaje) | ✅ |
| Condición 3A: Vendedor no disponible / zona peligrosa | 9.5.B — Condición 3A-a y 3A-b | ✅ |
| Condición 4A: Destino > 4 km → notifica al vendedor → vendedor rechaza | 9.5.C — `POST /rides` → FCM `ride_destination_too_far` → Vendedor rechaza → Comprador notificado | ✅ |
| Condición 6A: Vendedor rechaza manualmente | 9.5.D | ✅ |
| E1: Pérdida de conexión — última ubicación, ambos notificados, reconexión automática | 9.5.E | ✅ |
| E2: Cancelación por el comprador — vendedor notificado, queda disponible | 9.5.F | ✅ |
| Pre-condición: `ride_enabled` del vendedor | 9.5.A — FastAPI verifica `users/{vendor_uid}.ride_enabled` | ✅ |
| Pre-condición: vendedor disponible | 9.5.A — FastAPI query `rides` + `stop_requests` activos | ✅ |
| Pre-condición: comprador fuera de zona HIGH | 9.5.A — query `risk_zones` | ✅ |
| Post-condición éxito: raite registrado como activo | 9.5.A — `rides/{id}.status = in_progress / completed` | ✅ |
| Post-condición fracaso: vendedor disponible para otros usuarios | 9.5.C, 9.5.D, 9.5.F, 9.5.G — status `rejected`/`expired` libera al vendedor | ✅ |
| Post-condición fracaso: UBISAFE notifica al comprador el motivo | 9.5.B (error inline), 9.5.C, 9.5.D, 9.5.F, 9.5.G — FCM con `reason` | ✅ |

**Resultado: todos los RF/CA de CU-04 tienen cobertura en los diagramas de secuencia. ✅**

---

## Historial del archivo

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| V1.0 | 24/04/2026 | Miguel Rivera (con asistencia de Claude) | Fase 4.A' inicial: diagramas 9.5.A, 9.5.B, 9.5.C con flujo normal, 4 condiciones alternativas y 2 excepciones combinadas. |
| V2.0 | 24/04/2026 | Miguel Rivera (con asistencia de Claude) | Correcciones de consistencia SRS v2.1: Condición 4A corregida (actor Vendedor); excepciones renombradas E1/E2/E3; `in_progress` separado de `vendor_arrived`; diagramas CU-05 y CU-06 agregados temporalmente. |
| V3.0 | 24/04/2026 | Miguel Rivera (con asistencia de Claude) | Reestructuración completa: CU-05 y CU-06 removidos (corresponden a otra fase). CU-04 expandido a 7 diagramas de secuencia independientes (9.5.A–G): flujo normal + 3 condiciones alternativas individuales + 3 excepciones individuales. Checklist y tabla FCM actualizados. |

---

*Fase 4.A' completada. Output: `SDD2_FASE4A_UBISAFE.md`. Compartir a Alexis al finalizar para consolidación.*
*Actualizado: 24/04/2026 — Los Borbotones / UBISAFE Iteración 2*
