# PLAN_CODE — UBISAFE
**Proyecto:** Los Borbotones · TSP · ITESM
**Fecha:** 25/04/2026
**Versión:** V1.0
**Alcance:** Iteración 1 (CU-01/02/03 + Auth) + Iteración 2 (CU-04/05/06)
**Equipo:** Alexis Córdova (PM/líder de equipo) · Miguel Esaú Rivera Román (líder técnico) · Leonardo Fernández Morales (líder de calidad)

---

## 0. ¿Cómo usar este plan?

Este documento es la **guía de implementación** que mapea cada decisión del SDD a tareas de código ejecutables. Está pensado para ser ejecutado en sesiones independientes de Claude Code por Alexis y Miguel, cada quien con su propia cuenta.

**Reglas de oro al ejecutar este plan en Claude Code:**

1. **Antes de cada fase**, abrir el SDD relevante listado en la cabecera de la fase. No leer todos los SDDs en una sola sesión — cargar solo los que se referencian.
2. **Para mapear archivos del SDD a fases**, consultar siempre `INDICE_SDD_UBISAFE.md`. Es el índice maestro y evita cargar contexto innecesario.
3. **Una rama, un PR, un CU** (ver §4 — Estrategia de Git). Nunca mezclar dominios distintos en el mismo PR.
4. **Cada fase tiene un Definition of Done explícito** — no marcar como completa hasta que pasen los tests + el peer review.
5. **Si encuentras un conflicto entre el código que vas a escribir y el SDD**, NO improvises: documenta la duda, pide clarificación al PM (Alexis) y, si la decisión es nueva, regístrala como ADR antes de escribir código.

> **Referencia maestra:** `INDICE_SDD_UBISAFE.md` (en la raíz del proyecto). Cada fase de este plan apunta a uno o varios archivos SDD que se deben leer **antes** de empezar a codificar.

---

## 1. Resumen ejecutivo

UBISAFE consiste en **3 componentes desplegables independientes** + **tres bases de datos**:

| Componente           | Tecnología                               | Carpeta del repo | Iteración     |
| -------------------- | ---------------------------------------- | ---------------- | ------------- |
| App móvil            | Flutter 3.x / Dart 3.x · Android API 29+ | `ubisafe_app/`   | 1 + 2         |
| API REST             | Python 3.11+ / FastAPI 0.110+            | `ubisafe_api/`   | 1 + 2         |
| Funciones serverless | Python gen2 / Firebase Functions         | `functions/`     | **2** (nueva) |

| Persistencia        | Servicio                         | Uso                                                                                        |
| ------------------- | -------------------------------- | ------------------------------------------------------------------------------------------ |
| Datos estructurados | Cloud Firestore                  | `users`, `stop_requests`, `risk_zones`, `rides` *(iter.2)*, `community_reports` *(iter.2)* |
| Tiempo real         | Firebase RTDB                    | `/vendedores_activos/{vendor_uid}`                                                         |
| Identidad           | Firebase Auth                    | JWT 1h + refresh automático                                                                |
| Push                | FCM                              | 7 tipos de evento (3 iter.1 + 4 iter.2)                                                    |
| Mapas/rutas         | Google Maps SDK + Directions API | Visualización + cálculo de rutas seguras                                                   |

**Dominios (Bounded Contexts) — la estructura de carpetas refleja esta agrupación:**

`Identity & Access` · `Presence` · `Dispatching` · `Safety` · `Community` *(activado iter.2)* · `Shared`

---

## 2. Plugins recomendados de Claude Code

Estos plugins se instalan **una vez por persona** en su instancia de Claude Code (cada miembro del equipo gestiona sus propios plugins). Son recomendaciones de `claude-plugins-official` (o equivalentes mantenidos por Anthropic) más uno o dos comunitarios bien probados.

### 2.1. Plugins esenciales (instalar al inicio de F0)

| Plugin          | Origen                                                 | Por qué nos sirve                                                                                                                                                           | Prioridad       |
| --------------- | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- |
| **engineering** | `claude-plugins-official`                              | Skills para code-review, debug, system-design, testing-strategy, documentation, deploy-checklist, incident-response. Cubre la mayoría de tareas de implementación.          | **Obligatorio** |
| **design**      | `claude-plugins-official`                              | Skills para design-handoff, design-critique, ux-copy, accessibility-review. Útil al implementar wireframes y validar AA WCAG (RNF-02 — accesibilidad para adultos mayores). | **Obligatorio** |
| **github**      | `claude-plugins-official` (si existe) o conector MCP   | Crear/listar issues, abrir PR con plantilla, leer reviews, gestionar branches sin salir de la sesión.                                                                       | **Recomendado** |
| **firebase**    | `claude-plugins-official` (si existe) o `firebase` MCP | Inspección de Firestore, despliegue de reglas, despliegue de Cloud Functions, lectura de logs. Acelera mucho el F0 y el F7.                                                 | **Recomendado** |

### 2.2. Plugins opcionales (instalar si surge la necesidad)

| Plugin | Cuándo activarlo |
|---|---|
| **flutter** (si existe oficial) | Si el equipo encuentra fricción con el toolchain de Flutter (gradle, build runner, lint). |
| **postman** o **httpie** MCP | Para testear endpoints REST de FastAPI sin salir de Claude Code. |

### 2.3. Skills built-in que ya tenemos en este proyecto

Sin instalar nada adicional, ya están disponibles:

- `borbotones-docs` — generación de docs Word con la plantilla del proyecto.
- `srs-review` — auditor del SRS (útil si se descubre un gap durante la codificación).
- `docx`, `pdf`, `xlsx`, `pptx` — para entregables académicos.
- `init`, `review`, `security-review` — slash commands built-in.

> **Convención del equipo:** Cada persona declara en su `CLAUDE.md` local los plugins que instaló, para que el otro pueda replicar el setup si quiere.

---

## 3. Agentes propuestos para el proyecto

Los agentes son sub-Claudes especializados que se invocan con la tool `Agent` o el slash command equivalente. Todos viven en `.claude/agents/` del repositorio (compartidos entre Alexis y Miguel via Git). Se proponen 4 agentes — los dos primeros son **muy recomendados**, los otros dos son opcionales.

### 3.1. `sdd-traceability-checker` (recomendado)

**Cuándo usarlo:** Antes de abrir un PR, para verificar que el código nuevo cumple con lo descrito en el SDD asociado al CU.

**Input:**
- Diff del PR
- ID del CU (ej. CU-01)
- Path al archivo SDD correspondiente (ej. `SDD_FASE2_PASO25_UBISAFE.md`)

**Output:** Reporte con:
- ¿Los componentes implementados coinciden con los nombres canónicos del SDD?
- ¿Los endpoints implementados coinciden con la tabla del SDD?
- ¿Las colecciones Firestore tienen exactamente los campos del esquema?
- Lista de discrepancias y sugerencias de fix.

**Tools:** Read, Grep, Glob.

**Por qué importa:** El SDD es la fuente de verdad. Este agente detecta drift entre código y diseño antes de que llegue a `main`.

---

### 3.2. `firestore-rules-reviewer` (recomendado)

**Cuándo usarlo:** Cada vez que se modifica `firestore.rules` o `database.rules.json`.

**Input:** Diff de las reglas + lista de colecciones afectadas.

**Output:**
- ¿Las reglas reflejan exactamente las restricciones del SDD §7.2.4 / §7.3.5 / §3.A'.3 / §3.B'.3?
- ¿Hay alguna regla más permisiva de lo necesario?
- ¿Hay reglas faltantes para colecciones nuevas?
- Sugerencia de tests con el emulador.

**Tools:** Read, Grep, Bash (para correr `firebase emulators:exec` con tests).

**Por qué importa:** Una regla mal escrita = brecha de seguridad. RNF-05 lo exige.

---

### 3.3. `flutter-test-writer` (opcional)

**Cuándo usarlo:** Al cerrar un componente de Flutter sin tests.

**Input:** Path al archivo Dart (ej. `lib/features/dispatching/services/stop_request_module.dart`).

**Output:** Archivo de test correspondiente con:
- Tests unitarios de cada método público.
- Mocks de Firebase / API HTTP.
- Tests de los providers Riverpod si aplica.

**Tools:** Read, Write, Edit, Bash (para correr `flutter test`).

---

### 3.4. `acceptance-runner` (opcional)

**Cuándo usarlo:** Al cerrar un CU completo, para validar todos los criterios de aceptación de extremo a extremo.

**Input:** ID del CU + ambiente local funcionando.

**Output:**
- Reporte de qué CA pasaron y cuáles no.
- Para los que fallaron: traza de la falla (request/response, log de FastAPI, snapshot de Firestore).

**Tools:** Bash (curl, firebase emulator), Read.

---

## 4. Estrategia de Git y convenciones para Claude Code

### 4.1. Branching — GitHub Flow simple

```
main (protegida, requiere PR + 1 review)
  ├── feat/auth/signup-screen
  ├── feat/dispatching/cu-01-stop-request
  ├── fix/auth/jwt-refresh
  └── chore/setup/ci-pipeline
```

**Reglas:**

- `main` es siempre desplegable. Nunca pushear directo.
- Una rama por fase/CU/feature. Nunca mezclar dos dominios en una rama.
- Las ramas viven **máximo 5 días**. Si una fase requiere más tiempo, partirla en sub-PRs.
- La rama se elimina al merge.

### 4.2. Naming convention de ramas

`<tipo>/<dominio>/<descripcion-corta>`

| Tipo | Cuándo usarlo | Ejemplo |
|---|---|---|
| `feat` | Funcionalidad nueva | `feat/safety/cu-03-risk-form` |
| `fix` | Corrección de bug | `fix/dispatching/timeout-race-condition` |
| `chore` | Tareas de mantenimiento (deps, config, docs) | `chore/setup/firebase-emulators` |
| `refactor` | Refactor sin cambio funcional | `refactor/shared/firestore-service-async` |
| `docs` | Solo cambios en docs | `docs/readme/setup-instructions` |
| `test` | Solo añadir tests | `test/identity/auth-module-coverage` |

**Dominios válidos:** `identity`, `presence`, `dispatching`, `safety`, `community`, `shared`, `setup`, `infra`.

### 4.3. Convention de commits — Conventional Commits

```
<tipo>(<scope>): <mensaje en imperativo>

[cuerpo opcional]

[footer opcional con CU/issue]
```

**Tipos:** `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `style`, `perf`.

**Ejemplos:**

```
feat(dispatching): implement POST /stops endpoint with FCM notification

- Add StopRequestRouter with auth middleware
- Wire FirestoreService for stop_requests collection
- Send stop_request_incoming FCM event on creation

Refs: CU-01 §8.1.A
```

```
fix(presence): handle GPS timeout gracefully

The geolocator stream was throwing on timeout instead of emitting
GPSServiceState.error_no_signal. Now matches SDD §5.3.2.1.

Refs: CU-02
```

### 4.4. Plantilla de PR

Crear `.github/pull_request_template.md` en F0 con:

```markdown
## Resumen
<descripción breve de qué resuelve este PR>

## CU / Fase del plan
- CU: <CU-XX o "Setup" o "Cross-cutting">
- Fase de plan_code.md: <F1 / F2 / ...>
- SDD relevante: <archivo(s) consultado(s)>

## Checklist
- [ ] Tests unitarios añadidos / actualizados
- [ ] Tests de aceptación pasan localmente
- [ ] Reglas Firestore/RTDB actualizadas si aplica
- [ ] Documentación / SDD actualizado si hubo desviación
- [ ] Lint y format pasan (`flutter analyze`, `ruff check`)
- [ ] Sin secretos en el diff (revisar `.env`, claves Firebase)

## Cómo probar
<pasos concretos para que el reviewer verifique>

## Notas para el reviewer
<cualquier decisión no obvia, deuda técnica intencional, etc.>
```

### 4.5. Reglas para Claude Code en operaciones Git

Estas son **reglas duras** que cualquier sesión de Claude Code debe seguir. Cada persona pegará esto en su `CLAUDE.md` local.

**Lo que Claude Code SÍ puede hacer sin preguntar:**

- `git status`, `git diff`, `git log`, `git branch` — comandos de lectura.
- `git checkout -b feat/<dominio>/<descripcion>` cuando se inicia una fase.
- `git add <archivos específicos>` (nunca `git add .` sin revisar).
- `git commit -m "<mensaje conventional>"` con el mensaje propuesto.
- `git push` a la rama propia (nunca a `main`).

**Lo que Claude Code SIEMPRE debe preguntar antes de hacer:**

- `git push --force` o `git push --force-with-lease`.
- `git rebase`, `git reset --hard`, `git cherry-pick`.
- `git merge` directo a `main`.
- Eliminar ramas remotas.
- Modificar `.git/config` o hooks.
- Tocar archivos sensibles: `.env`, `firebase-service-account.json`, `google-services.json`.

**Lo que Claude Code NUNCA debe hacer:**

- Commitear secretos (claves de API, tokens, credenciales).
- Pushear a `main` directamente.
- Reescribir historia que ya fue pusheada (sin permiso explícito).
- Borrar `main` o ramas de otra persona.

### 4.6. Code review

- Cada PR requiere **1 aprobación** del otro miembro del equipo (Alexis revisa los de Miguel y viceversa).
- El revisor usa el slash command `/review` o el agente `sdd-traceability-checker` antes de aprobar.
- Comentarios deben ser específicos (línea + sugerencia concreta), no genéricos.
- Si el revisor no responde en 24h, el autor puede mergear con auto-aprobación documentando la situación.

### 4.7. CI mínimo (configurar en F0)

`.github/workflows/ci.yml` corre en cada PR:

1. **Flutter:** `flutter pub get` → `flutter analyze` → `flutter test`.
2. **FastAPI:** `pip install -r requirements.txt` → `ruff check` → `pytest`.
3. **Cloud Functions** *(iter.2)*: `pip install` → `pytest functions/tests/`.
4. **Firebase rules:** `firebase emulators:exec --only firestore "npm run test:rules"` (si configurado).

Si CI falla, el PR no puede mergear.

---

## 5. Estrategia de testing

### 5.1. Pirámide del proyecto

```
                    ┌──────────────┐
                    │  Acceptance  │  ← 1 por CU al cerrar la fase
                    │   (E2E)      │
                    └──────────────┘
                  ┌──────────────────┐
                  │   Integration    │  ← solo donde hay riesgo (Firebase)
                  │  (subset crit.)  │
                  └──────────────────┘
                ┌──────────────────────┐
                │     Unit tests       │  ← cada componente nuevo
                │   (durante fase)     │
                └──────────────────────┘
```

### 5.2. Cobertura por capa

| Capa | Herramienta | Mínimo aceptable | Cuándo se escribe |
|---|---|---|---|
| **Flutter widgets / providers** | `flutter_test`, `mocktail`, `riverpod` test utilities | 70% líneas en `services/` y `modules/` | Junto al código del componente |
| **Flutter UI golden tests** | `flutter_test` + `golden_toolkit` (opcional) | 1 golden por wireframe principal del CU | Al cerrar la fase del CU |
| **FastAPI endpoints** | `pytest`, `httpx`, `pytest-asyncio` | 80% líneas en routers, 90% en services | Junto al código del endpoint |
| **Firebase rules** | `@firebase/rules-unit-testing` (Node) o `firebase emulators:exec` con suite Python | Cada operación allow/deny tiene test | Al modificar las reglas |
| **Cloud Functions** *(iter.2)* | `pytest` + Firebase Functions Framework | 80% lógica de `DuplicateDetector` | Junto a la función |
| **Acceptance E2E** | Test manual scripted + curl/postman + emulador | 100% CA del CU pasa | Al cerrar la fase del CU |

### 5.3. Cuándo se ejecutan acceptance tests

- **Al cerrar cada CU:** Ejecutar la suite completa de acceptance del CU. Si falla cualquier CA, la fase no está completa.
- **Antes de mergear cualquier PR cross-cutting (F0, F8):** Suite completa de todos los CUs hasta el momento.
- **Antes del cierre de iteración:** Suite full + revisión manual contra wireframes.

### 5.4. Estrategia de fixtures

- Crear `ubisafe_api/tests/fixtures/` con docs JSON de ejemplo de cada colección (un `user_buyer.json`, `user_vendor.json`, `stop_request_pending.json`, etc.).
- Usar Firebase Emulator Suite **siempre** en tests; nunca el proyecto real de Firebase.
- En Flutter, `mocktail` para mockear `FirebaseAuth`, `FirebaseFirestore`, `FirebaseDatabase`. No usar el SDK real en tests unitarios.

### 5.5. Tests obligatorios por fase (resumen)

| Fase | Tests mínimos |
|---|---|
| F0 | Smoke test: arrancar la app, arrancar el API, conectar al emulador |
| F1 | Tests unitarios de design system + ApiClient interceptor + GpsRequiredEmptyState |
| F2 | Auth flow E2E (signup → login → logout); tests de AuthMiddleware (401/403/200) |
| F3 | GPSService start/stop; VendorTracker filtrado por radio; tests rules RTDB |
| F4 | CU-01 acceptance completo (3 escenarios: normal, rechazo, timeout) |
| F5 | CU-03 acceptance (HIGH, MEDIUM, LOW, duplicado) |
| F6 *(iter.2)* | CU-04 acceptance (4 escenarios principales) |
| F7 *(iter.2)* | CU-05 + CU-06 acceptance + test del Cloud Function trigger |
| F8 | Suite completa + tests de carga ligera + verificación de RNF |

---

## 6. Mapa general de fases

| Fase | Nombre | Iter | Líder tentativo | Duración estim. | Bloqueado por |
|---|---|---|---|---|---|
| **F0** | Setup del repositorio y CI | — | **Alexis** + Miguel pair | 2-3 días | — |
| **F1** | Foundation (design system, core, navegación) | 1 | **Miguel** | 2-3 días | F0 |
| **F2** | Identity & Access (Auth + Drawer) | 1 | **Alexis** | 3-4 días | F1 |
| **F3** | Presence (GPSService + VendorTracker) | 1 | **Miguel** | 3 días | F1 + F2 |
| **F4** | Dispatching iter.1 (CU-01 + mapas) | 1 | **Miguel** (back) + **Alexis** (front) | 5-6 días | F2 + F3 |
| **F5** | Safety (CU-03) | 1 | **Alexis** | 3 días | F4 (puede solapar parcialmente) |
| **F6** | Dispatching iter.2 (CU-04 raite) | 2 | **Miguel** | 4-5 días | F4 + F5 cerradas |
| **F7** | Community (CU-05 + CU-06 + Cloud Function) | 2 | **Alexis** (back/CF) + **Miguel** (front) | 5-6 días | F6 |
| **F8** | Hardening, E2E, despliegue, polish | 1+2 | Pair Alexis + Miguel | 2-3 días | Todas las anteriores |

> **Nota:** "Líder tentativo" significa quién es **dueño** de la fase, no que la otra persona no pueda colaborar. La división se basa en: (1) Miguel es tech lead y conoce mejor C4/Flutter; (2) Alexis es PM y tiene mejor contexto del SRS y reglas de negocio. Ambos hacen review de PRs del otro.

---

# PARTE A — ITERACIÓN 1

## F0 — Setup del repositorio y CI

**Líder:** Alexis (con Miguel en pair la primera sesión)
**SDD a consultar antes de empezar:**
- `INDICE_SDD_UBISAFE.md` (visión general)
- `SDD_FASE0_UBISAFE.md` §7.1 (design system tokens)
- `SDD_FASE2_PASO25_UBISAFE.md` §11 (estructura de carpetas final iter.1)
- `SDD2_FASE2_UBISAFE.md` §11 (estructura de carpetas con iter.2 — para conocer la forma final del repo)

### F0.1 — Auditar el repositorio existente

Antes de tocar nada, Claude Code debe inspeccionar lo que ya existe:

1. `git status`, `git log --oneline -20`, `ls -la` en raíz.
2. Listar carpetas en `ubisafe_app/`, `ubisafe_api/` (si existen).
3. Comparar contra la estructura objetivo de `SDD_FASE2_PASO25_UBISAFE.md §11.1` (Flutter) y `§11.2` (FastAPI).
4. Comparar contra `SDD2_FASE2_UBISAFE.md §11.1`/§11.2/§11.3 (forma final con iter.2).
5. Producir un **diff documento** en `docs/repo_audit_F0.md` con:
   - ✅ Qué ya existe y está bien.
   - ❌ Qué falta.
   - ⚠️ Qué existe pero no coincide (ej. nombre de carpeta, archivo en lugar incorrecto).

### F0.2 — Reorganizar a la estructura objetivo

Crear/mover archivos para que coincidan con la estructura domain-first **considerando ya las carpetas de iter.2** (no es trabajo extra: solo creamos `lib/features/community/` y `modules/community/` vacías para no rehacer en F6/F7).

**Estructura objetivo del repo:**

```
ubisafe-monorepo/
├── ubisafe_app/                       # Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── api/api_client.dart
│   │   │   └── design_system/{colors,typography,spacing,theme}.dart
│   │   ├── features/
│   │   │   ├── identity/{auth,profile}/
│   │   │   ├── presence/{services,models}/
│   │   │   ├── dispatching/{screens,services,widgets,models}/
│   │   │   ├── safety/{screens,models}/
│   │   │   ├── community/                  # vacía iter.1, activa iter.2
│   │   │   └── shared/{notifications,widgets}/
│   │   └── router/app_router.dart
│   ├── test/                            # paralelo a lib/
│   ├── pubspec.yaml
│   └── android/
├── ubisafe_api/                       # FastAPI
│   ├── main.py
│   ├── modules/
│   │   ├── identity/
│   │   ├── dispatching/
│   │   ├── safety/
│   │   ├── community/                   # vacía iter.1, activa iter.2
│   │   └── shared/
│   ├── dependencies.py
│   ├── tests/
│   ├── requirements.txt
│   ├── .env.example                    # template, NUNCA .env real
│   └── Dockerfile
├── functions/                         # vacío en iter.1, activo iter.2
│   └── README.md
├── firestore.rules
├── database.rules.json
├── firebase.json
├── .firebaserc
├── .github/
│   ├── workflows/ci.yml
│   └── pull_request_template.md
├── .claude/
│   ├── agents/                        # los 4 agentes propuestos
│   └── commands/                      # slash commands del proyecto
├── docs/
│   └── (toda la documentación SDD/SRS ya existente)
├── CLAUDE.md                          # guía para Claude Code
├── README.md
├── .gitignore
└── plan_code.md                       # este archivo
```

### F0.3 — Configurar herramientas

**Flutter:**
- `pubspec.yaml` con todas las deps de iter.1 (ver lista en `SDD_FASE2_PASO25_UBISAFE.md §11.1`) + `flutter_riverpod: ^2.5.1`.
- `analysis_options.yaml` con lints estrictos (`flutter_lints` + reglas custom para `prefer_const_constructors`, `avoid_print`).
- `.gitignore` para `*.env`, `google-services.json`, `*.keystore`.

**FastAPI:**
- `requirements.txt` con deps de `SDD_FASE2_PASO25_UBISAFE.md §11.2`.
- `pyproject.toml` con `ruff` para lint y `pytest` para test.
- `.env.example` con todas las variables que se necesitan (sin valores reales).

**Firebase:**
- `firebase.json` con configuración de emuladores: Auth, Firestore, RTDB, Functions (puerto 9099, 8080, 9000, 5001).
- `firestore.rules` y `database.rules.json` con las reglas iniciales del SDD §7.2.4 y §7.3.5 (aún sin colecciones de iter.2).
- `firestore.indexes.json` vacío al inicio; se irá poblando.

### F0.4 — Configurar CI

`.github/workflows/ci.yml` con los pasos de §4.7. Probar abriendo un PR dummy con un cambio trivial.

### F0.5 — Crear los agentes y slash commands del proyecto

En `.claude/agents/`:
- `sdd-traceability-checker.md`
- `firestore-rules-reviewer.md`

(Los otros dos agentes son opcionales y se pueden añadir cuando se necesiten.)

En `.claude/commands/` (opcional):
- `/run-acceptance.md` — ejecuta la suite de acceptance del CU pasado como argumento.
- `/sdd-check.md` — invoca el agente sdd-traceability-checker.

### F0.6 — Crear `CLAUDE.md` raíz

Documentar:
- Estructura del repo (apuntando al SDD y al INDICE).
- Comandos comunes: `flutter run`, `uvicorn main:app --reload`, `firebase emulators:start`.
- Reglas Git de §4.5.
- Lista de plugins instalados.
- Apuntar a `plan_code.md` como guía de implementación.

### Definition of Done — F0

- [ ] Estructura de carpetas coincide 1:1 con SDD §11 + carpetas vacías iter.2.
- [ ] `flutter analyze` y `ruff check` pasan sin errores.
- [ ] `firebase emulators:start` arranca los 4 servicios sin errores.
- [ ] Flutter app levanta y muestra `main.dart` (placeholder).
- [ ] FastAPI levanta en `localhost:8000/docs` y muestra OpenAPI vacío.
- [ ] CI pasa en un PR dummy.
- [ ] `CLAUDE.md` raíz creado y revisado por ambos miembros.
- [ ] `docs/repo_audit_F0.md` cierra con todos los gaps resueltos.
- [ ] Agentes `sdd-traceability-checker` y `firestore-rules-reviewer` creados y probados manualmente con un input simple.

---

## F1 — Foundation (design system + core + navegación)

**Líder:** Miguel
**SDD a consultar:**
- `SDD_FASE0_UBISAFE.md` §7.1 (design system completo)
- `SDD_FASE0_PASOS05_06_UBISAFE.md` §2.5 (bounded contexts) y §10 ADR #4 (Riverpod)
- `SDD_FASE2_PASO25_UBISAFE.md` §5.3.6.5 (GpsRequiredEmptyState)
- `SDD_FASE5_UBISAFE.md` §10 (diagrama de navegación) y §8.1 (design system consolidado)

### F1.1 — Design system en Flutter

Implementar `lib/core/design_system/`:
- `colors.dart` — tokens de `SDD_FASE0_UBISAFE.md §7.1.1` (primarios, secundarios, semánticos, neutros, mapa).
- `typography.dart` — escala Inter de §7.1.2 (display 24, heading-1 20, body-1 16, button 16, caption 12).
- `spacing.dart` — `xs 4, sm 8, md 16, lg 24, xl 32, xxl 48`.
- `theme.dart` — `ThemeData` que aplica los tokens (Material 3 con seed `primary-700`).

**Tests:** smoke test que verifica que `theme.dart` produce un `ThemeData` con los colores correctos.

### F1.2 — Riverpod setup

- Añadir `flutter_riverpod: ^2.5.1` a `pubspec.yaml`.
- Envolver `runApp` en `ProviderScope`.
- Crear `lib/core/providers/` con un `app_lifecycle_provider.dart` placeholder para que el equipo se familiarice.
- Configurar VS Code / IDE con snippets básicos.

**Decisión Riverpod vs Provider:** Confirmar al inicio del sprint según ADR #4. Por defecto **Riverpod**; si en pair el equipo lo siente excesivo, fallback a Provider.
Nota escrita Alexis: se escogerá Riverpod

### F1.3 — Cliente HTTP con interceptor JWT

`lib/core/api/api_client.dart`:
- Singleton `dio` con baseURL desde `--dart-define`.
- Interceptor que inyecta `Authorization: Bearer <token>` leyendo de `FirebaseAuth.instance.currentUser?.getIdToken()`.
- Interceptor de retry con backoff exponencial para errores de red.
- Manejo central de 401 → invocar `AuthModule.logout()`.

**Tests:** unit test del interceptor con un mock de `FirebaseAuth`.

### F1.4 — Inicialización Firebase

`main.dart`:
- `WidgetsFlutterBinding.ensureInitialized()`.
- `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
- En modo debug, conectar a emuladores: `FirebaseAuth.instance.useAuthEmulator('localhost', 9099)`, etc.
- Inicializar `NotificationHandler` (placeholder en F1, se completa en F4).

### F1.5 — Navegación con go_router (esqueleto)

`lib/router/app_router.dart`:
- Definir todas las rutas según `SDD_FASE5_UBISAFE.md §10`:
  - `/splash`, `/welcome`, `/login`, `/signup-data`, `/signup-role`
  - `/home/buyer`, `/home/vendor`
  - `/tracking`, `/profile`, `/history`
- Cada ruta apunta a un widget placeholder (Scaffold con texto "Pantalla X").
- Configurar `redirect` que aplica la lógica de `SessionCheck` (sin sesión → welcome; con sesión → home según rol).

### F1.6 — `GpsRequiredEmptyState`

`lib/features/shared/widgets/gps_required_empty_state.dart`:
- ConsumerWidget que observa `gpsStatusProvider` (definido en F3, en F1 mockear con un StateProvider local).
- Renderiza ilustración + título + descripción + CTA según `GpsStatus.permissionDenied | serviceOff | ready`.
- Implementación exacta de `SDD_FASE2_PASO25_UBISAFE.md §5.3.6.5`.

**Tests:** widget test que verifica los 2 estados (permission denied / service off) y que el CTA llama al callback correcto.

### F1.7 — FastAPI app skeleton

`ubisafe_api/main.py`:
- Crear app FastAPI con `lifespan` que inicializa Firebase Admin SDK (`shared/firebase_admin_init.py`).
- Registrar (vacíos por ahora) los routers: `auth`, `dispatching/stop_request`, `safety/risk_zone`. Los routers tendrán solo un `GET /health` que devuelve `{"status": "ok"}`.
- Configurar CORS para `localhost` en dev.
- Logger estructurado con `logging` configurado por nivel desde env.

**Tests:** `pytest` con `httpx.AsyncClient` que valida `GET /health` por cada router devuelve 200.

### Definition of Done — F1

- [ ] App Flutter arranca y muestra Splash placeholder con tema UBISAFE aplicado (azul + verde correctos).
- [ ] Riverpod ProviderScope envuelve la app.
- [ ] `api_client` con interceptor JWT funcional (mock test pasa).
- [ ] `GpsRequiredEmptyState` renderiza correctamente sus 2 variantes (golden test opcional).
- [ ] go_router configurado con todas las rutas; redirect funcional.
- [ ] FastAPI levanta, expone `/health` por router, conecta a Firebase Admin (en dev contra emulador).
- [ ] Tests pasan en CI.

---

## F2 — Identity & Access (Auth + Drawer)

**Líder:** Alexis
**SDD a consultar:**
- `SDD_FASE2_PASO25_UBISAFE.md` §5.3.1 (AuthModule, DrawerModule, AuthMiddleware, AuthRouter)
- `SDD_FASE3_UBISAFE.md` §7.2.1 (esquema `users` + reglas Firestore §7.2.4)
- `SDD_FASE4_UBISAFE.md` §8.4 (diagramas de secuencia Auth — Registro y Login)
- `SDD_FASE5_UBISAFE.md` §10 (navegación Auth)

### F2.1 — Modelo `users` en FastAPI

`ubisafe_api/modules/identity/schemas.py`:
- `UserProfile`, `SyncProfileRequest`, `DeviceTokenRequest`.
- Campos según SDD §7.2.1 + el campo anticipatorio `last_location` y `last_location_at` (nullable).

`ubisafe_api/modules/shared/firestore_service.py` — métodos:
- `get_user(uid)`, `upsert_user(uid, data)`.

### F2.2 — `AuthMiddleware` y `AuthRouter`

`ubisafe_api/dependencies.py`:
- `get_current_user()` que verifica el JWT con `firebase_admin.auth.verify_id_token()`.
- Devuelve `AuthContext { uid, claims }`.
- Lanza 401 si token inválido, 403 si rol incorrecto (sobreparametrizable por endpoint).

`ubisafe_api/modules/identity/router.py`:
- `POST /auth/sync-profile` — upsert en `users/{uid}`. Body: `SyncProfileRequest`.
- `PATCH /auth/device-token` — actualiza `fcm_token`.

**Tests:**
- `AuthMiddleware`: token válido → 200 con uid; expirado → 401; rol incorrecto → 403.
- `POST /auth/sync-profile`: crea usuario nuevo → 200; actualiza existente → 200.

### F2.3 — `AuthModule` en Flutter

`lib/features/identity/auth/auth_module.dart`:
- Métodos: `login(email, password)`, `register(name, phone, role, email, password)`, `logout()`, `getCurrentToken()`, `Stream<User?> authStateChanges`.
- Implementación según SDD §5.3.1.1.

`lib/core/providers/auth_providers.dart`:
- `authStateProvider: StreamProvider<User?>`.
- `userProfileProvider: FutureProvider<UserProfile>`.

### F2.4 — Pantallas de Auth

Implementar según wireframes `SDD_FASE5_UBISAFE.md`:
- W-01 Splash (con `SessionCheck`)
- W-02 Welcome
- W-03 Login (formulario + manejo de error inline)
- W-04 SignUp Datos (nombre + teléfono)
- W-05 SignUp Rol (BUYER/VENDOR)

**UX copy:** validar con la skill `design:ux-copy` (errores, placeholders, CTAs).

### F2.5 — Drawer

`lib/features/identity/profile/widgets/drawer_module.dart`:
- Header con nombre + rol del usuario actual.
- Items: Mi Perfil, Historial de Actividad, Cerrar Sesión.
- En F2 los items "Mi Perfil" e "Historial" navegan a placeholders; se completan en F8.
- "Cerrar Sesión" llama a `AuthModule.logout()` y navega a Welcome.

### F2.6 — Reglas Firestore para `users`

Aplicar las reglas de SDD §7.2.4. Probar con el agente `firestore-rules-reviewer` y suite de emulator.

### F2.7 — Acceptance E2E del flujo Auth

Script en `tests/acceptance/auth.md` con pasos manuales:
1. Abrir app sin sesión → debe ir a Welcome.
2. Tocar "Crear cuenta" → SignUp Datos → SignUp Rol → registrarse → debe ir al Home según rol.
3. Cerrar app y reabrir → debe ir directo al Home (sesión persistente).
4. Drawer → Cerrar Sesión → debe ir a Welcome.
5. Login con credenciales correctas → Home.
6. Login con credenciales incorrectas → error inline, queda en Login.

### Definition of Done — F2

- [ ] Los 6 pasos del acceptance manual pasan.
- [ ] `users/{uid}` en Firestore tiene exactamente los campos del SDD §7.2.1.
- [ ] Reglas Firestore verificadas con emulator (escritura desde otro uid → denegada).
- [ ] Tests unitarios cubren `AuthModule`, `AuthMiddleware`, endpoints de `AuthRouter`.
- [ ] Token JWT se refresca automáticamente (validar dejando la app abierta > 1h en dev).
- [ ] PR aprobado por Miguel, mergeado a `main`.

---

## F3 — Presence (GPSService + VendorTracker)

**Líder:** Miguel
**SDD a consultar:**
- `SDD_FASE2_PASO25_UBISAFE.md` §5.3.2 (GPSService, VendorTracker)
- `SDD_FASE3_UBISAFE.md` §7.3 (esquema RTDB + reglas §7.3.5)
- `SDD_FASE4_UBISAFE.md` §8.2 (diagramas CU-02)
- `SDD_FASE1_UBISAFE.md` ADR #2 (justificación GPS directo a RTDB)

### F3.1 — `GPSService`

`lib/features/presence/services/gps_service.dart`:
- `startTransmission(vendorUid)` — inicia stream con `geolocator` (frecuencia 3s, 10m).
- `stopTransmission(vendorUid)` — detiene stream + remove RTDB node.
- Configurar `onDisconnect().remove()` antes de la primera escritura.
- Stream `stateStream` con `active | inactive | error_no_signal`.
- **`gpsStatusProvider: StreamProvider<GpsStatus>`** que combina permiso del SO + estado del servicio.

**Tests unitarios:**
- Mock de `geolocator` que emite posiciones; verificar que `set` se llama en RTDB con el shape correcto.
- Mock de `geolocator` que tira timeout; verificar que stateStream emite `error_no_signal`.

### F3.2 — `VendorTracker`

`lib/features/presence/services/vendor_tracker.dart`:
- Suscripción a `/vendedores_activos` en RTDB.
- Filtro Haversine 4km en cliente.
- Convierte cada nodo en `VendorMarker` (`models/vendor_marker.dart`).
- Stream `Stream<List<VendorMarker>>`.
- `vendorMarkersProvider: StreamProvider<List<VendorMarker>>`.

**Modelo `VendorMarker`** ya con el campo `ride_enabled: bool` aunque en iter.1 no se use (para no migrar después).

**Tests unitarios:**
- Test de filtrado Haversine: 3 vendedores a 1km, 5km, 3km → solo se devuelven los 2 dentro del radio.
- Test de eliminación: si un nodo desaparece del árbol, el stream emite la nueva lista sin él.

### F3.3 — Reglas RTDB

Aplicar `database.rules.json` exactamente como SDD §7.3.5. Validar con `firestore-rules-reviewer` (extender el agente o uno hermano para RTDB).

### F3.4 — Test del `onDisconnect`

Test manual con el emulador:
1. Vendedor activa GPS → su nodo aparece en RTDB.
2. Cerrar la app abruptamente (kill process).
3. Verificar que el nodo desaparece de RTDB en < 30s (el emulador tarda más que prod, eso es ok).

### F3.5 — Acceptance E2E parcial del CU-02

> El CU-02 completo (con UI de toggle, popup de confirmación y feedback "Ahora eres visible") se cierra en F4. Aquí solo validamos la capa de servicios.

`tests/acceptance/cu-02-services.md`:
1. **Activación:** invocar `GPSService.startTransmission(uid)` → en RTDB aparece `/vendedores_activos/{uid}` con los 4 campos correctos.
2. **Desactivación:** invocar `GPSService.stopTransmission(uid)` → el nodo desaparece.
3. **Suscripción:** un comprador con `VendorTracker` activo ve el `VendorMarker` aparecer/desaparecer en su stream cuando el vendedor entra/sale.
4. **Filtrado por radio:** un vendedor a 5km no aparece en el stream del comprador (radio 4km).
5. **Recuperación:** apagar el GPS del SO durante una sesión → `gpsStatusProvider` emite `serviceOff`; al re-encenderlo, vuelve a `ready` sin reiniciar la app.

### Definition of Done — F3

- [ ] GPSService publica posiciones a RTDB con la frecuencia y umbral correctos.
- [ ] `gpsStatusProvider` emite los 3 valores correctamente según permiso/servicio del SO.
- [ ] VendorTracker filtra por radio 4km en cliente.
- [ ] `onDisconnect().remove()` funciona (test manual).
- [ ] Reglas RTDB: un usuario A no puede escribir en `/vendedores_activos/{uid_de_B}` (test del emulador).
- [ ] Tests unitarios de ambos servicios pasan.
- [ ] Los 5 escenarios de acceptance parcial CU-02 pasan.

---

## F4 — Dispatching iter.1 (CU-01 + Mapas)

**Líder:** Miguel (backend + servicios) + Alexis (UI + flujo de pantallas)
**SDD a consultar:**
- `SDD_FASE2_PASO25_UBISAFE.md` §5.3.3 (MapScreenBuyer, MapScreenVendor, StopRequestModule, StopRequestRouter)
- `SDD_FASE3_UBISAFE.md` §7.2.2 (esquema `stop_requests`)
- `SDD_FASE4_UBISAFE.md` §8.1 (3 diagramas de secuencia CU-01: normal, rechazo, timeout)
- `SDD_FASE5_UBISAFE.md` §8.2 (wireframes W-06, W-07, W-09, W-10, W-11, W-12, W-15, W-16, W-17)

### F4.1 — Backend `StopRequestRouter` (Miguel)

`ubisafe_api/modules/dispatching/router.py`:
- `POST /stops` — valida rol BUYER, crea `stop_requests/{id}` con `status: pending`, `expires_at: now+60s`. Envía FCM `stop_request_incoming` al vendor.
- `GET /stops/{stop_id}` — devuelve estado actual; ACL: solo buyer o vendor del request.
- `PATCH /stops/{stop_id}/status` — máquina de estados:
  - VENDOR puede `pending → accepted | rejected`.
  - VENDOR puede `accepted → completed`.
  - SISTEMA/CLIENTE puede `pending → expired` (race condition handling: 409 si servidor ya expiró).
- Envía FCM correspondiente en cada transición.

`schemas.py`: `StopRequest`, `CreateStopRequestBody`, `UpdateStatusBody`.

`firestore_service.py` extender con: `create_stop_request`, `get_stop_request`, `update_stop_request_status`.

**Tests:**
- Cada endpoint con cada combinación rol válido / rol inválido / estado inválido.
- Race condition: buyer hace expired al mismo tiempo que vendor hace accepted.

### F4.2 — `NotificationService` y FCM (Miguel)

`modules/shared/notification_service.py`:
- `notify_stop_request_incoming(vendor_uid, stop_request_data)`.
- `notify_stop_request_accepted/rejected/completed(buyer_uid, ...)`.
- `notify_stop_request_expired(buyer_uid)`.
- Manejo de `UnregisteredError` (token FCM caducó) → eliminar token de Firestore.

### F4.3 — `NotificationHandler` Flutter (Alexis)

`lib/features/shared/notifications/notification_handler.dart`:
- Inicializa FCM, registra token, lo envía con `PATCH /auth/device-token`.
- Maneja `onMessage`, `onMessageOpenedApp`, `onBackgroundMessage`.
- Despacha cada tipo de evento a la pantalla correspondiente:
  - `stop_request_incoming` → `MapScreenVendor` muestra dialog.
  - `stop_request_accepted` → `MapScreenBuyer` navega a TrackingScreen.
  - `stop_request_rejected` → `MapScreenBuyer` snackbar.
- Listener `onTokenRefresh` que actualiza el token vía API.

### F4.4 — `StopRequestModule` Flutter (Alexis)

`lib/features/dispatching/services/stop_request_module.dart`:
- `createStopRequest(vendorId, buyerLocation)` → `POST /stops`.
- `cancelStopRequest(requestId)` → `PATCH /stops/{id}/status → expired`.
- Timer local de 60s que dispara `cancelStopRequest` automáticamente.
- `Stream<StopRequestStatus> requestStatusStream(requestId)`.
- `stopRequestProvider: StateNotifierProvider<StopRequest?>`.

### F4.5 — `MapScreenBuyer` (Alexis)

`lib/features/dispatching/screens/map_screen_buyer.dart`:
- Google Maps centered en posición del comprador.
- Marcadores de vendedores activos consumiendo `vendorMarkersProvider`.
- Polígonos/círculos de zonas de riesgo activo (consumir `activeRiskZonesProvider` — placeholder hasta F5).
- FAB "+" naranja → abre `RiskReportModule.openReportForm()` (placeholder hasta F5).
- Verifica `gpsStatusProvider`; si no es `ready`, renderiza `GpsRequiredEmptyState`.
- Al tocar marcador de vendedor → bottom sheet con info del vendedor + botón "Solicitar Parada".
- Confirmación → invoca `stopRequestModule.createStopRequest`.

**Estados UI:**
- `MapView` (idle).
- `Esperando` (después de confirmar solicitud, mientras `pending`).
- Reacciona a notificaciones FCM para transitar a Tracking, snackbar de rechazo, o snackbar de timeout.

### F4.6 — `TrackingScreen` (Alexis)

`lib/features/dispatching/screens/tracking_screen.dart`:
- Muestra posición del vendedor en tiempo real consumiendo `vendorMarkersProvider` filtrado por el `vendor_uid` activo.
- Distancia estimada (Haversine en cliente, OK para iter.1).
- Botón "Cancelar" que invoca `cancelStopRequest`.
- Al recibir FCM `stop_request_completed` → muestra confirmación de llegada.

### F4.7 — `MapScreenVendor` (Miguel/Alexis pair)

`lib/features/dispatching/screens/map_screen_vendor.dart`:
- Toggle de visibilidad: dispara `GPSService.startTransmission()` con confirmación.
- Feedback "Ahora eres Visible".
- Listener para FCM `stop_request_incoming` → muestra dialog (W-12) con detalle del comprador y botones Aceptar/Rechazar.
- Aceptar → `PATCH /stops/{id}/status → accepted` + verifica GPS activo (si no, renderiza `GpsRequiredEmptyState`) + obtiene ruta vía Directions API evitando zonas HIGH (placeholder hasta F5) + renderiza ruta en mapa.
- "Confirmar Entrega" en mapa de navegación → `PATCH → completed`.
- FAB "+" → `RiskReportModule` (placeholder hasta F5).

### F4.8 — Acceptance E2E del CU-01

`tests/acceptance/cu-01.md`:
1. **Normal:** buyer y vendor con sesiones distintas. Vendor activa GPS. Buyer ve marcador en mapa. Buyer toca y confirma. Vendor recibe push y dialog. Vendor acepta. Buyer va a Tracking y ve posición de vendor. Vendor confirma entrega. Buyer ve confirmación.
2. **Rechazo:** Igual hasta el dialog. Vendor rechaza. Buyer recibe snackbar y vuelve al mapa.
3. **Timeout:** Igual hasta el dialog. Vendor no responde. Cliente expira a los 60s. Buyer recibe snackbar.

### Definition of Done — F4

- [ ] Los 3 escenarios de acceptance pasan E2E con emuladores y 2 dispositivos.
- [ ] La máquina de estados de `stop_requests` es exacta a §7.2.2.
- [ ] Tests unitarios del router CU-01 cubren rol incorrecto, transición inválida, race condition.
- [ ] FCM funciona en foreground/background/terminated en Android.
- [ ] Reglas Firestore para `stop_requests` validadas (un buyer no ve solicitudes de otro).
- [ ] Wireframes W-06/W-09/W-10/W-11/W-12/W-15/W-16/W-17 implementados con tokens correctos.
- [ ] PR aprobado.

---

## F5 — Safety (CU-03)

**Líder:** Alexis
**SDD a consultar:**
- `SDD_FASE2_PASO25_UBISAFE.md` §5.3.4 (RiskReportModule, RiskZoneRouter)
- `SDD_FASE3_UBISAFE.md` §7.2.3 (esquema `risk_zones`)
- `SDD_FASE4_UBISAFE.md` §8.3 (3 diagramas CU-03)
- `SDD_FASE5_UBISAFE.md` wireframes W-13, W-14

### F5.1 — Backend `RiskZoneRouter`

`ubisafe_api/modules/safety/router.py`:
- `POST /risk-zones` — valida payload, calcula `expires_at = now + 24h`. Detecta duplicado (bbox + Haversine). Crea documento. Envía FCM fan-out a usuarios cercanos.
- `GET /risk-zones?lat=&lng=&radius_km=` — bbox + Haversine en Python.
- `DELETE /risk-zones/{zone_id}` — soft delete (set `active=false`, `expired_at=now`); solo el reporter puede.

### F5.2 — `notify_risk_zone_alert` (multicast)

Extender `NotificationService` con `notify_risk_zone_alert(user_uids, data)` usando `messaging.send_each()` o `send_multicast()`.

### F5.3 — `RiskReportModule` Flutter

`lib/features/safety/screens/risk_form_bottom_sheet.dart`:
- Bottom sheet con: tipo de amenaza (texto libre), nivel (chip selector HIGH/MEDIUM/LOW), coordenadas auto-detectadas.
- Verifica GPS antes de abrir (ver `SDD_FASE2_PASO25_UBISAFE.md §5.3.4.1` precondición GPS).
- `POST /risk-zones`, snackbar de éxito o error 409 (duplicado).

### F5.4 — Conectar polígonos al mapa

- En `MapScreenBuyer` y `MapScreenVendor`, consumir `activeRiskZonesProvider: FutureProvider<List<RiskZone>>` que llama a `GET /risk-zones`.
- Renderizar como círculos con colores semánticos:
  - HIGH → `#C62828` 35%.
  - MEDIUM → `#F57C00` 30%.
  - LOW → `#0277BD` 25%.
- Refrescar al recibir FCM `risk_zone_alert`.

### F5.5 — Cálculo de ruta segura (CU-01 retoque)

Volver al `MapScreenVendor` de F4.7: cuando vendedor acepta una solicitud, la llamada a Directions API debe pasar `avoid` con waypoints alrededor de zonas HIGH. Esta lógica vive en cliente Flutter; SDD §8.3 ya lo describe así.

### F5.6 — Acceptance E2E del CU-03

1. Reportar HIGH → debe verse en mapa de buyer y vendor con color rojo. Push recibido.
2. Reportar MEDIUM → naranja.
3. Reportar LOW → azul.
4. Reportar HIGH duplicado en mismas coords → 409, bottom sheet permanece.
5. Reportar HIGH y crear stop request con vendor del otro lado de la zona → ruta de vendor debe rodear la zona.

### Definition of Done — F5

- [ ] Los 5 escenarios pasan.
- [ ] Reglas Firestore para `risk_zones` validadas.
- [ ] Tests unitarios cubren detección de duplicado, expiración, multicast FCM.
- [ ] Wireframes W-13 y W-14 implementados.
- [ ] PR aprobado.

---

# PARTE B — ITERACIÓN 2

> **Antes de comenzar Parte B**, las fases F0–F5 deben estar **mergeadas a `main`** y la suite de acceptance de iter.1 (Auth + CU-01 + CU-02 + CU-03) debe pasar al 100%.

## F6 — Dispatching iter.2 (CU-04 — Solicitar Raite)

**Líder:** Miguel
**SDD a consultar:**
- `SDD2_FASE0_UBISAFE.md` (decisiones iter.2: timeout 60s, ride_enabled persistente, ruta evita HIGH+MEDIUM)
- `SDD2_FASE1_UBISAFE.md` (C4 L2 con Cloud Functions — para conocer la forma final, aunque CU-04 no usa Cloud Functions)
- `SDD2_FASE2_UBISAFE.md` §2'.3 (RideRequestModule, RideRouter), §2'.4 (extensiones a DrawerModule, MapScreenBuyer/Vendor, NotificationHandler)
- `SDD2_FASE3A_UBISAFE.md` (esquema `rides` + extensión `users.ride_enabled`)
- `SDD2_FASE4A_UBISAFE.md` (diagramas de secuencia CU-04: normal + 3 alt + 3 except)
- `SDD2_FASE5A_UBISAFE.md` §DestinationPicker, `SDD2_FASE5B_UBISAFE.md` W-CU04-01, `SDD2_FASE5Balt_UBISAFE.md` W-07/W-11/W-14b/W-19

### F6.1 — Migración del esquema `users` con `ride_enabled`

Solo backend: `firestore_service.update_ride_enabled(uid, value)`. Default `false` para vendors existentes (script de migración o lazy default).

### F6.2 — Backend `RideRouter`

`ubisafe_api/modules/dispatching/ride_router.py`:
- `POST /rides` — verifica:
  - Rol BUYER del JWT.
  - Vendor target con `ride_enabled == true`.
  - Vendor sin rides/stops activos (consulta).
  - Distancia pickup→destination ≤ 4km (Haversine).
  - Crea documento con `status: pending`, `expires_at: now+60s`. Envía FCM `ride_request_incoming`.
- `GET /rides/{id}` — ACL buyer/vendor.
- `PATCH /rides/{id}/status` — máquina de estados completa: `pending → accepted | rejected | expired`; `accepted → in_progress`; `in_progress → completed`. Envía FCMs en cada transición.

### F6.3 — Endpoint `PATCH /auth/ride-enabled`

`ubisafe_api/modules/identity/router.py` extendido. Body: `{"ride_enabled": bool}`. Solo VENDOR.

### F6.4 — `RideRequestModule` Flutter

`lib/features/dispatching/services/ride_request_module.dart`:
- `createRideRequest(vendorId, buyerLocation, destination)` → `POST /rides`.
- Validación cliente: distancia ≤ 4km antes de enviar.
- Timer 60s.
- Stream del estado del ride.

### F6.5 — `DestinationPicker` widget

`lib/features/dispatching/widgets/destination_picker.dart`:
- Mapa con pin draggable, autocomplete con Google Places, distancia en tiempo real.
- Estados: `idle`, `searching`, `selected_valid`, `selected_invalid` (>4km).

### F6.6 — Extender `MapScreenBuyer`

- Al tocar marcador de vendor con `ride_enabled: true`: bottom sheet ofrece "Solicitar Parada" + "Solicitar Raite".
- "Solicitar Raite" → flujo del `DestinationPicker` → `RideRequestModule.createRideRequest`.

### F6.7 — Extender `MapScreenVendor`

- Listener para FCM `ride_request_incoming` → dialog con info del raite (origen, destino, distancia).
- Aceptar → navegación a TrackingScreen reutilizada (con rol "rider"). Calcula ruta evitando HIGH+MEDIUM (mismo motor que CU-01).
- "Confirmar llegada al pickup" → `PATCH → in_progress`. Notifica al buyer.
- "Confirmar llegada al destino" → `PATCH → completed`.

### F6.8 — Extender `DrawerModule`

- Si rol VENDOR: `SwitchListTile` "Ofrecer raites" que invoca `PATCH /auth/ride-enabled`.
- Manejar fallo de red (revertir el toggle visual).

### F6.9 — Extender `NotificationHandler`

Añadir 3 eventos: `ride_request_incoming`, `ride_request_accepted`, `ride_request_rejected`.

### F6.10 — Acceptance E2E del CU-04

`tests/acceptance/cu-04.md`:
1. **Normal:** Vendor con `ride_enabled=true`. Buyer toca vendor → DestinationPicker → confirma destino válido → vendor acepta → tracking en dos fases (pickup + destino) → completed.
2. **Vendor ocupado:** Vendor ya con un stop_request activo → 409 conflict, snackbar al buyer.
3. **Destino > 4km:** error de validación cliente, no se envía request.
4. **Vendor rechaza:** snackbar al buyer.
5. **Timeout:** vendor no responde → expired a los 60s.
6. **Toggle ride_enabled:** vendor desactiva desde drawer → ya no aparece como ride-able en mapa de buyer (verificar `VendorMarker.ride_enabled` se actualiza vía RTDB).

### Definition of Done — F6

- [ ] Los 6 escenarios pasan.
- [ ] Máquina de estados `rides` exacta a §7.2.4.
- [ ] Reglas Firestore para `rides` validadas (read/update solo participantes).
- [ ] Tests cubren restricción 4km, ride_enabled, vendor ocupado.
- [ ] Wireframes W-CU04-01, W-07 ext, W-11b ext, W-14b, W-19 ext implementados.
- [ ] PR aprobado.

---

## F7 — Community iter.2 (CU-05 + CU-06 + Cloud Function)

**Líder:** Alexis (backend + Cloud Function) + Miguel (frontend)
**SDD a consultar:**
- `SDD2_FASE0_UBISAFE.md` §0'.3, §0'.4, §0'.5 (decisiones de Cloud Functions, coexistencia, votación simple)
- `SDD2_FASE1_UBISAFE.md` §4.2.5 (descripción Cloud Functions)
- `SDD2_FASE2_UBISAFE.md` §2'.2.3 (C4 L3 Cloud Functions), §2'.3 (CommunityReportModule, ReportValidationModule, CommunityReportRouter, ReportValidationRouter)
- `SDD2_FASE3B_UBISAFE.md` (esquema `community_reports`, ADRs #6/#7/#11, pseudocódigo Cloud Function)
- `SDD2_FASE4B_UBISAFE.md` (diagramas CU-05: 5 escenarios; CU-06: 6 escenarios)
- `SDD2_FASE5A_UBISAFE.md` (tokens negro/café), `SDD2_FASE5B_UBISAFE.md` W-CU05-01, W-CU06-01, W-CU06-02

### F7.1 — Backend `CommunityReportRouter`

`ubisafe_api/modules/community/report_router.py`:
- `POST /community-reports` — valida:
  - Distancia user-actual a `location` ≤ 4km.
  - `threat_type ∈ {animal_muerto, zona_sucia}`.
  - Crea con `status: pending_validation`, `radius_meters: 15`, `confirm_count: 0`, `dismiss_count: 0`, `is_duplicate: false`, `expires_at: +24h`.
  - Envía FCM `community_report_nearby` a usuarios con `last_location` ≤ 4km.
- `GET /community-reports?lat=&lng=&radius_km=` — bbox + Haversine, excluye `dismissed` y `expired`.

### F7.2 — Backend `ReportValidationRouter`

`ubisafe_api/modules/community/validation_router.py`:
- `PATCH /community-reports/{id}/validations` — body `{"vote": "confirm"|"dismiss"}`.
- Validaciones:
  - 403 si `validator_uid == reporter_uid`.
  - 409 si user ya votó.
  - 409 si reporte ya no está en `pending_validation`.
- Operación atómica:
  - Append a `validations[]`.
  - Incrementar `confirm_count` o `dismiss_count`.
  - Si `confirm_count >= 3` → `status = confirmed`.
  - Si `dismiss_count >= 3` → `status = dismissed`.
- Devuelve documento actualizado.

### F7.3 — Cloud Function `aggregateDuplicateReports`

`functions/main.py` + `functions/services/duplicate_detector.py`:
- Trigger: `onCreate` en `community_reports/{report_id}`.
- Lógica del pseudocódigo de `SDD2_FASE3B_UBISAFE.md §3.B'.4`.
- Detecta candidatos del mismo `threat_type` activos en radio 100m.
- Si encuentra → `update is_duplicate: true, canonical_report_id: <found.id>`.

`functions/requirements.txt`:
```
firebase-functions>=0.1.0
firebase-admin>=6.0.0
geopy>=2.4.0
```

`functions/tests/test_duplicate_detector.py`:
- Sin candidatos → no se modifica el doc.
- 1 candidato a 50m → marcado duplicado.
- 1 candidato a 200m → no marcado.
- Candidato del otro `threat_type` a 50m → no marcado.

### F7.4 — Frontend `CommunityReportModule`

`lib/features/community/services/community_report_module.dart`:
- `openReportForm()` — bottom sheet con selector de tipo, GPS auto-detectado.
- `POST /community-reports`. Retry exponencial ante red caída.
- `fetchReports(boundingBox)` — `GET /community-reports`.
- Stream de reports visibles en mapa.
- Renderiza marcadores: negro/café según tipo, con leyenda "Pendiente"/"Validado". Reportes con `is_duplicate: true` se agrupan visualmente bajo el canónico.

### F7.5 — Frontend `ReportValidationModule`

`lib/features/community/services/report_validation_module.dart`:
- `openValidationPanel(report)` — bottom sheet con info del reporte + 2 botones.
- Anti-voto-propio en cliente: si `report.reporter_uid == currentUser.uid`, oculta los botones.
- Anti-doble-voto en cliente: si user ya en `validations[]`, oculta los botones.
- `PATCH /community-reports/{id}/validations`. Retry ante red caída.
- Actualiza el stream de marcadores con la respuesta.

### F7.6 — UI: Lista de reportes activos + Detalle

- `lib/features/community/screens/active_reports_screen.dart` (W-CU06-01).
- `lib/features/community/screens/report_detail_screen.dart` (W-CU06-02) — invoca `ReportValidationModule`.

### F7.7 — Extender Drawer

Añadir entrada "Reportes activos" → navega a `ActiveReportsScreen`.

### F7.8 — Extender mapas (HomeC y HomeV)

- Cargar `community_reports` activos junto con `risk_zones` al iniciar.
- FAB "+" se transforma en `SpeedDial` con dos sub-acciones: "Reportar zona de riesgo" (CU-03) y "Reportar foco de infección" (CU-05).
- Al tocar marcador de community report → abrir panel de detalle (`ReportValidationModule`).

### F7.9 — Acceptance E2E

**CU-05:**
1. Reportar `animal_muerto` → marcador negro con leyenda "Pendiente". FCM a usuarios ≤4km.
2. Reportar `zona_sucia` → marcador café.
3. Reportar fuera de 4km → 400 Bad Request.
4. Reportar duplicado a 50m → Cloud Function lo marca; cliente lo agrupa visualmente.
5. Reportar y desconectar red → retry, persiste al reconectar.

**CU-06:**
1. Validar reporte ajeno → contador sube.
2. Tras 3 confirms → `confirmed`, leyenda "Validado".
3. Tras 3 dismisses → `dismissed`, marcador atenuado.
4. Intentar votar el propio reporte → 403 (cliente lo oculta).
5. Intentar votar 2 veces → 409.
6. Reporte ya no disponible (expirado) → 409 con mensaje claro.

### Definition of Done — F7

- [ ] Acceptance CU-05 y CU-06 pasan al 100%.
- [ ] Cloud Function desplegada (en emulator) y con tests verdes.
- [ ] Reglas Firestore para `community_reports` validadas.
- [ ] Wireframes W-CU05-01, W-CU06-01, W-CU06-02 implementados.
- [ ] FAB SpeedDial funciona en buyer y vendor.
- [ ] PR aprobado.

---

## F8 — Hardening, E2E, despliegue, polish

**Líder:** Pair Alexis + Miguel
**SDD a consultar:**
- `SDD2_FASE6_UBISAFE.md` (todos los ADRs — verificar que el código respeta cada decisión)
- `SDD2_FASE7_UBISAFE.md` (matrices de trazabilidad — usarlas como checklist)
- `SDD_FASE5_UBISAFE.md` y `SDD2_FASE5Balt_UBISAFE.md` (verificar wireframes con design-critique skill)

### F8.1 — Suite completa de acceptance

Correr **todo** lo de F2 a F7 en orden, en una sesión limpia con base de datos vacía. Documentar cualquier flake.

### F8.2 — Validación contra matrices de trazabilidad

Usar `SDD2_FASE7_UBISAFE.md`:
- Matriz 1 (CU → Componentes → Endpoints → Secuencias → UI): por cada CU, verificar que todo está implementado.
- Matriz 2 (RF → Componentes/Mecanismos): cada RF tiene código que lo cumple.
- Matriz 3 (RNF → ADRs): los RNF tienen mecanismo concreto. Específicamente:
  - **RNF-01 Performance:** medir CA-01.x, CA-04.1, CA-05.1, CA-06.1 con un script.
  - **RNF-02 Accesibilidad:** ejecutar `design:accessibility-review` skill sobre cada wireframe.
  - **RNF-05 Seguridad:** validar todas las reglas Firestore con el agente.

### F8.3 — Cleanup de código

- Eliminar `print()`, `console.log()`, `// TODO temp`.
- Verificar que todos los textos en UI vienen de un solo lugar (i18n placeholder o strings.dart).
- Verificar que no hay claves hardcoded ni URLs de dev en código de prod.
- Correr `flutter analyze` y `ruff check` con `--strict`.

### F8.4 — Pantallas pendientes

- W-19 Mi Perfil (datos editables: nombre, teléfono).
- W-20 Historial (lista de stop_requests + rides + reports propios, ordenados por fecha).
- W-18 Drawer pulido con avatar/iniciales.

### F8.5 — Despliegue

- **FastAPI:** desplegar a Cloud Run o similar (tier gratuito). Configurar variables de entorno desde Secret Manager.
- **Cloud Functions:** `firebase deploy --only functions`.
- **Reglas Firestore + RTDB:** `firebase deploy --only firestore:rules,database`.
- **App Flutter:** generar APK release firmado para entrega académica.

### F8.6 — Documentación final

- README.md con setup local + cómo correr tests + cómo desplegar.
- `docs/CONTRIBUTING.md` que apunta a `plan_code.md`, `INDICE_SDD_UBISAFE.md`, y la convención Git.
- Diagramas Mermaid del SDD exportados como PNG en `docs/diagrams/`.

### F8.7 — Smoke test final en dispositivo real

Probar el APK en al menos 2 dispositivos Android distintos (uno con API 29, uno con API 33+). Validar:
- Permisos de ubicación se piden y se manejan.
- Notificaciones push llegan en background.
- App no crashea al apagar/encender el GPS.

### Definition of Done — F8

- [ ] Suite completa de acceptance pasa.
- [ ] Matrices de trazabilidad confirman 0 gaps.
- [ ] CI verde en `main`.
- [ ] APK release firmado y probado en 2 dispositivos.
- [ ] README + CONTRIBUTING + plan_code.md alineados.
- [ ] FastAPI desplegada y `/health` responde 200.
- [ ] Cloud Function activa en proyecto Firebase real (test manual: crear un community_report → verificar que se marca duplicado si aplica).

---

## 7. Riesgos identificados y mitigaciones

| Riesgo | Mitigación |
|---|---|
| **Curva de Riverpod** golpea al equipo en F1 | Fallback a Provider documentado en ADR #4. Decisión final al inicio de F1 (no antes). |
| **FCM no llega en background** en algunos OEM Android (Xiaomi, Huawei) | Probar temprano en F4. Si falla, documentar como Deuda Técnica DT-X y notificar al usuario que active "Auto-start" en su OEM. |
| **Cloud Function cold start** afecta CA-05.3 | Cold start < 3s; CA-05.3 dice "10s registro" — hay margen. Si en producción real falla, evaluar `min_instances=1` (sale del tier gratuito). |
| **Race condition** entre cliente que expira un stop_request y vendor que lo acepta | Backend devuelve 409 si la transición ya ocurrió; cliente debe manejar 409 graceful. Test específico en F4. |
| **Reglas Firestore demasiado permisivas** | Agente `firestore-rules-reviewer` corre en cada PR que toca `firestore.rules`. |
| **Drift entre código y SDD** durante refactors | Agente `sdd-traceability-checker` antes de cada PR. Si hay conflicto, pausar y resolver con ADR. |
| **Costo Google Maps** (DT-03) | Aceptado para entrega académica. Documentado en ADR Retro-B y DT-03. |

---

## 8. Calendario tentativo

Asumiendo días de trabajo de ~6 horas efectivas por persona, dos personas en paralelo donde se pueda:

| Semana | Actividad principal | Quién |
|---|---|---|
| Semana 1 | F0 (setup pair) + F1 (Miguel) en paralelo a F0 | Ambos |
| Semana 2 | F2 (Alexis) + F3 (Miguel) en paralelo | Ambos |
| Semana 3 | F4 (pair, alta intensidad) | Ambos |
| Semana 4 | F5 (Alexis) + arranque F6 (Miguel) | Ambos |
| Semana 5 | F6 (Miguel) + F7 backend (Alexis) | Ambos |
| Semana 6 | F7 frontend (Miguel) + F7 cierre + arranque F8 | Ambos |
| Semana 7 | F8 (pair) | Ambos |

Total: ~7 semanas. Si hay que comprimir: F5 puede solapar con F4 (último 1-2 días), y W-19/W-20 de F8 pueden adelantarse a F2.

---

## 9. Cómo este plan dialoga con el SDD

> Esta sección existe para que cualquier persona que abra este archivo sin contexto entienda la relación entre `plan_code.md` y los archivos SDD.

- **El SDD describe el "qué" y el "por qué".** Los componentes, los flujos, las decisiones arquitectónicas, los esquemas de datos, los wireframes — todo eso vive en los archivos `SDD*.md`. La fuente de verdad de cada decisión es el SDD.
- **El plan_code describe el "cómo" y el "cuándo".** Toma el SDD como input inmutable y propone un orden de implementación, una división del trabajo, una estrategia de testing, y unas convenciones operacionales (Git, agentes, plugins).
- **Si el SDD cambia**, este plan se actualiza para reflejar el cambio (y se versiona). Si el plan choca con el SDD durante la implementación, **gana el SDD** — y se actualiza el plan, no el SDD.
- **El INDICE_SDD_UBISAFE.md es el atajo:** evita cargar todos los SDDs en una sesión de Claude Code. Cada fase de este plan apunta solo a los archivos que su ejecutor necesita leer.

---

## 10. Historial del documento

| Versión | Fecha | Autor | Cambios |
|---|---|---|---|
| V1.0 | 25/04/2026 | Alexis Córdova (con Claude) | Versión inicial. Cubre F0–F8, iter.1 + iter.2, plugins, agentes, Git, testing. |

---

*Plan generado el 25/04/2026 — Los Borbotones / UBISAFE.*
