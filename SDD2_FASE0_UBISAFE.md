# SDD2 — Fase 0': Preparación Iteración 2
## Decisiones anticipadas e impacto de CU-04 / CU-05 / CU-06
### UBISAFE · Los Borbotones · 24/04/2026

> **Propósito de este archivo:** Capturar las decisiones que desbloquean la paralelización de las fases 1', 2' y 3'. Producido en sesión pair (Alexis + Claude). Miguel debe leer este archivo antes de arrancar Fase 1' y Fase 4.A'.

---

## 0'.1 — Novedades de Iteración 2 respecto al SRS v2.1

### Casos de uso nuevos

| CU | Nombre | Actor(es) primario(s) | Prioridad | Dominio principal |
|---|---|---|---|---|
| **CU-04** | Solicitar raite | Comprador (solicita), Vendedor (atiende) | Alta | Dispatching (extendido) |
| **CU-05** | Reportar focos de infección | Comprador **y** Vendedor | Media | Safety (ampliado) → Community |
| **CU-06** | Verificar reportes comunitarios | Comprador **y** Vendedor | Media | Community (activa en iter. 2) |

### Elementos nuevos por CU

#### CU-04 — Solicitar raite
- **Pre-condición nueva:** el vendedor debe tener habilitada la opción de raite (`ride_enabled: boolean` en `users`)
- **Flujo crítico:** Comprador selecciona destino en mapa → UBISAFE valida disponibilidad del vendedor Y condiciones de seguridad de la ruta → notificación FCM al vendedor → vendedor acepta → ruta segura evitando zonas de riesgo → vendedor llega al punto de recogida → FCM al comprador → comprador sube → viaje al destino → UBISAFE registra finalización
- **Flujos alternativos:** vendedor no disponible (tiene parada activa o está dando raite), destino > 4 km desde punto de recogida, vendedor rechaza
- **Flujos de excepción:** pérdida de conexión GPS/internet (muestra última ubicación, notifica a ambos), cancelación por comprador antes del encuentro (vendedor vuelve a disponible)
- **Criterios de aceptación clave:**
  - CA-04.1: Notificación al vendedor en < 5 segundos
  - CA-04.2: Ruta segura evitando zonas de riesgo **HIGH y MEDIUM** *(resuelto: mismo criterio que `RiskZoneRouter` de CU-01)*
  - CA-04.3: Timeout **60 s** *(resuelto: igual que CU-01; el valor 15 s del SRS es un error — equipo confirmó 60 s)*
  - CA-04.4: Degradación controlada ante pérdida de conexión
- **Componentes implicados (nuevos):** `RideRequestModule` (Flutter), `RideRouter` (FastAPI), colección `rides` (Firestore)
- **Campo nuevo en `users`:** `ride_enabled: boolean` (solo VENDOR)

#### CU-05 — Reportar focos de infección
- **Actores primarios:** AMBOS roles (Comprador y Vendedor), a diferencia de CU-03 donde cualquier usuario reporta
- **Tipos de foco:** animal muerto, basura dispersa por perros (texto libre en SRS)
- **Radio:** usuario debe estar a ≤ 4 km del punto a reportar
- **Estado inicial:** `pending_validation` (diferencia clave vs. CU-03 que activa inmediatamente)
- **Flujo alternativo 7A clave:** "Alta densidad de reportes similares" → UBISAFE agrupa en una sola alerta (ver decisión 0'.3 — cómo se implementa)
- **Criterios de aceptación clave:**
  - CA-05.1: Registro en máx. 10 segundos
  - CA-05.2: Rechazo si usuario fuera del radio permitido
  - CA-05.3: Agrupación visual de reportes similares cercanos
  - CA-05.4: Retry automático ante pérdida de conexión
- **NO menciona** adjuntar fotos ni audio (ver decisión 0'.2)
- **Componentes implicados (nuevos):** `CommunityReportModule` (Flutter), `CommunityReportRouter` (FastAPI), colección `community_reports` (Firestore)

#### CU-06 — Verificar reportes comunitarios
- **Actores primarios:** AMBOS roles
- **Pre-condición:** reporte no ha sido verificado; usuario a ≤ 4 km del reporte
- **Acción:** confirmar o desmentir; UBISAFE actualiza "nivel de confianza"
- **Umbrales de estado:**
  - ≥ 3 confirmaciones → estado `confirmed`
  - ≥ 3 rechazos → estado `dismissed` (visibilidad atenuada hasta eliminar)
- **Bloqueo de doble voto:** el usuario que ya validó no puede volver a interactuar (condición 4A)
- **Criterios de aceptación clave:**
  - CA-06.1: Registro en máx. 10 segundos
  - CA-06.2: Estado → `confirmed` al superar umbral 3 confirmaciones
  - CA-06.3: Estado → `dismissed` al superar umbral 3 rechazos
- **Componentes implicados (nuevos):** `ReportValidationModule` (Flutter), `ReportValidationRouter` (FastAPI)
- **No define sistema de puntos de reputación** en el SRS (ver decisión 0'.5)

### Actores nuevos o extendidos

| Actor | Cambio en iter. 2 |
|---|---|
| **Comprador** | Ahora también es reportante (CU-05) y validador (CU-06); puede solicitar raite (CU-04) |
| **Vendedor** | Ahora puede ofrecer raites (CU-04, si `ride_enabled=true`); puede reportar (CU-05) y validar (CU-06) |
| **"Comunidad"** | Actor implícito colectivo en CU-06 (el conjunto de usuarios que valida reportes) — no requiere registro separado |

> **Conclusión para §2 del SDD:** No se añade un stakeholder nuevo formal. El actor "Comunidad" es el conjunto de compradores/vendedores ejerciendo la función de validación. Se extiende la tabla de actores existente con las nuevas responsabilidades.

### RNF que impactan iter. 2

| RNF | Impacto nuevo en iter. 2 |
|---|---|
| **RNF-01 Performance** | CA-04.1 exige notificación en < 5 s; CA-05.1 y CA-06.1 exigen registro en < 10 s; CA-04.3 timeout **60 s** (igual que CU-01) |
| **RNF-03 Confiabilidad** | CU-04 en curso requiere degradación controlada ante pérdida de GPS (CA-04.4); CU-05 y CU-06 requieren retry offline |
| **RNF-05 Seguridad** | Reglas Firestore nuevas: un usuario no puede validar su propio reporte; `rides` solo accesibles por buyer/vendor involucrados |

---

## 0'.2 — Decisión: ¿Firebase Storage entra en iter. 2?

**Respuesta: ❌ NO entra en iter. 2. Se pospone a iter. 3 (si aplica).**

### Análisis
El SRS v2.1 **no incluye adjuntar evidencias** (fotos, audio, video) en ninguno de los tres CU nuevos:

- **CU-05 flujo normal:** el usuario selecciona el tipo de foco y confirma el envío. No hay paso de adjuntar archivo.
- **CU-05 criterios de aceptación:** ningún CA menciona carga de archivo.
- **CU-06:** solo opera sobre reportes ya creados; no añade evidencias.
- **CU-04:** es un servicio de raite, sin archivos adjuntos.

### Consecuencias
- **Firebase Storage NO se añade** al C4 L2 en Fase 1'.
- La colección `community_reports` **no tendrá campo `evidence_urls[]`** en iter. 2.
- Si en iter. 3 el equipo decide incluir fotos de focos de infección, se activará Firebase Storage + ADR #5 en ese momento.
- **ADR #5 queda en estado "Diferido" (no redactar en iter. 2).**

---

## 0'.3 — Decisión: ¿Cloud Functions como contenedor en iter. 2?

**Respuesta: ✅ SÍ entra Cloud Functions, con alcance acotado.**

### Análisis
El flujo alternativo 7A de CU-05 exige que el sistema **detecte** múltiples reportes cercanos del mismo tipo y los **agrupe**. El CA-05.3 especifica agrupación visual, pero el flujo dice "UBISAFE agrupa los reportes en una sola alerta" —lo que implica lógica server-side.

**¿FastAPI job vs. Cloud Function trigger?**

| Criterio | FastAPI job periódico | Cloud Function `onCreate` trigger |
|---|---|---|
| Latencia de agrupación | Alta (depende del intervalo del job) | Baja (se dispara al crear el documento) |
| Complejidad de implementación | Media (requiere scheduler externo o cron) | Media (pero Cloud Functions ya está en Firebase Platform, sin infraestructura adicional) |
| Consistencia con el stack | Requiere ir fuera del tier gratuito de Cloud Run para schedulers | Tier gratuito de Cloud Functions (2M invocaciones/mes) |
| Alineación con ADR #2 | Coherente con el enfoque Firebase-first | Coherente con el enfoque Firebase-first |
| Riesgo de curva de aprendizaje | Bajo (Python, similar al backend) | Medio (Node.js o Python, nuevo para el equipo) |

**Decisión:** Cloud Function `onCreate` en `community_reports` para detectar duplicados. La validación de umbral (CU-06) permanece en FastAPI como endpoint PATCH (es lógica síncrona de negocio, no trigger asíncrono).

### Función en alcance iter. 2

| Función | Trigger | Lógica |
|---|---|---|
| `aggregateDuplicateReports` | `onCreate` en `community_reports/{id}` | Al crear un nuevo reporte, busca reportes activos del mismo `threat_type` en radio ≤ **100 m** *(resuelto)*. Si encuentra ≥ 1, marca el nuevo como `is_duplicate: true` y añade `canonical_report_id` referenciando al reporte original. |

### Consecuencias
- Cloud Functions **se añade como contenedor nuevo** en C4 L2 (Fase 1' — tarea de Miguel).
- La función está en **Node.js** (Cloud Functions gen2) para aprovechar el SDK de Firebase Admin que el equipo ya conoce de FastAPI via Python; **alternativa:** Cloud Functions for Python (gen2) para mantener un solo lenguaje.
  - **Recomendación:** Python gen2 (misma familia que FastAPI, sin cambio de lenguaje).
- **ADR #10 — Cloud Functions como orquestador:** APROBADO. Se redacta en Fase 6'.

---

## 0'.4 — Decisión: ¿Colección unificada de reportes o dos separadas?

**Respuesta: ✅ DOS colecciones separadas (`risk_zones` + `community_reports`) coexisten.**

### Análisis

| Criterio | Unificar en una colección | Dos colecciones separadas |
|---|---|---|
| Compatibilidad con iter. 1 | Rompe `risk_zones` existente; requiere migración | `risk_zones` queda intacta; zero breaking changes |
| Modelo de datos | Campos opcionales (nulos) para la mitad de documentos | Cada colección tiene solo sus campos; sin campos nulos |
| Lógica de negocio | Un solo router con condicionales complejos | Dos routers pequeños y especializados |
| Queries | Hay que filtrar por tipo de reporte en todas las queries | Queries simples sobre cada colección |
| Extensibilidad | Difícil distinguir futuros tipos de reporte | Fácil agregar más colecciones en iter. 3 |
| Riesgo operativo | Alto: toca código de CU-03 ya diseñado | Bajo: CU-03 no se modifica |

**Decisión:** `risk_zones` (iter. 1, CU-03) y `community_reports` (iter. 2, CU-05/06) **coexisten como colecciones independientes**.

### Diferencias de modelo que justifican la separación

| Campo/Comportamiento | `risk_zones` (CU-03) | `community_reports` (CU-05/06) |
|---|---|---|
| Creado por | Cualquier usuario, instantáneamente activo | Cualquier usuario, estado inicial `pending_validation` |
| Ciclo de vida | `active → expired` (24h automático) | `pending_validation → confirmed / dismissed / expired` (también expira a las **24h** igual que `risk_zones` *(resuelto)*) |
| Validación comunitaria | ❌ No | ✅ Sí (umbral de votos) |
| Tipo de amenaza | Cualquiera (`risk_level: HIGH/MEDIUM/LOW`) | Focos de infección (`threat_type`: `animal_muerto` \| `zona_sucia`) |
| Geometría | Círculo (GeoPoint + radius) | Círculo en iter. 2 (radio fijo 15 m, ver decisión 0'.6) |
| Visibilidad en mapa | Solo `active` | Visible desde `pending_validation` con leyenda **"Pendiente"**; cambia a **"Validado"** al llegar a `confirmed` *(resuelto)* |
| Color en mapa | Según `risk_level` (rojo/naranja/azul) | `animal_muerto` → **negro**; `zona_sucia` → **café** *(resuelto)* |
| Impacto en rutas vendedor | ✅ Bloquea rutas HIGH y MEDIUM | ❌ **Solo informativo, no bloquea rutas** *(resuelto)* |
| Duplicados | Sin lógica de agrupación | Cloud Function detecta y agrupa (radio 100 m, mismo `threat_type`) |

### Consecuencias
- **ADR #11 — Coexistencia:** APROBADO, dos colecciones. Se redacta en Fase 6'.
- En §8.3 del SDD (colecciones previstas iter. 2-3): `community_reports` pasa a "diseñada en iter. 2"; `risk_zones` permanece en iter. 1.
- El componente `RiskZoneRouter` (FastAPI) **no se modifica**; se crea `CommunityReportRouter` nuevo.

---

## 0'.5 — Decisión: Modelo de validación de CU-06

**Respuesta: ✅ Votación simple (sí/no) con umbral fijo de 3. Sin puntos de reputación en iter. 2.**

### Análisis
El SRS v2.1 especifica:
- CA-06.2: "cuando se supera el umbral definido (3), entonces el sistema cambia su estado a `confirmado`"
- CA-06.3: "cuando el nivel de confianza cae por debajo del umbral [3 rechazos], entonces UBISAFE lo marca como `descartado`"
- El SRS habla de "nivel de confianza" pero **no define pesos por rol ni puntos de reputación**

**Opciones evaluadas:**

| Modelo | Complejidad | Justificación en SRS | Recomendación |
|---|---|---|---|
| **Votación simple (sí/no, umbral 3)** | Baja | Directamente descrita en CA-06.2 y CA-06.3 | ✅ **Usar en iter. 2** |
| Pesos por rol (VENDOR voto vale más) | Media | No mencionada; asumiría que vendedores tienen más contexto | ❌ No en SRS; añade complejidad innecesaria |
| Puntos de reputación (`reputation_events`) | Alta | No mencionada en ningún CU del SRS v2.1 | ❌ Diferir a iter. 3 si aplica |

### Consecuencias
- El modelo de datos de `community_reports` incluirá:
  - `validations: [{user_uid, verdict: 'confirm'|'dismiss', timestamp}]`
  - `confirm_count: integer` (contador desnormalizado para performance)
  - `dismiss_count: integer`
  - Regla de negocio en FastAPI: si `confirm_count >= 3` → `status = confirmed`; si `dismiss_count >= 3` → `status = dismissed`
- La colección `reputation_events` **NO se crea en iter. 2.**
- **ADR #6 — Votación simple:** APROBADO. Se redacta en Fase 6'.

---

## 0'.6 — Decisión: Geometría de zonas de riesgo

**Respuesta: ✅ Se mantienen círculos (GeoPoint + radius) para `community_reports` en iter. 2. Polígonos diferidos a iter. 3.**

### Análisis
El plan iter. 2 anticipaba que CU-05 requeriría polígonos. Sin embargo, al revisar el SRS v2.1:

- CU-05 flujo normal: "UBISAFE **obtiene la ubicación actual** del comprador/vendedor" — el sistema toma la posición GPS del usuario, no le pide dibujar un polígono.
- CU-05 no tiene ningún paso de "dibujar área" o "seleccionar tramo".
- Los focos de infección son **puntos de origen** (donde el usuario está parado), no áreas extendidas.
- CU-06 dice "localización del reporte" (singular, un punto).

**Comparación:**

| Criterio | Polígono (GeoJSON) | Círculo (GeoPoint + radius) |
|---|---|---|
| Compatibilidad con SRS | No requerida explícitamente | Compatible con el flujo descrito |
| UX de creación | Compleja (requiere modo polígono en mapa) | Simple (autofill con ubicación GPS) |
| Complejidad de queries | Alta (cálculos geométricos) | Igual que iter. 1 (bounding box + Haversine) |
| Consistencia con `risk_zones` | Rompe consistencia | Mantiene consistencia |
| Esfuerzo de implementación | Alto | Bajo (reutiliza lógica de `risk_zones`) |

**Decisión:** `community_reports` usa el mismo modelo geométrico que `risk_zones` en iter. 2: `location: GeoPoint` + `radius_meters: number` (valor fijo **15 m** *(resuelto)* — no configurable por el usuario en iter. 2).

### Consecuencias
- No se requiere `DestinationPicker` para CU-05 (sí para CU-04).
- El widget de mapa no necesita modo "polígono" en iter. 2.
- `SDD_FASE5_UBISAFE.md` §8.1 Design System: los tokens de polígono de severidad planificados en Fase 5A' se simplifican — solo se necesitan círculos con colores de severidad.
- **ADR #7 — Geometría:** Círculos en iter. 2, polígonos evaluados en iter. 3. Se redacta en Fase 6'.

---

## 0'.7 — Actualización §1.2 Alcance del SDD

> **Instrucción para Alexis al integrar al .docx:** Reemplazar el párrafo de §1.2 "Alcance" por el siguiente texto, que extiende el alcance original con iter. 2. Marcar la sección añadida con **[iter. 2]**.

---

### §1.2 Alcance — Versión extendida [iter. 1 + iter. 2]

El producto **UBISAFE** es una aplicación de logística y seguridad comunitaria que conecta vendedores ambulantes con compradores en zonas semiurbanas, reduciendo la exposición peatonal a riesgos como jaurías de perros callejeros. El sistema se desarrolla de forma iterativa e incremental bajo la metodología Scrum.

**Iteración 1 — Base de Movilidad y Ubicación**

La primera iteración establece el núcleo funcional del producto mediante tres módulos:

- **CU-01 Solicitar parada a puerta:** El comprador solicita que el vendedor se detenga frente a su domicilio. El sistema valida la ubicación, traza una ruta segura evitando zonas de riesgo y notifica la llegada del vendedor.
- **CU-02 Activar radar de visibilidad:** El vendedor activa su presencia en el mapa en tiempo real, haciéndose visible para los compradores en un radio de 4 km.
- **CU-03 Bloquear zona por riesgo activo:** Cualquier usuario puede reportar una zona georreferenciada de riesgo (jaurías, accidentes, robos) que aparece en el mapa de todos los usuarios y restringe las rutas de navegación del vendedor.

**Iteración 2 — Escudo Comunitario [iter. 2]**

La segunda iteración extiende el producto con tres módulos que añaden capacidades de movilidad asistida y reporte colaborativo con validación comunitaria:

- **CU-04 Solicitar raite:** El comprador puede solicitar ser transportado al destino de su elección por un vendedor que haya habilitado esta opción desde el menú lateral. El sistema valida disponibilidad, traza una ruta segura evitando zonas de riesgo HIGH y MEDIUM, y gestiona el ciclo completo del acompañamiento hasta la confirmación de llegada al destino. El timeout de respuesta del vendedor es de 60 segundos.
- **CU-05 Reportar focos de infección:** Compradores y vendedores pueden reportar focos de infección georreferenciados (cadáveres de animales, zonas sucias por destrozos) desde su ubicación actual. El reporte se crea con estado `pendiente de validación` y se notifica a usuarios cercanos en un radio de 4 km. El sistema detecta y agrupa reportes duplicados cercanos del mismo tipo.
- **CU-06 Verificar reportes comunitarios:** Compradores y vendedores pueden corroborar o desmentir un reporte activo dentro de su radio de 4 km. El sistema actualiza el nivel de confianza del reporte según el número de confirmaciones o rechazos recibidos, activando o descartando el reporte al superar el umbral definido (3 validaciones del mismo tipo).

**Lo que UBISAFE no contempla en ninguna iteración planificada:**
- Procesamiento o mediación de pagos entre comprador y vendedor.
- Sistema de mensajería o chat directo entre usuarios.
- Gestión de inventario o catálogo de productos del vendedor.

---

## Resumen ejecutivo de decisiones (todas cerradas — V2.0)

| Decisión | Resultado definitivo | ADR | Fase que lo desarrolla |
|---|---|---|---|
| **Firebase Storage en iter. 2** | ❌ No entra — SRS no requiere adjuntar evidencias | #5 diferido | — (iter. 3 si aplica) |
| **Cloud Functions en iter. 2** | ✅ Entra — 1 función `aggregateDuplicateReports` (Python gen2), radio de detección **100 m** | #10 aprobado | Fase 1' (diagrama C4), Fase 2' (componente), Fase 6' (ADR) |
| **Colección unificada de reportes** | ❌ No — coexistencia: `risk_zones` + `community_reports` (expiración **24 h**, igual que `risk_zones`) | #11 aprobado | Fase 3.B' (modelo), Fase 6' (ADR) |
| **Modelo de validación CU-06** | ✅ Votación simple sí/no, umbral 3. Sin `reputation_events`. Reportes visibles desde `pending_validation` | #6 aprobado | Fase 3.B' (modelo), Fase 4.B' (secuencias), Fase 6' (ADR) |
| **Geometría de zonas** | ✅ Círculos, radio fijo **15 m**, sin polígonos en iter. 2. Colores: negro (cadáver), café (zona sucia). Solo informativos, no bloquean rutas | #7 aprobado | Fase 3.B' (modelo), Fase 5A' (tokens), Fase 6' (ADR) |
| **Timeout CU-04** | ✅ **60 s** — igual que CU-01. El valor 15 s del SRS es un error del documento | — | Fase 4.A' (`RideRouter`) |
| **`ride_enabled` — ubicación UI** | ✅ **Menú Lateral (Drawer)** — nueva entrada visible solo para VENDOR | — | Fase 5B.alt' (Drawer), Fase 3.A' (modelo) |
| **`ride_enabled` — persistencia** | ✅ **Persistente en Firestore** (`users.ride_enabled: boolean`). No se resetea al cerrar app | — | Fase 3.A' (modelo `users`) |
| **Ruta CU-04 evita niveles** | ✅ **HIGH + MEDIUM** — misma lógica que `RiskZoneRouter` de CU-01 | — | Fase 4.A' (secuencia), Fase 2' (componente `RideRouter`) |

---

## Lista de archivos que Miguel necesita antes de Fase 1' y 4.A'

> **Para el handoff a Miguel:**

Miguel debe tener acceso a los siguientes archivos antes de empezar Fase 1':
1. `SDD2_FASE0_UBISAFE.md` ← **este archivo**
2. `SDD_FASE1_UBISAFE.md` (C4 L1–L2 de iter. 1)
3. `RESUMEN_SDD_UBISAFE.md` (contexto consolidado iter. 1)

Y antes de Fase 4.A':
4. `SDD2_FASE3A_UBISAFE.md` (modelo `rides` — que produce Alexis en Fase 3.A')
5. `SDD_FASE4_UBISAFE.md` (convenciones de diagramas de secuencia iter. 1)

---

## Decisiones complementarias resueltas en pair Alexis + Miguel

> Todas las preguntas abiertas de la V1.0 han quedado resueltas. Se incorporan como **decisiones definitivas** para las fases subsiguientes.

| # | Pregunta original | Decisión definitiva | Impacta |
|---|---|---|---|
| **A-P1** | ¿Timeout CU-04 es 15 s (CA-04.3) o 60 s (igual que CU-01)? | **60 s en ambos CU-01 y CU-04.** El valor 15 s del SRS es error; el equipo confirma uniformidad. | Fase 4.A', `RideRouter` |
| **A-P2** | ¿`ride_enabled` toggle va en Mi Perfil o en HomeV? | **En el Menú Lateral (Drawer)**, nueva entrada visible solo para VENDOR. Perfil lo ocultaría; HomeV lo haría intrusivo. | Fase 3.A' (modelo: persistente), Fase 5B.alt' (Drawer extendido) |
| **A-P3** | ¿Radio de `community_reports` fijo o configurable? | **15 m fijo.** No configurable por el usuario en iter. 2. | Fase 3.B' (campo `radius_meters: 15`), Fase 5B' |
| **A-P4** | ¿`community_reports` confirmados bloquean rutas o solo informativos? | **Solo informativos.** No bloquean rutas del vendedor. Color en mapa: **negro** para `animal_muerto`, **café** para `zona_sucia`. | Fase 3.B', 4.B', 5A' (tokens de color) |
| **M-P1** | ¿`community_reports` expiran en 24h como `risk_zones`? | **Sí, expiran en 24h.** Misma lógica que `risk_zones`: campo `expires_at = created_at + 24h`. | Fase 3.B' (modelo BD) |
| **M-P2** | ¿Radio de agrupación para `aggregateDuplicateReports`? (Miguel propuso 50 m) | **100 m.** Radio de detección de duplicados del mismo `threat_type`. | Fase 2' (Cloud Function), Fase 3.B' |
| **M-P3** | ¿El mapa muestra reportes en `pending_validation` o solo `confirmed`? | **Se muestran desde `pending_validation`** con leyenda "Pendiente". Cuando pasan a `confirmed`, cambia a leyenda "Validado". | Fase 4.B' (secuencias), Fase 5B' (wireframes) |
| **M-P4** | ¿`ride_enabled` es persistente en Firestore o se resetea al cerrar app? | **Persistente.** Se guarda en `users.ride_enabled: boolean` y sobrevive al cerrar la app. Diferente al radar GPS (CU-02) que sí se resetea. | Fase 3.A' (modelo `users`) |
| **M-P5** | ¿La ruta de CU-04 evita solo zonas HIGH o también MEDIUM? | **HIGH y MEDIUM.** Misma lógica que `RiskZoneRouter` de CU-01. | Fase 4.A' (`RideRouter`), Fase 2' (componentes) |

---

## Historial de este archivo

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| V1.0 | 24/04/2026 | Alexis Córdova (con Claude) | Fase 0' completa — 5 decisiones + mapeo CU iter. 2 + §1.2 extendido |
| V2.0 | 24/04/2026 | Alexis Córdova (con Claude) — cruce con archivo de Miguel | Resolución de todas las preguntas abiertas: timeout CU-04 = 60 s, `ride_enabled` en Drawer y persistente, radio `community_reports` = 15 m, radio agrupación = 100 m, expiración 24 h, visibilidad desde `pending_validation`, colores negro/café, rutas evitan HIGH+MEDIUM. Sin preguntas abiertas pendientes. |
