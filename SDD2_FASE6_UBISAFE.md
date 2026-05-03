# SDD2 — Fase 6': ADRs Consolidados (Iteración 1 + Iteración 2)
## Sección §3 del SDD — Architecture Decision Records
### UBISAFE · Los Borbotones · 25/04/2026

> **Propósito de este archivo:** Compilar y redactar en formato canónico todos los ADRs del sistema UBISAFE, abarcando los ADRs #1–#4 de Iteración 1, los ADRs retroactivos pendientes (Retro-A, Retro-B, Retro-C) y los ADRs #5–#11 de Iteración 2. Organizado temáticamente para facilitar la integración en §3 del SDD (IEEE 1016-2009, Rationale Viewpoint). Producido por Alexis (Fase 6' del Plan Iter. 2).
>
> **Archivos base leídos:** `RESUMEN_SDD_UBISAFE.md`, `SDD2_FASE0_UBISAFE.md`, `SDD_FASE0_PASOS05_06_UBISAFE.md`, `SDD2_FASE3B_UBISAFE.md`.
>
> **ADRs aportados directamente por el equipo:** #1 (Monolito FastAPI), #2 (GPS directo RTDB), #3 (Persistencia políglota) — texto canónico suministrado por Alexis.

---

## Índice de ADRs

| ID | Título | Estado | Iteración | Tema |
|---|---|---|---|---|
| **Retro-A** | Firebase Auth como Proveedor de Identidad | ✅ Aceptado | Iter. 1 (retroactivo) | Seguridad e Identidad |
| **Retro-B** | Google Maps Platform como Solución Cartográfica | ✅ Aceptado | Iter. 1 (retroactivo) | Cartografía y Geometría |
| **Retro-C** | FCM como Canal Único de Notificaciones Push | ✅ Aceptado | Iter. 1 (retroactivo) | Notificaciones |
| **ADR #1** | Arquitectura de Backend: Monolito FastAPI | ✅ Aceptado | Iter. 1 | Persistencia y Backend |
| **ADR #2** | Transmisión GPS en Tiempo Real: Directo a Firebase RTDB | ✅ Aceptado | Iter. 1 | Persistencia y Backend |
| **ADR #3** | Persistencia Políglota: Cloud Firestore + Firebase RTDB | ✅ Aceptado | Iter. 1 | Persistencia y Backend |
| **ADR #4** | State Management en Flutter: Riverpod | ✅ Aceptado | Iter. 1 | Estado y UI |
| **ADR #5** | Firebase Storage para Evidencias | 🔵 Diferido | Iter. 2 (diferido a Iter. 3) | Almacenamiento |
| **ADR #6** | Modelo de Validación Comunitaria: Votación Simple | ✅ Aceptado | Iter. 2 | Validación Comunitaria |
| **ADR #7** | Geometría de Zonas: Círculos en Iter. 2 | ✅ Aceptado | Iter. 2 | Cartografía y Geometría |
| **ADR #10** | Cloud Functions como Orquestador de Eventos | ✅ Aceptado | Iter. 2 | Orquestación |
| **ADR #11** | Coexistencia de Dos Colecciones de Reportes | ✅ Aceptado | Iter. 2 | Persistencia y Backend |

> **Nota sobre numeración:** Los ADRs retroactivos se numeran con el prefijo "Retro" para distinguirlos de los ADRs planeados. Los ADRs #8 y #9 no fueron activados en ninguna iteración planificada hasta la fecha.

---

## Organización Temática

### Tema A — Persistencia y Backend
- ADR #1 (Monolito FastAPI)
- ADR #2 (GPS directo RTDB)
- ADR #3 (Persistencia políglota)
- ADR #11 (Coexistencia de colecciones) [iter. 2]

### Tema B — Cartografía y Geometría
- ADR Retro-B (Google Maps)
- ADR #7 (Geometría círculos) [iter. 2]

### Tema C — Notificaciones
- ADR Retro-C (FCM)

### Tema D — Estado y UI
- ADR #4 (Riverpod)

### Tema E — Seguridad e Identidad
- ADR Retro-A (Firebase Auth)

### Tema F — Orquestación
- ADR #10 (Cloud Functions) [iter. 2]

### Tema G — Almacenamiento de Evidencias
- ADR #5 (Firebase Storage diferido) [iter. 2]

### Tema H — Validación Comunitaria
- ADR #6 (Votación simple) [iter. 2]

---

## TEMA A — Persistencia y Backend

---

### ADR #1 — Arquitectura de Backend: Monolito FastAPI vs. Microservicios

| Campo | Valor |
|---|---|
| **ID** | ADR-001 |
| **Estado** | ✅ Aceptado |
| **Fecha** | 16/04/2026 |
| **Iteración** | Iteración 1 |
| **Autores** | Los Borbotones — UBISAFE |

#### Contexto

Se evaluaron dos enfoques arquitectónicos para el backend de UBISAFE. El sistema en Iteración 1 cubre tres casos de uso (CU-01, CU-02, CU-03) con un equipo de tres personas sin experiencia previa en arquitecturas de microservicios y bajo el constraint del tier gratuito de Firebase Hosting.

#### Opciones Evaluadas

| Opción | Descripción |
|---|---|
| **A) Monolito FastAPI** *(elegida)* | Una sola aplicación FastAPI con routers organizados por dominio (auth, stops, risk_zones, notifications). Desplegada como un único servicio. |
| **B) Microservicios** | Múltiples servicios independientes (un servicio por dominio): auth-service, stop-service, risk-service, notification-service. Cada uno con su propio despliegue y comunicación entre servicios vía HTTP o mensajería. |

#### Decisión

Se elige la **Opción A: Monolito FastAPI** para la Iteración 1. La aplicación FastAPI se organiza internamente con una estructura modular por dominio (routers separados por área de negocio). La modularización interna mitiga el principal riesgo de un monolito: el acoplamiento excesivo.

#### Justificación

- **Equipo:** Tres desarrolladores sin experiencia previa en microservicios ni en orquestación de contenedores múltiples.
- **Alcance:** Iteración 1 cubre solo 3 CU. Los microservicios aportarían sobrecarga operativa desproporcionada al tamaño del sistema.
- **Costo:** El tier gratuito de Firebase Hosting y Cloud Run limita la cantidad de instancias activas simultáneamente. Un monolito encaja directamente.
- **Velocidad de entrega:** El calendario académico no permite el tiempo de setup de un entorno de microservicios con service discovery, balanceo y comunicación inter-servicio.
- **Mitigación del riesgo de acoplamiento:** La organización interna domain-first (`modules/identity/`, `modules/dispatching/`, `modules/safety/`) hace que el monolito sea modular en código aunque no en despliegue.

#### Consecuencias

**Positivas:**
- Despliegue simplificado: una imagen Docker, un endpoint, un conjunto de variables de entorno.
- Debugging local directo: una sola instancia de la API, logs unificados.
- Onboarding rápido: cualquier miembro del equipo puede correr el backend completo con un solo comando.
- La organización domain-first facilita la extracción futura de dominios como microservicios si el volumen lo justifica.

**Negativas:**
- Fallo de un componente puede afectar a toda la API (mitigado con manejo de excepciones por router).
- Escalado homogéneo: no se puede escalar un dominio individualmente sin escalar toda la aplicación.

**Revisión prevista:** Al inicio de Iteración 2, evaluar si el volumen de CU adicionales (CU-04 a CU-06) justifica extraer algún dominio. Resultado de la revisión: **el monolito se mantiene en Iter. 2**. Cloud Functions se añade como componente complementario de orquestación de eventos (ver ADR #10), no como microservicio del núcleo.

---

### ADR #2 — Transmisión GPS en Tiempo Real: Directo a Firebase RTDB vs. Vía FastAPI

| Campo | Valor |
|---|---|
| **ID** | ADR-002 |
| **Estado** | ✅ Aceptado |
| **Fecha** | 16/04/2026 |
| **Iteración** | Iteración 1 |
| **Autores** | Los Borbotones — UBISAFE |

#### Contexto

El caso de uso CU-02 (Activar radar de visibilidad) requiere que la app del vendedor transmita su posición GPS al mapa comunitario con latencia mínima y de forma continua mientras el vendedor está activo. Los compradores deben ver la posición del vendedor actualizarse en tiempo real en su mapa. La frecuencia de transmisión es cada 3 segundos o cuando el vendedor se desplaza ≥10 metros.

#### Opciones Evaluadas

| Opción | Descripción |
|---|---|
| **A) App → FastAPI → Firebase RTDB** | La app del vendedor envía cada actualización GPS a FastAPI mediante un endpoint REST. FastAPI valida y reenvía la posición a Firebase RTDB. |
| **B) App → Firebase RTDB (directo)** *(elegida)* | La app del vendedor escribe directamente en Firebase RTDB sin pasar por FastAPI. Las reglas de seguridad de RTDB controlan el acceso. |

#### Decisión

Se elige la **Opción B: Transmisión GPS directa** desde la App al Firebase RTDB, sin pasar por FastAPI.

#### Justificación

- **Latencia:** La Opción A añadiría 200–500 ms adicionales por cada escritura GPS (round-trip HTTPS a FastAPI + reenvío a RTDB). La Opción B logra latencias de 30–80 ms directamente mediante el WebSocket persistente del SDK de Firebase RTDB.
- **Volumen de escrituras:** A una frecuencia de 1 escritura cada 3 segundos por vendedor activo, FastAPI procesaría exclusivamente tráfico GPS sin valor de negocio adicional. Esto satura innecesariamente el backend.
- **Lógica de negocio:** La posición GPS cruda no requiere lógica de negocio centralizada en Iteración 1. No hay validación de coordenadas ni transformación de datos en el servidor para este CU.
- **Seguridad equivalente:** Las reglas de seguridad de RTDB permiten restringir la escritura al propio nodo del vendedor (`auth.uid === $vendor_uid`), equivalente a la validación JWT que haría FastAPI.
- **Presencia nativa:** Firebase RTDB ofrece `onDisconnect().remove()`, que elimina el nodo del vendedor si la conexión se interrumpe abruptamente. Replicar este comportamiento vía FastAPI requeriría un mecanismo de heartbeat o TTL adicional.

Esta decisión es coherente con el patrón arquitectónico Firebase-first del proyecto: RTDB está diseñado específicamente para sincronización de datos en tiempo real con latencia sub-100 ms. FastAPI interviene únicamente en operaciones que requieren lógica de negocio centralizada (validaciones complejas, escrituras en Firestore, envío de FCM).

#### Consecuencias

**Positivas:**
- Latencia de actualización GPS < 100 ms para compradores suscritos.
- Cero carga en FastAPI por escrituras GPS.
- `onDisconnect().remove()` nativo: los nodos de vendedores inactivos se limpian automáticamente sin lógica adicional.
- Las reglas RTDB son suficientes para garantizar que cada vendedor solo escribe en su propio nodo.

**Negativas:**
- La app Flutter debe gestionar dos SDKs de Firebase: `cloud_firestore` y `firebase_database`.
- Las reglas de seguridad de RTDB (JSON) son independientes de las de Firestore (CEL), lo que requiere mantener dos conjuntos de reglas.

**Revisión prevista:** Si en Iteración 2 o posterior se requiere detección de anomalías GPS (velocidad imposible, saltos de coordenadas), se considerará añadir una Cloud Function que suscriba a los cambios en RTDB y aplique validación antes de propagar la posición.

---

### ADR #3 — Persistencia Políglota: Cloud Firestore + Firebase Realtime Database

| Campo | Valor |
|---|---|
| **ID** | ADR-003 |
| **Estado** | ✅ Aceptado |
| **Fecha** | 16/04/2026 |
| **Iteración** | Iteración 1 |
| **Autores** | Los Borbotones — UBISAFE |

#### Contexto

UBISAFE necesita almacenar dos categorías de datos con requerimientos radicalmente distintos:

**Categoría A — Datos estructurados y persistentes:**
- Perfiles de usuario (nombre, teléfono, rol, token FCM)
- Solicitudes de parada (estado del ciclo de vida CU-01)
- Zonas de riesgo (reportes CU-03, geometría, nivel de riesgo)

Características requeridas: consistencia fuerte, consultas flexibles, reglas de seguridad por documento, persistencia indefinida, latencia de escritura tolerable (~200–500 ms).

**Categoría B — Posiciones GPS en tiempo real:**
- Coordenadas del vendedor activo, actualización cada 3 segundos
- Ciclo de vida efímero: existe mientras el vendedor transmite y se elimina al desactivar
- Fan-out a compradores suscritos (N lectores por cada escritura de vendedor)

Características requeridas: latencia ultra-baja, escrituras de alta frecuencia a bajo costo, suscripciones reactivas tipo push, soporte de presencia (detección de desconexión).

#### Opciones Evaluadas

| Opción | Fortalezas | Debilidades |
|---|---|---|
| **Solo Cloud Firestore** | Un único sistema a gestionar | Latencia de escritura ~200–500 ms (demasiado para GPS); costo por operación más alto para escrituras de alta frecuencia; soporte de presencia más complejo |
| **Solo Firebase RTDB** | Latencia ultra-baja; presencia nativa | No soporta consultas complejas; modelo de datos plano (JSON); reglas de seguridad más limitadas; no escala bien para datos estructurados y complejos |
| **Firestore + RTDB** *(elegida)* | Cada base de datos optimizada para su caso de uso | Dos SDKs a gestionar; dos conjuntos de reglas de seguridad |
| **Firestore + Redis/WebSocket propio** | Control total | Infraestructura adicional que el equipo no puede mantener; complejidad operacional alta |

#### Decisión

Se adopta **persistencia políglota con dos bases de datos**: Cloud Firestore para datos estructurados/persistentes y Firebase Realtime Database para posiciones GPS en tiempo real.

**Distribución de responsabilidades:**

| Base de datos | Colecciones / Nodos | Acceso |
|---|---|---|
| **Cloud Firestore** | `users`, `stop_requests`, `risk_zones` | App Flutter (SDK cliente), FastAPI (Admin SDK) |
| **Firebase RTDB** | `/vendedores_activos/{uid}` | App Flutter (SDK cliente directo — ver ADR #2) |

Ambas bases de datos pertenecen al mismo proyecto Firebase, lo que simplifica la administración de credenciales y el uso del Firebase Admin SDK en FastAPI.

#### Consecuencias

**Positivas:**
- **Costo controlado:** Ambas bases de datos tienen tier gratuito generoso (Firebase Spark), adecuado para el proyecto académico.
- **Sin infraestructura adicional:** Ambas son servicios administrados de Firebase; el equipo no opera ni dimensiona servidores de base de datos.
- **Cohesión en el proyecto Firebase:** Un único proyecto, un único conjunto de credenciales de Admin SDK, facturación unificada.
- **Latencia GPS óptima:** RTDB entrega actualizaciones en < 100 ms a compradores suscritos; Firestore maneja datos persistentes sin presión de latencia.

**Negativas:**
- **Dos SDKs en Flutter:** La app importa tanto `firebase_database` (RTDB) como `cloud_firestore` (Firestore). Esto aumenta ligeramente el tamaño del bundle Android y la superficie de configuración.
- **Dos conjuntos de reglas de seguridad:** Las reglas de Firestore (lenguaje `.rules` basado en CEL) y las reglas de RTDB (JSON) tienen sintaxis y semántica distintas. El equipo debe mantener ambas.
- **Consultas geográficas limitadas en Firestore:** Firestore no soporta consultas por radio. El sistema usa bounding box + Haversine en Python para filtrar el resultado exacto. Ver sección de Deuda Técnica.

---

### ADR #11 — Coexistencia de Dos Colecciones de Reportes [iter. 2]

| Campo | Valor |
|---|---|
| **ID** | ADR-011 |
| **Estado** | ✅ Aceptado |
| **Fecha** | 24/04/2026 |
| **Iteración** | Iteración 2 |
| **Autores** | Los Borbotones — UBISAFE |

#### Contexto

El sistema ya dispone de la colección `risk_zones` (CU-03, Iteración 1) para reportar peligros de seguridad (jaurías, robos, accidentes). La Iteración 2 introduce CU-05 (Reportar focos de infección) y CU-06 (Verificar reportes comunitarios), que manejan un tipo de reporte diferente: focos sanitarios con validación comunitaria. Se evaluó si unificar ambos tipos en una sola colección o mantenerlos separados.

#### Opciones Evaluadas

| Criterio | Unificar en una colección | Dos colecciones separadas *(elegida)* |
|---|---|---|
| Breaking changes en iter. 1 | Rompe `risk_zones` existente | ✅ Zero breaking changes |
| Campos nulos | Campos opcionales en mitad de documentos | ✅ Cada colección tiene solo sus campos |
| Lógica de negocio | Router complejo con condicionales | ✅ Dos routers pequeños y especializados |
| Queries | Filtrar por tipo en todas las queries | ✅ Queries simples por colección |
| Riesgo operativo | Toca código CU-03 ya diseñado | ✅ CU-03 no se modifica |

#### Decisión

**Dos colecciones separadas coexisten**: `risk_zones` (Iter. 1, CU-03) y `community_reports` (Iter. 2, CU-05/06).

#### Diferencias de modelo que justifican la separación

| Característica | `risk_zones` (CU-03) | `community_reports` (CU-05/06) |
|---|---|---|
| Estado inicial | Activo inmediatamente | `pending_validation` |
| Validación comunitaria | No | Sí (votos, umbral 3) |
| Tipos de amenaza | Libre (`HIGH/MEDIUM/LOW`) | Enum: `animal_muerto \| zona_sucia` |
| Color en mapa | Rojo/naranja/azul | Negro (animal) / Café (zona sucia) |
| Impacto en rutas del vendor | ✅ Bloquea HIGH + MEDIUM | ❌ Solo informativo |
| Detección de duplicados | No | Sí (Cloud Function, radio 100 m) |
| Expiración | 24 h | 24 h (igual que `risk_zones`) |

#### Consecuencias

**Positivas:**
- `RiskZoneRouter` (FastAPI, Iter. 1) no se modifica: cero riesgo de regresión en CU-03.
- `CommunityReportRouter` es un router nuevo e independiente, con lógica propia de validación comunitaria.
- El modelo de cada colección es limpio, sin campos condicionales o nulos estructurales.

**Negativas:**
- El mapa del cliente Flutter debe consultar dos colecciones para mostrar todos los reportes activos, lo que implica dos streams o dos queries paralelas.

---

## TEMA B — Cartografía y Geometría

---

### ADR Retro-B — Google Maps Platform como Solución Cartográfica

| Campo | Valor |
|---|---|
| **ID** | ADR-Retro-B |
| **Estado** | ✅ Aceptado (retroactivo) |
| **Fecha** | 25/04/2026 (documentado retroactivamente) |
| **Decisión tomada implícitamente en:** | Iteración 1, Fase 0 |
| **Iteración** | Iteración 1 (retroactivo) |
| **Autores** | Los Borbotones — UBISAFE |

#### Contexto

UBISAFE es una aplicación centrada en mapas. Su propuesta de valor principal (ver vendedores en tiempo real, trazar rutas seguras, visualizar zonas de riesgo) requiere un componente cartográfico de alta calidad que soporte marcadores dinámicos, polígonos, rutas calculadas y geocodificación inversa. Esta decisión fue tomada implícitamente en la Fase 0 de Iteración 1 al incluir `google_maps_flutter` y `google_maps_directions_api` en el stack técnico, sin evaluación formal documentada.

#### Opciones Evaluadas

| Opción | Fortalezas | Debilidades |
|---|---|---|
| **Google Maps Platform** *(elegida)* | Plugin Flutter oficial (`google_maps_flutter`); SDK maduro y documentado; Directions API integrada; amplia adopción en la comunidad | Costo a escala: $2–$7 por 1000 solicitudes pasada la capa gratuita; dependencia de un proveedor propietario |
| **Mapbox** | Control sobre estilos de mapa; tier gratuito generoso; SDK Flutter disponible | Plugin Flutter menos maduro que `google_maps_flutter`; requiere cuenta y clave adicionales |
| **OpenStreetMap + flutter_map** | Gratuito y de código abierto; sin dependencia de proveedor | Sin Directions API nativa (requiere servicio externo como OSRM o Valhalla); mayor esfuerzo de integración; calidad del mapa variable en zonas semiurbanas |

#### Decisión

Se adopta **Google Maps Platform** como solución cartográfica, cubriendo:
- **Google Maps SDK for Flutter** (`google_maps_flutter 2.x`): mapa base, marcadores, polígonos, controles de mapa.
- **Directions API** (HTTP REST): cálculo de rutas seguras para CU-01 (Solicitar parada) y CU-04 (Solicitar raite), evitando zonas de riesgo `HIGH` y `MEDIUM`.

#### Justificación

- **Disponibilidad de plugin maduro:** `google_maps_flutter` es el plugin de mapas más usado y documentado para Flutter, con soporte oficial. Reduce el riesgo de incompatibilidades con versiones recientes del SDK.
- **Integración directa con Directions API:** la misma plataforma provee tanto el mapa base como el cálculo de rutas, sin necesidad de integrar un proveedor de rutas separado.
- **Costo en contexto académico:** el tier gratuito de Google Maps Platform ($200 USD de crédito mensual) es suficiente para el volumen de uso esperado en un proyecto académico. El costo a escala real es reconocido como deuda técnica (ver sección de Deuda Técnica Declarada).
- **Velocidad de desarrollo:** el equipo encontró abundante documentación y ejemplos en Flutter para `google_maps_flutter`, reduciendo el tiempo de onboarding.

#### Consecuencias

**Positivas:**
- Mapa base de alta calidad, especialmente en zonas semiurbanas de México.
- Cálculo de rutas con `Directions API` directamente desde FastAPI, sin infraestructura de routing adicional.
- Plugin Flutter estable y bien documentado.

**Negativas / Deuda técnica reconocida:**
- **Costo a escala:** En un despliegue real con usuarios activos, el costo de Google Maps Platform puede ser significativo. La alternativa de Mapbox o flutter_map + OSRM deberá evaluarse antes de pasar a producción real.
- **Dependencia de proveedor:** Si Google cambia sus condiciones de precio o discontinúa el plugin, la migración tendría un impacto alto en la capa de presentación.

**Revisión prevista:** Evaluar la viabilidad de Mapbox o `flutter_map` + OSRM antes de cualquier despliegue productivo fuera del contexto académico.

---

### ADR #7 — Geometría de Zonas de Riesgo: Círculos en Iteración 2 [iter. 2]

| Campo | Valor |
|---|---|
| **ID** | ADR-007 |
| **Estado** | ✅ Aceptado |
| **Fecha** | 24/04/2026 |
| **Iteración** | Iteración 2 |
| **Autores** | Los Borbotones — UBISAFE |

#### Contexto

El plan maestro de Iteración 2 anticipaba que CU-05 (Reportar focos de infección) requeriría polígonos para delimitar "tramos" de infección, dado que el SRS v2.1 mencionaba zonas de mayor extensión. Al revisar el flujo real de CU-05, se encontró que: "UBISAFE **obtiene la ubicación actual** del comprador/vendedor" — el sistema usa la posición GPS del reportante como origen, sin UI para dibujar zonas.

#### Opciones Evaluadas

| Criterio | Polígono GeoJSON | Círculo GeoPoint + radius *(elegida)* |
|---|---|---|
| Compatibilidad con SRS v2.1 | No requerido explícitamente | ✅ Compatible con el flujo descrito |
| UX de creación | Compleja (modo dibujo en mapa) | ✅ Simple (posición GPS automática) |
| Consistencia con `risk_zones` | Rompe consistencia | ✅ Mantiene consistencia de modelos |
| Consultas geográficas | Cálculos geométricos complejos | ✅ Bounding box + Haversine (reutiliza lógica iter. 1) |
| Esfuerzo de implementación | Alto | ✅ Bajo (reutiliza código de iter. 1) |

#### Decisión

`community_reports` usa el **mismo modelo geométrico que `risk_zones`**: `location: GeoPoint` + `radius_meters: number`. El radio es **fijo en 15 metros** (no configurable por el usuario en Iteración 2).

#### Consecuencias

**Positivas:**
- El componente `DestinationPicker` **no es necesario** para CU-05 (la ubicación se captura automáticamente del GPS del dispositivo).
- No se necesita un modo "dibujar polígono" en el mapa, eliminando un componente de UI complejo.
- La lógica de bounding box + Haversine de `RiskZoneRouter` se reutiliza directamente en `CommunityReportRouter`.
- `radius_meters = 15` es establecido por FastAPI al crear el documento, no recibido como input del usuario.

**Negativas / Deuda técnica:**
- Para focos de infección de mayor escala (zonas sucias extensas que cubren una calle completa), un radio de 15 m puede ser insuficiente. En Iteración 3 se evaluará si se requieren polígonos GeoJSON, activando Firebase Geo o una solución de geometría ad hoc.

---

## TEMA C — Notificaciones

---

### ADR Retro-C — FCM como Canal Único de Notificaciones Push

| Campo | Valor |
|---|---|
| **ID** | ADR-Retro-C |
| **Estado** | ✅ Aceptado (retroactivo) |
| **Fecha** | 25/04/2026 (documentado retroactivamente) |
| **Decisión tomada implícitamente en:** | Iteración 1, Fase 0 |
| **Iteración** | Iteración 1 (retroactivo) |
| **Autores** | Los Borbotones — UBISAFE |

#### Contexto

UBISAFE depende de notificaciones push para tres flujos críticos en Iteración 1: notificar al vendedor de una solicitud de parada entrante (CU-01), notificar al comprador cuando el vendedor acepta o rechaza (CU-01), y alertar a usuarios cercanos sobre una zona de riesgo nueva (CU-03). Esta decisión fue tomada implícitamente al incluir Firebase Cloud Messaging (FCM) en el stack inicial, sin evaluación formal de alternativas.

#### Opciones Evaluadas

| Opción | Fortalezas | Debilidades |
|---|---|---|
| **FCM (Firebase Cloud Messaging)** *(elegida)* | Gratuito; integrado con Firebase Admin SDK que ya usamos; plugin Flutter oficial (`firebase_messaging`); sin servidor adicional para envío | Android-only de facto en Iter. 1 (APNs requiere Apple Developer Program para iOS); sin action buttons nativos en mensajes de datos en Android < API 33 |
| **OneSignal** | Abstracción multi-plataforma (Android + iOS); panel de control rico | Capa adicional sobre FCM/APNs; costo a escala; dependencia de un tercer proveedor |
| **Push propio (WebSocket / SSE)** | Control total; bidireccional | Requiere infraestructura adicional permanentemente conectada; complejidad operacional alta; no apta para el tier gratuito |

#### Decisión

Se adopta **Firebase Cloud Messaging (FCM)** como canal único de notificaciones push en Iteración 1. El componente `NotificationHandler` (Flutter) gestiona la inicialización, el registro del token FCM y el despacho de tres tipos de evento a las pantallas correspondientes. El `NotificationService` (FastAPI) centraliza el envío mediante el Firebase Admin SDK.

#### Tipos de evento FCM definidos en Iter. 1

| Tipo de evento (`data.type`) | Origen | Destino | Acción en cliente |
|---|---|---|---|
| `stop_request_incoming` | `StopRequestRouter` | Vendedor | Muestra dialog de solicitud en `MapScreenVendor` |
| `stop_request_accepted` / `stop_request_rejected` | `StopRequestRouter` | Comprador | Navega a Tracking o devuelve al mapa |
| `risk_zone_alert` | `RiskZoneRouter` | Usuarios cercanos (fan-out) | Muestra alerta en la HomeScreen activa |

#### Consecuencias

**Positivas:**
- Cero costo: FCM es completamente gratuito para cualquier volumen.
- El Firebase Admin SDK ya está inicializado en FastAPI (`FirebaseAdminInit`), lo que significa que el envío de notificaciones no requiere ninguna dependencia adicional.
- Plugin Flutter `firebase_messaging` oficial, bien documentado y con mantenimiento activo.

**Negativas:**
- **Android-only de facto en Iter. 1:** Enviar notificaciones a dispositivos iOS requiere configurar APNs, lo que a su vez requiere una cuenta activa en el Apple Developer Program (costo: $99 USD/año). iOS queda fuera del alcance de Iter. 1.
- **Sin action buttons** en notificaciones de datos (mensajes `data-only`) en Android < API 33 sin configuración adicional de foreground service.
- **Sin push interactivo avanzado** (reply desde la notificación, imágenes enriquecidas): diferido a Iteración 3 si aplica.

**Revisión prevista:** Si en Iteración 3 se requiere soporte iOS, activar la configuración APNs en el proyecto Firebase y validar el flujo completo en dispositivos físicos iOS.

---

## TEMA D — Estado y UI

---

### ADR #4 — State Management en Flutter: Adopción de Riverpod

| Campo | Valor |
|---|---|
| **ID** | ADR-004 |
| **Estado** | ✅ Aceptado |
| **Fecha** | 17/04/2026 |
| **Iteración** | Iteración 1 |
| **Autores** | Los Borbotones — UBISAFE |

#### Contexto

La App Móvil Flutter de UBISAFE gestiona estado reactivo de naturaleza compleja y multi-pantalla:

- **Estado de autenticación:** sesión activa, rol del usuario, expiración del JWT.
- **Estado del GPS del vendedor:** activo / inactivo / error — necesario en `MapScreenVendor`, `GPSService` y la AppBar.
- **Stream de vendedores activos:** lista de `VendorMarker` actualizada en tiempo real desde RTDB — consumida por `MapScreenBuyer`.
- **Estado del ciclo de vida de una solicitud de parada:** `pending → accepted/rejected → completed` — consumido por `StopRequestModule`, `MapScreenBuyer` y la pantalla de seguimiento.
- **Lista de zonas de riesgo activo:** consultada al iniciar las HomeScreens y actualizada al recibir alertas FCM.

Compartir este estado entre múltiples widgets usando solo `setState` nativo requeriría pasar callbacks y datos a través de árboles de widgets profundos (*prop drilling*), generando código frágil. El equipo **no tiene experiencia previa** con ningún patrón de gestión de estado en Flutter.

#### Opciones Evaluadas

| Opción | Curva de aprendizaje | Ventajas | Desventajas |
|---|---|---|---|
| `setState` + `InheritedWidget` | Muy baja | Sin dependencias externas | Extremadamente verboso para estado global; no apto para streams multi-pantalla |
| **Provider** | Baja (~1 día) | Paquete oficial de Flutter, bien documentado | Depende del `context`; errores en tiempo de ejecución; no completamente type-safe |
| **Riverpod** *(elegida)* | Baja-media (~2-3 días) | Sin dependencia de `context`; type-safe en compilación; `StreamProvider` nativo para RTDB/FCM | Requiere aprender un nuevo paradigma |
| Bloc / Cubit | Alta (~1 semana) | Patrón establecido para apps grandes | Sobreingeniería para 3 CU; muy verboso |
| GetX | Baja | Sintaxis concisa | Antipatrones; dificulta testing; no recomendado por la comunidad Flutter |

#### Decisión

Se adopta **Riverpod 2.x** (`flutter_riverpod: ^2.5.1`) como solución de gestión de estado. Si el equipo evalúa al inicio del sprint que la curva de aprendizaje representa un riesgo para el calendario, se permite usar **Provider 6.x** como fallback temporal (mismos conceptos fundamentales; migración futura de bajo impacto). **La decisión final entre Riverpod y Provider se toma al inicio del primer sprint de implementación.**

#### Providers definidos en Iteración 1

| Provider | Tipo Riverpod | Estado que gestiona |
|---|---|---|
| `authStateProvider` | `StreamProvider<User?>` | Usuario autenticado (stream de Firebase Auth) |
| `userProfileProvider` | `FutureProvider<UserProfile>` | Perfil desde Firestore |
| `gpsStateProvider` | `StateProvider<GPSServiceState>` | Estado GPS del vendedor (`active \| inactive \| error_no_signal`) |
| `vendorMarkersProvider` | `StreamProvider<List<VendorMarker>>` | Vendedores activos desde RTDB |
| `stopRequestProvider` | `StateNotifierProvider<StopRequest?>` | Solicitud activa en curso |
| `activeRiskZonesProvider` | `FutureProvider<List<RiskZone>>` | Zonas de riesgo activas desde API |

#### Consecuencias

**Positivas:**
- Sin dependencia del `BuildContext` de Flutter: los providers pueden ser accedidos desde cualquier capa de la aplicación, incluyendo servicios no-widget.
- Type-safe en tiempo de compilación: los errores de tipo en el acceso a providers se detectan antes de ejecutar la app.
- `StreamProvider` maneja directamente los streams de Firebase RTDB y FCM sin boilerplate adicional.
- El fallback a Provider preserva la misma arquitectura conceptual con mínima reescritura.

**Negativas:**
- Curva de aprendizaje inicial de 2-3 días para un equipo sin experiencia en el patrón.
- La coexistencia temporal de Riverpod (principal) y Provider (fallback) durante el sprint podría generar inconsistencia en el código si no se define claramente cuándo aplica cada uno.

---

## TEMA E — Seguridad e Identidad

---

### ADR Retro-A — Firebase Auth como Proveedor de Identidad

| Campo | Valor |
|---|---|
| **ID** | ADR-Retro-A |
| **Estado** | ✅ Aceptado (retroactivo) |
| **Fecha** | 25/04/2026 (documentado retroactivamente) |
| **Decisión tomada implícitamente en:** | Iteración 1, Fase 0 |
| **Iteración** | Iteración 1 (retroactivo) |
| **Autores** | Los Borbotones — UBISAFE |

#### Contexto

UBISAFE requiere autenticación de usuarios con diferenciación de roles (BUYER / VENDOR). En Iteración 1, el mecanismo de autenticación fue establecido implícitamente al incluir Firebase Auth en el stack técnico durante la Fase 0, sin evaluación formal documentada de alternativas. Este ADR lo documenta retroactivamente para cubrir el Rationale Viewpoint de IEEE 1016-2009.

#### Opciones Evaluadas

| Opción | Fortalezas | Debilidades |
|---|---|---|
| **Firebase Auth** *(elegida)* | Gratuito; integrado nada más en el ecosistema Firebase del proyecto; JWT de 1 hora con refresco automático; `firebase_auth` plugin oficial para Flutter; Admin SDK disponible en FastAPI para verificar tokens | No expone control total sobre el almacenamiento de credenciales; menos flexible en flujos OAuth avanzados |
| **Auth0** | Dashboard rico; soporte multi-proveedor (Google, Apple, etc.); RBAC integrado | Costo desde $23/mes para > 7,500 MAU; dependencia de proveedor externo adicional; requiere configuración de reglas de autorización separadas |
| **Clerk** | Onboarding de usuario muy pulido; componentes UI preconstruidos | Costo similar a Auth0 a escala; menor madurez del SDK Flutter; dependencia adicional |
| **Backend propio (JWT + bcrypt)** | Control total | Requiere implementar almacenamiento seguro de contraseñas, rotación de tokens, refresh tokens; alta complejidad operacional para un equipo académico de 3 personas |

#### Decisión

Se adopta **Firebase Auth** como único proveedor de identidad para Iteración 1. El flujo de autenticación es:

1. App Flutter autentica con Firebase Auth SDK (email + contraseña en Iter. 1).
2. Firebase Auth emite un **JWT con expiración de 1 hora**; el SDK lo refresca automáticamente.
3. Cada solicitud al backend FastAPI incluye el JWT en el header `Authorization: Bearer <token>`.
4. `AuthMiddleware` (FastAPI) verifica el JWT usando `firebase_admin.auth.verify_id_token()` y extrae `uid` y `role` del perfil Firestore.
5. Al primer login exitoso, la app llama a `POST /auth/sync-profile` para crear o actualizar el perfil en la colección `users` de Firestore.

#### Justificación

- **Costo cero:** Firebase Auth es completamente gratuito para cualquier número de usuarios activos mensuales, a diferencia de Auth0 o Clerk.
- **Integración en el ecosistema Firebase:** El proyecto ya usa Firestore, RTDB y FCM. Firebase Auth añade zero complejidad operacional adicional: mismas credenciales, misma consola, mismo Admin SDK.
- **JWT compatible con FastAPI:** El token emitido por Firebase Auth puede ser verificado directamente con el Firebase Admin SDK (`firebase_admin.auth.verify_id_token()`), sin necesidad de configurar un servidor de autorización separado.
- **SDK Flutter oficial:** `firebase_auth` tiene soporte activo de Google y amplia documentación, reduciendo el riesgo de incompatibilidades con versiones del SDK de Flutter.

#### Consecuencias

**Positivas:**
- `AuthMiddleware` en FastAPI es una función de una sola llamada: `firebase_admin.auth.verify_id_token(token)` → extrae `uid` automáticamente.
- El stream `authStateChanges()` de Firebase Auth permite que la app reaccione instantáneamente a cambios de sesión (login, logout, expiración) sin polling.
- Zero infraestructura de autenticación propia: no hay base de datos de credenciales que mantener ni rotar.

**Negativas:**
- El rol del usuario (`BUYER`/`VENDOR`) no se almacena en el token JWT de Firebase Auth por defecto. Se almacena en Firestore (`users/{uid}.role`) y se consulta en cada request que requiera diferenciación de rol. Alternativa no implementada: Custom Claims en Firebase Auth (complejidad adicional en Iter. 1).
- El login en Iter. 1 es solo por email/contraseña. El soporte para login con Google, Apple o número de teléfono queda como mejora futura.

**Revisión prevista:** Si en Iteraciones 2-3 el número de proveedores de login crece o se requiere RBAC más granular, evaluar el uso de Firebase Auth Custom Claims para incrustar el rol en el JWT, eliminando la consulta extra a Firestore en cada request de FastAPI.

---

## TEMA F — Orquestación

---

### ADR #10 — Cloud Functions como Orquestador de Eventos [iter. 2]

| Campo | Valor |
|---|---|
| **ID** | ADR-010 |
| **Estado** | ✅ Aceptado |
| **Fecha** | 24/04/2026 |
| **Iteración** | Iteración 2 |
| **Autores** | Los Borbotones — UBISAFE |

#### Contexto

CU-05 (Reportar focos de infección) incluye el flujo alternativo 7A: "Alta densidad de reportes similares → UBISAFE agrupa los reportes en una sola alerta". El criterio de aceptación CA-05.3 exige agrupación visual de reportes similares cercanos. Esta lógica de detección de duplicados requiere ejecución server-side en respuesta a un evento (creación de un nuevo reporte), sin ser parte del flujo síncrono del endpoint REST.

#### Opciones Evaluadas

| Criterio | FastAPI job periódico | Cloud Function `onCreate` trigger *(elegida)* |
|---|---|---|
| Latencia de agrupación | Alta (depende del intervalo del job) | ✅ Baja (se dispara al crear el documento) |
| Complejidad de implementación | Media (requiere scheduler externo o cron) | Media (Firebase Platform, sin infraestructura adicional) |
| Consistencia con el stack Firebase-first | Requiere ir fuera del tier gratuito de Cloud Run | ✅ Tier gratuito Cloud Functions (2M invocaciones/mes) |
| Riesgo de curva de aprendizaje | Bajo (Python, similar al backend) | Medio (nuevo para el equipo, pero documentado) |

#### Decisión

Se adopta **Cloud Functions for Firebase (gen2)** como componente de orquestación para la detección de reportes duplicados. Lenguaje: **Python** (misma familia que FastAPI, sin cambio de lenguaje para el equipo).

**Función en alcance de Iteración 2:**

| Función | Trigger | Lógica |
|---|---|---|
| `aggregateDuplicateReports` | `onCreate` en `community_reports/{id}` | Al crear un nuevo reporte, busca reportes activos del mismo `threat_type` en radio ≤ 100 m. Si encuentra ≥ 1, marca el nuevo como `is_duplicate: true` y añade `canonical_report_id`. |

Cloud Functions **no reemplaza** la lógica de negocio síncrona de FastAPI (validaciones, transiciones de estado de CU-06). Solo maneja la detección asíncrona de duplicados, que no debe bloquear la respuesta al cliente.

#### Justificación

- **Asincronía adecuada:** La detección de duplicados no necesita estar en el camino crítico del `POST /community-reports`. El cliente recibe confirmación de creación (201) y el sistema marca el duplicado segundos después.
- **Trigger event-driven:** Un `onCreate` trigger es exactamente el patrón correcto: se dispara exactamente una vez por documento nuevo, sin polling.
- **Tier gratuito:** Cloud Functions for Firebase ofrece 2 millones de invocaciones gratuitas por mes, más que suficiente para el volumen académico.
- **Misma plataforma:** Cloud Functions es parte de Firebase Platform, con las mismas credenciales y el mismo proyecto. El equipo no gestiona infraestructura adicional.

#### Consecuencias

**Positivas:**
- La respuesta del `POST /community-reports` no se ve afectada por la lógica de detección de duplicados (asíncrona).
- El cliente Flutter puede mostrar el reporte inmediatamente con `is_duplicate: false` y actualizarlo cuando la Cloud Function lo marque (a través del listener de Firestore).
- Cloud Functions como contenedor nuevo en el C4 L2 del SDD, visible en la arquitectura del sistema.

**Negativas:**
- El equipo debe aprender a desplegar y depurar Cloud Functions for Firebase, lo que añade complejidad operacional moderada.
- El lenguaje Python para Cloud Functions gen2 requiere verificar compatibilidad con las dependencias de Firebase Admin SDK y Haversine disponibles en el runtime.
- Las funciones tienen un tiempo de arranque en frío (cold start) de ~1-3 s para gen2 Python; aceptable para detección de duplicados pero no apto para flujos síncronos de UI.

---

## TEMA G — Almacenamiento de Evidencias

---

### ADR #5 — Firebase Storage para Evidencias de Reportes Comunitarios [iter. 2]

| Campo | Valor |
|---|---|
| **ID** | ADR-005 |
| **Estado** | 🔵 Diferido — Iteración 3 (si aplica) |
| **Fecha** | 24/04/2026 |
| **Iteración** | Iteración 2 (evaluado y diferido) |
| **Autores** | Los Borbotones — UBISAFE |

#### Contexto

El plan de Iteración 2 anticipaba que CU-05 (Reportar focos de infección) podría incluir adjuntar evidencias fotográficas o de audio para respaldar el reporte. Si se hubiera implementado, habría requerido Firebase Storage como nuevo contenedor en el C4 L2 del SDD.

#### Análisis

Al revisar el SRS v2.1 exhaustivamente:
- El flujo normal de CU-05 no incluye ningún paso de "adjuntar archivo".
- Ningún criterio de aceptación de CU-05 menciona la carga de archivos.
- CU-06 (Verificar reportes) tampoco requiere evidencias adjuntas.
- CU-04 (Solicitar raite) no involucra archivos de ningún tipo.

#### Decisión

**Firebase Storage NO se implementa en Iteración 2.** La colección `community_reports` no incluye el campo `evidence_urls[]`. La decisión queda registrada para que, si en Iteración 3 el equipo o el cliente decide incluir fotografías de focos de infección, se active Firebase Storage con su respectivo ADR completo en esa iteración.

---

## TEMA H — Validación Comunitaria

---

### ADR #6 — Modelo de Validación Comunitaria: Votación Simple [iter. 2]

| Campo | Valor |
|---|---|
| **ID** | ADR-006 |
| **Estado** | ✅ Aceptado |
| **Fecha** | 24/04/2026 |
| **Iteración** | Iteración 2 |
| **Autores** | Los Borbotones — UBISAFE |

#### Contexto

CU-06 (Verificar reportes comunitarios) requiere que la comunidad valide los reportes de focos de infección. El SRS v2.1 especifica:
- CA-06.2: "cuando se supera el umbral definido (3), el sistema cambia su estado a `confirmado`"
- CA-06.3: "cuando el nivel de confianza cae por debajo del umbral (3 rechazos), UBISAFE lo marca como `descartado`"

Se evaluaron tres modelos alternativos para implementar este mecanismo de validación.

#### Opciones Evaluadas

| Modelo | Complejidad | Justificación en SRS | Resultado |
|---|---|---|---|
| **Votación simple (sí/no, umbral 3)** *(elegida)* | Baja | Directamente descrita en CA-06.2 y CA-06.3 | ✅ Elegida |
| Pesos por rol (voto VENDOR vale más) | Media | No mencionado en SRS | ❌ Rechazada |
| Sistema de puntos de reputación (`reputation_events`) | Alta | No mencionado en SRS | ❌ Diferida a Iter. 3 |

#### Decisión

Se implementa **votación simple binaria con umbral fijo de 3**:
- Cada usuario emite exactamente **un voto** por reporte (no modificable).
- El voto es binario: `"confirm"` (corrobora) o `"dismiss"` (desmiente).
- Umbral de confirmación: `confirm_count >= 3` → `status = confirmed`
- Umbral de rechazo: `dismiss_count >= 3` → `status = dismissed`
- Bloqueo de doble voto: FastAPI rechaza si `user_uid` ya existe en `validations[]`.
- El reportante no puede votar su propio reporte (`reporter_uid != request.auth.uid`).
- Los contadores `confirm_count` y `dismiss_count` son campos desnormalizados en el documento para evaluar el umbral en O(1).

#### Consecuencias

**Positivas:**
- Implementación directa del SRS sin suposiciones adicionales ni complejidad no requerida.
- El umbral de 3 es bajo, lo que facilita la activación de reportes en comunidades pequeñas (densidad de usuarios prevista: ~10 por sector).
- Contadores desnormalizados permiten evaluar umbrales sin iterar el array `validations[]`.

**Negativas / Deuda técnica:**
- Un actor malicioso con 3 cuentas distintas podría confirmar o descartar reportes sin base real. Mitigación futura: pesos por antigüedad de cuenta o verificación de identidad en Iteración 3.
- No hay mecanismo de desempate si el reporte expira con `confirm_count == dismiss_count`. Decisión tomada: el reporte expira en estado `expired` sin transitar a `confirmed` ni `dismissed`.
- La colección `reputation_events` (prevista en Iter. 1 como colección futura) **no se crea en Iter. 2** y se pospone a Iter. 3 de forma condicional.

---

## Sección §3.x — Deuda Técnica Declarada

Esta sección documenta las decisiones técnicas tomadas deliberadamente por razones de tiempo, costo o alcance, que se reconocen como deuda técnica a revisar en iteraciones futuras. La deuda técnica declarada no es un error de diseño: es una decisión consciente con trade-offs conocidos.

### DT-01 — Filtrado geográfico por Haversine en Python (client-side del servidor)

| Campo | Valor |
|---|---|
| **Afecta a** | `RiskZoneRouter` (`GET /risk-zones`), `CommunityReportRouter` (iter. 2) |
| **Detectada en** | Iteración 1 |
| **Decisión actual** | Bounding box en Firestore + filtrado Haversine en Python en FastAPI |
| **Revisión prevista** | Iteración 3 |

**Descripción:** Firestore no soporta queries nativas por radio geográfico. La solución actual calcula un bounding box (rango lat/lng) como primera aproximación en Firestore y aplica la fórmula de Haversine en el servidor Python para filtrar el resultado exacto. Este enfoque es correcto para el volumen de datos de Iteración 1 (< 1,000 documentos por colección), pero no escala eficientemente a densidades altas de reportes.

**Revisión propuesta:** En Iteración 3, evaluar la adopción de **Geohash** (bibliotecas `python-geohash` + `geoflutter`) o **GeoFirestore** para indexar documentos por geohash y hacer queries de proximidad directamente en Firestore, eliminando el paso de filtrado Python.

---

### DT-02 — Android-only en Iteración 1 (FCM sin APNs)

| Campo | Valor |
|---|---|
| **Afecta a** | `NotificationHandler` (Flutter), `NotificationService` (FastAPI) |
| **Detectada en** | Iteración 1 |
| **Decisión actual** | FCM solo para Android; iOS recibe silencio en notificaciones push |
| **Revisión prevista** | Antes de despliegue en producción real |

**Descripción:** FCM requiere APNs (Apple Push Notification Service) para entregar notificaciones a dispositivos iOS. La configuración de APNs requiere una cuenta activa en el Apple Developer Program. Sin esta configuración, los dispositivos iOS instalados con la app **no recibirán notificaciones push**, aunque la app sí podrá conectarse a Firestore y RTDB. En el contexto académico con dispositivos Android, esto no impacta el proyecto de Iteración 1. En un despliegue real, sería un defecto grave.

---

### DT-03 — Google Maps Platform a escala productiva

| Campo | Valor |
|---|---|
| **Afecta a** | `MapScreenBuyer`, `MapScreenVendor` (Flutter), Directions API (FastAPI) |
| **Detectada en** | Iteración 1 |
| **Decisión actual** | Google Maps Platform con crédito gratuito de $200 USD/mes |
| **Revisión prevista** | Antes de despliegue en producción real |

**Descripción:** El crédito gratuito mensual de Google Maps Platform ($200 USD) es suficiente para cubrir el uso en un proyecto académico. A escala real con usuarios activos, el costo de la API de Directions y el Maps JavaScript API puede superar este límite rápidamente. Las alternativas gratuitas (Mapbox con tier generoso, OpenStreetMap + OSRM) deberán evaluarse antes de pasar a producción.

---

### DT-04 — Rol de usuario almacenado en Firestore, no en Custom Claims de Firebase Auth

| Campo | Valor |
|---|---|
| **Afecta a** | `AuthMiddleware` (FastAPI), `AuthModule` (Flutter) |
| **Detectada en** | Iteración 1 |
| **Decisión actual** | Consulta a Firestore en cada request FastAPI que requiera diferenciación de rol |
| **Revisión prevista** | Iteración 2-3 si el volumen de requests lo justifica |

**Descripción:** El campo `role` del usuario se almacena en `users/{uid}.role` en Firestore. `AuthMiddleware` lo consulta en cada request que requiera diferenciación de roles. Esto añade una lectura de Firestore por request. La alternativa es usar **Firebase Auth Custom Claims** para incrustar el rol directamente en el JWT, eliminando la consulta extra. El impacto en Iter. 1 es mínimo dado el volumen de usuarios previsto.

---

## Resumen de cobertura — Fase 6'

| Paso | Output | Sección del SDD |
|---|---|---|
| **6'.1** | ADRs Retro-A (Firebase Auth), Retro-B (Google Maps), Retro-C (FCM) | §3 ADRs — completado retroactivo |
| **6'.2** | ADR #5 (Storage diferido), #6 (Votación simple), #7 (Geometría), #10 (Cloud Functions), #11 (Coexistencia) | §3 ADRs [iter. 2] |
| **6'.3** | Sección de Deuda Técnica Declarada (DT-01 a DT-04) | §3.x Deuda Técnica |
| **6'.4** | Organización temática (8 temas) + índice de ADRs | §3 estructura completa |

**Total de ADRs documentados:** 11 (4 de Iter. 1 + 3 retroactivos + 4 de Iter. 2 activos + 1 diferido)

---

## Historial del archivo

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| **V1.0** | 25/04/2026 | Alexis Córdova (con Claude) | Fase 6' completa. ADRs #1–#4 con texto canónico del equipo; Retro-A, Retro-B, Retro-C redactados; ADRs #5–#11 consolidados desde SDD2_FASE0 y SDD2_FASE3B. Deuda técnica DT-01 a DT-04 declarada. Organización temática en 8 temas. |

---

*Fase 6' completada. Output: `SDD2_FASE6_UBISAFE.md`. Este archivo es prerequisito para Fase 7' (Trazabilidad e historial V3.0).*
*Generado: 25/04/2026 — Los Borbotones / UBISAFE Iteración 2*
