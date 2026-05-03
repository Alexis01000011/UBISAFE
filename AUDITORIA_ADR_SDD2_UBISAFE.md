# Auditoría de ADRs — SDD2 UBISAFE
**Proyecto:** UBISAFE — Los Borbotones  
**Iteración:** 2  
**Fecha de auditoría:** 2026-04-25  
**Objetivo:** Verificar que las 11 ADRs documentadas en `SDD2_FASE6_UBISAFE.md` estén correctamente implementadas, referenciadas y sin inconsistencias en el conjunto de documentos `SDD2_FASEX_UBISAFE.md`.

---

## 1. Matriz de cobertura

Cada celda indica si el ADR aparece **explícitamente citado** (✅), está **implícitamente implementado** sin cita formal (⬜) o **no aplica** a ese documento (—).

| ADR | Título corto | FASE0 | FASE1 | FASE2 | FASE3A | FASE3B | FASE4A | FASE4B | FASE5A | FASE5B | FASE5Balt | FASE5C | FASE6 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| #1 | Monolito FastAPI | ⬜ | ✅ | ⬜ | — | — | — | — | — | — | — | — | ✅ |
| #2 | GPS directo RTDB | ✅ | — | ✅ | — | — | — | — | — | — | — | — | ✅ |
| #3 | Persistencia políglota | — | ⬜ | ⬜ | ⬜ | ⬜ | — | — | — | — | — | — | ✅ |
| #4 | Riverpod | — | — | — | — | — | — | — | — | — | — | — | ✅ |
| #5 | Firebase Storage (diferido) | ✅ | — | — | — | — | — | — | — | — | — | — | ✅ |
| #6 | Modelo de votación comunidad | ✅ | — | — | — | ✅ | — | ✅ | — | — | — | — | ✅ |
| #7 | Geometría de zonas (círculos) | ✅ | — | ✅ | — | ✅ | — | — | — | — | — | — | ✅ |
| #10 | Cloud Functions orquestador | ✅ | ✅ | — | — | — | — | — | — | — | — | — | ✅ |
| #11 | Dos colecciones separadas | ✅ | — | ✅ | — | ✅ | — | — | — | — | — | — | ✅ |
| Retro-A | Firebase Auth | — | ⬜ | — | — | — | — | — | — | — | — | — | ✅ |
| Retro-B | Google Maps Platform | — | ⬜ | — | — | — | — | — | — | — | — | — | ✅ |
| Retro-C | FCM canal push | — | ⬜ | — | — | — | — | — | — | — | — | — | ✅ |

**Leyenda:** ✅ citado explícitamente con etiqueta `ADR #X` · ⬜ implementado sin cita formal · — no aplica / no referenciado

---

## 2. Hallazgos por severidad

### 🔴 CRÍTICO — Correcciones aplicadas

#### C-01: Conteo de eventos FCM incorrecto en FASE1
- **Archivo:** `SDD2_FASE1_UBISAFE.md`, línea 320 (antes de corrección)
- **Texto original:** `Total de tipos de evento FCM tras iter. 2: 7 (3 de iter. 1 + 4 nuevos)`
- **Texto correcto:** `Total de tipos de evento FCM tras iter. 2: 8 (4 de iter. 1 + 4 nuevos)`
- **Causa:** iter. 1 definió 4 eventos FCM (`stop_request_incoming`, `stop_request_accepted`, `stop_request_rejected`, `risk_zone_alert`), no 3. `SDD2_FASE2_UBISAFE.md` ya lo contaba correctamente como 8.
- **Estado:** ✅ **Corregido automáticamente.**

#### C-02: Estado `cancelled` fantasma en `rides` — FASE1
- **Archivo:** `SDD2_FASE1_UBISAFE.md`, líneas 208 y 223 (antes de corrección)
- **Texto original (l. 223):** `status distinto de completed, cancelled o rejected`
- **Texto correcto:** `status distinto de completed, rejected o expired`
- **Causa:** El modelo canónico de `rides` (definido en `SDD2_FASE3A_UBISAFE.md`) no contempla el estado `cancelled`. Los estados válidos son: `pending`, `accepted`, `in_progress`, `completed`, `rejected`, `expired`. El estado de terminación para rides que no son aceptadas es `rejected`; el de las que expiran por timeout es `expired`.
- **Contexto adicional:** la misma línea 208 también mencionaba `status ≠ completed/cancelled` para la comprobación inline del párrafo descriptivo — también corregido.
- **Estado:** ✅ **Corregido automáticamente** (dos ocurrencias en la misma línea/párrafo).

---

### 🟡 MENOR — Corrección recomendada (no crítica)

#### M-01: Mención residual de "Node.js" en FASE0
- **Archivo:** `SDD2_FASE0_UBISAFE.md`, línea 130
- **Texto:** `La función está en **Node.js** (Cloud Functions gen2) para aprovechar el SDK de Firebase Admin que el equipo ya conoce de FastAPI via Python; **alternativa:** Cloud Functions for Python (gen2) para mantener un solo lenguaje.`
- **Problema:** El texto presenta Node.js como primera opción y Python gen2 como "alternativa", pero la decisión oficial (ratificada en §0'.3 del mismo documento y en todos los demás archivos) es Python gen2. Esta formulación invierte el orden y puede confundir a un revisor externo.
- **Corrección sugerida:** Cambiar el texto a: `La función se implementa en **Python gen2** (Cloud Functions gen2) para mantener consistencia de lenguaje con el monolito FastAPI; se descartó Node.js porque añadiría una segunda tecnología de runtime sin beneficio funcional para el equipo.`
- **Estado:** ⚠️ **No corregido.** Corrección menor — requiere aprobación del equipo antes de modificar.

---

### 🔵 INFORMATIVO — Sin acción requerida

#### I-01: Recuento de métodos en NotificationService diverge entre fases
- **FASE2** (`SDD2_FASE2_UBISAFE.md`): describe 8 métodos totales en `NotificationService` (4 iter. 1 + 4 raite/reporte iter. 2).
- **FASE4B** (`SDD2_FASE4B_UBISAFE.md`): describe 11 métodos totales (4 iter. 1 + 4 raite + 3 validación CU-06 iter. 2).
- **Diagnóstico:** Evolución legítima. FASE4B documenta el estado final tras añadir los 3 métodos de notificación de validación (`notifyReportConfirmed`, `notifyReportDismissed`, `notifyValidationReceived`) que no existían aún cuando se escribió FASE2. FASE4B es la fuente de verdad para el estado final de `NotificationService`.
- **Estado:** ℹ️ Sin acción — los documentos reflejan el orden cronológico de diseño.

#### I-02: ADR #3 (persistencia políglota) no tiene cita explícita en documentos operacionales
- **Situación:** La split Firestore/RTDB está implementada correctamente en todos los documentos (FASE1-5), pero ninguno incluye la etiqueta formal `(ADR #3)` junto a la descripción del split.
- **Impacto:** Bajo. La implementación es consistente; la ausencia es solo de trazabilidad formal.
- **Recomendación:** En iter. 3, si se escribe un documento de contexto de decisiones, añadir `(ver ADR #3)` en la descripción del contenedor Cloud Firestore en FASE1 y en la tabla de bounded contexts de FASE2.
- **Estado:** ℹ️ Sin acción urgente.

#### I-03: ADR #4 (Riverpod) no tiene cita explícita en ningún FASE2-5
- **Situación:** Riverpod es el state manager de Flutter pero los documentos de iter. 2 no referencian `ADR #4` en ninguna sección de componentes Flutter (FASE2) ni en secuencias (FASE4A).
- **Diagnóstico:** Los documentos de iter. 2 se focalizan en backend; la decisión de state management pertenece a iter. 1 y no hubo cambios.
- **Estado:** ℹ️ Sin acción — expected behavior para ADR de iter. anterior sin cambios.

#### I-04: ADRs Retro-A/B/C sin referencias en documentos operacionales
- **Situación:** Por su naturaleza retroactiva, Firebase Auth, Google Maps y FCM como canal push nunca fueron documentados con etiqueta ADR antes de FASE6. Los documentos operacionales los mencionan como tecnologías externas sin cita ADR.
- **Estado:** ℹ️ Sin acción — la FASE6 los consolida correctamente.

---

## 3. Resumen ejecutivo

| Categoría | Cantidad | Estado |
|---|---|---|
| 🔴 Críticos | 2 | ✅ Corregidos en `SDD2_FASE1_UBISAFE.md` |
| 🟡 Menores | 1 | ⚠️ Pendiente de aprobación (FASE0 l.130) |
| 🔵 Informativos | 4 | ℹ️ Sin acción requerida |

**ADRs con cobertura completa** (citados explícitamente en al menos 2 documentos operacionales + FASE6): #2, #5, #6, #7, #10, #11

**ADRs con cobertura parcial** (implementados pero sin citas formales en documentos operacionales): #1, #3, #4, Retro-A, Retro-B, Retro-C

**ADRs que no aplican a documentos operacionales** (correctamente centralizados en FASE0/FASE6): #5 (diferido)

---

## 4. Archivos modificados

| Archivo | Línea | Cambio |
|---|---|---|
| `SDD2_FASE1_UBISAFE.md` | 208 | `status ≠ completed/cancelled` → `status ≠ completed/rejected/expired` |
| `SDD2_FASE1_UBISAFE.md` | 223 | `cancelled o rejected` → `rejected o expired` |
| `SDD2_FASE1_UBISAFE.md` | 320 | `7 (3 de iter. 1 + 4 nuevos)` → `8 (4 de iter. 1 + 4 nuevos)` |
