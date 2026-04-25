# CLAUDE.md — UBISAFE
**Proyecto:** Los Borbotones · TSP · ITESM  
**Equipo:** Alexis Córdova (PM/líder) · Miguel Esaú Rivera Román (tech lead) · Leonardo Fernández Morales (QA)

---

## Arquitectura del repo

Este repositorio es un **monorepo** con tres componentes desplegables independientes:

| Carpeta | Tecnología | Iteración |
|---|---|---|
| `ubisafe_app/` | Flutter 3.x / Dart 3.x | 1 + 2 |
| `ubisafe_api/` | Python 3.12 / FastAPI 0.111+ | 1 + 2 |
| `functions/` | Python / Firebase Functions gen2 | 2 (F7) |

**Fuentes de verdad:**
- `INDICE_SDD_UBISAFE.md` — índice de todos los SDDs (leer antes de buscar en los SDDs individuales)
- `plan_code.md` — guía de implementación: qué se hace, en qué orden, y quién lidera cada fase
- Los SDDs individuales son la fuente de verdad técnica — si hay conflicto entre código y SDD, **gana el SDD**

---

## Comandos comunes

```bash
# Flutter
cd ubisafe_app
flutter pub get
flutter run                          # requiere dispositivo/emulador Android conectado
flutter analyze
flutter test

# FastAPI
cd ubisafe_api
pip install -r requirements.txt
uvicorn main:app --reload            # http://localhost:8000/docs
ruff check .
pytest

# Firebase Emulators (desde la raíz del repo)
firebase emulators:start --project demo-ubisafe
# UI en http://localhost:4000
# Auth: 9099 | Firestore: 8080 | RTDB: 9000 | Functions: 5001
```

---

## Setup inicial (por desarrollador, una vez)

1. **Flutter:** Instalar Flutter 3.x stable. Verificar con `flutter doctor`.
2. **Firebase Tools:** `npm install -g firebase-tools` → `firebase login`
3. **`google-services.json`:** Descargar del proyecto Firebase en console.firebase.google.com y colocar en `ubisafe_app/android/app/google-services.json` (este archivo está en `.gitignore`, nunca se commitea).
4. **`.env`:** Copiar `ubisafe_api/.env.example` a `ubisafe_api/.env` y completar los valores reales.
5. **Demo project para emuladores:** El `.firebaserc` apunta a `demo-ubisafe`. Para desarrollo local con emuladores, no se necesita un proyecto real. Para deploy a producción, ejecutar `firebase use --add` y seleccionar el proyecto real.

---

## Reglas Git para Claude Code

### Claude Code PUEDE hacer sin preguntar:
- `git status`, `git diff`, `git log`, `git branch` — comandos de lectura
- `git checkout -b feat/<dominio>/<descripcion>` — crear rama nueva
- `git add <archivos específicos>` (nunca `git add .` sin revisión previa)
- `git commit -m "<mensaje conventional>"` con el mensaje propuesto
- `git push` a la rama propia (nunca a `main`)

### Claude Code SIEMPRE debe preguntar antes de:
- `git push --force` o `git push --force-with-lease`
- `git rebase`, `git reset --hard`, `git cherry-pick`
- `git merge` directo a `main`
- Eliminar ramas remotas
- Tocar archivos sensibles: `.env`, `firebase-service-account.json`, `google-services.json`

### Claude Code NUNCA debe:
- Commitear secretos (claves de API, tokens, credenciales)
- Pushear a `main` directamente
- Reescribir historia ya pusheada (sin permiso explícito)

### Naming de ramas:
`<tipo>/<dominio>/<descripcion-corta>`
- Tipos: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`
- Dominios: `identity`, `presence`, `dispatching`, `safety`, `community`, `shared`, `setup`, `infra`

### Commits — Conventional Commits:
`<tipo>(<scope>): <mensaje en imperativo>`  
Ejemplo: `feat(dispatching): implement POST /stops with FCM notification`

---

## Guía de implementación

Las fases se ejecutan en este orden: **F0 → F1 → F2 → F3 → F4 → F5** (iter.1) **→ F6 → F7 → F8** (iter.2).

Cada fase tiene:
- Un **SDD a leer** antes de empezar (ver `plan_code.md` cabecera de cada fase)
- Subtareas numeradas (F1.1, F1.2, etc.)
- Un **Definition of Done** explícito — no marcar como completa hasta que pasen los tests + CI verde

**Cómo empezar una fase nueva:**
1. Leer los SDDs listados en la cabecera de la fase en `plan_code.md`
2. Crear la rama: `git checkout -b feat/<dominio>/f<N>-<descripcion>`
3. Ejecutar las subtareas en orden
4. Verificar el DoD
5. Abrir PR con la plantilla de `.github/pull_request_template.md`

---

## Agentes disponibles

| Agente | Cuándo usarlo | Archivo |
|---|---|---|
| `sdd-traceability-checker` | Antes de abrir cualquier PR de feature | `.claude/agents/sdd-traceability-checker.md` |
| `firestore-rules-reviewer` | Cada vez que se modifica `firestore.rules` o `database.rules.json` | `.claude/agents/firestore-rules-reviewer.md` |

---

## Notas de seguridad

- Las reglas de Firestore (`firestore.rules`) y RTDB (`database.rules.json`) son la primera línea de defensa del cliente.
- El Admin SDK de FastAPI **bypass** las reglas de Firestore — la autorización de negocio la aplica FastAPI.
- Nunca hardcodear claves de API en código de producción. Usar variables de entorno y `.env.example` como referencia.
- El agente `firestore-rules-reviewer` debe correr en cada PR que toque archivos de reglas.
