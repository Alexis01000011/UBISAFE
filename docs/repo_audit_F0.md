# Repo Audit — F0 Setup
**Fecha:** 25/04/2026  
**Autor:** Alexis Córdova  
**Propósito:** Comparar estado del repo vs estructura objetivo (SDD_FASE2_PASO25_UBISAFE.md §11 + SDD2_FASE2_UBISAFE.md §11)

---

## Estructura de carpetas

### `ubisafe_app/lib/`
| Carpeta | Estado | Nota |
|---|---|---|
| `core/api/api_client.dart` | ✅ | Existe |
| `core/design_system/colors.dart` | ✅ | Existe |
| `core/design_system/typography.dart` | ✅ | Existe |
| `core/design_system/spacing.dart` | ✅ | Existe |
| `core/design_system/theme.dart` | ✅ | Existe |
| `features/identity/` | ✅ | Existe con auth + profile |
| `features/presence/` | ✅ | Existe con services + models |
| `features/dispatching/` | ✅ | Existe con screens + services + widgets + models |
| `features/safety/` | ✅ | Existe con screens + models |
| `features/community/` | ✅ | Existe (placeholder iter.2) |
| `features/shared/` | ✅ | Existe con notifications + widgets |
| `router/app_router.dart` | ✅ | Existe |
| `main.dart` | ✅ | Existe |

### `ubisafe_app/test/`
| Elemento | Estado | Nota |
|---|---|---|
| `smoke_test.dart` | ✅ | Creado en F0 |

### `ubisafe_api/`
| Elemento | Estado | Nota |
|---|---|---|
| `main.py` | ✅ | Existe |
| `dependencies.py` | ✅ | Existe |
| `routers/auth.py` | ✅ | Existe |
| `routers/stops.py` | ✅ | Existe |
| `routers/risk_zones.py` | ✅ | Existe |
| `services/firebase_admin_init.py` | ✅ | Existe |
| `services/firestore_service.py` | ✅ | Existe |
| `services/notification_service.py` | ✅ | Existe |
| `schemas/user.py` | ✅ | Existe |
| `schemas/stop_request.py` | ✅ | Existe |
| `schemas/risk_zone.py` | ✅ | Existe |
| `requirements.txt` | ✅ | Actualizado en F0 |
| `.env.example` | ✅ | Existe |
| `Dockerfile` | ✅ | Existe |
| `pyproject.toml` | ✅ | Creado en F0 |
| `modules/community/` | ✅ | Placeholder iter.2 |
| `tests/` | ⚠️ | Directorio sin tests aún — se poblará en F2+ |

### Raíz del repo
| Elemento | Estado | Nota |
|---|---|---|
| `firebase.json` | ✅ | Creado en F0 |
| `firestore.rules` | ✅ | Creado en F0 (iter.1) |
| `database.rules.json` | ✅ | Creado en F0 (iter.1) |
| `firestore.indexes.json` | ✅ | Creado en F0 (vacío) |
| `.firebaserc` | ✅ | Creado en F0 (demo-ubisafe) |
| `.github/workflows/ci.yml` | ✅ | Creado en F0 |
| `.github/pull_request_template.md` | ✅ | Creado en F0 |
| `.claude/agents/sdd-traceability-checker.md` | ✅ | Creado en F0 |
| `.claude/agents/firestore-rules-reviewer.md` | ✅ | Creado en F0 |
| `CLAUDE.md` | ✅ | Creado en F0 |
| `functions/README.md` | ✅ | Creado en F0 (placeholder) |
| `INDICE_SDD_UBISAFE.md` | ✅ | Existe |
| `README.md` | ✅ | Existe |
| `.gitignore` | ✅ | Existe |
| `plan_code.md` | ✅ | Existe |

## Dependencias Flutter (`pubspec.yaml`)
| Dep | Pre-F0 | Post-F0 | Nota |
|---|---|---|---|
| `flutter_riverpod` | ^2.4.9 | ^2.5.1 | Bump requerido por plan §F0.3 |
| `firebase_database` | ❌ | ^10.4.0 | Necesaria para RTDB (F3) |
| `mocktail` (dev) | ❌ | ^1.0.0 | Testing en F2–F5 |
| Resto de deps | ✅ | ✅ | Sin cambios |

## Dependencias FastAPI (`requirements.txt`)
| Dep | Pre-F0 | Post-F0 | Nota |
|---|---|---|---|
| `httpx` | ❌ | ^0.27.0 | Cliente HTTP + tests |
| `python-jose` | ❌ | ^3.3.0 | JWT utilities (SDD §11.2) |
| `pytest` | ❌ | ^8.0.0 | Testing |
| `pytest-asyncio` | ❌ | ^0.23.0 | Testing async endpoints |
| `ruff` | ❌ | ^0.4.0 | Lint |
| Resto de deps | ✅ | ✅ | Sin cambios |

---

## Gaps identificados al inicio de F0 (todos resueltos ✅)

Al iniciar F0 faltaban: `firebase.json`, `firestore.rules`, `database.rules.json`, `.firebaserc`, `firestore.indexes.json`, `.github/workflows/ci.yml`, `.github/pull_request_template.md`, `.claude/agents/`, `CLAUDE.md`, `functions/README.md`, `analysis_options.yaml`, `pyproject.toml`.

**Estado final:** todos los gaps resueltos. Ver tabla de archivos arriba.

---

*Actualizado al cerrar F0.*
