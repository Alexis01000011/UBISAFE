# Plan Maestro — System Design Document (SDD) de UBISAFE
## Los Borbotones · **Iteración 2** · Versión 1.0
### Generado: 23/04/2026

> **Propósito de este plan:** El SDD de Iteración 1 ya está prácticamente cerrado (Fases 0–5 completas, ver `PLAN_SDD_UBISAFE.md` + `RESUMEN_SDD_UBISAFE.md`). Este plan describe **qué se debe añadir, extender o actualizar** en el mismo documento SDD para reflejar los cambios del **SRS v2.1** (CU-04, CU-05, CU-06). **NO es un SDD nuevo desde cero** — es una pasada de actualización incremental.
>
> **Resultado esperado:** El .docx del SDD pasa de "SDD v1.0 (iter. 1)" a "SDD v2.0 (iter. 1 + iter. 2)". Las secciones ya existentes se amplían; las ya presentes se marcan claramente como "contenido nuevo en iter. 2" con marcadores visuales (tabla con columna *Iteración*, anotaciones *[iter. 2]* en títulos, o similar). La trazabilidad en §12 se extiende con los CU nuevos.

---

## 0. Instrucciones de uso (leer antes de empezar cualquier sesión)

### 0.1. Para cualquier Claude que retome este plan

> Este plan está pensado para ser ejecutado por **Alexis** y **Miguel** de forma **paralela en dos máquinas distintas**. Si eres el Claude de Alexis o el Claude de Miguel, haz lo siguiente al iniciar una sesión:
>
> 1. **Pregunta al usuario:** "¿En qué fase/paso del plan iteración 2 vamos?" (o infiere del contexto si ves archivos ya generados como `SDD2_FASE3_UBISAFE.md`, etc.).
> 2. **Pregunta al usuario:** "¿Eres Alexis o Miguel?" — esto determina qué fases te corresponden según la división de trabajo de §3 de este plan.
> 3. **Lee los documentos de contexto base** (§0.3 de este plan) antes de trabajar en cualquier fase.
> 4. **Usa las skills sugeridas** en cada paso (`/engineering:architecture`, `/engineering:system-design`, `/engineering:documentation`, `/design:design-system`, `/design:design-critique`, `/design:accessibility-review`, etc.). Tanto Alexis como Miguel tienen estas skills disponibles en su Claude Cowork.
> 5. **Al terminar cada paso/fase**, guarda el output en un archivo `SDD2_FASEX_UBISAFE.md` en la carpeta del proyecto y confirma al usuario qué compartir con la otra persona (§4 de este plan).
> 6. **Recuerda:** Cada fase produce Markdown + diagramas Mermaid que Alexis integrará manualmente al `.docx` final.

### 0.2. Instrucciones para Miguel — Claude Design

Parte de la Fase 5 de este plan requiere generar mockups de alta fidelidad. **En iter. 1** se usó el conector Figma; **en iter. 2** usaremos **Claude Design** con prompts bien construidos a partir de wireframes y design tokens.

> **Miguel:** Si no has usado Claude Design antes, entras desde **https://claude.ai/** y activas el modo de generación de artefactos visuales/diseño. Lo que hacemos aquí es construir prompts bien estructurados (que incluyen el design system, la pantalla a replicar y un wireframe textual) y pegarlos allá para que Claude Design genere el mockup. El Claude de este plan **no genera el mockup directamente** — genera el **prompt** que tú copias y pegas en Claude Design.
>
> Si tu Claude Cowork te pregunta "¿Ya abriste Claude Design?" en la Fase 5C, la respuesta esperada es que tienes `https://claude.ai/` abierto en otra pestaña listo para pegar el prompt.

### 0.3. Documentos base de contexto (leer antes de empezar)

| Documento | Qué saca cada Claude de aquí |
|---|---|
| `BB_SRS_V2.1.md` | **Obligatorio.** Contiene CU-04, CU-05, CU-06 con actores, flujos, RF/RNF. Este plan depende 100% de él. |
| `RESUMEN_SDD_UBISAFE.md` | **Obligatorio.** Contexto consolidado del SDD iter. 1: stack, dominios, componentes, BD, ADRs, design system, nombres canónicos del apéndice. |
| `PLAN_SDD_UBISAFE.md` | Referencia del plan iter. 1 (estructura IEEE 1016, fases originales). |
| `SDD_FASE0_UBISAFE.md` | Diseño system completo (tokens, tipografía, componentes base). Necesario para Fase 5A'. |
| `SDD_FASE0_PASOS05_06_UBISAFE.md` | Bounded contexts + ADR #4 (Riverpod). Necesario para Fase 0' y Fase 2'. |
| `SDD_FASE1_UBISAFE.md` | C4 L1–L2 + ADR #1, #2. Necesario para Fase 1'. |
| `SDD_FASE2_UBISAFE.md` + `SDD_FASE2_PASO25_UBISAFE.md` | C4 L3 por dominios + estructura carpetas. Necesario para Fase 2'. |
| `SDD_FASE3_UBISAFE.md` | BD completa (Firestore + RTDB + ADR #3). Necesario para Fase 3'. |
| `SDD_FASE4_UBISAFE.md` | Diagramas de secuencia iter. 1. Necesario para Fase 4' (mismo estilo, misma convención de actores). |
| `SDD_FASE5_UBISAFE.md` | Diseño de interfaces iter. 1 (5A, 5B, 5C, 5D). Necesario para Fase 5'. |

---

## 1. Cambios que introduce iter. 2 (resumen ejecutivo)

Del `BB_SRS_V2.1.md`:

| # | Caso de Uso | Dominio principal | Impacto arquitectónico |
|---|---|---|---|
| **CU-04** | Solicitar raite | **Dispatching** (extendido) + **Safety** (validación de ruta) | Nuevo endpoint `/rides`, nueva colección `rides`, nuevo toggle `rideEnabled` en perfil vendedor, selector de destino en mapa |
| **CU-05** | Reportar focos de infección | **Safety** (ampliado) + nueva mini-capa **Community** | Nueva colección `community_reports`, polígonos (no solo círculos), agregación de reportes duplicados (Cloud Function u orquestación server-side), estado `pending_validation` |
| **CU-06** | Verificar reportes comunitarios | **Community** (nueva) | Nueva pantalla de validación/votación, lógica de validación comunitaria, extensión del modelo `community_reports` con `validations[]` |

**Nuevas dependencias/anticipaciones que sí aterrizan en iter. 2:**
- **Cloud Functions** (para agregación de reportes duplicados y sincronización) → **entra como contenedor nuevo en C4 L2**.
- **Firebase Storage** (si se incluyen evidencias adjuntas en reportes) → **pendiente de decisión en Fase 0'; si entra, es contenedor nuevo**.
- **Polígonos en mapa** (no solo círculos como en CU-03) → impacta Google Maps SDK y modelo de datos.
- **Extensión del modelo `users`** con `rideEnabled: boolean`.

**ADRs nuevos previstos para iter. 2:**

| ADR # | Tema | Fase donde se redacta |
|---|---|---|
| **ADR #5** | Firebase Storage para evidencias de reportes comunitarios (sí/no en iter. 2) | Fase 0' y/o Fase 3' |
| **ADR #6** | Modelo de reputación/validación comunitaria (CU-06: votación simple vs. pesos por rol vs. puntos) | Fase 3' |
| **ADR #7** | Geometría de zonas bloqueadas: polígonos vs. círculos con radio variable | Fase 3' |
| **ADR #10** | Cloud Functions como orquestador (trigger RTDB / Firestore) | Fase 1' o Fase 3' |
| **ADR #11** | Unificación de reportes comunitarios (CU-03 simple vs. CU-05 con validación) — ¿una colección o dos? | Fase 3' |

---

## 2. Estructura del SDD (dónde aterriza cada cambio)

> La estructura IEEE 1016 del SDD **no cambia**. Se amplían secciones existentes. La columna *Acción iter. 2* indica qué hacer:

| Sección del SDD | Contenido original (iter. 1) | Acción iter. 2 |
|---|---|---|
| §1 Introducción | Propósito, alcance | **Extender** §1.2 Alcance para incluir CU-04/05/06 |
| §2 Stakeholders | Actores + concerns | **Revisar** si CU-05/06 introduce algún stakeholder nuevo (p.ej. "comunidad" como colectivo) |
| §2.5 Dominios | 5 dominios + mapping CU | **Actualizar** mapping: CU-04 → Dispatching, CU-05/06 → Safety+Community. Activar contenidos en dominio Community |
| §3 ADRs | 4 ADRs + 3 retroactivos | **Añadir** ADR #5, #6, #7, #10, #11 (los que apliquen) |
| §4 C4 L1 | Contexto | **Revisar** si aparecen sistemas externos nuevos (no se espera ninguno) |
| §5 C4 L2 | Contenedores | **Añadir** Cloud Functions como contenedor y (si aplica) Firebase Storage |
| §5.3 C4 L3 | Componentes Flutter + FastAPI por dominio | **Añadir** componentes: `RideRequestModule`, `CommunityReportModule`, `ReportValidationModule` (Flutter); `RideRouter`, `CommunityReportRouter`, `ReportValidationRouter` (FastAPI); funciones: `aggregateDuplicateReports`, `validateReport` (Cloud Functions) |
| §7 BD | Firestore + RTDB | **Añadir** colecciones `rides`, `community_reports`, `reputation_events` (si aplica ADR #6), campos nuevos en `users` (`rideEnabled`). Actualizar §8.3 "Colecciones previstas iter. 2-3" → mover lo aplicable a iter. 2 y retirar las colecciones ya diseñadas |
| §8 UI / Design System | Tokens + wireframes + mockups | **Añadir** pantallas nuevas: Solicitud de Raite, Validación de Reportes, Lista de Reportes Activos, Perfil Vendedor extendido con toggle |
| §9 Secuencias | CU-01, 02, 03 + Auth | **Añadir** diagramas CU-04, CU-05, CU-06 (cada uno con flujo normal + alt + excepción) |
| §10 Navegación | Diagrama Mermaid completo | **Extender** grafo con nodos de CU-04/05/06 y nueva entrada en Drawer (Validación de reportes) |
| §11 Estructura de proyecto | `lib/features/` y `modules/` | **Extender** con carpetas nuevas en `dispatching/`, `safety/`, y activar `community/` en ambos stacks |
| §12 Trazabilidad | Matriz RF → Componentes | **Extender** matriz con RF/CU de iter. 2 |
| §13 Historial | V1.0, V2.0 | **Añadir** V3.0 con los cambios de iter. 2 |

---

## 3. Fases de ejecución y división Alexis / Miguel

### Nomenclatura
Fases numeradas con **apóstrofe** (`Fase 1'`, `Fase 2'`, etc.) para distinguirlas de las de iter. 1. El apóstrofe se lee como "prima" (Fase 1-prima).

### 3.1. Tabla maestra — división de trabajo

> **Leyenda:**
> - 🟦 **Alexis** (PM/integrador al .docx, visión de producto, BD, trazabilidad)
> - 🟩 **Miguel** (líder técnico, C4, secuencias, UI mockups)
> - 🟨 **Conjunto** (pair-session o revisión cruzada obligatoria)
> - ⚡ **Paralelizable** (Alexis y Miguel pueden ejecutar en simultáneo sin dependencias)
> - ⛓️ **Secuencial** (depende del output de otra fase)

| Fase | Nombre | Responsable | Paralelizable con | Sesiones estimadas |
|---|---|---|---|---|
| **Fase 0'** | Preparación iter. 2 (decisiones anticipadas + impacto de CU-04/05/06) | 🟨 Conjunto (1 sesión pair) | — | 1 |
| **Fase 1'** | Actualización C4 L1–L2 (añadir Cloud Functions y Storage si aplica) | 🟩 Miguel | ⚡ Fase 3.A' | 0.5–1 |
| **Fase 2'** | C4 L3 + componentes nuevos por dominio | 🟩 Miguel | ⚡ Fase 3.B' | 1 |
| **Fase 3.A'** | Diseño BD: `rides` + extensión `users` (CU-04) | 🟦 Alexis | ⚡ Fase 1' | 0.5 |
| **Fase 3.B'** | Diseño BD: `community_reports` + `reputation_events` + ADRs #6, #7, #11 (CU-05 y CU-06) | 🟦 Alexis | ⚡ Fase 2' | 1 |
| **Fase 4.A'** | Secuencia CU-04 Solicitar raite | 🟩 Miguel | ⚡ Fase 4.B' | 0.5–1 |
| **Fase 4.B'** | Secuencia CU-05 Reportar focos + CU-06 Verificar reportes | 🟦 Alexis | ⚡ Fase 4.A' | 1 |
| **Fase 5A'** | Revisión/extensión Design System (tokens nuevos: polígonos, severidades, chips de estado) | 🟨 Conjunto (review) | — | 0.5 |
| **Fase 5B'** | Wireframes pantallas nuevas (4 pantallas) | 🟩 Miguel | ⚡ Fase 5B.alt' | 1 |
| **Fase 5B.alt'** | Wireframes de extensiones de pantallas existentes (Home, Perfil, Drawer, Historial) | 🟦 Alexis | ⚡ Fase 5B' | 0.5–1 |
| **Fase 5C'** | Mockups alta fidelidad (prompts Claude Design) | 🟩 Miguel | ⛓️ tras 5B' + 5B.alt' | 1–2 |
| **Fase 5D'** | Diagrama de Navegación extendido | 🟦 Alexis | ⚡ Fase 5C' | 0.5 |
| **Fase 6'** | ADRs consolidados iter. 1 + iter. 2 (incluye retroactivos pendientes) | 🟦 Alexis | — | 1 |
| **Fase 7'** | Trazabilidad extendida (CU-04/05/06 → componentes → secuencias → UI) + historial V3.0 | 🟨 Conjunto (pair final) | — | 1 |
| **Fase 8'** | Verificación IEEE 1016 + checklist profesor + checklist equipo | 🟨 Conjunto (pair final) | — | 0.5–1 |

**Esfuerzo total estimado:** 9–13 sesiones repartidas entre Alexis y Miguel. Con buena paralelización ⇒ **≈ 5–7 sesiones calendario** si trabajan en paralelo.

### 3.2. Diagrama de dependencias y paralelización

```
Fase 0' (conjunto, pair)
      │
      ├───⚡──────┐
      │           │
  Fase 1' (M)  Fase 3.A' (A)
      │           │
      ├───⚡──────┤
      │           │
  Fase 2' (M)  Fase 3.B' (A)
      │           │
      ├───⚡──────┤
      │           │
  Fase 4.A' (M) Fase 4.B' (A)
      │           │
      └─────┬─────┘
            │
      Fase 5A' (conjunto, review)
            │
      ┌─────┴─────┐
      │           │
 Fase 5B' (M) Fase 5B.alt' (A)
      │           │
      └─────┬─────┘
            │
      Fase 5C' (M)  ←── secuencial (necesita wireframes)
            │
            ├───⚡──────┐
            │           │
      Fase 5D' (A)      │
            │           │
            └─────┬─────┘
                  │
            Fase 6' (A)
                  │
            Fase 7' (conjunto, pair final)
                  │
            Fase 8' (conjunto, verificación)
```

---

## 4. Archivos a intercambiar entre Alexis y Miguel

> **Regla práctica:** cada fase produce un archivo `SDD2_FASE<X>_UBISAFE.md` en la carpeta del proyecto. Dado que trabajan en máquinas distintas y no comparten filesystem, **deberán compartir los archivos explícitamente** (Drive, WhatsApp, lo que prefieran).

### 4.1. Matriz de dependencias de archivos

| Fase | Lee | Produce | Debe compartir con |
|---|---|---|---|
| **0'** | `BB_SRS_V2.1.md`, `RESUMEN_SDD_UBISAFE.md` | `SDD2_FASE0_UBISAFE.md` (decisiones, ADRs de entrada, lista de preguntas abiertas) | Ambos tienen su copia al terminar la pair-session |
| **1'** (Miguel) | `SDD_FASE1_UBISAFE.md`, `SDD2_FASE0_UBISAFE.md` | `SDD2_FASE1_UBISAFE.md` (C4 L1–L2 actualizado) | **Compartir a Alexis** al terminar (Alexis lo necesita en 3.B' para confirmar Cloud Functions) |
| **2'** (Miguel) | `SDD_FASE2_UBISAFE.md`, `SDD_FASE2_PASO25_UBISAFE.md`, `SDD2_FASE1_UBISAFE.md` | `SDD2_FASE2_UBISAFE.md` (C4 L3 + estructura proyecto extendida) | **Compartir a Alexis** (Alexis lo necesita en 4.B' y en 7') |
| **3.A'** (Alexis) | `SDD_FASE3_UBISAFE.md`, `BB_SRS_V2.1.md` (CU-04) | `SDD2_FASE3A_UBISAFE.md` (modelo `rides` + extensión `users`) | **Compartir a Miguel** (necesario para 4.A') |
| **3.B'** (Alexis) | `SDD_FASE3_UBISAFE.md`, `BB_SRS_V2.1.md` (CU-05/06), `SDD2_FASE1_UBISAFE.md` | `SDD2_FASE3B_UBISAFE.md` (`community_reports`, `reputation_events`, ADRs #6 #7 #11) | **Compartir a Miguel** (necesario para 4.B' si Miguel lo retoma) |
| **4.A'** (Miguel) | `SDD_FASE4_UBISAFE.md` (estilo/convenciones), `SDD2_FASE2_UBISAFE.md`, `SDD2_FASE3A_UBISAFE.md` | `SDD2_FASE4A_UBISAFE.md` (secuencia CU-04) | **Compartir a Alexis** al final para consolidar |
| **4.B'** (Alexis) | `SDD_FASE4_UBISAFE.md`, `SDD2_FASE2_UBISAFE.md`, `SDD2_FASE3B_UBISAFE.md` | `SDD2_FASE4B_UBISAFE.md` (secuencias CU-05 + CU-06) | **Compartir a Miguel** para revisión cruzada |
| **5A'** | `SDD_FASE5_UBISAFE.md` §8.1 Design System | `SDD2_FASE5A_UBISAFE.md` (tokens extendidos) | Ambos lo generan en pair |
| **5B'** (Miguel) | `SDD2_FASE5A_UBISAFE.md`, `SDD_FASE5_UBISAFE.md` (estilo wireframes) | `SDD2_FASE5B_UBISAFE.md` (wireframes pantallas nuevas) | **Compartir a Alexis** |
| **5B.alt'** (Alexis) | `SDD_FASE5_UBISAFE.md` (pantallas iter. 1 existentes) | `SDD2_FASE5Balt_UBISAFE.md` (extensiones a pantallas existentes) | **Compartir a Miguel** (antes de 5C') |
| **5C'** (Miguel) | `SDD2_FASE5B_UBISAFE.md`, `SDD2_FASE5Balt_UBISAFE.md`, `SDD_FASE5_UBISAFE.md` (§8.18 prompts iter. 1) | `SDD2_FASE5C_UBISAFE.md` (prompts Claude Design + mockups resultantes como imágenes) | **Compartir a Alexis** |
| **5D'** (Alexis) | `SDD_FASE5_UBISAFE.md` §10 Navegación, `BB_SRS_V2.1.md` | `SDD2_FASE5D_UBISAFE.md` (Mermaid extendido) | **Compartir a Miguel** para validación |
| **6'** (Alexis) | Todos los ADRs previos + `SDD2_FASE*.md` | `SDD2_FASE6_UBISAFE.md` (ADRs consolidados) | Input para Fase 7' |
| **7'** | Todos los outputs de iter. 2 | `SDD2_FASE7_UBISAFE.md` (matrices + historial V3.0) | Ambos (pair) |
| **8'** | Todo | Checklist firmada | Ambos (pair final) |

### 4.2. Protocolo sugerido de handoff

Cada vez que una persona termina una fase:

1. Guarda el archivo `SDD2_FASE<X>_UBISAFE.md` en su carpeta local.
2. Escribe un mensaje corto a la otra persona con:
   - **Qué terminé:** (1 frase)
   - **Adjunto:** el archivo
   - **Tu Claude debería leer:** (lista de archivos previos + el recién generado) antes de empezar la siguiente fase
   - **Preguntas abiertas / decisiones pendientes:** (si hay)

---

## 5. Detalle de cada fase

### Fase 0' — Preparación iter. 2 y decisiones anticipadas
**🟨 Conjunto · Pair session · 1 sesión**

**Objetivo:** Tomar decisiones clave antes de diagramar, para que 1', 2' y 3' sean paralelizables sin conflictos.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 0'.1 | Leer `BB_SRS_V2.1.md` y marcar explícitamente qué es nuevo de iter. 2 (CU-04, 05, 06 + nuevos RF/RNF) | — | Lista enumerada |
| 0'.2 | **Decisión: ¿Firebase Storage entra en iter. 2?** Depende de si CU-05/06 incluye evidencias adjuntas (fotos, audio). Si sí → ADR #5 + contenedor nuevo en C4 L2. Si no → se pospone a iter. 3. | `/engineering:architecture` | Decisión documentada |
| 0'.3 | **Decisión: ¿Cloud Functions es contenedor en iter. 2?** Para agregación de reportes duplicados (CU-05) el server-side puede ser FastAPI-job o Cloud Function-trigger. Definir cuál. | `/engineering:architecture` | ADR #10 borrador |
| 0'.4 | **Decisión: ¿Colección unificada de reportes o dos separadas?** CU-03 (iter. 1) creó `risk_zones` simple. CU-05/06 crea `community_reports` con validaciones. ¿Se unifican (ADR #11) o coexisten? | `/engineering:architecture` | ADR #11 borrador |
| 0'.5 | **Decisión: modelo de validación de CU-06.** Votación simple (sí/no) vs. pesos por rol vs. puntos de reputación. El SRS v2.1 debe indicar el nivel esperado. | `/engineering:architecture` | ADR #6 borrador |
| 0'.6 | **Decisión: Geometría de zonas de riesgo.** CU-03 usó círculos (lat,lng + radius). CU-05 habla de "tramo/polígono". ¿Se migra a polígonos o se deja dual? | `/engineering:architecture` | ADR #7 borrador |
| 0'.7 | Actualizar §1.2 del SDD (Alcance) para incluir CU-04/05/06 | `/engineering:documentation` | Texto Markdown |

**Cubre:** F1 (Rationale Viewpoint), F2 y F3 (justificación de decisiones).

**Nota para ambos Claude:** En esta fase es importante **no decidir implementación detallada** — solo las decisiones que bloquean la paralelización de 1', 2' y 3'. Los detalles se trabajan en la fase correspondiente.

---

### Fase 1' — Actualización C4 Nivel 1–2
**🟩 Miguel · Paralelizable con Fase 3.A' · 0.5–1 sesión**

**Objetivo:** Reflejar Cloud Functions (y Firebase Storage si aplica) en los diagramas C4 L1 y L2 existentes.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 1'.1 | Revisar `SDD_FASE1_UBISAFE.md` §4 (C4 L1): ¿hay sistemas externos nuevos? (generalmente no) | `/engineering:system-design` | Confirmación o diagrama actualizado |
| 1'.2 | **C4 L2 actualizado:** añadir *Cloud Functions* como contenedor nuevo. Especificar qué triggers usa (onCreate en `community_reports`, scheduled para limpieza de `stop_requests` expirados) | `/engineering:system-design` | Diagrama Mermaid |
| 1'.3 | Si ADR #5 activa Storage → añadir *Firebase Storage* como contenedor | `/engineering:system-design` | Diagrama Mermaid |
| 1'.4 | Texto descriptivo de nuevos contenedores: responsabilidad, tecnología, protocolos | `/engineering:documentation` | Texto Markdown |

**Archivos necesarios:** `SDD_FASE1_UBISAFE.md`, `SDD2_FASE0_UBISAFE.md` (decisiones).

---

### Fase 2' — C4 Nivel 3 ampliado
**🟩 Miguel · Paralelizable con Fase 3.B' · 1 sesión**

**Objetivo:** Añadir los componentes nuevos al C4 L3 por dominio y actualizar §11 (estructura de carpetas).

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 2'.1 | **Componentes Flutter nuevos** (agregar al C4 L3 del dominio Dispatching, Safety y activar Community): `RideRequestModule`, `CommunityReportModule`, `ReportValidationModule`, `DestinationPicker` (widget compartido) | `/engineering:system-design` | Diagrama Mermaid + texto |
| 2'.2 | **Componentes FastAPI nuevos:** `RideRouter` (dominio Dispatching), `CommunityReportRouter` (dominio Community), `ReportValidationRouter` (Community), `ReportAggregatorService` (shared o Community) | `/engineering:system-design` | Diagrama Mermaid + texto |
| 2'.3 | **Cloud Functions** (si ADR #10 positivo): listar funciones como `aggregateDuplicateReports`, `expireStopRequests`, `notifyCommunityOnValidation` | `/engineering:system-design` | Diagrama/tabla |
| 2'.4 | **Estructura de carpetas extendida** (§11 del SDD): activar `lib/features/community/` en Flutter, `modules/community/` en FastAPI, añadir `functions/` en la raíz si entra Cloud Functions | `/engineering:documentation` | Texto Markdown |
| 2'.5 | **Extender el mapping dominio → componentes** (tabla del RESUMEN §6) con los nuevos | — | Tabla actualizada |

**Archivos necesarios:** `SDD_FASE2_UBISAFE.md`, `SDD_FASE2_PASO25_UBISAFE.md`, `SDD2_FASE1_UBISAFE.md`.

---

### Fase 3.A' — Base de datos: raite (CU-04)
**🟦 Alexis · Paralelizable con Fase 1' · 0.5 sesión**

**Objetivo:** Modelar la colección `rides` y extender `users` para soportar CU-04.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 3.A'.1 | Diseñar colección `rides/{id}`: `buyer_uid`, `vendor_uid`, `pickup_location` (GeoPoint), `destination` (GeoPoint), `route_polyline`, `status` (`pending → accepted → in_progress → completed` / `rejected` / `expired`), timestamps | `/engineering:documentation` | Tabla + texto Markdown |
| 3.A'.2 | Extender colección `users` con `ride_enabled: boolean` (solo VENDOR) | `/engineering:documentation` | Actualización tabla `users` |
| 3.A'.3 | Definir reglas Firestore para `rides` (buyer lee solo sus rides, vendor lee los suyos, escritura limitada por rol) | `/engineering:documentation` | Pseudocode reglas |
| 3.A'.4 | Validar con SRS v2.1 que todos los RF de CU-04 tienen cobertura en el modelo | — | Checklist |

**Archivos necesarios:** `SDD_FASE3_UBISAFE.md`, `BB_SRS_V2.1.md` (sección CU-04).

---

### Fase 3.B' — Base de datos: reportes comunitarios (CU-05 + CU-06)
**🟦 Alexis · Paralelizable con Fase 2' · 1 sesión**

**Objetivo:** Modelar la capa de reportes comunitarios con validación y redactar los ADRs asociados.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 3.B'.1 | Diseñar colección `community_reports/{id}`: `reporter_uid`, `threat_type`, `severity` (`HIGH/MEDIUM/LOW`), `geometry` (polígono GeoJSON o círculo), `status` (`pending_validation / active / dismissed / expired`), `validations[]` (array de `{validator_uid, verdict, timestamp}`), `validation_count`, timestamps, `expires_at` | `/engineering:documentation` | Tabla + texto Markdown |
| 3.B'.2 | (Si ADR #6 define puntos de reputación) Diseñar colección `reputation_events/{id}`: `user_uid`, `event_type`, `delta`, `ref_id`, `created_at` | `/engineering:documentation` | Tabla |
| 3.B'.3 | **ADR #6 — Modelo de validación/reputación** (versión final consolidada desde borrador de Fase 0') | `/engineering:architecture` | ADR Markdown |
| 3.B'.4 | **ADR #7 — Geometría de zonas (polígonos vs círculos, migración `risk_zones`)** | `/engineering:architecture` | ADR Markdown |
| 3.B'.5 | **ADR #11 — Unificación de reportes (o coexistencia con `risk_zones`)** | `/engineering:architecture` | ADR Markdown |
| 3.B'.6 | (Si aplica Cloud Function) Documentar trigger `onCreate` en `community_reports` que dispara `aggregateDuplicateReports` | `/engineering:documentation` | Pseudocode |
| 3.B'.7 | Actualizar sección §8.3 del SDD iter. 1 "Colecciones previstas iter. 2-3": tachar las ya diseñadas | — | Actualización de texto |

**Archivos necesarios:** `SDD_FASE3_UBISAFE.md`, `BB_SRS_V2.1.md` (CU-05, CU-06), `SDD2_FASE1_UBISAFE.md` (para saber si Cloud Functions aplica).

---

### Fase 4.A' — Diagrama de Secuencia CU-04 (Raite)
**🟩 Miguel · Paralelizable con Fase 4.B' · 0.5–1 sesión**

**Objetivo:** Documentar el comportamiento dinámico de CU-04 en el mismo estilo que `SDD_FASE4_UBISAFE.md`.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 4.A'.1 | **Diagrama 9.5.A — Flujo normal CU-04:** Comprador elige destino → validación distancia ≤4km y zona segura → POST `/rides` → notificación FCM a vendedor → vendedor acepta → navegación con Directions API → llegada al punto de recogida → viaje al destino → confirmación | `/engineering:system-design` | Mermaid sequenceDiagram |
| 4.A'.2 | **Diagrama 9.5.B — Flujo alternativo:** vendedor rechaza ó destino fuera de radio permitido ó ruta atraviesa zona HIGH | `/engineering:system-design` | Mermaid |
| 4.A'.3 | **Diagrama 9.5.C — Excepción:** pérdida de GPS a mitad del raite ó timeout en aceptación | `/engineering:system-design` | Mermaid |
| 4.A'.4 | Texto descriptivo previo a cada diagrama (estilo §8.1 del SDD) | `/engineering:documentation` | Markdown |

**Archivos necesarios:** `SDD_FASE4_UBISAFE.md` (estilo y convenciones), `SDD2_FASE2_UBISAFE.md`, `SDD2_FASE3A_UBISAFE.md`.

**Nota:** Mantener **exactamente los nombres canónicos** del Apéndice del RESUMEN (`MapScreenBuyer`, `RideRouter`, `StopRequestModule`, etc.).

---

### Fase 4.B' — Diagramas de Secuencia CU-05 + CU-06
**🟦 Alexis · Paralelizable con Fase 4.A' · 1 sesión**

**Objetivo:** Documentar los dos CU de dominio Safety/Community.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 4.B'.1 | **Diagrama 9.6.A — CU-05 Flujo normal:** Usuario define polígono/zona → POST `/community-reports` → FastAPI crea doc con `status: pending_validation` → Cloud Function `aggregateDuplicateReports` valida duplicados → si único, sincroniza a RTDB o FCM masivo | `/engineering:system-design` | Mermaid |
| 4.B'.2 | **Diagrama 9.6.B — CU-05 Alt/Excepción:** reporte duplicado (agrega validación existente), nivel LOW/MEDIUM distinto, pérdida de conexión con retry | `/engineering:system-design` | Mermaid |
| 4.B'.3 | **Diagrama 9.7.A — CU-06 Flujo normal:** Usuario abre lista de reportes activos → filtra → entra a detalle → aprueba/desaprueba → PATCH `/community-reports/{id}/validations` → actualización de `validation_count` → recomputa `status` si umbral cruzado | `/engineering:system-design` | Mermaid |
| 4.B'.4 | **Diagrama 9.7.B — CU-06 Alt/Excepción:** usuario intenta validar su propio reporte (rechazo), reporte ya no activo | `/engineering:system-design` | Mermaid |

**Archivos necesarios:** `SDD_FASE4_UBISAFE.md`, `SDD2_FASE2_UBISAFE.md`, `SDD2_FASE3B_UBISAFE.md`.

---

### Fase 5A' — Extensión del Design System
**🟨 Conjunto · Review · 0.5 sesión**

**Objetivo:** Asegurar que los tokens existentes cubren las necesidades nuevas (polígonos de severidad, chips de estado, indicadores de validación). Si falta algo, añadirlo.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 5A'.1 | Revisar §8.1 de `SDD_FASE5_UBISAFE.md`: ¿los colores semánticos cubren los 3 niveles de severidad (HIGH rojo, MEDIUM naranja, LOW azul)? (Sí, ya están.) | `/design:design-system` | Confirmación |
| 5A'.2 | **Añadir tokens/components nuevos:** chip de estado `pending_validation` (amarillo), chip `validated` (verde), chip `dismissed` (gris); indicador de votación (counter + ícono pulgar); estilo de polígono vs círculo en mapa | `/design:design-system` | Tokens Markdown |
| 5A'.3 | **Añadir patrón "DestinationPicker":** input con autocomplete + pin draggable + confirmación | `/design:design-system` | Spec del componente |

**Archivos necesarios:** `SDD_FASE5_UBISAFE.md`.

---

### Fase 5B' — Wireframes pantallas nuevas
**🟩 Miguel · Paralelizable con Fase 5B.alt' · 1 sesión**

**Objetivo:** Diseñar wireframes de baja fidelidad (ASCII o HTML al estilo iter. 1) para las pantallas completamente nuevas.

| # | Pantalla nueva | CU origen | Notas |
|---|---|---|---|
| 5B'.1 | **Pantalla Solicitud de Raite** (destino + estimación + botón solicitar) | CU-04 | Mapa fullscreen con bottom sheet de confirmación |
| 5B'.2 | **Pantalla Reportar Foco de Infección** (tipo amenaza + severidad + selector de polígono o círculo) | CU-05 | Extensión del bottom sheet de riesgo, con modo polígono |
| 5B'.3 | **Pantalla Lista de Reportes Activos** (cards con tipo, severidad, ubicación, estado de validación) | CU-06 | Entrada desde Drawer |
| 5B'.4 | **Pantalla Detalle + Validación de Reporte** (datos + mapa + botones aprobar/desaprobar + contador) | CU-06 | Navegación desde 5B'.3 |

**Skill:** — (wireframes manuales / HTML al estilo iter. 1, sin skill específica).

**Output:** `SDD2_FASE5B_UBISAFE.md` con bloques ASCII y/o archivos HTML `wireframe_<pantalla>.html` en la carpeta del proyecto.

**Archivos necesarios:** `SDD2_FASE5A_UBISAFE.md`, `SDD_FASE5_UBISAFE.md` (para mantener estilo).

---

### Fase 5B.alt' — Wireframes de extensiones
**🟦 Alexis · Paralelizable con Fase 5B' · 0.5–1 sesión**

**Objetivo:** Diseñar las modificaciones a pantallas ya existentes.

| # | Pantalla existente | Modificación |
|---|---|---|
| 5B.alt'.1 | **Home Comprador** (MapScreenBuyer) | Añadir polígonos (no solo círculos) y botón "Solicitar raite" al tocar vendedor |
| 5B.alt'.2 | **Home Vendedor** (MapScreenVendor) | Añadir recepción de solicitud de raite (dialog distinto al de parada) |
| 5B.alt'.3 | **Mi Perfil** | Añadir toggle "Habilitar raites" (solo VENDOR) |
| 5B.alt'.4 | **Drawer** | Añadir entrada "Reportes activos" → lleva a 5B'.3 |
| 5B.alt'.5 | **Historial de Actividad** | Añadir tab/filtro "Raites" |

**Skill:** —

**Output:** `SDD2_FASE5Balt_UBISAFE.md`.

**Archivos necesarios:** `SDD_FASE5_UBISAFE.md` (pantallas existentes como base).

---

### Fase 5C' — Mockups de alta fidelidad (Claude Design)
**🟩 Miguel · Secuencial (tras 5B' y 5B.alt') · 1–2 sesiones**

**Objetivo:** Generar prompts para Claude Design que produzcan los mockups alta fidelidad a partir de los wireframes aprobados.

> **⚠ Miguel:** esta fase requiere que tengas **https://claude.ai/** abierto en otra pestaña. El Claude de este plan **no** genera los mockups — te prepara los **prompts**. Tú los pegas en Claude Design, recibes el mockup, lo guardas como imagen y lo adjuntas al archivo final.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 5C'.1 | Para cada pantalla de 5B' y 5B.alt' generar un prompt estructurado que incluya: (a) design tokens de §8.1 de `SDD_FASE5_UBISAFE.md`, (b) wireframe textual, (c) requisitos de accesibilidad (14sp mínimo, contraste, touch ≥48dp), (d) rol/contexto de la pantalla, (e) referencia al look & feel de los mockups de iter. 1 | `/design:design-handoff` | Prompts en Markdown |
| 5C'.2 | Pegar cada prompt en Claude Design (https://claude.ai), capturar el mockup resultante, guardarlo como `mockup_<pantalla>.png` en la carpeta | — | Imágenes |
| 5C'.3 | **Revisión de consistencia visual** entre los 9 mockups totales (5 nuevos + 4 modificados) | `/design:design-critique` | Feedback estructurado |
| 5C'.4 | **Revisión de accesibilidad** (adultos mayores, uso en exterior) | `/design:accessibility-review` | Reporte |

**Archivos necesarios:** `SDD2_FASE5B_UBISAFE.md`, `SDD2_FASE5Balt_UBISAFE.md`, `SDD_FASE5_UBISAFE.md` §8.1 (design system) y §8.18+ (ejemplo prompts iter. 1).

---

### Fase 5D' — Diagrama de Navegación extendido
**🟦 Alexis · Paralelizable con Fase 5C' · 0.5 sesión**

**Objetivo:** Extender el `graph TD` de navegación existente con los nodos de CU-04/05/06 y la entrada nueva del Drawer.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 5D'.1 | Añadir nodos de CU-04: desde HomeC → "Solicitar raite" → DestinoPicker → Confirmación → Tracking (reusar nodo Tracking) | — | Mermaid extendido |
| 5D'.2 | Añadir nodos de CU-05: variante del FAB "+" → elección modal (reportar riesgo simple vs. reportar foco con validación) | — | Mermaid extendido |
| 5D'.3 | Añadir nodos de CU-06: Drawer → "Reportes activos" → Lista → Detalle/Validación | — | Mermaid extendido |
| 5D'.4 | Validar que el grafo extendido cubre todos los CU del SRS v2.1 | — | Checklist |

**Archivos necesarios:** `SDD_FASE5_UBISAFE.md` §10 (diagrama original), `BB_SRS_V2.1.md`.

---

### Fase 6' — ADRs consolidados
**🟦 Alexis · 1 sesión**

**Objetivo:** Compilar todos los ADRs en la §3 del SDD, incluyendo los pendientes de iter. 1 y los nuevos de iter. 2.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 6'.1 | Redactar (o recopilar) los **ADRs retroactivos A, B, C** de iter. 1 que quedaron pendientes: Firebase Auth, Google Maps, FCM | `/engineering:architecture` | 3 ADRs en Markdown |
| 6'.2 | Consolidar **ADRs #5, #6, #7, #10, #11** (los que se activaron en iter. 2) con formato estándar (Context, Decision, Consequences) | `/engineering:architecture` | 3–5 ADRs |
| 6'.3 | Redactar sección breve de **deuda técnica declarada** (Haversine client-side, fan-out geográfico pendiente a iter. 3 si no entra en iter. 2) | `/engineering:documentation` | Párrafo Markdown |
| 6'.4 | Organizar la §3 del SDD cronológica o temáticamente (sugerencia: temática — Persistencia, Cartografía, Notificaciones, Estado, Seguridad) | — | Estructura final |

**Archivos necesarios:** Todos los ADRs dispersos en los `SDD_FASE*.md` y `SDD2_FASE*.md`.

---

### Fase 7' — Trazabilidad e historial
**🟨 Conjunto · Pair final · 1 sesión**

**Objetivo:** Asegurar que todo CU-04/05/06 se rastrea desde SRS hasta UI.

| Paso | Actividad | Skill sugerida | Output |
|---|---|---|---|
| 7'.1 | Extender **Matriz 1:** CU → Componentes → Interfaces → Diagrama de secuencia → Pantallas UI. Añadir filas para CU-04, CU-05, CU-06 | `/engineering:documentation` | Tabla |
| 7'.2 | Extender **Matriz 2:** RNFs (del SRS v2.1) → Decisiones arquitectónicas. Mapear RNFs nuevos y reforzados (performance <30s, ≤100m GPS, retry offline) | `/engineering:documentation` | Tabla |
| 7'.3 | **Historial V3.0:** añadir entrada al §13 con fecha, autores, resumen de cambios iter. 2 | — | Tabla de versiones extendida |
| 7'.4 | **Marcadores visuales** en todas las secciones nuevas: anotación *[iter. 2]* en encabezados o columna *Iteración* en tablas | — | Aplicado en todo el .docx |

---

### Fase 8' — Verificación final
**🟨 Conjunto · Pair · 0.5–1 sesión**

**Objetivo:** Quality gate antes de entregar.

| Paso | Verificación | Método |
|---|---|---|
| 8'.1 | **IEEE 1016-2009:** todos los Design Viewpoints tienen diagrama + descripción (ahora con CU-04/05/06 cubiertos) | Checklist |
| 8'.2 | **Profesor — 6 criterios:** componentes+relaciones, BD, detalles de componentes, UI, C4/UML, contenidos de la iteración | Checklist |
| 8'.3 | **Equipo — checklist interno** | Checklist |
| 8'.4 | **Consistencia de nombres:** los nombres canónicos (Apéndice del RESUMEN) se mantienen en todos los diagramas y textos nuevos | Revisión cruzada Alexis+Miguel |
| 8'.5 | **Trazabilidad completa:** cada CU del SRS v2.1 aparece en al menos un diagrama de secuencia, un diagrama de componentes y una pantalla de UI | Matriz §12 |
| 8'.6 | Sugerencia: usar la skill `srs-review` para validar en paralelo que el SRS v2.1 sigue siendo consistente con el SDD v2.0 | `/anthropic-skills:srs-review` opcional |

---

## 6. Uso estratégico de skills por fase (recordatorio)

Tanto Alexis como Miguel tienen estas skills en su Claude Cowork:

| Skill | Fases que más la usan |
|---|---|
| `/engineering:architecture` | 0', 1', 2', 3.A', 3.B', 6' |
| `/engineering:system-design` | 1', 2', 4.A', 4.B' |
| `/engineering:documentation` | 0', 2', 3.A', 3.B', 4.A', 4.B', 6', 7' |
| `/design:design-system` | 5A' |
| `/design:design-handoff` | **5C'** (clave para generar prompts Claude Design) |
| `/design:design-critique` | 5C' |
| `/design:accessibility-review` | 5C' |
| `/anthropic-skills:srs-review` | 8' (opcional) |

**Herramienta clave nueva:** **Claude Design** (https://claude.ai/) — reemplaza al conector Figma de iter. 1. **Miguel** la usará en Fase 5C'. Si nunca la ha abierto, entra a `https://claude.ai/`, abre una conversación nueva y pega el prompt preparado en 5C'.1 — Claude Design genera un mockup como artefacto HTML/SVG que Miguel puede exportar como imagen.

---

## 7. Checklist rápido para arrancar

> Antes de empezar la primera sesión de pair (Fase 0'):

- [ ] Ambos han leído `BB_SRS_V2.1.md` y saben qué es nuevo (CU-04/05/06)
- [ ] Ambos tienen en su máquina los 10 archivos base listados en §0.3
- [ ] Ambos acuerdan el canal de handoff (Drive / WhatsApp / otro)
- [ ] Alexis reserva la pair session de Fase 0' (≈ 1h)
- [ ] Miguel tiene https://claude.ai/ probado y listo (no necesario hasta Fase 5C', pero conviene anticiparse)

---

## 8. Historial del plan

| Versión | Fecha | Autor(es) | Descripción |
|---|---|---|---|
| **V1.0** | 2026-04-23 | Alexis Córdova (con asistencia de Claude) | Plan inicial iter. 2. Basado en SRS v2.1 y SDD iter. 1 completo (Fases 0–5). Estructurado para ejecución paralela entre Alexis y Miguel. Reemplaza Figma por Claude Design en Fase 5C'. |

---

*Plan generado el 23/04/2026 — Los Borbotones / UBISAFE Iteración 2.*
