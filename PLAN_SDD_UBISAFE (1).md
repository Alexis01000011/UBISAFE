# Plan Maestro — System Design Document (SDD) de UBISAFE
## Los Borbotones · Iteración 1
### Versión 2.0 — Actualización del 17/04/2026

> **⚠️ Esta es la V2 del plan.** Se incorporaron decisiones tomadas tras la revisión arquitectónica del 17/04/2026 (ver `REVISION_ARQUITECTURA_UBISAFE.md` y `ANALISIS_ITER2_ITER3_UBISAFE.md`). Los cambios se marcan con **[V2]** en cada sección. El historial completo está al final del documento.

---

## Instrucciones de uso para Claude

> **Este documento es el plan de trabajo para construir el SDD de UBISAFE.** Está pensado para usarse en múltiples chats de forma progresiva.
>
> **Al iniciar una nueva sesión de trabajo con este plan:**
> 1. Pregunta a Alexis: "¿En qué fase/paso del plan vamos?" o bien infiere la fase actual a partir del contexto de la conversación (archivos ya creados, diagramas ya aprobados, etc.).
> 2. No repitas trabajo de fases ya completadas a menos que Alexis lo pida explícitamente.
> 3. Antes de iniciar una fase, confirma brevemente el alcance de la sesión: "¿Trabajamos toda la Fase X o solo ciertos pasos?"
> 4. Al terminar cada paso, marca el progreso y pregunta si se avanza al siguiente o se hace pausa.
> 5. Usa las skills sugeridas en cada paso cuando estén disponibles.
> 6. Recuerda: el output de cada fase es Markdown + diagramas Mermaid que Alexis integrará manualmente a un .docx.
>
> **[V2] Punto de re-entrada tras la actualización:** Las Fases 0, 1 y 2 están completas pero requieren **pequeñas adiciones retroactivas** (sección 0.5, 0.6 y 2.5 nuevas). Se recomienda retomar desde **Fase 2.5** y luego avanzar a **Fase 3**, que es donde aterrizan las decisiones más sustanciales derivadas de la revisión.
>
> **[V2] Separación iter. 1 vs iter. 2-3:** este plan sigue siendo exclusivo para iter. 1. Se anticipan ADRs de iter. 2-3 (#5 a #11) para que el equipo los tenga presentes, pero **NO entran al SDD final de iter. 1**. Solo los ADRs #1 a #4 se documentan en el entregable final.

---

## 0. Filosofía del plan

Este plan está diseñado para producir un SDD **sección por sección**, donde cada fase genera artefactos concretos (diagramas, textos, mockups) que Alexis integrará manualmente en un `.docx` con formato final. El plan está alineado con tres marcos de verificación simultáneos:

| # | Marco | Propósito |
|---|---|---|
| F1 | **IEEE 1016-2009** | Estructura estándar del SDD |
| F2 | **Checklist del Profesor** | 6 criterios cualitativos de evaluación |
| F3 | **Checklist del Equipo** | 6 criterios de verificación interna |

Cada fase indica qué criterios de F1/F2/F3 cubre, para que al terminar el plan completo tengamos cobertura total.

---

## 1. Estructura propuesta del SDD (basada en IEEE 1016-2009)

El IEEE 1016-2009 define un SDD como un conjunto de **Design Views** (vistas de diseño), cada una con sus **Design Elements** y **Design Overlays**. Adaptaremos esto al contexto académico de UBISAFE:

| Sección                              | Contenido                                                                                                                                                  | Vista IEEE 1016                          |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| 1. Introducción                      | Propósito, alcance, audiencia, referencias, glosario                                                                                                       | Identificación del SDD                   |
| 2. Stakeholders y Concerns           | Quiénes consumirán el SDD y qué les importa                                                                                                                | Design Stakeholders & Concerns           |
| 3. Decisiones Arquitectónicas (ADRs) | Trade-offs y justificaciones clave. Va antes de los diagramas para que el equipo y el lector entiendan las decisiones *antes* de ver el diseño resultante. | Rationale Viewpoint                      |
| 4. Vista de Contexto (C4 L1)         | Diagrama de contexto del sistema                                                                                                                           | Context Viewpoint                        |
| 5. Vista de Contenedores (C4 L2)     | Contenedores principales y sus interacciones                                                                                                               | Composition Viewpoint                    |
| 6. Vista de Componentes (C4 L3)      | Componentes internos de cada contenedor                                                                                                                    | Composition Viewpoint (detalle)          |
| 7. Diseño de Base de Datos           | Modelo de datos Firestore + RTDB, esquemas, relaciones                                                                                                     | Information Viewpoint                    |
| 8. Diseño de Interfaces de Usuario   | Wireframes, mockups, sistema de diseño, navegación                                                                                                         | Interface Viewpoint                      |
| 9. Diagramas de Secuencia            | Flujos dinámicos por caso de uso                                                                                                                           | Interaction Viewpoint                    |
| 10. Diagrama de Navegación           | Flujo de pantallas completo                                                                                                                                | Interface Viewpoint (complemento)        |
| 11. Estructura del Proyecto          | Descripción textual de la organización de paquetes/módulos                                                                                                 | Detailed Design Viewpoint (simplificado) |
| 12. Trazabilidad                     | Mapeo SRS → componentes → interfaces                                                                                                                       | Design Overlay                           |
| 13. Historial de Versiones           | Control de cambios por iteración                                                                                                                           | Identificación del SDD                   |

---

## 2. Fases de ejecución

### FASE 0 — Preparación y alineación
**Objetivo:** Establecer bases de diseño antes de diagramar.

**Estado:** ✅ Completada parcialmente. **[V2]** Se añaden pasos 0.5 y 0.6 retroactivos derivados de la revisión del 17/04.

| Paso         | Actividad                                                                                                                                                                                                                                         | Skill sugerida              | Output                               |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- | ------------------------------------ |
| 0.1          | Definir Design Stakeholders & Concerns (quién lee el SDD y qué espera)                                                                                                                                                                            | —                           | Texto para sección 2                 |
| 0.2          | Revisar y confirmar stack técnico definitivo para iter. 1                                                                                                                                                                                         | `/engineering:architecture` | Confirmación escrita                 |
| 0.3          | Definir el **sistema de diseño visual** (paleta de colores, tipografía, tamaños de botones, espaciados, iconografía) para que todas las interfaces sean coherentes                                                                                | `/design:design-system`     | Design tokens documentados           |
| 0.4          | Redactar sección 1 (Introducción) del SDD                                                                                                                                                                                                         | —                           | Texto Markdown                       |
| **0.5 [V2]** | **Definir la organización de módulos por dominio (bounded contexts):** Identity & Access · Presence · Dispatching · Safety · Community. Esta organización aplicará tanto a Flutter como a FastAPI y reemplaza la división "layer-first" original. | `/engineering:architecture` | Tabla de dominios + mapeo CU→dominio |
| **0.6 [V2]** | **Redactar ADR #4 — State Management en Flutter:** decisión de adoptar **Riverpod** (con Provider como fallback si el equipo prefiere menor inversión inicial). Esta decisión sí entra al SDD iter. 1.                                            | `/engineering:architecture` | ADR en Markdown                      |

**Cubre:** F1 (secciones 1-2), F3 (estándar de formato). **[V2]** Adicionalmente F1 (Rationale Viewpoint para ADR #4).

---

### FASE 1 — Arquitectura de alto nivel (C4 Niveles 1-2)
**Objetivo:** Definir el contexto y los contenedores del sistema.

**Estado:** ✅ Completada (salida en `SDD_FASE1_UBISAFE.md`). **[V2]** No se reabre, pero se listan decisiones implícitas para documentar como ADRs retroactivos en Fase 6.

| Paso | Actividad                                                                                                                                      | Skill sugerida               | Output                              |
| ---- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- | ----------------------------------- |
| 1.1  | **Diagrama C4 Nivel 1 — Contexto:** UBISAFE como caja negra, actores externos (Comprador, Vendedor), sistemas externos (Google Maps, Firebase) | `/engineering:system-design` | Diagrama Mermaid + imagen exportada |
| 1.2  | **Diagrama C4 Nivel 2 — Contenedores:** App Flutter, API FastAPI, Firestore, RTDB, Firebase Auth, FCM, Google Maps SDK/Directions API          | `/engineering:system-design` | Diagrama Mermaid + imagen exportada |
| 1.3  | Texto descriptivo de cada contenedor: responsabilidad, tecnología, protocolos de comunicación                                                  | `/engineering:documentation` | Texto Markdown                      |
| 1.4  | **ADR #1:** Justificación de monolito FastAPI vs. microservicios                                                                               | `/engineering:architecture`  | ADR en Markdown                     |
| 1.5  | **ADR #2:** Justificación de GPS vía FastAPI vs. directo a Firebase                                                                            | `/engineering:architecture`  | ADR en Markdown                     |

**Cubre:** F1 (Context Viewpoint, Composition Viewpoint), F2 (componentes y relaciones, modelo C4), F3 (componentes y relaciones, diagramas claros)

**Nota:** El C4 L1 ya fue aprobado previamente. Revisaremos si necesita actualizaciones.

**[V2] Decisiones implícitas detectadas en Fase 1** — documentar en Fase 6 como ADRs retroactivos (entran al SDD iter. 1):

| Decisión implícita | ADR que la documentará |
|---|---|
| Firebase Auth como Identity Provider (no Auth0/Clerk/backend propio) | ADR retroactivo a incluir en §10 |
| Google Maps SDK + Directions API (no Mapbox/OSRM) — con riesgo de costo | ADR retroactivo con nota de revisión post-TSP |
| FCM como canal único de push (implica Android-only de facto en iter. 1) | ADR retroactivo |
| Cálculo Haversine client-side para filtrar vendedores en 4 km | Deuda técnica declarada (revisar iter. 3 o post-TSP) |

---

### FASE 2 — Arquitectura de detalle (C4 Nivel 3)
**Objetivo:** Descomponer cada contenedor en sus componentes internos.

**Estado:** ✅ Completada (salida en `SDD_FASE2_UBISAFE.md`). **[V2]** Se añade paso 2.5 para reorganización por dominios. Los pasos 2.1-2.4 siguen válidos; el paso 2.4 se **reemplaza** por la nueva estructura del paso 2.5.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 2.1 | **C4 L3 — App Flutter:** Componentes internos (MapScreen, AuthModule, NotificationHandler, GPSService, RiskReportModule, VendorTracker) | `/engineering:system-design` | Diagrama Mermaid |
| 2.2 | **C4 L3 — API FastAPI:** Componentes internos (AuthRouter, LocationRouter, RiskZoneRouter, StopRequestRouter, NotificationService) | `/engineering:system-design` | Diagrama Mermaid |
| 2.3 | Texto descriptivo de cada componente: responsabilidad, interfaces expuestas, dependencias | `/engineering:documentation` | Texto Markdown |
| 2.4 | **Estructura del proyecto (texto):** Descripción breve de la organización de carpetas/paquetes de Flutter y FastAPI. No es un diagrama formal, solo una referencia textual de cómo se organiza el código para dar contexto a los componentes del C4 L3. | — | Texto Markdown breve |
| **2.5 [V2]** | **Reorganizar la estructura del proyecto y los componentes C4 L3 por dominios (bounded contexts):** mapear cada uno de los 9 componentes Flutter y 7 componentes FastAPI al dominio correspondiente (Identity · Presence · Dispatching · Safety · Community). Actualizar §5.3 del SDD agrupando componentes por dominio y §11 (Estructura del Proyecto) con las carpetas `lib/features/identity/`, `lib/features/presence/`, etc. en Flutter y `ubisafe_api/modules/identity/`, etc. en FastAPI. | `/engineering:architecture` + `/engineering:documentation` | Estructura de carpetas actualizada + §5.3 reagrupada |

**Cubre:** F1 (Composition Viewpoint detallado, Detailed Design Viewpoint simplificado), F2 (detalles de componentes, consistencia), F3 (detalles de componentes, consistencia)

**[V2] Mapeo dominio → componentes (referencia rápida):**

| Dominio | Componentes Flutter | Componentes FastAPI |
|---|---|---|
| **Identity & Access** | AuthModule, DrawerModule (parcial) | AuthRouter, AuthMiddleware |
| **Presence** | GPSService, VendorTracker | (ninguno en iter. 1 — GPS va directo a RTDB) |
| **Dispatching** | MapScreenBuyer, MapScreenVendor (parcial), StopRequestModule | StopRequestRouter |
| **Safety** | RiskReportModule | RiskZoneRouter |
| **Community** | (vacío en iter. 1) | (vacío en iter. 1) |
| **Transversales (shared)** | NotificationHandler, api_client | FirebaseAdminInit, FirestoreService, NotificationService |

---

### FASE 3 — Diseño de Base de Datos
**Objetivo:** Modelar completamente la capa de datos.

**Estado:** ⬜ Pendiente. **[V2]** Fase ampliada con pasos 3.5, 3.6 y 3.7 derivados de la revisión.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 3.1 | Diagrama ER / modelo de datos conceptual (entidades: User, Vendor, Buyer, RiskZone, StopRequest, GPSPosition) | `/engineering:system-design` | Diagrama Mermaid |
| 3.2 | Esquema detallado de Firestore: colecciones, documentos, campos, tipos, reglas de seguridad | `/engineering:documentation` | Tabla + texto Markdown |
| 3.3 | Esquema de Firebase Realtime DB: estructura JSON para posiciones GPS en tiempo real | `/engineering:documentation` | Estructura JSON documentada |
| 3.4 | **ADR #3:** Justificación de Firestore (datos estructurados) + RTDB (GPS en tiempo real) como modelo dual | `/engineering:architecture` | ADR en Markdown |
| **3.5 [V2]** | **Definir la estrategia de consolidación GPS → Firestore:** decidir quién ejecuta la consolidación del historial de posiciones cuando el vendedor desactiva su radar (Cloud Function vía trigger RTDB · job en FastAPI · no consolidar en iter. 1). Documentar el responsable en §4.2.3/4.2.4. | `/engineering:architecture` | Decisión documentada en §4.2 |
| **3.6 [V2]** | **Decisión sobre `users.last_location` (anticipación de fan-out geográfico):** aunque el fan-out masivo por radio es un problema de iter. 3 (CU-7), decidir **desde iter. 1** si el modelo `users` incluye `last_location` + `last_location_at` (para facilitar iter. 3) o si se deja sin ese campo. Recomendación: **incluirlo desde iter. 1** con actualización sólo en foreground de la app. | `/engineering:architecture` | Campo documentado en esquema `users` |
| **3.7 [V2]** | **Anticipar colecciones de iter. 2-3 (solo mención, no diseño detallado):** identificar los huecos que vendrán: `community_reports` (CU-6+CU-8), `reputation_events` (transversal), `subscriptions` (CU-9), `vendor_catalog` (CU-9), `verifications` (CU-7). NO se detallan en el SDD iter. 1, pero se listan como "colecciones previstas para iteraciones futuras" en §2.5 (Evolución previsible). | `/engineering:documentation` | Listado breve en §2.5 del SDD |

**💡 Sugerencia:** Para la **implementación real** de la base de datos (reglas Firestore, índices, scripts de seed), recomiendo que se haga en un **chat separado en modo Dev** para no cargar este chat. Aquí solo diseñamos el modelo, allá se ejecuta.

**[V2] Nota sobre Firebase Storage:** Storage **no entra al SDD iter. 1** (no lo requiere ninguno de los 3 CU de iter. 1). Se anticipa como nuevo contenedor a partir de iter. 2 (requerido por CU-6). Se mencionará en §2.5 del SDD como "evolución previsible".

**Cubre:** F1 (Information Viewpoint), F2 (diseño de BD consistente), F3 (diseño de BD consistente)

---

### FASE 4 — Diagramas de Secuencia
**Objetivo:** Documentar el comportamiento dinámico del sistema por caso de uso.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 4.1 | **Diagrama de secuencia — CU-01:** Solicitar parada (flujo normal + alternativo: vendedor rechaza + excepción: timeout) | `/engineering:system-design` | Diagrama Mermaid |
| 4.2 | **Diagrama de secuencia — CU-02:** Activar radar de visibilidad (flujo normal + alternativo: señal GPS débil + excepción: conexión perdida) | `/engineering:system-design` | Diagrama Mermaid |
| 4.3 | **Diagrama de secuencia — CU-03:** Bloquear zona por riesgo activo (flujo normal + alternativo: niveles medio/bajo + excepción: reporte duplicado) | `/engineering:system-design` | Diagrama Mermaid |
| 4.4 | **Diagrama de secuencia — Auth:** Registro + Login (flujo normal) | `/engineering:system-design` | Diagrama Mermaid |

**Cubre:** F1 (Interaction Viewpoint), F2 (detalles de componentes consistentes), F3 (detalles de componentes consistentes)

---

### FASE 5 — Diseño de Interfaces de Usuario
**Objetivo:** Diseñar interfaces coherentes, accesibles y bonitas. **Aquí pensamos como diseñadores.**

Esta es la fase más visual del plan. Se divide en sub-fases:

#### 5A — Sistema de Diseño (Design System)
| Paso | Actividad                                                                                                     | Skill sugerida          | Output                     |
| ---- | ------------------------------------------------------------------------------------------------------------- | ----------------------- | -------------------------- |
| 5A.1 | Definir paleta de colores principal (basada en identidad UBISAFE: seguridad, confianza, comunidad)            | `/design:design-system` | Paleta con hex codes       |
| 5A.2 | Definir tipografía (familia, tamaños para headers/body/captions, pesos)                                       | `/design:design-system` | Especificación tipográfica |
| 5A.3 | Definir componentes base: botones (primario, secundario, peligro), cards, inputs, modals, bottom sheets, FABs | `/design:design-system` | Component library spec     |
| 5A.4 | Definir iconografía y estilo de ilustraciones (line icons vs. filled, estilo de marcadores del mapa)          | `/design:design-system` | Guía de iconografía        |
| 5A.5 | Definir espaciados y grid system (8px grid, márgenes, paddings estándar)                                      | `/design:design-system` | Spacing tokens             |

#### 5B — Wireframes de baja fidelidad
| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 5B.1 | Wireframes: Splash, Bienvenida, Login, Registro (datos + selección de rol) | — | Sketches / wireframes |
| 5B.2 | Wireframes: Home Comprador (mapa con radar), Home Vendedor (mapa con navegación) | — | Sketches / wireframes |
| 5B.3 | Wireframes: Flujo de solicitar parada (seleccionar vendedor → confirmación → tracking) | — | Sketches / wireframes |
| 5B.4 | Wireframes: Flujo de activar visibilidad (toggle → popup → estado activo → solicitud entrante) | — | Sketches / wireframes |
| 5B.5 | Wireframes: Flujo de reportar riesgo (botón + → formulario → confirmación) | — | Sketches / wireframes |
| 5B.6 | Wireframes: Drawer (menú lateral), Perfil, Historial | — | Sketches / wireframes |

#### 5C — Mockups de alta fidelidad
| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 5C.1 | Mockups finales aplicando design system a todos los wireframes aprobados | **Figma** (conector) | Archivos Figma / imágenes |
| 5C.2 | Revisión de consistencia visual entre todas las pantallas | `/design:design-critique` | Feedback estructurado |
| 5C.3 | Revisión de accesibilidad (contraste, tamaños touch, legibilidad para adultos mayores) | `/design:accessibility-review` | Reporte de accesibilidad |

#### 5D — Diagrama de Navegación
| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 5D.1 | Diagrama de navegación completo (basado en el flujo del knowledge source que ya tenemos) | — | Diagrama Mermaid actualizado |
| 5D.2 | Validar que el diagrama de navegación cubre todos los CU y flujos del SRS | — | Checklist de cobertura |

**Cubre:** F1 (Interface Viewpoint), F2 (diseño de interfaz consistente, modelo C4/UML), F3 (contenidos claros de la iteración, diagramas claros)

---

### FASE 6 — Decisiones Arquitectónicas consolidadas
**Objetivo:** Compilar los ADRs generados durante las fases anteriores en una sección cohesiva.

**Estado:** ⬜ Pendiente. **[V2]** Alcance ampliado: de 3 ADRs originales a 4 ADRs + 3 ADRs retroactivos en el SDD iter. 1, más un apéndice anticipatorio de ADRs iter. 2-3.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 6.1 | Consolidar ADRs #1, #2, #3, **#4 [V2]** y los ADRs retroactivos en una sola sección | `/engineering:architecture` | Sección completa de ADRs |
| **6.2 [V2]** | Escribir ADRs retroactivos para decisiones implícitas de Fase 1 (Firebase Auth, Google Maps, FCM como canales) | `/engineering:architecture` | ADRs en Markdown |
| **6.3 [V2]** | Documentar deuda técnica declarada (Haversine client-side) con plan de revisión | `/engineering:documentation` | Nota en §10 del SDD |
| **6.4 [V2]** | Redactar un **apéndice anticipatorio** (opcional, fuera del SDD iter. 1) con los ADRs previstos para iter. 2-3: #5 Firebase Storage, #6 Reputación, #7 Geometría zonas bloqueadas, #8 Fan-out geográfico, #9 Push interactivo FCM, #10 Cloud Functions, #11 Unificación reportes comunitarios. Sirve de memoria para el equipo, NO entra al SDD final iter. 1. | `/engineering:architecture` | Documento separado (ej. `ROADMAP_ADR_ITER_2_3.md`) |

**[V2] Lista completa de ADRs que entran al SDD iter. 1:**

| ADR # | Tema | Fase origen | Estado |
|---|---|---|---|
| ADR #1 | Monolito FastAPI vs microservicios | Fase 1 | ✅ Escrito |
| ADR #2 | GPS directo a RTDB vs vía FastAPI | Fase 1 | ✅ Escrito |
| ADR #3 | Firestore + RTDB (polyglot persistence) | Fase 3 | ⬜ Pendiente |
| **ADR #4** | **State Management en Flutter (Riverpod)** | **Fase 0.6 [V2]** | ⬜ Pendiente |
| ADR retroactivo A | Firebase Auth como IdP | Fase 6.2 [V2] | ⬜ Pendiente |
| ADR retroactivo B | Google Maps como cartografía (con nota costo) | Fase 6.2 [V2] | ⬜ Pendiente |
| ADR retroactivo C | FCM como único canal de push | Fase 6.2 [V2] | ⬜ Pendiente |

**[V2] ADRs anticipados (NO entran al SDD iter. 1, sirven de referencia al equipo):**

| ADR # | Tema | Iteración |
|---|---|---|
| ADR #5 | Firebase Storage para evidencias | Iter. 2 (CU-6) |
| ADR #6 | Sistema de reputación y puntos | Iter. 2 (CU-5, CU-6, CU-8) |
| ADR #7 | Modelo geométrico para zonas bloqueadas (polígonos finos) | Iter. 2 (CU-5) |
| ADR #8 | Fan-out geográfico de alertas (server-side con `last_location`) | Iter. 3 (CU-7) |
| ADR #9 | Push interactivo FCM (action buttons) | Iter. 3 (CU-7) |
| ADR #10 | Cloud Functions como trigger RTDB | Iter. 3 (CU-9) |
| ADR #11 | Unificación de reportes comunitarios | Iter. 3 (CU-8 reusa CU-6) |

**Cubre:** F1 (Rationale Viewpoint), F2 (componentes y relaciones justificadas)

---

### FASE 7 — Trazabilidad y cierre
**Objetivo:** Asegurar que todo el diseño se conecta con los requisitos.

| Paso | Actividad                                                                                                  | Skill sugerida               | Output                        |
| ---- | ---------------------------------------------------------------------------------------------------------- | ---------------------------- | ----------------------------- |
| 7.1  | Crear matriz de trazabilidad: Requisito funcional (CU) → Componentes → Interfaces → Diagramas de secuencia | `/engineering:documentation` | Tabla de trazabilidad         |
| 7.2  | Crear matriz de trazabilidad: RNFs → Decisiones arquitectónicas que los satisfacen                         | `/engineering:documentation` | Tabla de trazabilidad         |
| 7.3  | Documentar historial de versiones del SDD (iteración 1)                                                    | —                            | Tabla de versiones            |
| 7.4  | Marcar claramente qué contenidos fueron añadidos en esta iteración                                         | —                            | Marcadores visuales en el doc |

**Cubre:** F1 (Design Overlay), F2 (iteración correspondiente), F3 (contenidos de la iteración, formato estándar)

---

### FASE 8 — Verificación contra los tres marcos
**Objetivo:** Verificación final cruzada. Este es el "quality gate" antes de entregar.

| Paso | Verificación | Resultado esperado |
|---|---|---|
| 8.1 | **IEEE 1016-2009:** ¿Cada Design Viewpoint tiene al menos un diagrama + descripción textual? | Checklist completo |
| 8.2 | **Profesor — Criterio 1:** ¿Se describen componentes y sus relaciones (arquitectura)? | Fases 1, 2 |
| 8.3 | **Profesor — Criterio 2:** ¿Se describe el diseño de BD y es consistente? | Fase 3 |
| 8.4 | **Profesor — Criterio 3:** ¿Se describen detalles de componentes (diagramas) y son consistentes? | Fases 2, 4 |
| 8.5 | **Profesor — Criterio 4:** ¿Se describe diseño de interfaz y es consistente? | Fase 5 |
| 8.6 | **Profesor — Criterio 5:** ¿Se utiliza C4 (y UML donde sea necesario)? | Fases 1, 2, 4 |
| 8.7 | **Profesor — Criterio 6:** ¿Se muestran claramente contenidos de la iteración? | Fase 7 |
| 8.8 | **Equipo — Todos los criterios:** Verificación cruzada con checklist del equipo | Global |

---

## 3. Orden recomendado de ejecución

**[V2] Orden actualizado** para reflejar los pasos 0.5, 0.6, 2.5, 3.5, 3.6, 3.7 y la re-entrada tras la revisión del 17/04:

```
FASE 0 (Preparación)
  ├─ 0.1 → 0.4 ✅ (completado)
  ├─ 0.5 [V2] Organización por dominios     ← PUNTO DE RE-ENTRADA (ejecutar antes de Fase 3)
  └─ 0.6 [V2] ADR #4 State Management       ← PUNTO DE RE-ENTRADA (ejecutar antes de Fase 3)
      │
      └─→ FASE 1 (C4 L1-L2)  ✅ Completada
            │
            └─→ FASE 2 (C4 L3 + estructura de proyecto)  ✅ Completada (2.1-2.4)
                  └─ 2.5 [V2] Reorganización por dominios  ← ejecutar tras 0.5 y 0.6
                        │
                        ├─→ FASE 3 (Base de datos)  ← depende de 0.5, 0.6 y 2.5
                        │     └─ 3.1 → 3.4 + 3.5, 3.6, 3.7 [V2]
                        │
                        └─→ FASE 4 (Secuencias)  ← paralelizable con Fase 3
                              │
                              └─→ FASE 5 (Interfaces)
                                    ├─→ 5A (Design system)
                                    ├─→ 5B (Wireframes)    ← depende de 5A
                                    ├─→ 5C (Mockups)       ← depende de 5B
                                    └─→ 5D (Navegación)
                                          │
                                          └─→ FASE 6 (ADRs consolidados + retroactivos [V2])
                                                │
                                                └─→ FASE 7 (Trazabilidad)
                                                      │
                                                      └─→ FASE 8 (Verificación)
```

**[V2] Secuencia inmediata recomendada (próximas sesiones):**

1. **Fase 0.5** — Formalizar los 5 dominios (30-60 min).
2. **Fase 0.6** — Escribir ADR #4 (Riverpod) + prototipo de "Hello World Riverpod" (1 sesión + 1 día de prototipo en paralelo por Miguel).
3. **Fase 2.5** — Reorganizar §5.3 y §11 del SDD por dominios (1 sesión).
4. **Fase 3** completa — incluyendo 3.5, 3.6, 3.7 (1-2 sesiones).
5. **Fase 4** — diagramas de secuencia (1-2 sesiones, paralelizable).

---

## 4. Formato de entrega por fase

Cada fase se trabajará en este u otros chats y producirá:

- **Texto en Markdown** → Alexis copia a su .docx y da formato
- **Diagramas en Mermaid** → Alexis exporta como imagen (o renderiza en Miro) y pega en .docx
- **Wireframes/Mockups** → Se generan como HTML/React o se trabajan en Figma, se exportan como imagen para el .docx
- **ADRs** → Texto Markdown con formato estándar (Context, Decision, Consequences)

---

## 5. Uso estratégico de skills por fase

| Skill | Fases donde se usa | Propósito |
|---|---|---|
| `/engineering:architecture` | 0, 1, 3, 6 | ADRs, trade-offs, justificaciones técnicas |
| `/engineering:system-design` | 1, 2, 3, 4 | Diagramas C4, secuencia, estructura |
| `/engineering:documentation` | 1, 2, 3, 7 | Texto descriptivo, matrices de trazabilidad |
| `/design:design-system` | 0, 5A | Tokens de diseño, componentes base |
| `/design:design-critique` | 5C | Revisión de consistencia visual |
| `/design:accessibility-review` | 5C | Accesibilidad para adultos mayores |
| **Figma** (conector) | 5C | Mockups de alta fidelidad |

---

## 6. Estimación de esfuerzo por fase

**[V2] Tabla actualizada** con los pasos nuevos de la revisión del 17/04:

| Fase | Complejidad | Sesiones estimadas* | Estado |
|---|---|---|---|
| Fase 0 (0.1-0.4) | Baja | 1 sesión | ✅ Completada |
| **Fase 0 (0.5-0.6) [V2]** | Baja | 1 sesión + 1 día de prototipo (paralelo) | ⬜ Pendiente |
| Fase 1 | Media | 1-2 sesiones | ✅ Completada |
| Fase 2 (2.1-2.4) | Media | 1 sesión | ✅ Completada |
| **Fase 2.5 [V2]** | Baja | 0.5-1 sesión | ⬜ Pendiente |
| Fase 3 (3.1-3.4) | Media | 1 sesión | ⬜ Pendiente |
| **Fase 3 (3.5-3.7) [V2]** | Baja-Media | 0.5 sesión (extensión de 3.1-3.4) | ⬜ Pendiente |
| Fase 4 | Media-Alta | 1-2 sesiones | ⬜ Pendiente |
| Fase 5 | Alta | 2-4 sesiones | ⬜ Pendiente |
| Fase 6 (6.1) | Baja | 0.5 sesión (compilación) | ⬜ Pendiente |
| **Fase 6 (6.2-6.4) [V2]** | Baja-Media | 0.5-1 sesión (retroactivos + roadmap ADR iter. 2-3) | ⬜ Pendiente |
| Fase 7 | Media | 1 sesión | ⬜ Pendiente |
| Fase 8 | Media | 1 sesión | ⬜ Pendiente |

*Una "sesión" = un chat/conversación enfocada en esa fase.

**[V2] Esfuerzo total restante estimado:** 6-10 sesiones de Claude + 1 día de prototipo (Riverpod por Miguel), lo cual es compatible con el tiempo remaining antes del cierre de iter. 1.

---

## 7. Dependencias externas y notas

- **Diagrama de navegación existente:** El knowledge source del proyecto ya contiene un diagrama de navegación Mermaid completo. Lo usaremos como base en la Fase 5D.
- **C4 L1 ya aprobado:** Según el memory del proyecto, el diagrama de contexto C4 ya fue aprobado. Lo revisaremos en Fase 1.1 para confirmar que sigue vigente.
- **C4 L2 en progreso:** El diagrama de contenedores estaba en construcción. Lo retomaremos en Fase 1.2.
- **Figma:** Disponible como conector para mockups de alta fidelidad en Fase 5C.
- **Chat separado para BD:** La implementación técnica de la base de datos (reglas, índices, scripts) se recomienda hacer en otro chat para mantener este enfocado en diseño.

**[V2] Documentos complementarios añadidos el 17/04/2026:**

- **`REVISION_ARQUITECTURA_UBISAFE.md`** — Evaluación crítica de las decisiones tomadas hasta el 16/04 + análisis de gaps + propuesta de 5 dominios.
- **`ANALISIS_ITER2_ITER3_UBISAFE.md`** — Análisis arquitectónico específico de los 6 CU de iter. 2-3 + decisión sobre Riverpod + listado de ADRs anticipados.

Ambos documentos son **referencia de contexto para las fases 0.5, 0.6, 2.5, 3.5-3.7 y 6.2-6.4**. No son entregables del SDD iter. 1 pero su contenido alimenta las decisiones que sí lo son.

---

## 8. Historial de Versiones del Plan

| Versión | Fecha | Autor(es) | Descripción de cambios |
|---|---|---|---|
| **V1.0** | 16/04/2026 | Alexis Córdova (con asistencia de Claude) | Versión inicial del plan maestro. 8 fases definidas (0 a 8). 3 ADRs planeados (#1 monolito, #2 GPS directo, #3 polyglot). Estructura IEEE 1016-2009 adaptada. Estimación de 8-12 sesiones totales. |
| **V2.0** | 17/04/2026 | Alexis Córdova (con asistencia de Claude) | Actualización tras revisión arquitectónica. Ver detalle abajo. |

### Detalle de cambios de V1.0 → V2.0

**Contexto del cambio:** Tras completar Fases 0 (parcial), 1 y 2, se realizó una revisión arquitectónica completa de las decisiones tomadas y se consideraron los 6 CU de iter. 2-3 recién compartidos por el equipo. La revisión produjo tres salidas: `REVISION_ARQUITECTURA_UBISAFE.md`, `ANALISIS_ITER2_ITER3_UBISAFE.md` y esta actualización del plan.

**Cambios estructurales:**

| # | Cambio | Fase afectada | Motivación |
|---|---|---|---|
| 1 | Se añade paso **0.5 — Organización por dominios (bounded contexts)** | Fase 0 | La división por capas técnicas (routers/services/schemas) deja invisible la división funcional. Se propone migrar a 5 dominios: Identity, Presence, Dispatching, Safety, Community. |
| 2 | Se añade paso **0.6 — ADR #4 State Management (Riverpod)** | Fase 0 | Gap crítico detectado: no había decisión sobre state management en Flutter. Equipo sin experiencia previa. Se elige Riverpod por balance curva de aprendizaje/escalabilidad. |
| 3 | Se añade paso **2.5 — Reorganización de componentes por dominios** | Fase 2 | Consecuencia de 0.5. Los diagramas C4 L3 y la estructura del proyecto deben agrupar componentes por dominio, no por capa. |
| 4 | Se añade paso **3.5 — Estrategia de consolidación GPS → Firestore** | Fase 3 | Hueco detectado en §4.2 del SDD: no hay dueño claro para consolidar historial GPS cuando el vendedor desactiva el radar. |
| 5 | Se añade paso **3.6 — Campo `users.last_location`** | Fase 3 | Decisión anticipatoria: aunque se usa en iter. 3 (CU-7 fan-out), conviene modelarla desde iter. 1 para evitar migración posterior. |
| 6 | Se añade paso **3.7 — Anticipación de colecciones iter. 2-3** | Fase 3 | Listar `community_reports`, `reputation_events`, `subscriptions`, `vendor_catalog`, `verifications` en §2.5 (Evolución previsible) sin detallarlas. |
| 7 | Se añaden pasos **6.2, 6.3, 6.4 — ADRs retroactivos + deuda técnica + apéndice anticipatorio** | Fase 6 | Decisiones implícitas (Firebase Auth, Google Maps, FCM, Haversine client-side) no estaban documentadas. Además, se crea un roadmap de ADRs iter. 2-3 como referencia (no entra al SDD iter. 1). |
| 8 | Se documenta mapeo **dominio → componentes** | Fase 2 | Tabla que traduce los 9 componentes Flutter y 7 componentes FastAPI actuales a los 5 dominios nuevos. |
| 9 | Se actualiza el **diagrama de orden de ejecución** con los nuevos pasos y el punto de re-entrada | §3 | Refleja la nueva secuencia de trabajo. |
| 10 | Se actualiza la **tabla de estimación de esfuerzo** con estado y pasos nuevos | §6 | Visibilidad de progreso + estimación del esfuerzo restante (6-10 sesiones). |
| 11 | Se añaden referencias a los **documentos complementarios** | §7 | `REVISION_ARQUITECTURA_UBISAFE.md` y `ANALISIS_ITER2_ITER3_UBISAFE.md`. |

**Cambios explícitamente NO realizados (alcance protegido):**

- No se modificaron los ADRs #1 y #2 ya escritos (siguen válidos).
- No se modificó el C4 L1 ni el C4 L2 (siguen válidos).
- No se añadieron Firebase Storage ni Cloud Functions al SDD iter. 1 (se anticipan en §2.5 "Evolución previsible" pero no entran al diseño detallado).
- No se detallaron las 5 colecciones nuevas de iter. 2-3 (solo se listan).
- No se cambió el stack técnico (Flutter + FastAPI + Firebase + Google Maps sigue siendo la base).

**Punto de re-entrada para la próxima sesión de trabajo:** **Fase 2.5** (reorganización por dominios), precedida por las decisiones de **Fase 0.5 y 0.6** si aún no se han tomado formalmente. Luego avanzar a **Fase 3**.

---

*Plan generado inicialmente el 16/04/2026. Actualizado a V2.0 el 17/04/2026 — Los Borbotones / UBISAFE Iteración 1.*
