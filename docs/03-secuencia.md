# 03 — Diagramas de Secuencia

Un diagrama de secuencia por caso de uso (CU-07, CU-08, CU-09). Reflejan el flujo normal y
los principales flujos alternativos/excepción del SRS, anclados a los endpoints y servicios
reales del backend (`ubisafe_api/`) y las Cloud Functions (`functions/main.py`).

Participantes comunes:
- **App**: app Flutter (`ubisafe_app/`).
- **API**: FastAPI (`ubisafe_api/`), con `FirestoreService` y `NotificationService`.
- **Firestore**: base de datos.
- **CF**: Cloud Functions.
- **FCM**: Firebase Cloud Messaging.

---

## CU-07 — Gestionar lotes baldíos

Cubre los tres momentos: reportar, apoyar (umbral de 3) y resolver.

```mermaid
sequenceDiagram
    autonumber
    actor U as Comprador/Vendedor
    participant App
    participant API as API (lot/report_router)
    participant FS as Firestore
    participant Notif as NotificationService
    participant FCM

    rect rgb(235, 245, 255)
    note over U,FS: Reportar lote baldio
    U->>App: Selecciona "Lote baldio" + punto + descripcion
    App->>API: POST /community-reports {threat_type:"lote", location, description}
    API->>API: Valida ubicacion dentro de 1 km de last_location
    alt fuera de rango
        API-->>App: 422 location_out_of_range
    else valido
        API->>FS: create_community_report (status=pending_validation, TTL 24h)
        FS-->>API: reporte creado
        API-->>App: 201 CommunityReport
    end
    end

    rect rgb(240, 255, 240)
    note over U,FS: Apoyar el reporte (otros usuarios, umbral = 3)
    U->>App: Abre /community/reports y pulsa "Apoyar"
    App->>API: POST /community-reports/{id}/support
    API->>API: Verifica es lote, status pendiente, no apoyado antes
    API->>FS: support_community_report (transaccion: +1 supporters)
    alt 3er soporte
        FS->>FS: Fija pending_resolver_uid = UID del 3er soporte
    end
    FS-->>API: reporte actualizado
    API-->>App: 200 CommunityReport
    end

    rect rgb(255, 248, 235)
    note over U,FCM: Marcar como resuelto (solo el 3er soporte)
    U->>App: Pulsa "Marcar como resuelto"
    App->>API: PATCH /community-reports/{id}/resolve
    API->>API: Verifica pending_resolver_uid == solicitante
    alt no autorizado
        API-->>App: 403 not_pending_resolver
    else autorizado
        API->>FS: resolve_community_report (status=resolved)
        API->>Notif: send_lot_resolved (reportador + soportes)
        Notif->>FCM: push "lot_resolved"
        FCM-->>App: notifica a reportador y soportes
        API-->>App: 200 CommunityReport (resolved)
    end
    end
```

**Criterios SRS cubiertos:** CA-07.1 (registro < 10 s e informa a cercanos), CA-07.2 (rechazo
fuera de 4 km — aquí validado a 1 km del `last_location`), CA-07.3 (descripción suficiente),
CA-07.4 (3 confirmaciones), CA-07.5 (resolución + reputación al resolutor).

---

## CU-08 — Suscribirse a cercanía de vendedor

Dos fases: la suscripción (síncrona) y la alerta de proximidad (reactiva, vía Cloud Function
cuando el vendedor activa su radar).

```mermaid
sequenceDiagram
    autonumber
    actor C as Comprador
    actor V as Vendedor
    participant App
    participant API as API (subscription_router)
    participant FS as Firestore
    participant CF as Cloud Function
    participant FCM

    rect rgb(235, 245, 255)
    note over C,FS: Suscribirse a un vendedor
    C->>App: Toca marcador de vendedor y pulsa "Suscribirse"
    App->>API: POST /subscriptions {vendor_uid}
    API->>API: Verifica rol BUYER y que no exista suscripcion activa
    alt ya existe activa
        API-->>App: 409 (suscripcion duplicada)
    else nueva o reactivada
        API->>FS: create_subscription (id = buyer_uid_vendor_uid, active=true)
        API-->>App: 201 Subscription
    end
    end

    rect rgb(240, 255, 240)
    note over V,FCM: Alerta de proximidad (cuando el vendedor activa su radar)
    V->>App: Activa visibilidad (radar)
    App->>FS: users/{vendor}.is_active_radar = true
    FS-->>CF: onUpdate users/{uid} (transicion a true)
    CF->>CF: Guarda: rol VENDOR y last_location presente
    CF->>FS: Query subscriptions(active, vendor_uid) + users
    CF->>CF: Filtra suscriptores dentro de 4 km (Haversine)
    CF->>FCM: Multicast "vendor_proximity_alert"
    FCM-->>App: Comprador recibe push y muestra SnackBar
    end

    rect rgb(255, 248, 235)
    note over C,FS: Cancelar suscripcion
    C->>App: Pantalla Mis suscripciones, eliminar
    App->>API: DELETE /subscriptions/{id}
    API->>FS: cancel_subscription (active=false, cancelled_at)
    API-->>App: 204 No Content
    end
```

**Criterios SRS cubiertos:** CA-08.1 (registro < 10 s), CA-08.2 (aviso de proximidad < 10 s
dentro de 4 km), CA-08.3 (cancelación). CA-08.4 (baja automática si el vendedor elimina su
cuenta) no tiene aún disparador dedicado en el código revisado — ver sección de pendientes
en el documento de navegación.

---

## CU-09 — Programar estancia grupal

Programación con validación de zona de riesgo y solapamiento, notificación a compradores
cercanos, confirmación de asistencia y cancelación (manual o automática por zona HIGH).

```mermaid
sequenceDiagram
    autonumber
    actor V as Vendedor
    actor C as Comprador
    participant App
    participant API as API (group_stay_router)
    participant FS as Firestore
    participant CF as Cloud Functions
    participant FCM

    rect rgb(235, 245, 255)
    note over V,FCM: Programar estancia
    V->>App: Programar estancia (punto, fecha/hora, duracion)
    App->>API: POST /group-stays {location, start_at, duration_minutes}
    API->>API: Verifica rol VENDOR y adelanto minimo de 5 minutos
    API->>FS: get_active_risk_zones_near (radio 200 m)
    alt zona HIGH cercana
        API-->>App: 422 {error:"zone_high", risk_zone_ids}
    else solapamiento de horario
        API->>FS: vendor_has_overlapping_stay
        API-->>App: 409 vendor_has_active_stay
    else valido (con warning si MEDIUM/LOW)
        API->>FS: create_group_stay (status=scheduled)
        API-->>App: 201 {stay, warning?}
        FS-->>CF: onCreate group_stays
        CF->>FS: Busca compradores BUYER en 500 m con last_location
        CF->>FCM: Multicast "rsvp_group_stay"
        FCM-->>App: Compradores cercanos reciben push
    end
    end

    rect rgb(240, 255, 240)
    note over C,FS: Confirmar asistencia
    C->>App: Abre detalle de la estancia y pulsa Confirmar asistencia
    App->>API: POST /group-stays/{id}/attendances
    API->>API: Verifica rol BUYER y estado scheduled/active
    API->>FS: confirm_attendance (subcol attendances + attendees_count +1)
    API-->>App: 204 No Content
    end

    rect rgb(255, 248, 235)
    note over V,FCM: Cancelacion y transiciones automaticas
    par Cancelacion manual del vendedor
        V->>App: "Cancelar estancia"
        App->>API: PATCH /group-stays/{id}/cancel
        API->>FS: cancel_group_stay (cancelled, vendor_cancelled)
        API->>FCM: send_group_stay_cancelled a asistentes
    and Scheduler (cada 5 min)
        CF->>FS: expire_group_stays (scheduled a active a ended)
    and Zona pasa a HIGH
        FS-->>CF: onUpdate risk_zones (cambia a HIGH activa)
        CF->>FS: cancel estancias en el radio (risk_zone_high)
        CF->>FCM: Multicast "group_stay_cancelled" a vendedor + asistentes
    end
    FCM-->>App: Participantes reciben push de cancelacion
    end
```

**Criterios SRS cubiertos:** CA-09.1 (registro < 10 s), CA-09.2 (aviso a compradores en 500 m),
CA-09.3 (confirmar asistencia y contador), CA-09.4 (cancelación automática por zona HIGH +
aviso), CA-09.5 (rechazo al programar en zona HIGH).
