# SDD2 — Fase 7': Trazabilidad e Historial V3.0
## Sección §12 (Trazabilidad) + §13 (Historial) del SDD
### UBISAFE · Los Borbotones · Iteración 2 · 25/04/2026

> **Propósito de este archivo:** Cerrar el ciclo de trazabilidad del SDD v2.0 garantizando que cada elemento nuevo de Iteración 2 (CU-04, CU-05, CU-06 y sus RF/RNF) se rastrea desde el SRS v2.1 hasta los componentes, secuencias, base de datos y pantallas de UI documentados en las fases anteriores. Adicionalmente, registra el historial V3.0 del documento y aplica los marcadores visuales `[iter. 2]` requeridos por el Plan Maestro.
>
> **Alcance:** Esta fase NO añade contenido arquitectónico nuevo — consolida y verifica la trazabilidad de todo lo producido en Fases 0' a 6'.
>
> **Responsable:** 🟨 Conjunto (Alexis + Miguel · pair final).
>
> **Archivos base leídos:**
> - `BB_SRS_V2.1.md` (CU-04, CU-05, CU-06; RNF-01 a RNF-06)
> - `BB_SDD_V1.0.md` (estructura base, §12 Trazabilidad y §13 Historial originales)
> - `SDD2_FASE0_UBISAFE.md` (decisiones definitivas — A-P1 a A-P4, M-P1 a M-P5)
> - `SDD2_FASE1_UBISAFE.md` (C4 L1–L2 + Cloud Functions)
> - `SDD2_FASE2_UBISAFE.md` (C4 L3 + componentes nuevos)
> - `SDD2_FASE3A_UBISAFE.md` (colección `rides`, extensión `users.ride_enabled`)
> - `SDD2_FASE3B_UBISAFE.md` (colección `community_reports`, ADRs #6/#7/#11)
> - `SDD2_FASE4A_UBISAFE.md` (secuencias §9.5 CU-04)
> - `SDD2_FASE4B_UBISAFE.md` (secuencias §9.6 CU-05 y §9.7 CU-06)
> - `SDD2_FASE5A_UBISAFE.md` (Design System extendido)
> - `SDD2_FASE5B_UBISAFE.md` (wireframes 4 pantallas nuevas)
> - `SDD2_FASE5Balt_UBISAFE.md` (wireframes 7 extensiones a pantallas existentes)
> - `SDD2_FASE5C_UBISAFE.md` (9 prompts Claude Design para mockups alta fidelidad)
> - `SDD2_FASE6_UBISAFE.md` (ADRs consolidados — 11 ADRs + 4 deudas técnicas)

---

## Índice

1. [§12.0 Convención de marcadores [iter. 2]](#convencion-marcadores)
2. [§12.1 Matriz 1 — CU → Componentes → Endpoints → Secuencias → Pantallas](#matriz-1)
3. [§12.2 Matriz 2 — RF / Criterios de Aceptación → Componentes / Mecanismos](#matriz-2)
4. [§12.3 Matriz 3 — RNF → Decisiones Arquitectónicas (ADRs)](#matriz-3)
5. [§12.4 Matriz 4 — CU → Colecciones de Base de Datos](#matriz-4)
6. [§12.5 Matriz 5 — CU → Eventos FCM](#matriz-5)
7. [§12.6 Verificación cruzada con BB_SDD_V1.0 y BB_SRS_V2.1](#verificacion-cruzada)
8. [§13 Historial — Entrada V3.0](#historial-v30)
9. [§13.1 Marcadores visuales `[iter. 2]` aplicables al .docx](#marcadores-docx)
10. [Resumen de cobertura — Fase 7'](#resumen-cobertura)

---

## §12.0 — Convención de marcadores [iter. 2] {#convencion-marcadores}

A partir de la integración del SDD v2.0 al .docx final, **todo elemento incorporado en Iteración 2** se identifica visualmente mediante una de estas tres convenciones, aplicadas de forma consistente:

| Convención | Cuándo usar | Ejemplo |
|---|---|---|
| Anotación `[iter. 2]` al final del título de sección, sub-sección o componente | Para secciones nuevas o componentes recién introducidos | `### 5.3.5.1 CommunityReportModule [iter. 2]` |
| Columna *Iteración* en tablas | Para tablas que mezclan filas de iter. 1 e iter. 2 (Matrices 1–5, tabla de componentes, tabla de eventos FCM) | Columna con valores `iter. 1` / `iter. 2` |
| Etiqueta `[iter. 2]` en campos individuales o filas | Cuando se añaden campos o filas a estructuras de iter. 1 sin reescribir la tabla completa | `ride_enabled: boolean ← [iter. 2]` |

Adicionalmente, los componentes existentes que han sido **extendidos** (no creados de cero) en iter. 2 se marcan con `[iter. 2 extendido]` en el encabezado y la descripción de la extensión va separada del párrafo original con el sub-título "**Extensiones en iter. 2:**".

---

## §12.1 — Matriz 1: CU → Componentes → Endpoints → Secuencias → Pantallas UI {#matriz-1}

> **Propósito:** Demostrar la trazabilidad horizontal completa de cada caso de uso del SRS, desde el módulo Flutter que lo origina hasta los mockups UI que lo materializan. La fila puede leerse de izquierda a derecha como la "ruta de implementación" del caso de uso.

### Matriz 1 — Iteración 1 + Iteración 2 (consolidada)

| CU | Iteración | Dominio | Componentes Flutter | Componentes FastAPI | Cloud Function | Endpoints REST | Diagramas de secuencia | Pantallas UI / Wireframes | Mockup ID |
|---|---|---|---|---|---|---|---|---|---|
| **CU-01** Solicitar parada a puerta | iter. 1 | Dispatching | `MapScreenBuyer`, `StopRequestModule`, `NotificationHandler`, `MapScreenVendor` | `StopRequestRouter`, `AuthMiddleware`, `FirestoreService`, `NotificationService` | — | `POST /stops`, `GET /stops/{id}`, `PATCH /stops/{id}/status` | §7.1.1 (normal), §7.1.2 (alt), §7.1.3 (timeout) | W-06, W-07, W-09, W-10, W-12 | (mockups iter. 1) |
| **CU-02** Activar radar de visibilidad | iter. 1 | Presence | `GPSService`, `VendorTracker`, `MapScreenVendor` | *(GPS directo a RTDB — sin router, ADR #2)* | — | — *(escritura directa RTDB)* | §7.2.1 (normal), §7.2.2 (alt GPS débil), §7.2.3 (excepción) | W-11a/b/c, W-13, W-14, W-15 | (mockups iter. 1) |
| **CU-03** Bloquear zona por riesgo activo | iter. 1 | Safety | `RiskReportModule`, `MapScreenBuyer`, `MapScreenVendor`, `NotificationHandler` | `RiskZoneRouter`, `AuthMiddleware`, `FirestoreService`, `NotificationService` | — | `POST /risk-zones`, `GET /risk-zones`, `DELETE /risk-zones/{id}` | §7.3.1 (HIGH), §7.3.2 (MEDIUM/LOW), §7.3.3 (duplicado) | W-17 (Bottom Sheet) | (mockups iter. 1) |
| **CU-04** Solicitar raite **[iter. 2]** | **iter. 2** | Dispatching (extendido) | `RideRequestModule`, `DestinationPicker`, `MapScreenBuyer` *(ext.)*, `MapScreenVendor` *(ext.)*, `NotificationHandler` *(ext.)*, `DrawerModule` *(ext.)* | `RideRouter`, `AuthMiddleware`, `AuthRouter` *(ext. PATCH /auth/ride-enabled)*, `FirestoreService` *(ext.)*, `NotificationService` *(ext.)* | — | `POST /rides`, `GET /rides/{id}`, `PATCH /rides/{id}/status`, `POST /rides/{id}/vendor_arrived`, `PATCH /auth/ride-enabled` | **§9.5.A** (Flujo normal), **§9.5.B** (Cond. 3A, 4A, 6A), **§9.5.C** (E1 conexión, E2 buyer cancela, E3 timeout 60 s) | **W-CU04-01** Solicitud de Raite, **W-14b** Dialog Raite Entrante, W-06b ext, W-07 ext, W-11b/c ext, W-18 ext, W-19 ext, W-20 ext | **CD2-01**, **CD2-05**, CD2-06, CD2-08 |
| **CU-05** Reportar focos de infección **[iter. 2]** | **iter. 2** | Community (activado) | `CommunityReportModule`, `MapScreenBuyer` *(ext.)*, `MapScreenVendor` *(ext.)*, `NotificationHandler` *(ext.)* | `CommunityReportRouter`, `AuthMiddleware`, `FirestoreService` *(ext.)*, `NotificationService` *(ext.)* | **`aggregateDuplicateReports`** (trigger `onCreate` en `community_reports`) | `POST /community-reports`, `GET /community-reports` | **§9.6.A** (Flujo normal), **§9.6.B** (Cond. 5A fuera de radio), **§9.6.C** (Cond. 7A duplicados), **§9.6.D** (E1 conexión), **§9.6.E** (E2 GPS) | **W-CU05-01** Reportar Foco, W-06b ext (polígonos en mapa), W-07 ext (FAB expandible) | **CD2-02**, CD2-07 |
| **CU-06** Verificar reportes comunitarios **[iter. 2]** | **iter. 2** | Community (activado) | `ReportValidationModule`, `CommunityReportModule` *(panel detalle)*, `DrawerModule` *(ext. "Reportes activos")* | `ReportValidationRouter`, `AuthMiddleware`, `FirestoreService` *(ext.)*, `NotificationService` *(ext. — 3 métodos nuevos)* | — | `PATCH /community-reports/{id}/validations` | **§9.7.A** (Flujo normal), **§9.7.B** (Cond. 4A doble voto), **§9.7.C** (Cond. 8A confirmado), **§9.7.D** (Cond. 8B descartado), **§9.7.E** (E1 conexión), **§9.7.F** (E2 reporte ya no disponible) | **W-CU06-01** Lista Reportes Activos, **W-CU06-02** Detalle + Validación, W-18 ext (Drawer + badge) | **CD2-03**, **CD2-04**, CD2-09 |
| **Auth** Registro y Login | iter. 1 | Identity & Access | `AuthModule` | `AuthRouter`, `AuthMiddleware` | — | `POST /auth/sync-profile`, `POST /auth/device-token` | §7.4.1 (Sign Up), §7.4.2 (Login) | W-02, W-03, W-04, W-05 | (mockups iter. 1) |

> **Nota — extensiones marcadas con `(ext.)`:** El componente existía en iter. 1 y se le añadió responsabilidad nueva en iter. 2 sin reescribir su contrato base. Ver `SDD2_FASE2_UBISAFE.md §PASO 2'.4` para el detalle de cada extensión.

### Resumen de filas nuevas en Matriz 1 [iter. 2]

| Métrica | iter. 1 | iter. 2 (suma) | Total tras iter. 2 |
|---|---|---|---|
| Casos de Uso documentados | 3 (CU-01, 02, 03) + Auth | +3 (CU-04, 05, 06) | 6 + Auth |
| Componentes Flutter referenciados | 10 | +4 nuevos + 4 extendidos | 14 |
| Componentes FastAPI referenciados | 7 | +3 nuevos + 4 extendidos | 10 |
| Cloud Functions | 0 | +1 (`aggregateDuplicateReports`) | 1 |
| Endpoints REST documentados | 11 | +6 nuevos + 1 extendido (`PATCH /auth/ride-enabled`) | 18 |
| Diagramas de secuencia | ~8 | +14 (3 CU-04 + 5 CU-05 + 6 CU-06) | ~22 |
| Pantallas / wireframes documentados | 20 | +4 nuevas + 7 extensiones + 1 dialog (W-14b) | 32 |
| Mockups Claude Design | (iter. 1) | +9 prompts (5 nuevos + 4 modificados) | 9 prompts iter. 2 |

---

## §12.2 — Matriz 2: RF / Criterios de Aceptación → Componentes / Mecanismos {#matriz-2}

> **Propósito:** Demostrar que cada Criterio de Aceptación (CA) y cada flujo (Normal / Alternativo / Excepción) descrito en el SRS v2.1 está cubierto por al menos un componente de diseño y al menos un mecanismo concreto (campo, endpoint, regla de negocio o trigger).
>
> **Cobertura iter. 1:** Los CA de CU-01, CU-02 y CU-03 (ya cubiertos en SDD v1.0) se omiten aquí por brevedad. Esta matriz documenta exclusivamente los CA de iter. 2 (CU-04, CU-05, CU-06).

### Matriz 2.A — CU-04 Solicitar raite [iter. 2]

| RF / CA / Flujo | Componente que lo implementa | Mecanismo / Campo / Regla | Diagrama §9.5 | ✅/⚠️ |
|---|---|---|---|---|
| **CA-04.1** Notificación al vendedor < 5 s | `RideRouter` (FastAPI) → `NotificationService.notify_ride_request_incoming` → FCM | Envío FCM directo tras `POST /rides`, sin pasos intermedios bloqueantes | 9.5.A | ✅ |
| **CA-04.2** Ruta segura evitando zonas HIGH y MEDIUM | `RideRequestModule` (Flutter) → Directions API client-side con `avoid_polygons` derivados de `risk_zones` HIGH+MEDIUM | Lógica equivalente a `RiskZoneRouter` reutilizada (decisión Fase 0' M-P5) | 9.5.A | ✅ |
| **CA-04.3** Timeout 60 s sin respuesta del vendedor | Campo `rides.expires_at = created_at + 60s` + timer local en `RideRequestModule` que dispara `PATCH /rides/{id}/status → expired` | Timeout uniforme con CU-01 (Fase 0' A-P1) | 9.5.C E3 | ✅ |
| **CA-04.4** Pérdida de conexión → última ubicación conocida | `TrackingScreen` muestra `pickup_location` y `destination` cacheados; banner "Conexión perdida"; reconexión automática | Campos persistentes en `rides` permiten fallback estático sin server | 9.5.C E1 | ✅ |
| **Pre-cond:** Comprador con sesión activa | `AuthMiddleware` valida JWT en cada request | `verify_id_token()` Firebase Admin SDK | Todos | ✅ |
| **Pre-cond:** Vendedor con `ride_enabled: true` | `RideRouter` consulta `users/{vendor_uid}.ride_enabled` antes de `POST /rides` | Campo `users.ride_enabled: boolean` (Fase 3.A') · Persistente (Fase 0' M-P4) · Toggle en Drawer (Fase 0' A-P2) | 9.5.A paso ~14 | ✅ |
| **Pre-cond:** Vendedor disponible (sin parada ni raite activo) | `FirestoreService.get_active_rides_for_vendor()` + consulta `stop_requests` activos → si existen, `409 Conflict` | Regla de negocio crítica documentada en `SDD2_FASE1_UBISAFE.md §4.2.2` | 9.5.A paso ~13 | ✅ |
| **Pre-cond:** Comprador no en zona bloqueada por riesgo | Validación previa en `RiskZoneRouter` | Reutiliza lógica de CU-01 | 9.5.A paso ~12 | ✅ |
| **Pre-cond:** Vendedor a ≤ 4 km del comprador | Cálculo Haversine en FastAPI | Idéntico a CU-01 | 9.5.A paso ~11 | ✅ |
| **Cond. 3A** Vendedor no disponible / zona peligrosa | `RideRouter` retorna `409 Conflict` con mensaje específico | `rejected_reason: "vendor_busy"` | 9.5.B Cond. 3A | ✅ |
| **Cond. 4A** Destino > 4 km desde recogida | `RideRequestModule` valida Haversine local + `RideRouter` re-valida | `rejected_reason: "destination_too_far"` (`400 Bad Request`) | 9.5.B Cond. 4A | ✅ |
| **Cond. 6A** Vendedor rechaza la solicitud | `PATCH /rides/{id}/status → rejected` por VENDOR | `rejected_reason: "vendor_rejected"` + FCM `ride_request_rejected` al BUYER | 9.5.B Cond. 6A | ✅ |
| **E1** Pérdida de conexión durante raite | `RideRequestModule` + `TrackingScreen` reaccionan a stream RTDB congelado | Última ubicación conocida + reintentos automáticos | 9.5.C E1 | ✅ |
| **E2** Cancelación por el comprador | `PATCH /rides/{id}/status → rejected` con `rejected_reason: "buyer_cancelled"` + FCM `ride_cancelled_by_buyer` al VENDOR | Vendedor vuelve a estado disponible | 9.5.C E2 | ✅ |
| **Post-cond éxito:** Raite registrado y servicio finalizado | `rides.status: "completed"` + timestamp `completed_at` | Documento permanece persistido para historial (W-20 ext) | 9.5.A | ✅ |
| **Post-cond fracaso:** Vendedor disponible para otros usuarios | Estados `rejected`/`expired` liberan al vendedor de la query de disponibilidad | `get_active_rides_for_vendor` excluye estos estados | 9.5.B / 9.5.C | ✅ |

### Matriz 2.B — CU-05 Reportar focos de infección [iter. 2]

| RF / CA / Flujo | Componente que lo implementa | Mecanismo / Campo / Regla | Diagrama §9.6 | ✅/⚠️ |
|---|---|---|---|---|
| **CA-05.1** Registro en máx. 10 s | `CommunityReportRouter.POST /community-reports` → Firestore write directo, sin lógica bloqueante | Cloud Function de duplicados se ejecuta asíncrona post-creación, no bloquea respuesta al cliente | 9.6.A | ✅ |
| **CA-05.2** Rechazo si usuario fuera del radio permitido | `CommunityReportRouter` valida Haversine entre `request.user.location` y `location` ≤ 4 km | Devuelve `400 Bad Request` con mensaje claro si excede | 9.6.B (Cond. 5A) | ✅ |
| **CA-05.3** Agrupación visual de reportes similares cercanos | Cloud Function `aggregateDuplicateReports` (trigger `onCreate`, radio 100 m, mismo `threat_type`) | Campos `is_duplicate: boolean` + `canonical_report_id: string\|null` en `community_reports` | 9.6.C (Cond. 7A) | ✅ |
| **CA-05.4** Retry automático ante pérdida de conexión | `CommunityReportModule` mantiene payload en memoria + backoff exponencial + Firebase Firestore offline cache | 3 intentos antes de notificar fallo | 9.6.D (E1) | ✅ |
| **Pre-cond:** Cuenta activa + GPS activo | `AuthMiddleware` (JWT) + `GPSService.gpsStatusProvider` (Riverpod) | Si GPS no disponible, `CommunityReportModule` muestra `GpsRequiredEmptyState` | 9.6.E (E2) | ✅ |
| **Pre-cond:** Usuario a ≤ 4 km del punto a reportar | Validación Haversine doble (cliente + servidor) | El punto reportado **es** la posición GPS del usuario (decisión Fase 0' 0'.6) | 9.6.A | ✅ |
| **Cond. 5A** Usuario fuera del radio permitido | `CommunityReportRouter` rechaza con `400 Bad Request` | Mensaje localizado al usuario | 9.6.B | ✅ |
| **Cond. 7A** Alta densidad de reportes similares → agrupar | Cloud Function `aggregateDuplicateReports` marca duplicados | Cliente Flutter agrupa visualmente bajo el reporte canónico | 9.6.C | ✅ |
| **E1** Pérdida de conexión durante envío | Firebase SDK retry offline + payload en memoria de `CommunityReportModule` | Reintentos automáticos sin intervención del usuario | 9.6.D | ✅ |
| **E2** Error en geolocalización (GPS apagado) | `GPSService` emite estado `error_no_signal` → `CommunityReportModule` bloquea formulario y muestra deep-link a Settings | Patrón consistente con `GpsRequiredEmptyState` de iter. 1 | 9.6.E | ✅ |
| **Post-cond éxito:** Estado inicial `pending_validation` | `CommunityReportRouter` establece `status: "pending_validation"` al crear | Mismo estado para ambos `threat_type` | 9.6.A | ✅ |
| **Post-cond:** Notificación a usuarios cercanos a 4 km | `NotificationService.notify_community_report_nearby()` → FCM multicast | Fan-out por `last_location` ≤ 4 km del reporte | 9.6.A | ✅ |
| **Tipo de foco** `animal_muerto` o `zona_sucia` | Enum validado en `CommunityReportRouter` | Color en mapa: negro / café (decisión Fase 0' A-P4) | 9.6.A | ✅ |

### Matriz 2.C — CU-06 Verificar reportes comunitarios [iter. 2]

| RF / CA / Flujo | Componente que lo implementa | Mecanismo / Campo / Regla | Diagrama §9.7 | ✅/⚠️ |
|---|---|---|---|---|
| **CA-06.1** Registro de validación en máx. 10 s | `ReportValidationRouter.PATCH .../validations` → Firestore update atómico | Operación O(1) con contadores desnormalizados (`confirm_count`, `dismiss_count`) | 9.7.A | ✅ |
| **CA-06.2** `confirm_count >= 3` → `status = confirmed` | `ReportValidationRouter` evalúa contador después de cada voto y aplica transición | Regla de negocio explícita en `SDD2_FASE3B_UBISAFE.md §3.B'.1` | 9.7.A / 9.7.C (Cond. 8A) | ✅ |
| **CA-06.3** `dismiss_count >= 3` → `status = dismissed` | `ReportValidationRouter` evalúa contador y aplica transición | Marcador atenuado en mapa hasta expirar | 9.7.D (Cond. 8B) | ✅ |
| **Pre-cond:** Cuenta activa | `AuthMiddleware` valida JWT | Idéntico a CU-04/05 | Todos §9.7 | ✅ |
| **Pre-cond:** Reporte aún no verificado | `ReportValidationRouter` verifica `status == pending_validation` antes de procesar | Si no, retorna `409 Conflict` con mensaje específico (E2) | 9.7.A / 9.7.F | ✅ |
| **Pre-cond:** Usuario a ≤ 4 km del reporte | `ReportValidationRouter` calcula Haversine `validator_lat/lng` vs `report.location` | Body del PATCH incluye coordenadas actuales del validador | 9.7.A paso ~5 | ✅ |
| **Cond. 4A** Usuario ya validó previamente | `ReportValidationRouter` busca `user_uid` en array `validations[]` antes de añadir | Retorna `409 Conflict` "Ya validaste este reporte" | 9.7.B | ✅ |
| **Cond. 8A** Alta confiabilidad → `confirmed` | Misma regla de CA-06.2 + FCM `community_report_confirmed` a usuarios cercanos | Color en mapa cambia a versión saturada / leyenda "Validado" | 9.7.C | ✅ |
| **Cond. 8B** Baja confiabilidad → `dismissed` | Misma regla de CA-06.3 + FCM `community_report_dismissed` opcional | Marcador atenuado, oculto al expirar a las 24 h | 9.7.D | ✅ |
| **Anti-voto propio** (regla de negocio ADR #6) | `ReportValidationRouter` rechaza `403 Forbidden` si `validator_uid == reporter_uid` | También bloqueado en cliente por `ReportValidationModule` (UX) | (no en SRS) | ✅ |
| **E1** Pérdida de conexión durante validación | Retry automático del SDK Firebase + `ReportValidationModule` reintenta | Hasta 3 intentos con backoff | 9.7.E | ✅ |
| **E2** Reporte ya no disponible (cambió de estado) | `ReportValidationRouter` retorna `409 Conflict` y el cliente refresca el reporte | Mensaje claro al usuario, `CommunityReportModule` actualiza marcador | 9.7.F | ✅ |
| **Post-cond éxito:** `confirmation_level` actualizado | Contadores `confirm_count` / `dismiss_count` desnormalizados se actualizan tras cada voto | Estado del reporte se recalcula en O(1) | 9.7.A | ✅ |
| **Post-cond:** Notificación a cercanos al confirmar | `NotificationService.notify_community_report_confirmed()` → FCM multicast | Solo al cruzar el umbral, no en cada voto | 9.7.C | ✅ |

**Resultado consolidado de Matriz 2:** Los **30+ criterios de aceptación, pre-condiciones, flujos alternativos y excepciones** del SRS v2.1 para CU-04, CU-05 y CU-06 tienen **cobertura completa** en al menos un componente y un mecanismo concreto. ✅

---

## §12.3 — Matriz 3: RNF → Decisiones Arquitectónicas (ADRs) {#matriz-3}

> **Propósito:** Vincular cada Requisito No Funcional del SRS v2.1 con las decisiones arquitectónicas (ADRs) que lo soportan, indicando explícitamente qué aspectos se introdujeron o reforzaron en iter. 2.

### Matriz 3 — RNFs (SRS v2.1) → ADRs (Fase 6')

| RNF | Aspecto evaluado | ADRs que lo sustentan | Mecanismos / Componentes | Iteración | Cobertura |
|---|---|---|---|---|---|
| **RNF-01 Performance** | Latencia de actualización GPS < 10 s | **ADR #2** (GPS directo a RTDB) + **ADR #3** (RTDB para tiempo real) | `GPSService` + RTDB WebSocket; latencia medida ~30–80 ms | iter. 1 (sigue vigente) | ✅ |
| **RNF-01 Performance** | Notificación al vendedor < 5 s (CA-04.1) | ADR Retro-C (FCM) + **ADR #1** (Monolito FastAPI síncrono) | `NotificationService.notify_ride_request_incoming()` directo, sin colas intermedias | **iter. 2** (CA nuevo) | ✅ |
| **RNF-01 Performance** | Registro de reporte < 10 s (CA-05.1) | **ADR #1** + **ADR #10** (Cloud Functions asíncronas) | `POST /community-reports` síncrono ≤ 200 ms; agrupación de duplicados se ejecuta asíncrona post-creación, no bloquea respuesta | **iter. 2** | ✅ |
| **RNF-01 Performance** | Registro de validación < 10 s (CA-06.1) | **ADR #1** + contadores desnormalizados (decisión BD) | `PATCH .../validations` evalúa umbral en O(1) gracias a `confirm_count`/`dismiss_count` | **iter. 2** | ✅ |
| **RNF-01 Performance** | 10 usuarios concurrentes por sector | ADR #1 + **DT-03** (Cloud Run scaling automático) | FastAPI escala horizontalmente; Firebase RTDB soporta miles de conexiones simultáneas | iter. 1 (vigente) | ✅ |
| **RNF-02 Usabilidad** | Solicitud de parada en máx. 3 pasos | Decisiones de UX iter. 1 (W-06, W-07) | Mapa → marcador vendedor → bottom sheet → confirmar | iter. 1 (vigente) | ✅ |
| **RNF-02 Usabilidad** | Solicitud de raite en pasos mínimos | Diseño W-CU04-01 + `DestinationPicker` + bottom sheet vendedor (W-07 ext) | 4 pasos: tap vendedor → "Solicitar raite" → arrastrar pin destino → confirmar | **iter. 2** | ✅ |
| **RNF-02 Usabilidad** | Reportar foco en pasos mínimos | Diseño W-CU05-01 + FAB expandible (W-07 ext) | 3 pasos: FAB "+" → "Reportar foco" → seleccionar tipo → enviar | **iter. 2** | ✅ |
| **RNF-02 Usabilidad** | Texto legible (mín. 14sp) y botones grandes (≥48dp) | Design System §8.1 (Fase 5A' verifica continuidad) | Tokens de tipografía y spacing reutilizados; mockups iter. 2 verificados WCAG AA en `SDD2_FASE5C_UBISAFE.md §8.19.4` | iter. 1 + iter. 2 | ✅ |
| **RNF-03 Confiabilidad** | Margen de error GPS ≤ 100 m | ADR #2 (RTDB) + `GPSService` con `accuracy: high` | `geolocator` Flutter con configuración alta precisión | iter. 1 (vigente para CU-04) | ✅ |
| **RNF-03 Confiabilidad** | Frecuencia GPS ≥ 1 vez/10 s | ADR #2 + `GPSService` configurado a 3 s o 10 m de desplazamiento | Configuración en `GPSService` se reutiliza para CU-04 (tracking de raite) | iter. 1 (vigente) | ✅ |
| **RNF-03 Confiabilidad** | Degradación controlada ante pérdida de conexión | ADR #2 + ADR #3 + Firebase SDK offline cache | CA-04.4: muestra última ubicación conocida; CA-05.4: retry automático; CA-06: idem | **iter. 2** (refuerzo) | ✅ |
| **RNF-03 Confiabilidad** | Reintento automático sin intervención manual | ADR Retro-C (FCM) + Firebase Firestore SDK offline persistence | `CommunityReportModule` + `ReportValidationModule` implementan backoff exponencial; FCM tiene reintentos nativos | **iter. 2** | ✅ |
| **RNF-04 Compatibilidad** | Android 10.0+ (API 29+) | Stack Flutter (no requiere ADR específico) | `pubspec.yaml` + `android/build.gradle` | iter. 1 (vigente) | ✅ |
| **RNF-04 Compatibilidad** | Pantallas 5.5–7" | Design System (responsive) | Layouts Flutter con `MediaQuery` + `LayoutBuilder` (iter. 1 + iter. 2 mockups verificados a 360–420 dp ancho) | iter. 1 + iter. 2 | ✅ |
| **RNF-05 Seguridad** | Acceso restringido a usuarios autenticados | **ADR Retro-A** (Firebase Auth) + `AuthMiddleware` | JWT verificado en todas las requests; reglas Firestore `isAuthenticated()` | iter. 1 + iter. 2 | ✅ |
| **RNF-05 Seguridad** | Datos de ubicación seguros en tránsito y almacenamiento | ADR Retro-A + ADR #3 (Firestore + RTDB con TLS) | Firebase usa HTTPS/WebSocket TLS por defecto; reglas de seguridad por documento | iter. 1 + iter. 2 | ✅ |
| **RNF-05 Seguridad** | `rides` accesibles solo por buyer/vendor involucrados | Reglas Firestore para colección `rides` (`SDD2_FASE3A_UBISAFE.md §3.A'.3`) | `allow read/update: if buyer_uid == auth.uid \|\| vendor_uid == auth.uid` | **iter. 2** | ✅ |
| **RNF-05 Seguridad** | Usuario no puede validar su propio reporte | **ADR #6** (Votación simple) + `ReportValidationRouter` | `403 Forbidden` si `validator_uid == reporter_uid` | **iter. 2** | ✅ |
| **RNF-05 Seguridad** | Anti-doble voto en CU-06 | **ADR #6** + array `validations[]` con verificación previa | `409 Conflict` si `user_uid` ya está en el array | **iter. 2** | ✅ |
| **RNF-06 Mantenibilidad** *(implícito)* | Modularización por dominio | **ADR #1** (Monolito modular) + estructura domain-first (`SDD2_FASE2_UBISAFE.md §2'.5`) | Carpetas `lib/features/<domain>/` y `modules/<domain>/` | iter. 1 + iter. 2 (extendido) | ✅ |
| **RNF-06 Mantenibilidad** *(implícito)* | Decisiones documentadas con trazabilidad | **Todos los ADRs** + esta matriz | 11 ADRs + 4 deudas técnicas en `SDD2_FASE6_UBISAFE.md` | iter. 1 + iter. 2 | ✅ |

> **Nota:** El SRS v2.1 lista RNF-01 a RNF-05. RNF-06 (mantenibilidad) se incluye como derivado implícito de la organización domain-first y los ADRs, sin contradecir el SRS.

### Aspectos de RNF reforzados específicamente por iter. 2

| RNF | Refuerzo introducido | Evidencia |
|---|---|---|
| RNF-01 | Cloud Functions asíncronas para no bloquear el camino crítico de `POST /community-reports` | ADR #10 |
| RNF-02 | DestinationPicker como patrón nuevo del Design System (Fase 5A') | `SDD2_FASE5A_UBISAFE.md §5A'.3` |
| RNF-03 | Triple capa de retry (Firebase SDK + módulo Flutter + servidor) en CU-05/06 | `SDD2_FASE4B_UBISAFE.md` E1 de cada CU |
| RNF-05 | Reglas Firestore por colección nuevas (`rides`, `community_reports`) | `SDD2_FASE3A_UBISAFE.md §3.A'.3`, `SDD2_FASE3B_UBISAFE.md §3.B'.3` |
| RNF-05 | Validación geográfica anti-spoofing en CU-06 (validator debe estar a ≤ 4 km del reporte que valida) | `SDD2_FASE1_UBISAFE.md §4.2.2` |

---

## §12.4 — Matriz 4: CU → Colecciones de Base de Datos {#matriz-4}

> **Propósito:** Trazar cada caso de uso a las colecciones Firestore / nodos RTDB que lee, escribe o consulta. Sirve para validar que el modelo de datos cubre el alcance funcional sin colecciones huérfanas ni CU sin persistencia.

### Matriz 4 — CU → Colecciones / Nodos

| CU | Iteración | Lee | Escribe / Crea | Actualiza | Trigger Cloud Function | Notas |
|---|---|---|---|---|---|---|
| **CU-01** | iter. 1 | `users/{vendor_uid}` (perfil + FCM token), `risk_zones` (rutas seguras) | `stop_requests/{id}` con `status: pending` | `stop_requests/{id}.status` (transiciones), `users/{uid}.fcm_token` | — | — |
| **CU-02** | iter. 1 | — | RTDB `/vendedores_activos/{uid}` (escritura directa) | RTDB nodo | — | ADR #2 (escritura directa, no pasa por FastAPI) |
| **CU-03** | iter. 1 | `users` (FCM tokens cercanos) | `risk_zones/{id}` con `active: true` | `risk_zones/{id}.active`, `expired_at` | — | — |
| **CU-04** Solicitar raite **[iter. 2]** | **iter. 2** | `users/{vendor_uid}.ride_enabled` *(campo nuevo)*, `users/{vendor_uid}.fcm_token`, `risk_zones` (rutas seguras), `stop_requests` y `rides` (verificar disponibilidad del vendedor) | **`rides/{id}`** *(colección nueva)* con `status: pending` | `rides/{id}.status`, `users/{uid}.fcm_token` | — | Extensión `users.ride_enabled: boolean` (Fase 3.A') |
| **CU-05** Reportar foco **[iter. 2]** | **iter. 2** | `users` (FCM tokens cercanos a 4 km) | **`community_reports/{id}`** *(colección nueva)* con `status: pending_validation`, `is_duplicate: false` | (sin updates desde CU-05; los updates vienen de CU-06) | **`aggregateDuplicateReports`** (`onCreate`): consulta `community_reports` activos del mismo `threat_type` y actualiza `is_duplicate` + `canonical_report_id` | Cloud Function escribe el campo de duplicado tras crear |
| **CU-06** Verificar reporte **[iter. 2]** | **iter. 2** | `community_reports/{id}` (estado, validations[], ubicación), `users` (FCM tokens al confirmar/descartar) | (sin creación de nuevos documentos) | `community_reports/{id}.validations[]`, `confirm_count`, `dismiss_count`, `status` (transición a `confirmed`/`dismissed`) | — | Reglas Firestore + lógica FastAPI bloquean doble voto y voto propio |
| **Auth** | iter. 1 | `users/{uid}` | `users/{uid}` (sync-profile) | `users/{uid}.fcm_token`, `users/{uid}.updated_at` | — | — |
| **Toggle ride_enabled (Drawer)** | **iter. 2** | `users/{uid}.ride_enabled` | — | `users/{uid}.ride_enabled` | — | Endpoint `PATCH /auth/ride-enabled` (extensión `AuthRouter`) |

### Resumen de cambios al esquema de BD en iter. 2

| Cambio | Tipo | Documento de referencia |
|---|---|---|
| **Nueva colección** `rides/{ride_id}` (15 campos, ciclo de vida 6 estados) | Aditivo | `SDD2_FASE3A_UBISAFE.md §3.A'.1` |
| **Nueva colección** `community_reports/{report_id}` (14 campos, ciclo de vida 4 estados, array `validations[]`) | Aditivo | `SDD2_FASE3B_UBISAFE.md §3.B'.1` |
| **Campo nuevo** `users.ride_enabled: boolean \| null` (solo VENDOR; persistente; default `false`) | Extensión a colección existente | `SDD2_FASE3A_UBISAFE.md §3.A'.2` |
| **Reglas Firestore** para `rides` (lectura/escritura solo para `buyer_uid` o `vendor_uid`) | Aditivo | `SDD2_FASE3A_UBISAFE.md §3.A'.3` |
| **Reglas Firestore** para `community_reports` (lectura pública autenticada; escritura validada por FastAPI) | Aditivo | `SDD2_FASE3B_UBISAFE.md §3.B'.3` |
| `risk_zones` (CU-03) | **Sin cambios** | Coexistencia documentada en ADR #11 |
| `stop_requests` (CU-01) | **Sin cambios** | Reutilizada solo para verificar disponibilidad del vendedor en CU-04 |
| RTDB `/vendedores_activos` (CU-02) | **Sin cambios** | El tracking de raite reutiliza el stream existente |
| `reputation_events` | **NO se crea en iter. 2** | Diferida a iter. 3 (decisión Fase 0' 0'.5, ADR #6) |

---

## §12.5 — Matriz 5: CU → Eventos FCM {#matriz-5}

> **Propósito:** Documentar el catálogo completo de eventos push tras iter. 2 (8 tipos = 4 iter. 1 + 4 iter. 2 base + 3 adicionales detectados en Fase 4.B' = **11 eventos**) y vincularlos a su CU origen y su acción en el cliente.

| Evento FCM (`data.type`) | CU origen | Iteración | Origen (FastAPI / Función) | Destinatario | Acción en cliente |
|---|---|---|---|---|---|
| `stop_request_incoming` | CU-01 | iter. 1 | `StopRequestRouter` | Vendedor | Dialog de solicitud entrante en `MapScreenVendor` |
| `stop_request_accepted` | CU-01 | iter. 1 | `StopRequestRouter` | Comprador | Navega a `TrackingScreen` |
| `stop_request_rejected` | CU-01 | iter. 1 | `StopRequestRouter` | Comprador | SnackBar + vuelve al mapa |
| `risk_zone_alert` | CU-03 | iter. 1 | `RiskZoneRouter` | Usuarios cercanos (fan-out) | Alerta visual en HomeScreen |
| `ride_request_incoming` **[iter. 2]** | CU-04 | **iter. 2** | `RideRouter` | Vendedor | Dialog "Solicitud de Raite Entrante" (W-14b) en `MapScreenVendor` |
| `ride_request_accepted` **[iter. 2]** | CU-04 | **iter. 2** | `RideRouter` | Comprador | Navega a `TrackingScreen` con rol `rider` |
| `ride_request_rejected` **[iter. 2]** | CU-04 | **iter. 2** | `RideRouter` | Comprador | SnackBar de rechazo + vuelve al mapa |
| `ride_cancelled_by_buyer` **[iter. 2]** | CU-04 (E2) | **iter. 2** | `RideRouter` (PATCH al cancelar) | Vendedor | Notificación "Raite cancelado" + vuelve a estado disponible |
| `community_report_nearby` **[iter. 2]** | CU-05 | **iter. 2** | `CommunityReportRouter` | Usuarios cercanos a 4 km (fan-out) | Alerta informativa de nuevo foco; no fuerza navegación |
| `community_report_confirmed` **[iter. 2]** | CU-06 (Cond. 8A) | **iter. 2** | `ReportValidationRouter` | Usuarios cercanos | Actualiza marcador en mapa a estado "Validado" |
| `community_report_dismissed` **[iter. 2]** | CU-06 (Cond. 8B) | **iter. 2** | `ReportValidationRouter` | Usuarios cercanos *(opcional)* | Atenúa marcador en mapa hasta expiración |

> **Nota — eventos detectados en Fase 4.B' V2.0:** Los métodos `notify_community_report_updated`, `notify_community_report_confirmed` y `notify_community_report_dismissed` no estaban en el diseño original de Fase 2'. Su descubrimiento durante el modelado de secuencias CU-06 obliga a actualizar la sección §5.3.5.4 (`ReportValidationRouter`) y §5.3.6.4 (`NotificationService`) en el .docx final con las llamadas FCM correspondientes. Esta es una corrección que se incorpora retrospectivamente al SDD v2.0.

---

## §12.6 — Verificación cruzada con BB_SDD_V1.0 y BB_SRS_V2.1 {#verificacion-cruzada}

> **Propósito:** Pasar un control de consistencia explícito entre el SDD v1.0 (baseline iter. 1, archivo `BB_SDD_V1.0.md`) y los outputs de iter. 2, así como entre estos y el SRS v2.1 (CU-04, CU-05, CU-06).

### 12.6.1 — Consistencia con BB_SDD_V1.0.md (baseline iter. 1)

| Aspecto verificado | Estado |
|---|---|
| **Estructura IEEE 1016 conservada:** §1 Intro, §2 Stakeholders, §3 ADRs, §4 C4 L1, §5 C4 L2, §5.3 C4 L3, §6 BD, §8 UI, §9 Secuencias (renombrado de §7 a §9), §10 Navegación, §11 Estructura, §12 Trazabilidad, §13 Historial | ✅ Conservada — Las nuevas secciones se insertan con marcador `[iter. 2]`, sin reemplazar las originales. |
| **Componentes iter. 1 sin cambios estructurales:** `StopRequestRouter`, `RiskZoneRouter`, `GPSService`, `VendorTracker`, `AuthMiddleware`, `AuthRouter` (este último solo añade `PATCH /auth/ride-enabled`) | ✅ Confirmado — `RiskZoneRouter` y `StopRequestRouter` no se modifican (ADR #11 asegura coexistencia sin breaking changes). |
| **Colecciones iter. 1 sin cambios:** `stop_requests`, `risk_zones` mantienen su esquema original | ✅ Confirmado |
| **Colección `users` solo se extiende:** se añade `ride_enabled: boolean \| null`, no se renombra ni elimina ningún campo | ✅ Confirmado en `SDD2_FASE3A_UBISAFE.md §3.A'.2` |
| **Eventos FCM iter. 1 conservados:** `stop_request_incoming`, `stop_request_accepted`, `stop_request_rejected`, `risk_zone_alert` | ✅ Confirmado en `SDD2_FASE1_UBISAFE.md §4.2.7` |
| **Convención de nombres canónicos del Apéndice del RESUMEN:** los nombres `MapScreenBuyer`, `MapScreenVendor`, `StopRequestModule`, etc. se usan idénticos en todos los outputs iter. 2 | ✅ Verificado en Fases 2', 4.A', 4.B', 5B' |
| **ADRs iter. 1 (#1, #2, #3, #4) conservados literalmente** + redactados los retroactivos pendientes | ✅ Fase 6' (`SDD2_FASE6_UBISAFE.md`) consolida los 11 ADRs sin alterar los originales |
| **Routing por rol (BUYER/VENDOR):** sin cambios; `ride_enabled` no afecta el routing inicial, solo desbloquea acciones en HomeC | ✅ Confirmado |

### 12.6.2 — Consistencia con BB_SRS_V2.1.md (CU-04, CU-05, CU-06)

| CU | Aspecto del SRS | Verificación en outputs iter. 2 | Estado |
|---|---|---|---|
| **CU-04** | Pre-condición: vendedor `ride_enabled` activo | Modelado en `users.ride_enabled: boolean \| null`; verificado por `RideRouter` antes de crear `rides`; toggle expuesto en Drawer | ✅ |
| **CU-04** | Pre-condición: vendedor disponible (sin parada/raite activo) | `FirestoreService.get_active_rides_for_vendor()` consulta `stop_requests` y `rides` activos | ✅ |
| **CU-04** | Pre-condición: vendedor a ≤ 4 km del comprador | Cálculo Haversine en FastAPI; mismo umbral que CU-01 | ✅ |
| **CU-04** | Pre-condición: comprador no en zona bloqueada | Validación previa en `RiskZoneRouter` reutilizada | ✅ |
| **CU-04** | Pre-condición: vendedor con `ride_enabled` | Modelado en Fase 3.A' | ✅ |
| **CU-04** | CA-04.1 (5 s) | FCM directo en flujo síncrono — diagrama 9.5.A | ✅ |
| **CU-04** | CA-04.2 (rutas evitan riesgo) | Decisión Fase 0' M-P5: HIGH+MEDIUM | ✅ |
| **CU-04** | CA-04.3 (timeout 60 s — corregido del SRS que decía 15 s) | Decisión Fase 0' A-P1 documentada explícitamente; campo `expires_at = created_at + 60s` | ✅ con nota |
| **CU-04** | CA-04.4 (degradación GPS) | Diagrama 9.5.C E1 + fallback estático en `RideRequestModule` | ✅ |
| **CU-04** | Cond. 3A, 4A, 6A | Diagramas 9.5.B con sub-flujos para cada condición | ✅ |
| **CU-04** | Excepciones E1 (conexión), E2 (cancelación) | Diagramas 9.5.C E1 y E2 + E3 (timeout) añadido para cubrir CA-04.3 | ✅ |
| **CU-05** | Actores: Comprador y Vendedor (ambos roles) | Reglas Firestore permiten escritura a cualquier autenticado; sin diferenciación de rol en el endpoint | ✅ |
| **CU-05** | Tipos de foco (`animal_muerto`, `zona_sucia`) | Enum validado en `CommunityReportRouter` | ✅ |
| **CU-05** | Pre-cond: usuario a ≤ 4 km | Validación Haversine en FastAPI | ✅ |
| **CU-05** | Estado inicial `pending_validation` | Establecido por `CommunityReportRouter` al crear | ✅ |
| **CU-05** | Cond. 7A (alta densidad → agrupar) | Cloud Function `aggregateDuplicateReports` (ADR #10); radio 100 m (Fase 0' M-P2) | ✅ |
| **CU-05** | CA-05.1 (10 s) | Endpoint síncrono ≤ 200 ms; agrupación asíncrona post-creación | ✅ |
| **CU-05** | CA-05.2, 5.3, 5.4 | Diagramas 9.6.B, 9.6.C, 9.6.D | ✅ |
| **CU-05** | Excepciones E1 (conexión) y E2 (GPS) | Diagramas 9.6.D y 9.6.E | ✅ |
| **CU-05** | NO incluye adjuntar evidencias (fotos/audio) | Confirmado: ADR #5 diferido; sin campo `evidence_urls[]` en el modelo | ✅ |
| **CU-06** | Actores: Comprador y Vendedor | Reglas Firestore + `ReportValidationRouter` aceptan ambos roles | ✅ |
| **CU-06** | Pre-cond: reporte aún no verificado | `ReportValidationRouter` verifica `status == pending_validation` | ✅ |
| **CU-06** | Pre-cond: usuario a ≤ 4 km del reporte | Body del PATCH incluye coordenadas validador; FastAPI valida Haversine | ✅ |
| **CU-06** | Cond. 4A (ya validó) | Búsqueda en array `validations[]` antes de añadir; `409 Conflict` | ✅ |
| **CU-06** | Cond. 8A / 8B (umbral 3 confirmaciones / rechazos) | Contadores `confirm_count`/`dismiss_count` desnormalizados; transición automática | ✅ |
| **CU-06** | CA-06.1 (10 s) | Operación atómica Firestore | ✅ |
| **CU-06** | CA-06.2 (umbral 3 → confirmed) | Regla de transición en `ReportValidationRouter` | ✅ |
| **CU-06** | CA-06.3 (umbral 3 → dismissed) | Regla de transición en `ReportValidationRouter` | ✅ |
| **CU-06** | Excepciones E1 (conexión) y E2 (reporte ya no disponible) | Diagramas 9.7.E y 9.7.F | ✅ |

### 12.6.3 — Discrepancias detectadas y resoluciones

| Discrepancia entre SRS v2.1 y diseño | Resolución | Documento que lo registra |
|---|---|---|
| SRS CA-04.3 indica timeout de 15 s, pero CU-01 usa 60 s | **Resuelto: 60 s en ambos.** El equipo confirmó que el valor 15 s es un error del SRS; uniformidad con CU-01. | `SDD2_FASE0_UBISAFE.md §A-P1` |
| SRS no especifica ubicación UI del toggle `ride_enabled` (Perfil vs HomeV vs Drawer) | **Resuelto: Drawer.** Decisión documentada antes de Fase 5B.alt'. | `SDD2_FASE0_UBISAFE.md §A-P2` |
| SRS no especifica si `community_reports` bloquean rutas como `risk_zones` | **Resuelto: NO bloquean.** Solo informativos (ADR #11 columna comparativa). | `SDD2_FASE0_UBISAFE.md §A-P4` |
| SRS habla de "tramo/polígono" en CU-05 pero el flujo es punto único | **Resuelto: círculos con radio fijo 15 m** (consistente con `risk_zones`). | `SDD2_FASE0_UBISAFE.md §0'.6` + ADR #7 |
| SRS no especifica si `reputation_events` se crea en iter. 2 | **Resuelto: NO se crea.** Pospuesto a iter. 3. | `SDD2_FASE0_UBISAFE.md §0'.5` + ADR #6 |
| SRS no menciona Cloud Functions ni Firebase Storage | **Cloud Functions sí entra (CA-05.3 lo justifica indirectamente); Storage NO entra.** | ADR #10 (aprobado), ADR #5 (diferido) |
| SRS menciona "agrupar reportes en una sola alerta" sin detallar criterio | **Resuelto: mismo `threat_type` + Haversine ≤ 100 m.** | `SDD2_FASE0_UBISAFE.md §M-P2` |
| SRS no especifica visibilidad de reportes en `pending_validation` en mapa | **Resuelto: visibles desde el inicio con leyenda "Pendiente"; cambian a "Validado" al confirmar.** | `SDD2_FASE0_UBISAFE.md §M-P3` |

> **Conclusión de §12.6:** No hay discrepancias sin resolver entre el SDD v2.0 y el SRS v2.1. Las 8 discrepancias detectadas durante Fase 0' fueron decididas explícitamente y registradas como ADRs o decisiones de equipo. ✅

---

## §13 — Historial de Versiones (entrada V3.0) {#historial-v30}

> **Instrucción para Alexis al integrar al .docx:** Reemplazar la tabla vacía de §13 (líneas 1460-1462 del `BB_SDD_V1.0.md`) por la siguiente tabla, manteniendo la fila V1.0 / V2.0 si ya están registradas; añadir la fila V3.0 al final.

### Tabla §13 — Historial de Versiones

| Versión | Fecha | Autor(es) | Descripción de cambios |
|---|---|---|---|
| **V1.0** | 17/04/2026 | Los Borbotones (Alexis Córdova, Miguel Rivera, Leo Fernández) | Versión inicial del SDD para Iteración 1. Incluye §1 Introducción, §2 Stakeholders + Dominios, §3 ADRs (4 originales + 3 retroactivos pendientes), §4 C4 L1, §5 C4 L2, §5.3 C4 L3 por dominio, §6 Base de datos (Firestore + RTDB con `users`, `stop_requests`, `risk_zones`), §7–§9 Diagramas de Secuencia (CU-01, CU-02, CU-03, Auth), §8 Diseño UI + Design System, §10 Navegación, §11 Estructura de proyecto. Cubre los 3 CU originales del SRS v1.0. |
| **V2.0** | 23/04/2026 | Alexis Córdova (con asistencia de Claude) | Versión consolidada de Iteración 1 tras resolución de inconsistencias y cierre de fases pendientes (Fase 5 completa con mockups Figma; ADR #4 Riverpod añadido). Sin cambios en alcance funcional. |
| **V3.0 [iter. 2]** | 25/04/2026 | Alexis Córdova + Miguel Rivera (con asistencia de Claude — ejecución paralela en dos máquinas) | **Iteración 2 completa.** Extiende el SDD v2.0 con CU-04 (Solicitar raite), CU-05 (Reportar focos de infección) y CU-06 (Verificar reportes comunitarios). **Cambios principales:** (1) §1.2 Alcance extendido con sub-sección "Iteración 2 — Escudo Comunitario"; (2) §2.5 Mapping CU↔dominio actualizado (Community activado, Dispatching extendido); (3) §3 ADRs: +ADR #5 diferido, +ADR #6 (Votación simple), +ADR #7 (Geometría círculos), +ADR #10 (Cloud Functions), +ADR #11 (Coexistencia colecciones), +Retro-A (Firebase Auth), +Retro-B (Google Maps), +Retro-C (FCM), +sección Deuda Técnica DT-01 a DT-04; (4) §4 C4 L2: +contenedor Cloud Functions; (5) §5 C4 L3: +`RideRequestModule`, `DestinationPicker`, `CommunityReportModule`, `ReportValidationModule` (Flutter); +`RideRouter`, `CommunityReportRouter`, `ReportValidationRouter` (FastAPI); +`aggregateDuplicateReports` (Cloud Function); extensiones a `DrawerModule`, `MapScreenBuyer`, `MapScreenVendor`, `NotificationHandler`, `FirestoreService`, `NotificationService`, `AuthRouter`; (6) §7 BD: +colección `rides` (15 campos), +colección `community_reports` (14 campos con `validations[]`, `confirm_count`, `dismiss_count`, `is_duplicate`, `canonical_report_id`), +campo `users.ride_enabled`, +reglas Firestore para ambas colecciones; §7.4.3 actualizado: `community_reports` movida a "diseñada en iter. 2", `reputation_events` diferida; (7) §8 Design System extendido (tokens negro/café para focos, chips de estado `ReportStatusChip`, `VotingIndicator`, FAB expandible, `DestinationPicker`); +4 wireframes nuevos + 7 extensiones de wireframes existentes + 1 dialog (W-14b) = 12 wireframes nuevos/modificados; +9 prompts Claude Design para mockups alta fidelidad (CD2-01 a CD2-09); (8) §9 Secuencias: +§9.5 (CU-04: 9.5.A, 9.5.B, 9.5.C — 3 diagramas), +§9.6 (CU-05: 9.6.A, 9.6.B, 9.6.C, 9.6.D, 9.6.E — 5 diagramas), +§9.7 (CU-06: 9.7.A, 9.7.B, 9.7.C, 9.7.D, 9.7.E, 9.7.F — 6 diagramas) = **14 diagramas de secuencia nuevos**; (9) §10 Navegación extendida con rutas `/ride/request`, `/community-reports`, `/community-reports/:id`; (10) §11 Estructura: +`lib/features/community/`, +`modules/community/`, +carpeta raíz `functions/` (Cloud Functions); (11) §12 Trazabilidad: 5 matrices nuevas (CU↔Componentes, RF↔Componentes, RNF↔ADRs, CU↔Colecciones, CU↔Eventos FCM) consolidando iter. 1 + iter. 2; (12) §13 Historial actualizado con esta entrada V3.0. **8 decisiones de equipo registradas** que resuelven discrepancias del SRS v2.1 (timeout 60 s, ubicación toggle, geometría círculos, umbral 3, expiración 24 h, radio agrupación 100 m, visibilidad pending_validation, colores negro/café). **Total tras iter. 2:** 14 componentes Flutter + 10 componentes FastAPI + 1 Cloud Function + 11 ADRs + 5 colecciones (3 Firestore iter.1 + 2 nuevas iter.2) + 1 nodo RTDB + 11 eventos FCM + ~22 diagramas de secuencia + 32 pantallas/wireframes. |

---

## §13.1 — Marcadores visuales `[iter. 2]` aplicables al .docx {#marcadores-docx}

> **Checklist para Alexis durante la integración al .docx final.** Cada elemento añadido en iter. 2 debe llevar al menos una marca visual. Esta sub-sección NO se incluye en el .docx — es una guía de integración.

### A. Encabezados de sección que reciben anotación `[iter. 2]`

- [x] §1.2 Alcance — sub-sección "**Iteración 2 — Escudo Comunitario [iter. 2]**" añadida
- [x] §2.3.2 Mapping CU ↔ Dominio — fila CU-04, CU-05, CU-06 marcadas
- [x] §3 ADRs — encabezados ADR #5, #6, #7, #10, #11 con sufijo `[iter. 2]`
- [x] §3.x Deuda Técnica — sección nueva `[iter. 2]`
- [x] §4.2.5 Cloud Functions — encabezado `[iter. 2 — contenedor nuevo]`
- [x] §5.3.3.5 RideRequestModule — `[iter. 2]`
- [x] §5.3.3.6 RideRouter — `[iter. 2]`
- [x] §5.3.5 Dominio Community — `[iter. 2 — activado]`
- [x] §5.3.5.1 CommunityReportModule — `[iter. 2]`
- [x] §5.3.5.2 ReportValidationModule — `[iter. 2]`
- [x] §5.3.5.3 CommunityReportRouter — `[iter. 2]`
- [x] §5.3.5.4 ReportValidationRouter — `[iter. 2]`
- [x] §5.4 Cloud Functions C4 L3 — sección nueva `[iter. 2]`
- [x] §6.2.4 Colección `rides` — `[iter. 2]`
- [x] §6.2.5 Colección `community_reports` — `[iter. 2]`
- [x] §6.4.3 Tabla "Colecciones previstas" — fila `community_reports` actualizada a "diseñada iter. 2"; `reputation_events` actualizada a "diferida"
- [x] §6.5 Cloud Functions (esquema) — sección nueva `[iter. 2]`
- [x] §7.5 Diagramas de secuencia §9.5, §9.6, §9.7 — `[iter. 2]`
- [x] §8.1 Design System extendido — sub-sección `[iter. 2 — Extensiones]`
- [x] §8.8–§8.11 Wireframes nuevos (W-CU04-01, W-CU05-01, W-CU06-01, W-CU06-02) + W-14b — `[iter. 2]`
- [x] §8.12 Wireframes extendidos — `[iter. 2]`
- [x] §8.19 Prompts Claude Design — `[iter. 2]`
- [x] §10 Navegación — nodos nuevos en grafo Mermaid

### B. Filas / columnas dentro de tablas existentes

- [x] Tabla §2.3.1 Dominios: dominio Community pasa de "vacío iter. 1" a "activado iter. 2"
- [x] Tabla §3 ADRs: filas Retro-A, Retro-B, Retro-C, ADR #5, #6, #7, #10, #11 con columna *Iteración* = `iter. 2` (o `Retroactivo`)
- [x] Tabla §4.2 Contenedores: fila Cloud Functions con marca `[iter. 2]`
- [x] Tabla §5.3 Componentes Flutter: 4 filas nuevas + columna *Iteración*
- [x] Tabla §5.3 Componentes FastAPI: 3 filas nuevas + columna *Iteración*
- [x] Tabla §6.2.1 `users`: campo `ride_enabled` con etiqueta `[iter. 2]`
- [x] Tabla §9.2 Pantallas: 5 filas nuevas (W-CU04-01, W-CU05-01, W-CU06-01, W-CU06-02, W-14b) + 7 extensiones marcadas

### C. Eventos FCM (Tabla en §4.2.7)

- [x] 4 eventos nuevos del catálogo iter. 2 base + 3 detectados en Fase 4.B' V2.0 → marca `[iter. 2]` en la columna *Iteración*

### D. Matrices §12 (esta fase)

- [x] Matriz 1 — columna *Iteración* aplicada
- [x] Matriz 2 — sub-secciones explícitas A (CU-04), B (CU-05), C (CU-06) — todas `[iter. 2]`
- [x] Matriz 3 — columna *Iteración* en cada fila de RNF
- [x] Matriz 4 — columna *Iteración* en CU
- [x] Matriz 5 — columna *Iteración* en eventos FCM

---

## Resumen de cobertura — Fase 7' {#resumen-cobertura}

| Paso del Plan | Output generado | Sección del SDD que actualiza | Estado |
|---|---|---|---|
| **7'.1** | Matriz 1 (CU → Componentes → Endpoints → Secuencias → Pantallas) consolidada con CU-04, CU-05, CU-06 | §12.1 | ✅ |
| **7'.1** | Matriz 2 (RF / CA → Componentes / Mecanismos) — 30+ filas para CU-04/05/06 | §12.2 | ✅ |
| **7'.1** | Matriz 4 (CU → Colecciones de BD) actualizada | §12.4 | ✅ |
| **7'.1** | Matriz 5 (CU → Eventos FCM) — 11 eventos catalogados | §12.5 | ✅ |
| **7'.2** | Matriz 3 (RNF → ADRs) ampliada con aspectos reforzados en iter. 2 | §12.3 | ✅ |
| **7'.3** | Entrada V3.0 del Historial completa | §13 | ✅ |
| **7'.4** | Checklist de marcadores visuales `[iter. 2]` para integración al .docx | §13.1 (guía) | ✅ |
| **Adicional** | Verificación cruzada con BB_SDD_V1.0.md y BB_SRS_V2.1.md | §12.6 | ✅ |
| **Adicional** | Documentación de las 8 discrepancias del SRS v2.1 resueltas en Fase 0' | §12.6.3 | ✅ |

**Trazabilidad alcanzada:**
- ✅ Cada uno de los **3 CU nuevos** se rastrea desde el SRS v2.1 hasta el mockup CD2-XX correspondiente.
- ✅ Cada uno de los **30+ Criterios de Aceptación** de iter. 2 tiene componente + mecanismo concreto que lo cubre.
- ✅ Cada uno de los **5 RNF del SRS** tiene al menos un ADR que lo sustenta (algunos reforzados específicamente en iter. 2).
- ✅ Cada **colección nueva** de Firestore (`rides`, `community_reports`) y cada **extensión** (`users.ride_enabled`) está vinculada a su CU.
- ✅ Los **11 eventos FCM** (4 iter. 1 + 7 iter. 2) están catalogados con CU origen, destinatario y acción en cliente.
- ✅ Las **8 discrepancias** detectadas entre SRS v2.1 y necesidades de diseño fueron decididas y documentadas.

---

## Handoff a Fase 8' (Verificación Final)

**Para Alexis y Miguel en la sesión pair de Fase 8':**

1. **Antes de la pair:** Tener este archivo + `SDD2_FASE6_UBISAFE.md` + el .docx en su versión integrada parcialmente.
2. **Durante la pair:** Aplicar los 6 checks de §3.1 / §8 del Plan Maestro (IEEE 1016, profesor 6 criterios, equipo, consistencia de nombres, trazabilidad completa, opcional `srs-review`).
3. **Resultado esperado:** Checklist de Fase 8' firmada por ambos. Con eso el SDD v3.0 [iter. 2] queda listo para entrega académica.

**Salida que produce esta fase para Fase 8':**
- Las 5 matrices completas (§12.1 a §12.5) — *insumo directo del check de "trazabilidad completa"*.
- §12.6 verificación cruzada — *insumo del check de "consistencia de nombres" y de la opción `srs-review`*.
- §13 Historial V3.0 — *insumo del check de "contenidos de la iteración"*.
- §13.1 Checklist de marcadores `[iter. 2]` — *insumo de la integración final al .docx*.

---

## Historial del archivo

| Versión | Fecha | Autor(es) | Descripción |
|---|---|---|---|
| **V1.0** | 25/04/2026 | Alexis Córdova + Miguel Rivera (con asistencia de Claude — pair final) | Fase 7' completa: Matriz 1 (CU↔Componentes↔Endpoints↔Secuencias↔UI) + Matriz 2 (RF/CA↔Componentes — 3 sub-matrices CU-04/05/06) + Matriz 3 (RNF↔ADRs) + Matriz 4 (CU↔BD) + Matriz 5 (CU↔Eventos FCM) + Verificación cruzada con BB_SDD_V1.0 y BB_SRS_V2.1 + Resolución de 8 discrepancias del SRS + Historial V3.0 + Checklist de marcadores visuales `[iter. 2]` para integración al .docx final. |

---

*Fase 7' completada. Output: `SDD2_FASE7_UBISAFE.md`. Este archivo es prerequisito para la Fase 8' (verificación final) y para la integración del SDD v3.0 [iter. 2] al .docx.*
*Generado: 25/04/2026 — Los Borbotones / UBISAFE Iteración 2*
