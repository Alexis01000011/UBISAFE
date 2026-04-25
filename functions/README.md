# functions/

Cloud Functions para UBISAFE — activadas en **Iteración 2** (F6/F7).

## Contenido planificado

- `main.py` — entry point de Firebase Functions (gen2 Python)
- `services/duplicate_detector.py` — lógica de detección de reportes duplicados
- `tests/test_duplicate_detector.py` — suite de tests
- `requirements.txt` — deps: firebase-functions, firebase-admin, geopy

## Cuándo se activa

Esta carpeta se implementa en **F7** (Community iter.2 — CU-05/CU-06).  
El trigger es `onCreate` en la colección `community_reports/{report_id}`.

## Setup local (cuando llegue F7)

```bash
cd functions
pip install -r requirements.txt
firebase emulators:start --only functions
```

Ver `SDD2_FASE3B_UBISAFE.md §3.B'.4` para el pseudocódigo del Cloud Function.
