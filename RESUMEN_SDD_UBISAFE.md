# RESUMEN CONSOLIDADO — SDD UBISAFE
## Documento de contexto para sesiones de trabajo progresivas
### Los Borbotones · Iteración 1 · Actualizado: 18/04/2026

> **Propósito de este documento:** Servir de briefing para cualquier sesión de Claude que retome el trabajo del SDD. Al iniciar una nueva sesión, pasar este archivo junto con el `PLAN_SDD_UBISAFE.md` y preguntar en qué fase/paso se retoma. Con ambos documentos, Claude puede continuar sin releer todos los archivos de fases anteriores.
>
> **Fuente:** Consolidado a partir de `SDD_FASE0_UBISAFE.md`, `SDD_FASE0_PASOS05_06_UBISAFE.md`, `SDD_FASE1_UBISAFE.md`, `SDD_FASE2_UBISAFE.md`, `SDD_FASE2_PASO25_UBISAFE.md`, `SDD_FASE3_UBISAFE.md`.

---

## ÍNDICE

1. [Contexto del proyecto](#1-contexto-del-proyecto)
2. [Estado del plan SDD](#2-estado-del-plan-sdd)
3. [El sistema UBISAFE — casos de uso y actores](#3-el-sistema-ubisafe)
4. [Stack técnico confirmado](#4-stack-técnico-confirmado)
5. [Arquitectura — C4 niveles 1 y 2](#5-arquitectura-c4-niveles-1-y-2)
6. [Organización por dominios (bounded contexts)](#6-organización-por-dominios)
7. [Componentes internos — C4 Nivel 3](#7-componentes-internos-c4-nivel-3)
8. [Base de datos — Firestore + RTDB](#8-base-de-datos)
9. [Decisiones Arquitectónicas (ADRs)](#9-decisiones-arquitectónicas)
10. [Design System](#10-design-system)
11. [Gestión de estado — Riverpod](#11-gestión-de-estado-riverpod)
12. [Estructura de carpetas del proyecto](#12-estructura-de-carpetas)
13. [Lo que necesitas saber por fase](#13-contexto-por-fase-restante)

---

## 1. CONTEXTO DEL PROYECTO

| Campo | Valor                                                                                                               |
|---|---|
| **Sistema** | UBISAFE — app móvil comunitaria para zonas semiurbanas                                                              |
| **Equipo** | Los Borbotones (3 personas): Alexis Córdova (PM/líder), Miguel Rivera (líder técnico), Leonardo Fernández (calidad) |
| **Marco** | TSP (Team Software Process) — proyecto académico                                                                    |
| **Entregable** | SDD de Iteración 1, estándar IEEE 1016-2009, adaptado al modelo C4                                                  |
| **Documento SRS de referencia** | `BB_SRS_V1.6` (11/04/2026)                                                                                          |
| **Iteración actual** | Iteración 1 (CU-01, CU-02, CU-03)                                                                                   |
| **Output de cada fase** | Markdown + diagramas Mermaid → Alexis integra manualmente al .docx final                                            |

**Nota crítica sobre el equipo:** Ningún integrante tiene experiencia previa con gestión de estado en Flutter (Riverpod/Provider/Bloc). Esta restricción informó la decisión del ADR #4. Preferir siempre soluciones simples y con documentación abundante.

---

## 2. ESTADO DEL PLAN SDD

| Fase | Descripción | Estado | Archivo de output |
|---|---|---|---|
| **Fase 0** (0.1–0.4) | Stakeholders, stack, design system, introducción | ✅ Completa | `SDD_FASE0_UBISAFE.md` |
| **Fase 0.5–0.6** [V2] | Bounded contexts + ADR #4 (Riverpod) | ✅ Completa | `SDD_FASE0_PASOS05_06_UBISAFE.md` |
| **Fase 1** | C4 Nivel 1 (contexto) + C4 Nivel 2 (contenedores) + ADR #1, #2 | ✅ Completa | `SDD_FASE1_UBISAFE.md` |
| **Fase 2** (2.1–2.4) | C4 Nivel 3 (componentes Flutter y FastAPI) + estructura del proyecto | ✅ Completa | `SDD_FASE2_UBISAFE.md` |
| **Fase 2.5** [V2] | Reorganización §5.3 y §11 por dominios (domain-first) | ✅ Completa | `SDD_FASE2_PASO25_UBISAFE.md` |
| **Fase 3** (3.1–3.7) | Diseño de base de datos (Firestore + RTDB + ADR #3) | ✅ Completa | `SDD_FASE3_UBISAFE.md` |
| **Fase 4** | Diagramas de secuencia (CU-01, CU-02, CU-03, Auth) | ⬜ Pendiente | — |
| **Fase 5A** | Design system ya documentado en Fase 0 (usar ese output) | ⬜ Pendiente (integrar) | — |
| **Fase 5B** | Wireframes de baja fidelidad (todas las pantallas) | ⬜ Pendiente | — |
| **Fase 5C** | Mockups de alta fidelidad (Figma + revisión accesibilidad) | ⬜ Pendiente | — |
| **Fase 5D** | Diagrama de navegación completo | ⬜ Pendiente | — |
| **Fase 6** | ADRs consolidados (#1–#4 + retroactivos A, B, C) | ⬜ Pendiente | — |
| **Fase 7** | Trazabilidad SRS → componentes + historial de versiones | ⬜ Pendiente | — |
| **Fase 8** | Verificación final contra IEEE 1016, checklist profesor, checklist equipo | ⬜ Pendiente | — |

**ADRs pendientes de escribir en Fase 6:**
- ADR retroactivo A: Firebase Auth como Identity Provider (vs Auth0/Clerk/backend propio)
- ADR retroactivo B: Google Maps como cartografía (con nota de riesgo de costo post-TSP)
- ADR retroactivo C: FCM como único canal de push (implica Android-only en iter. 1)
- Deuda técnica declarada: cálculo Haversine client-side para filtrar vendedores en 4 km (revisar iter. 3)

---

## 3. EL SISTEMA UBISAFE

### 3.1. ¿Qué hace?

UBISAFE conecta **compradores** (habitantes de zonas semiurbanas) con **vendedores** ambulantes en zonas semiurbanas. Permite:
- Ver en un mapa qué vendedores están activos y cercanos (radio 4 km)
- Solicitar que un vendedor se detenga en tu domicilio
- Reportar zonas de riesgo georreferenciadas (jaurías, accidentes, robos) que aparecen en el mapa y modifican las rutas del vendedor

### 3.2. Actores

| Actor                                        | Rol en el sistema |
| -------------------------------------------- | ------------------------------------------------------------------------------ |
| **Comprador (Habitante de zona semiurbana)** | Consulta mapa, solicita paradas (CU-01), reporta riesgos (CU-03) |
| **Vendedor (Comerciante ambulante)**         | Activa radar GPS (CU-02), atiende solicitudes (CU-01), reporta riesgos (CU-03) |

### 3.3. Casos de uso — Iteración 1

| CU | Nombre | Actores | Descripción resumida |
|---|---|---|---|
| **CU-01** | Solicitar parada a puerta | Comprador + Vendedor | Comprador selecciona vendedor en mapa → envía solicitud → Vendedor acepta/rechaza → si acepta, navega al domicilio → Comprador ve seguimiento en tiempo real |
| **CU-02** | Activar radar de visibilidad | Vendedor | Vendedor activa toggle → popup de confirmación → GPS se transmite a RTDB → aparece en mapa de compradores |
| **CU-03** | Bloquear zona por riesgo activo | Comprador o Vendedor | Cualquier usuario toca FAB "+" → llena formulario (tipo amenaza, nivel, coords) → se registra en Firestore → aparece en mapas de todos los usuarios → restringe rutas del vendedor |
| **Auth** | Registro y Login | Cualquiera | Registro: nombre + teléfono + rol → Login: credenciales → Firebase Auth JWT → redirige al Home según rol |

### 3.4. Flujo de navegación (diagrama del knowledge source del proyecto)

```
Apertura App → Splash Screen → ¿Sesión activa?
  ├─ No → Pantalla de Bienvenida
  │         ├─ Tiene cuenta → Login → Credenciales → ¿Válidas? → [sí/no]
  │         └─ No tiene cuenta → SignUp → Nombre+Teléfono → Rol (Comprador/Vendedor) → Login
  └─ Sí → Verificar Rol
             ├─ BUYER → HomeC (Mapa Comprador — Radar de Seguridad)
             │   ├─ GPS Encendido → Mapa: Ver Vendedores en 4km
             │   │   └─ Seleccionar Vendedor → [Vendedor Acepta → Tracking] / [Rechaza → Mapa]
             │   ├─ GPS Apagado → Aviso GPS
             │   └─ Botón "+" → CU-03 Reportar Riesgo
             └─ VENDOR → HomeV (Mapa Vendedor — Navegación y Riesgos)
                 ├─ Botón Activar Visibilidad → Popup → [Sí → Visibilidad ON → Escucha Pedidos]
                 │   └─ Solicitud Entrante → [Aceptar → Navegación Segura → Confirmar Entrega] / [Rechazar]
                 └─ Botón "+" → CU-03 Reportar Riesgo

Menú Lateral (desde cualquier Home):
  ├─ Mi Perfil
  ├─ Historial de Actividad
  └─ Cerrar Sesión → Pantalla de Bienvenida
```

**Pantallas identificadas** (para wireframes Fase 5B):
1. Splash Screen
2. Pantalla de Bienvenida
3. Login
4. SignUp — Datos (nombre, teléfono)
5. SignUp — Selección de Rol
6. Home Comprador (mapa con radar)
7. Home Vendedor (mapa con navegación)
8. Pantalla de Seguimiento en Tiempo Real (post-aceptación CU-01)
9. Dialog: Solicitud de Parada Entrante (en Home Vendedor)
10. Dialog: Confirmación "¿Deseas iniciar transmisión?" (CU-02)
11. Feedback: "Ahora eres Visible" (CU-02)
12. Risk Report Form (bottom sheet — CU-03)
13. Empty State: "Enciende el GPS para ver vendedores"
14. Mi Perfil
15. Historial de Actividad
16. Drawer (menú lateral)

---

## 4. STACK TÉCNICO CONFIRMADO

| Capa | Tecnología | Versión | Notas clave |
|---|---|---|---|
| **App móvil** | Flutter / Dart | 3.x / 3.x | Android (API 29+) en iter. 1; iOS futuro |
| **Backend API** | FastAPI / Python | 0.110+ / 3.11+ | Monolito (ver ADR #1); desplegado en Firebase Hosting |
| **Autenticación** | Firebase Auth | SDK v5.x | JWT de 1 hora; refresco automático |
| **BD principal** | Cloud Firestore | SDK v4.x | datos persistentes estructurados |
| **BD tiempo real** | Firebase RTDB | SDK v10.x | GPS del vendedor únicamente |
| **Notificaciones push** | Firebase Cloud Messaging (FCM) | SDK v9.x | Android-only en iter. 1 |
| **Mapas y rutas** | Google Maps SDK + Directions API | Maps SDK 2.x | Riesgo: costo a escala; revisar post-TSP |
| **State management** | Riverpod 2.x | ^2.5.1 | Fallback: Provider si curva de aprendizaje es riesgo |
| **Cliente HTTP** | dio | ^5.x | Interceptor de JWT automático |
| **Navegación** | go_router | ^12.x | Navegación declarativa |
| **GPS device** | geolocator | ^10.x | Umbral: 3s ó ≥10m desplazamiento |

**Regla de comunicación crítica:**
- App → FastAPI: HTTPS/REST + JWT (para lógica de negocio: CU-01 solicitudes, CU-03 reportes, auth sync)
- App → RTDB: **directo** (sin pasar por FastAPI) para GPS en tiempo real (ver ADR #2)
- FastAPI → Firestore: Admin SDK / gRPC
- FastAPI → FCM: Admin SDK / HTTPS

---

## 5. ARQUITECTURA — C4 NIVELES 1 Y 2

### 5.1. C4 Nivel 1 — Contexto (sección 3 del SDD)

```
[Comprador] ──────────────────┐
                               ▼
                         [UBISAFE App]
                               │
[Vendedor] ───────────────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
        [Firebase          [Google Maps     (sistemas
         Platform]          Platform]        externos)
        Auth+Firestore
        RTDB+FCM
```

### 5.2. C4 Nivel 2 — Contenedores (sección 4 del SDD)

| Contenedor | Tecnología | Responsabilidad |
|---|---|---|
| **App Móvil Flutter** | Flutter/Dart | UI, mapa, GPS, FCM, lógica de presentación |
| **API REST FastAPI** | Python/FastAPI | Lógica de negocio, validación JWT, escritura Firestore, envío FCM |
| **Cloud Firestore** | Firebase NoSQL | Datos persistentes: users, stop_requests, risk_zones |
| **Firebase RTDB** | Firebase JSON | Posiciones GPS en tiempo real de vendedores activos |
| **Firebase Auth** | (externo) | Emite JWT; verifica credenciales |
| **FCM** | (externo) | Notificaciones push Android |
| **Google Maps Platform** | (externo) | Mapa base, marcadores, polígonos, rutas (Directions API) |

**Protocolos:**
- App Flutter ↔ Firebase Auth: Firebase Auth SDK (HTTPS)
- App Flutter ↔ API FastAPI: HTTPS/REST JSON + `Authorization: Bearer <JWT>`
- App Flutter ↔ RTDB: WebSocket persistente (Firebase RTDB SDK)
- App Flutter ↔ Google Maps: Google Maps SDK for Flutter
- API FastAPI ↔ Firebase Auth: Firebase Admin SDK (verifica JWT)
- API FastAPI ↔ Firestore: Firestore Admin SDK / gRPC
- API FastAPI ↔ FCM: FCM Admin SDK / HTTPS

---

## 6. ORGANIZACIÓN POR DOMINIOS

El sistema usa **bounded contexts** (domain-first), no capas técnicas. Esto aplica a la estructura de carpetas Flutter (`lib/features/{dominio}/`) y FastAPI (`modules/{dominio}/`).

| Dominio | ID | Responsabilidad | Flutter | FastAPI |
|---|---|---|---|---|
| **Identity & Access** | D-01 | Registro, login, sesión, JWT, roles | AuthModule, DrawerModule | AuthMiddleware, AuthRouter |
| **Presence** | D-02 | GPS en tiempo real del vendedor | GPSService, VendorTracker | *(vacío en iter. 1 — GPS va directo a RTDB)* |
| **Dispatching** | D-03 | Mapa, solicitud de parada, seguimiento | MapScreenBuyer, MapScreenVendor, StopRequestModule | StopRequestRouter |
| **Safety** | D-04 | Zonas de riesgo | RiskReportModule | RiskZoneRouter |
| **Community** | D-05 | Reputación, reseñas, reportes colaborativos | *(vacío iter. 1)* | *(vacío iter. 1)* |
| **Shared** | — | Infraestructura transversal | NotificationHandler | FirebaseAdminInit, FirestoreService, NotificationService |

**Mapeo CU → Dominio principal:**
- Auth → Identity & Access
- CU-01 → Dispatching (+ Presence para ubicación, + Shared para FCM)
- CU-02 → Presence (+ Dispatching para mapa del vendedor)
- CU-03 → Safety (+ Identity para JWT, + Shared para FCM)

---

## 7. COMPONENTES INTERNOS — C4 NIVEL 3

### 7.1. App Móvil Flutter (9 componentes)

| Componente | Dominio | Tecnología | Responsabilidad resumida |
|---|---|---|---|
| **AuthModule** | Identity | Firebase Auth SDK | Login, registro, JWT, `authStateChanges`, redirige por rol |
| **DrawerModule** | Identity | Flutter Widget | Menú lateral: Perfil, Historial, Logout → invoca `AuthModule.logout()` |
| **GPSService** | Presence | geolocator + RTDB SDK | Lee GPS cada 3s/≥10m, publica en `/vendedores_activos/{uid}`, elimina nodo al desactivar, `onDisconnect().remove()` |
| **VendorTracker** | Presence | Firebase RTDB SDK | Suscribe a `/vendedores_activos`, filtra radio 4km (Haversine client), emite `Stream<List<VendorMarker>>` |
| **MapScreenBuyer** | Dispatching | Flutter + Google Maps SDK | Home del Comprador: mapa, marcadores de vendedores, polígonos de riesgo, FAB CU-03 |
| **MapScreenVendor** | Dispatching | Flutter + Google Maps + Directions API | Home del Vendedor: toggle visibilidad, dialog solicitud entrante, ruta segura |
| **StopRequestModule** | Dispatching | dio HTTP | CU-01: POST /stops → espera aceptación → tracking; timeout 60s |
| **RiskReportModule** | Safety | Flutter + HTTP | CU-03: bottom sheet formulario → POST /risk-zones |
| **NotificationHandler** | Shared | Firebase Messaging SDK | FCM init, registra token, despacha 3 tipos de eventos a pantallas |

**Interfaces clave del GPSService:**
- `startTransmission(vendorUid)` — activa stream GPS + escritura RTDB
- `stopTransmission(vendorUid)` — detiene stream, elimina nodo RTDB
- `Stream<GPSServiceState> stateStream` → estados: `active | inactive | error_no_signal`

**Tipos de eventos FCM que maneja NotificationHandler:**
1. `stop_request_incoming` → muestra dialog de solicitud en MapScreenVendor
2. `stop_request_accepted` / `stop_request_rejected` → navega a tracking o mapa en MapScreenBuyer
3. `risk_zone_alert` → muestra alerta en HomeScreen activa

### 7.2. API REST FastAPI (7 componentes)

| Componente | Dominio | Tipo | Responsabilidad / Endpoints |
|---|---|---|---|
| **FirebaseAdminInit** | Shared | Módulo init | Inicializa Firebase Admin SDK en `lifespan`. Expone `get_firestore_client()` y `get_fcm_client()` |
| **AuthMiddleware** | Identity | FastAPI Depends | Verifica JWT con `firebase_admin.auth.verify_id_token()`. Retorna `AuthContext(uid, rol)`. Lanza 401/403 |
| **AuthRouter** | Identity | APIRouter `/auth` | `POST /auth/sync-profile` (upsert perfil en `users`), `PATCH /auth/device-token` (actualiza FCM token) |
| **StopRequestRouter** | Dispatching | APIRouter `/stops` | `POST /stops` (crea solicitud, notifica vendedor), `GET /stops/{id}` (consulta estado), `PATCH /stops/{id}/status` (acepta/rechaza/completa, notifica comprador) |
| **RiskZoneRouter** | Safety | APIRouter `/risk-zones` | `POST /risk-zones` (crea zona, calcula expires_at +24h, notifica FCM), `GET /risk-zones` (filtra por bounding box + Haversine), `DELETE /risk-zones/{id}` (soft-delete por reporter) |
| **FirestoreService** | Shared | Data Access Layer | CRUD abstracto sobre `users`, `stop_requests`, `risk_zones`. Maneja serialización Pydantic ↔ Firestore |
| **NotificationService** | Shared | Servicio transversal | `notify_stop_request_incoming(vendor_uid, data)`, `notify_stop_request_accepted/rejected(buyer_uid)`, `notify_risk_zone_alert(user_uids[], data)` |

---

## 8. BASE DE DATOS

### 8.1. Cloud Firestore — 3 colecciones

#### `users/{uid}`
| Campo | Tipo | Nota |
|---|---|---|
| `uid` | string | = Firebase Auth UID = ID del documento |
| `name` | string | |
| `phone` | string | |
| `role` | string | `BUYER` ó `VENDOR`; inmutable en iter. 1 |
| `fcm_token` | string\|null | Se actualiza en cada login / cuando FCM rota token |
| `last_location` | GeoPoint\|null | **[V2 anticipatorio iter.3]** Solo vendors, solo foreground |
| `last_location_at` | Timestamp\|null | **[V2 anticipatorio iter.3]** |
| `created_at` | Timestamp | |
| `updated_at` | Timestamp | |

#### `stop_requests/{id}`
| Campo | Tipo | Nota |
|---|---|---|
| `id` | string | Auto-generado por Firestore |
| `buyer_uid` | string | ref → users |
| `vendor_uid` | string | ref → users |
| `buyer_location` | GeoPoint | Posición del comprador al crear la solicitud |
| `status` | string | `pending→accepted→completed` ó `pending→rejected` ó `pending→expired` |
| `created_at` | Timestamp | |
| `updated_at` | Timestamp | |
| `accepted_at` | Timestamp\|null | |
| `completed_at` | Timestamp\|null | |
| `expires_at` | Timestamp | `created_at + 60s` (timeout de respuesta del vendor) |

#### `risk_zones/{id}`
| Campo | Tipo | Nota |
|---|---|---|
| `id` | string | Auto-generado |
| `reporter_uid` | string | ref → users |
| `threat_type` | string | Texto libre ("robo", "accidente"…) |
| `risk_level` | string | `HIGH` ó `MEDIUM` ó `LOW` |
| `location` | GeoPoint | Centro de la zona |
| `radius_meters` | number | default 100 |
| `active` | boolean | Todas las consultas filtran `active == true` |
| `created_at` | Timestamp | |
| `expires_at` | Timestamp | `created_at + 24h` |
| `expired_at` | Timestamp\|null | Si fue expirada manualmente |

**Nota consultas geográficas:** Firestore no soporta queries por radio. El sistema usa **bounding box** (rango lat/lng) + **Haversine en Python** para filtrar el resultado exacto. Deuda técnica declarada para iter. 3.

### 8.2. Firebase RTDB — árbol GPS

```json
{
  "vendedores_activos": {
    "{vendor_uid}": {
      "lat": 20.6739,
      "lng": -103.4439,
      "timestamp": 1713457200000,
      "activo": true
    }
  }
}
```

**Reglas clave:**
- Solo el propio vendedor puede escribir su nodo (`auth.uid === $vendor_uid`)
- Cualquier usuario autenticado puede leer (para el mapa de compradores)
- El nodo se **elimina** (no se pone `activo: false`) cuando el vendor desactiva; `onDisconnect().remove()` limpia nodos huérfanos si la app se cierra inesperadamente

**Frecuencia de escritura:** cada 3 segundos ó cuando el vendor se desplaza ≥10 metros  
**No se consolida historial GPS en iter. 1** (decisión §3.5 — ningún CU lo requiere)

### 8.3. Colecciones previstas iter. 2–3 (no diseñadas aún)

`community_reports`, `reputation_events`, `subscriptions`, `vendor_catalog`, `verifications`

---

## 9. DECISIONES ARQUITECTÓNICAS (ADRs)

### ADR #1 — Monolito FastAPI (vs. microservicios)
**Decisión:** Monolito con routers por dominio  
**Por qué:** Equipo de 3 personas, 3 CU en iter. 1, tier gratuito, velocidad de entrega  
**Revisión:** Al inicio de iter. 2 evaluar si el volumen de CU adicionales (CU-04 a CU-09) justifica extraer algún dominio

### ADR #2 — GPS directo a RTDB (vs. vía FastAPI)
**Decisión:** App Flutter escribe directamente en RTDB sin pasar por FastAPI  
**Por qué:** Latencia 30–80ms vs. 200–500ms adicionales; cero carga en FastAPI; lógica de negocio GPS no existe en iter. 1; reglas RTDB equivalentes en seguridad  
**Revisión:** Si iter. 2 necesita detección de anomalías GPS, añadir Cloud Function intermedia

### ADR #3 — Persistencia políglota: Firestore + RTDB
**Decisión:** Firestore para datos estructurados persistentes; RTDB para GPS en tiempo real  
**Por qué:** Cada BD optimizada para su caso de uso; ambas son Firebase (mismas credenciales Admin SDK); RTDB tiene `onDisconnect()` nativo para presencia  
**Deuda:** Dos SDKs en Flutter; dos conjuntos de reglas de seguridad

### ADR #4 — State Management en Flutter: Riverpod
**Decisión:** Riverpod 2.x (con fallback a Provider si la curva de aprendizaje es riesgo)  
**Por qué:** Sin dependencia de BuildContext; type-safe en compilación; `StreamProvider` nativo para RTDB/FCM; mejor que Provider para streams multi-pantalla  
**Fallback:** Provider 6.x si el equipo necesita reducir inversión inicial (mismos conceptos, migración sencilla)

**Providers definidos:**

| Provider | Tipo Riverpod | Estado |
|---|---|---|
| `authStateProvider` | `StreamProvider<User?>` | Usuario autenticado (Firebase Auth stream) |
| `userProfileProvider` | `FutureProvider<UserProfile>` | Perfil desde Firestore |
| `gpsStateProvider` | `StateProvider<GPSServiceState>` | Estado GPS del vendedor |
| `vendorMarkersProvider` | `StreamProvider<List<VendorMarker>>` | Vendedores activos desde RTDB |
| `stopRequestProvider` | `StateNotifierProvider<StopRequest?>` | Solicitud activa en curso |
| `activeRiskZonesProvider` | `FutureProvider<List<RiskZone>>` | Zonas de riesgo desde API |

**ADRs retroactivos pendientes (Fase 6):**

| ADR | Tema | Resumen anticipado |
|---|---|---|
| Retroactivo A | Firebase Auth como IdP | Decisión implícita en Fase 1; no se evaluó Auth0/Clerk porque Firebase Auth es gratis y ya está integrado en el ecosistema Firebase del proyecto |
| Retroactivo B | Google Maps como cartografía | Decisión implícita; riesgo de costo a escala real post-TSP; Mapbox u OSM como alternativas no evaluadas formalmente |
| Retroactivo C | FCM como único canal de push | Implica Android-only de facto en iter. 1; sin push interactivo (action buttons) hasta iter. 3 |
| Deuda técnica | Haversine client-side | Para filtrado de 4km en VendorTracker; precisión suficiente en iter. 1; evaluar geohash en iter. 3 |

---

## 10. DESIGN SYSTEM

*(Completo en `SDD_FASE0_UBISAFE.md` §7.1. Resumen de lo más relevante para wireframes/mockups:)*

### Colores principales
| Token | Hex | Uso clave |
|---|---|---|
| `primary-700` | `#1565C0` | Color de marca, AppBar, botones primarios |
| `secondary-700` | `#2E7D32` | "Vendedor activo", confirmaciones |
| `secondary-500` | `#43A047` | Marcadores de vendedor en el mapa |
| `danger-500` | `#E53935` | Errores, botones destructivos |
| `warning-700` | `#E65100` | FAB de reporte de riesgo, zonas riesgo Medio |
| `info-500` | `#0277BD` | Zonas riesgo Bajo |

**Home Comprador:** fondo `#E3F2FD` (azul claro) | **Home Vendedor:** fondo `#F1F8E9` (verde claro)

### Mapa — colores de polígonos
- Riesgo **ALTO:** rojo `#C62828` al 35% fill, borde 100%
- Riesgo **MEDIO:** naranja `#F57C00` al 30% fill
- Riesgo **BAJO:** azul `#0277BD` al 25% fill
- Marcador vendedor activo: círculo verde `#43A047`

### Tipografía: Inter
- Texto mínimo funcional: **14sp** (accesibilidad adultos mayores)
- Texto de acción crítica: mínimo **16sp**
- Body principal: 16sp Regular | Botones: 16sp SemiBold | Caption: 12sp

### Componentes clave
- **Botón primario:** 52dp alto, radio 12dp, fondo `primary-700`
- **FAB "+" (CU-03):** 56×56dp, radio 16dp, fondo `warning-700`, ícono `add` blanco
- **Bottom sheet:** radio superior 24dp (para RiskReportModule y diálogos)
- **Cards:** radio 16dp, elevación 2dp
- Grid de 8px: spacing XS=4, SM=8, MD=16, LG=24, XL=32, XXL=48

### Iconografía: Material Design Icons — estilo **Outlined** (excepto estados activos → Filled)

---

## 11. GESTIÓN DE ESTADO — RIVERPOD

**Principio:** `setState` para estado local de un solo widget. Riverpod para estado compartido entre pantallas.

**Dependencia en pubspec.yaml:**
```yaml
flutter_riverpod: ^2.5.1
```

El equipo aún no ha implementado. La decisión de usar Riverpod vs. el fallback Provider **se toma al inicio del primer sprint de implementación**. El documento debe mencionarlo como "decisión pendiente de confirmar al inicio de la implementación".

---

## 12. ESTRUCTURA DE CARPETAS DEL PROYECTO

*(Completa en `SDD_FASE2_PASO25_UBISAFE.md` §11. Resumen:)*

### Flutter — Domain-First (`lib/features/{dominio}/`)
```
lib/
├── main.dart
├── core/           → api_client.dart, design_system/ (tokens)
├── features/
│   ├── identity/   → auth/ (AuthModule, pantallas Login/SignUp), profile/ (DrawerModule, perfil, historial)
│   ├── presence/   → services/ (GPSService, VendorTracker), models/ (VendorMarker)
│   ├── dispatching/→ screens/ (MapScreenBuyer, MapScreenVendor, TrackingScreen), services/ (StopRequestModule), widgets/ (visibility_toggle)
│   ├── safety/     → screens/ (RiskFormBottomSheet), models/ (RiskZone)
│   └── shared/     → notifications/ (NotificationHandler)
└── router/         → app_router.dart (go_router)
```

### FastAPI — Modules by Domain (`modules/{dominio}/`)
```
ubisafe_api/
├── main.py
├── modules/
│   ├── identity/    → router.py (/auth endpoints), schemas.py
│   ├── dispatching/ → router.py (/stops endpoints), schemas.py
│   ├── safety/      → router.py (/risk-zones endpoints), schemas.py
│   └── shared/      → firebase_admin_init.py, firestore_service.py, notification_service.py
├── dependencies.py  → AuthMiddleware (FastAPI Depends)
└── requirements.txt, Dockerfile
```

---

## 13. CONTEXTO POR FASE RESTANTE

### Fase 4 — Diagramas de Secuencia

**Necesitas saber:**
- Los 4 diagramas a producir: CU-01 (+ alternativo: vendor rechaza + excepción: timeout 60s), CU-02 (+ alternativo: señal GPS débil + excepción: conexión perdida), CU-03 (+ alternativo: nivel medio/bajo + excepción: reporte duplicado), Auth (registro + login)
- **Actores en los diagramas:** App Flutter (o sus componentes específicos), API FastAPI, Firebase Auth, Firestore, RTDB, FCM, Google Maps
- **Endpoints clave por CU:**
  - CU-01: `POST /stops` → `PATCH /stops/{id}/status` → FCM notify vendor → FCM notify buyer
  - CU-02: GPSService escribe directo en RTDB (sin pasar por FastAPI); MapScreenVendor controla el toggle
  - CU-03: `POST /risk-zones` → FCM `notify_risk_zone_alert(user_uids[])`
  - Auth: Firebase Auth SDK → `POST /auth/sync-profile` → `PATCH /auth/device-token`
- **Tiempos/umbrales:** timeout solicitud = 60s; GPS frecuencia = 3s ó ≥10m; JWT expiración = 1h
- **Estados de `stop_requests.status`:** `pending → accepted → completed` / `pending → rejected` / `pending → expired`
- **Recomendación de formato:** usar `sequenceDiagram` de Mermaid con `participant` por componente. Incluir flujo normal + alternativo + excepción en diagramas separados o con `alt`/`opt`/`loop`

### Fase 5B — Wireframes

**Necesitas saber:**
- Las 16 pantallas identificadas en §3.4 de este documento
- El design system está en `SDD_FASE0_UBISAFE.md` §7.1 (paleta, tipografía, componentes, tokens)
- La navegación está en el diagrama del knowledge source del proyecto (y en §3.4 de este resumen)
- El FAB naranja (CU-03) aparece en AMBAS HomeScreens (Comprador y Vendedor)
- El drawer (menú lateral) es accesible desde ambas HomeScreens
- El diálogo de solicitud entrante aparece sobre MapScreenVendor (no es una pantalla nueva)
- La pantalla de Tracking usa VendorTracker (posición del vendor en tiempo real) + distancia estimada

### Fase 5C — Mockups de alta fidelidad

**Necesitas saber:**
- El conector Figma está disponible si se instala
- La revisión de accesibilidad (`/design:accessibility-review`) debe enfocarse en: contraste para adultos mayores, tamaños touch ≥48dp, texto ≥14sp, legibilidad en condiciones de baja luz (uso en exterior)
- Los dos fondos distintos: Home Comprador (azul claro #E3F2FD) vs. Home Vendedor (verde claro #F1F8E9)

### Fase 5D — Diagrama de Navegación

**Necesitas saber:**
- El diagrama ya existe en el knowledge source del proyecto (importado como `custom_instructions` en la fuente TSP) — es el diagrama Mermaid `graph TD` con todos los estados
- La tarea es validar que ese diagrama cubre todos los CU y flujos del SRS, y actualizarlo/formalizarlo para el SDD
- Secciones del SDD donde va: §9 (Diagrama de Navegación) y §10 (Interface Viewpoint complemento)

### Fase 6 — ADRs consolidados

**Necesitas saber:**
- ADRs ya escritos: #1 (monolito), #2 (GPS directo RTDB), #3 (Firestore+RTDB), #4 (Riverpod) → recopilarlos en §3 del SDD de forma cohesiva
- ADRs retroactivos pendientes de redactar (A, B, C) — ver §9 de este resumen para contexto
- Deuda técnica a documentar: Haversine client-side (§3 del SDD, nota en §10 del SDD plan)
- El apéndice de ADRs iter. 2-3 (#5–#11) es **opcional y no entra al SDD iter. 1** — es documento separado para el equipo

### Fase 7 — Trazabilidad

**Necesitas saber:**
- Se necesita la **tabla de RFs del SRS** (BB_SRS_V1.6): los CU-01, CU-02, CU-03 son los RF relevantes para iter. 1
- Matriz 1: RF (CU) → Componentes que lo implementan → Interfaces expuestas → Diagrama de secuencia correspondiente
- Matriz 2: RNFs del SRS → Decisiones arquitectónicas que los satisfacen (ej. RNF-05 Seguridad → AuthMiddleware + JWT; RNF-02 Accesibilidad → design system con 14sp mínimo)
- El historial de versiones del SDD: V1.0 (16/04/2026, fases 0-2) → V2.0 (17/04/2026, revisión arquitectónica)

### Fase 8 — Verificación

**Checklist del profesor (6 criterios):**
1. ¿Se describen componentes y sus relaciones? → Fases 1, 2
2. ¿Se describe el diseño de BD y es consistente? → Fase 3
3. ¿Se describen detalles de componentes con diagramas consistentes? → Fases 2, 4
4. ¿Se describe diseño de interfaz y es consistente? → Fase 5
5. ¿Se usa C4 (y UML donde sea necesario)? → Fases 1, 2, 4
6. ¿Se muestran claramente los contenidos de la iteración? → Fase 7

**IEEE 1016-2009 Viewpoints cubiertos:**
- Context Viewpoint → §3 (C4 L1) ✅
- Composition Viewpoint → §4 (C4 L2) + §5 (C4 L3) ✅
- Information Viewpoint → §7 (BD) ✅
- Rationale Viewpoint → §3 del SDD (ADRs) — parcial
- Interface Viewpoint → §8 (UI) + §9 (Navegación) — pendiente
- Interaction Viewpoint → §8 (Secuencias) — pendiente
- Detailed Design Viewpoint → §11 (Estructura proyecto) ✅

---

## APÉNDICE — NOMBRES EXACTOS PARA CONSISTENCIA

> Usar estos nombres exactamente así en todos los diagramas y textos futuros. La inconsistencia entre fases es el error más común que rompe la coherencia del SDD.

**Colecciones Firestore:** `users`, `stop_requests`, `risk_zones`  
**Nodo RTDB:** `/vendedores_activos/{vendor_uid}`  
**Campos status en stop_requests:** `pending`, `accepted`, `rejected`, `completed`, `expired`  
**Niveles de riesgo:** `HIGH`, `MEDIUM`, `LOW` (mayúsculas, en inglés)  
**Roles de usuario:** `BUYER`, `VENDOR` (mayúsculas)  
**Nombres de componentes Flutter:** AuthModule, DrawerModule, GPSService, VendorTracker, MapScreenBuyer, MapScreenVendor, StopRequestModule, RiskReportModule, NotificationHandler  
**Nombres de componentes FastAPI:** FirebaseAdminInit, AuthMiddleware, AuthRouter, StopRequestRouter, RiskZoneRouter, FirestoreService, NotificationService  
**Endpoints API:** `POST /auth/sync-profile`, `PATCH /auth/device-token`, `POST /stops`, `GET /stops/{stop_id}`, `PATCH /stops/{stop_id}/status`, `POST /risk-zones`, `GET /risk-zones`, `DELETE /risk-zones/{zone_id}`  
**Dominios:** Identity & Access, Presence, Dispatching, Safety, Community, Shared  
**Secciones del SDD:** §1 Intro, §2 Stakeholders, §2.5 Dominios, §3 ADRs, §4 C4 L1, §5 C4 L2, §5.3 C4 L3, §7 BD, §8 UI/Design System, §9 Secuencias, §10 Navegación, §11 Estructura Proyecto, §12 Trazabilidad, §13 Historial

---

*Resumen generado: 18/04/2026 — Los Borbotones / UBISAFE · Consolidado desde Fases 0–3 del SDD*
