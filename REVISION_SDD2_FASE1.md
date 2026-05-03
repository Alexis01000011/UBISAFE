# Revisión de SDD2_FASE1_UBISAFE.md
**Revisado por:** Claude (Cowork)  
**Fecha:** 24/04/2026  
**Documentos de referencia:** BB_SDD_V1.0.md · BB_SDS_V1.5.md · BB_SRS_V2.1.md

---

## Resumen ejecutivo

Se identificaron **8 errores** distribuidos en tres categorías de gravedad: 2 errores críticos (impactan la implementación o la integridad estructural del documento), 4 errores moderados (inconsistencias con los documentos base o reglas de negocio incompletas) y 2 errores menores (tipográficos o de claridad). No se encontraron contradicciones directas con el SRS en los flujos principales de CU-04, CU-05 y CU-06.

---

## Errores críticos

### ERROR-01 — Numeración §4.2 en conflicto con BB_SDD_V1.0.md

**Sección afectada:** §4.2.5 a §4.2.8  
**Gravedad:** Crítica

**Descripción:**  
El documento inserta Cloud Functions como el nuevo §4.2.5. Esto desplaza los números de los contenedores existentes del BB_SDD_V1.0.md:

| Contenedor | Número en BB_SDD_V1.0 | Número asignado en SDD2 |
|---|---|---|
| Firebase Auth | §4.2.5 | §4.2.6 |
| FCM | §4.2.6 | §4.2.7 |
| Google Maps | §4.2.7 | §4.2.8 |

El documento no indica a Alexis cómo resolver este desplazamiento al integrar en el .docx. La nota de integración del encabezado dice "Alexis debe integrar este contenido al .docx sobre las secciones §3 y §4 existentes" pero no especifica la estrategia de renumeración. Además, la referencia en §4.2.6 a "Ver `SDD_FASE1_UBISAFE.md §4.2.5`" apunta al §4.2.5 del documento original (Firebase Auth), lo cual es correcto para el original, pero en el contexto de SDD2 §4.2.5 es Cloud Functions — generando una referencia ambigua para cualquier lector que lea los dos documentos en paralelo.

**Corrección propuesta:**  
Agregar una nota de integración explícita que indique: "Al insertar §4.2.5 Cloud Functions en el .docx, renumerar §4.2.5→§4.2.6 (Firebase Auth), §4.2.6→§4.2.7 (FCM) y §4.2.7→§4.2.8 (Google Maps) en el documento original. Actualizar todas las referencias internas a esas secciones en el .docx."

---

### ERROR-02 — `.firebaserc` mal ubicado en la estructura de archivos de Cloud Functions

**Sección afectada:** §4.2.5 — Estructura de archivos  
**Gravedad:** Crítica (error técnico de implementación)

**Descripción:**  
La estructura de archivos propuesta para Cloud Functions lista `.firebaserc` dentro de la carpeta `functions/`:

```
functions/
├── main.py
├── services/
│   └── duplicate_detector.py
├── requirements.txt
└── .firebaserc         ← ERROR: no pertenece aquí
```

`.firebaserc` es un archivo de configuración a nivel raíz del proyecto Firebase (define qué proyecto Firebase se usa). Debe vivir en la raíz del repositorio junto con `firebase.json`, no dentro de la carpeta `functions/`. Si se coloca dentro de `functions/`, Firebase CLI no lo reconoce para las operaciones de deploy (`firebase deploy --only functions`).

La estructura correcta sería:

```
/                           ← Raíz del repositorio
├── .firebaserc             ← Aquí
├── firebase.json
├── functions/
│   ├── main.py
│   ├── services/
│   │   └── duplicate_detector.py
│   └── requirements.txt
└── ...
```

**Corrección propuesta:**  
Mover `.firebaserc` fuera de `functions/` en el diagrama y añadir `firebase.json` a la raíz, que también es necesario para el deploy y no se menciona.

---

## Errores moderados

### ERROR-03 — Omisión de §4.2.4 (Firebase RTDB — sin cambios)

**Sección afectada:** §4.2 en general  
**Gravedad:** Moderada (inconsistencia estructural)

**Descripción:**  
El documento cubre los contenedores de la siguiente manera: §4.2.1 (App Flutter), §4.2.2 (FastAPI), §4.2.3 (Firestore), §4.2.5 (Cloud Functions — nuevo), §4.2.6 (Firebase Auth — sin cambios), §4.2.7 (FCM — extensión), §4.2.8 (Google Maps — sin cambios). Se salta completamente §4.2.4 (Firebase RTDB). Todos los contenedores que no cambian tienen su subsección declarando el estado explícitamente (§4.2.6 y §4.2.8), excepto RTDB.

Esto es un hueco estructural que puede interpretarse como un olvido al revisar la sección, o como que Firebase RTDB fue eliminado o remplazado (lo cual es incorrecto — RTDB sigue siendo el contenedor de posiciones GPS en tiempo real).

**Corrección propuesta:**  
Añadir la subsección faltante:

> **§4.2.4. Firebase Realtime Database (RTDB) — sin cambios**  
> Sin cambios respecto a iter. 1. Ver `SDD_FASE1_UBISAFE.md §4.2.4`.

---

### ERROR-04 — Regla de negocio CU-06 incompleta: falta validación de proximidad en la API

**Sección afectada:** §4.2.2 — API REST FastAPI, descripción de CU-06  
**Gravedad:** Moderada (regla de negocio del SRS no reflejada en diseño)

**Descripción:**  
El SRS (BB_SRS_V2.1.md, CU-06 Pre-condiciones) establece explícitamente:

> "El vendedor/comprador se encuentra dentro de un radio máximo de 4 km del reporte"

La descripción de la API en §4.2.2 solo documenta una regla crítica de negocio para CU-06:

> "FastAPI rechaza con `403 Forbidden` si `validator_uid === reporter_uid` (un usuario no puede validar su propio reporte)."

La validación de proximidad (el validador debe estar a ≤4 km del reporte) no está documentada en la lógica de `PATCH /community-reports/{id}/validations`. Esta validación requiere que la app envíe la ubicación actual del validador en el request, o que FastAPI la obtenga de otro lado — ninguna de las dos opciones está especificada.

**Corrección propuesta:**  
En §4.2.2, agregar a la descripción de CU-06:

> "FastAPI valida que las coordenadas del validador (enviadas en el body del PATCH) se encuentren en un radio ≤4 km del campo `location` del reporte. Si la condición no se cumple, retorna `403 Forbidden` con mensaje de proximidad insuficiente."

Y en el endpoint `PATCH /community-reports/{id}/validations`, especificar que el body incluye la ubicación actual del validador.

---

### ERROR-05 — CU-04: Verificación de disponibilidad del vendedor incompleta

**Sección afectada:** §4.2.2 — API REST FastAPI, descripción de CU-04  
**Gravedad:** Moderada (pre-condición del SRS no cubierta en diseño)

**Descripción:**  
El SRS (BB_SRS_V2.1.md, CU-04 Pre-condiciones) establece:

> "El vendedor tiene que estar disponible (no tener ninguna solicitud de parada)"

La descripción de la API en §4.2.2 dice que FastAPI "verifica que el vendedor tiene `ride_enabled: true` y **no tiene solicitudes activas**". Sin embargo, el término "solicitudes activas" en el contexto del documento SDD2 se refiere implícitamente a solicitudes de raite activas en la colección `rides`. No se documenta que la API también deba verificar que el vendedor no tenga una solicitud de parada activa en la colección `stop_requests`.

Esto significa que un vendedor podría recibir simultáneamente una solicitud de parada (CU-01) y una de raite (CU-04), lo cual viola la pre-condición del SRS.

**Corrección propuesta:**  
En §4.2.2, en la descripción de creación del raite, especificar:

> "FastAPI verifica que el vendedor tiene `ride_enabled: true`, no tiene ninguna solicitud de raite activa en la colección `rides` (status ≠ completed/cancelled), **y no tiene ninguna solicitud de parada activa en la colección `stop_requests`** (status ≠ completed/cancelled/rejected)."

---

## Errores menores

### ERROR-06 — Typo con soft-hyphen en el diagrama flowchart §4.1

**Sección afectada:** §4.1 — Diagrama alternativo (flowchart)  
**Gravedad:** Menor (tipográfico, pero puede impactar implementación)

**Descripción:**  
En el label del nodo Cloud Functions del diagrama flowchart aparece el nombre de la función como:

```
aggregateD­uplicateReports
```

Hay un carácter de guion suave (U+00AD, soft-hyphen) invisible entre la 'D' y la 'u': `aggregateD[­]uplicateReports`. Esto no es visible en la mayoría de los editores de texto, pero si alguien copia el nombre directamente del markdown para usarlo en código Python (en `main.py`), el nombre de la función contendrá un carácter no válido y el deploy fallará.

El diagrama C4 Mermaid en la misma sección y las descripciones en §4.2.5 usan correctamente `aggregateDuplicateReports` sin el carácter extraño.

**Corrección propuesta:**  
Reescribir el label del nodo en el flowchart eliminando el soft-hyphen:

```
cf["☁ Cloud Functions\n(Python gen2)\naggregateD­uplicateReports [iter.2]"]
```
→
```
cf["☁ Cloud Functions\n(Python gen2)\naggregateDuplicateReports [iter.2]"]
```

---

### ERROR-07 — FCM: Falta evento de notificación por confirmación/rechazo de reporte comunitario

**Sección afectada:** §4.2.7 — FCM, nuevos eventos iter. 2  
**Gravedad:** Menor (omisión de caso de uso implícito en el SRS)

**Descripción:**  
El SRS (CU-06 Flujos Alternativos) menciona que UBISAFE debe notificar la agrupación o resolución de reportes similares. La tabla de nuevos eventos FCM en §4.2.7 cubre el raite (3 eventos) y la creación de reportes (`community_report_nearby`), pero no incluye ningún evento para cuando un reporte cambia de estado a `confirmed` o `dismissed`.

Cuando `confirm_count ≥ 3` o `dismiss_count ≥ 3`, el estado del reporte cambia. Los usuarios que recibieron la alerta original de `community_report_nearby` deberían recibir una notificación de actualización — de lo contrario, seguirán viendo en su feed un reporte pendiente que ya fue resuelto.

Esto podría ser una decisión de diseño intencional (evitar notificaciones excesivas), pero no está documentada como tal.

**Corrección propuesta:**  
Agregar en §4.2.7 una nota explícita:

> **Decisión de diseño:** No se emite evento FCM al confirmar o desmentir un reporte (status → confirmed/dismissed). El cliente Flutter actualiza el estado del marcador en el mapa mediante el endpoint `GET /community-reports` (polling) o suscripción Firestore directa. Esta decisión evita notificaciones push redundantes a usuarios que pueden ya no estar en el área.

O bien, agregar el evento:

| Evento | Enviado por | Destinatario | CU |
|---|---|---|---|
| `community_report_resolved` | FastAPI | Usuarios que recibieron `community_report_nearby` | CU-06 |

---

## Aspectos correctos destacados

Para equilibrar la revisión, los siguientes aspectos están bien documentados y alineados con los documentos base:

**C4 Nivel 1 — Correcto:** La decisión de no añadir nuevos sistemas externos en iter. 2 está bien justificada. Cloud Functions vive dentro del boundary de Firebase Platform (L1), no como sistema externo nuevo. Esto es consistente con el BB_SDD_V1.0.md §3.4 donde Firebase Platform ya era el boundary unificado.

**Dominio Community — Correcto:** La activación del dominio Community (vacío en iter. 1 según BB_SDD_V1.0.md §2.3.1) con CU-05 y CU-06 es coherente con lo previsto en el SRS y el SDD original.

**Regla 403 para auto-validación — Correcto:** La regla `validator_uid !== reporter_uid` (ERROR-04 es un complemento, no una contradicción) está alineada con el espíritu del SRS CU-06 que busca validación comunitaria independiente.

**Conteo FCM — Correcto:** 3 eventos iter. 1 + 4 nuevos iter. 2 = 7 total. El conteo coincide con lo documentado en BB_SDD_V1.0.md §4.2.6 (3 eventos originales) y los 4 nuevos de §4.2.7 de este documento.

**Cloud Functions como complemento asíncrono — Correcto:** La decisión de separar la lógica de duplicados en Cloud Functions (asíncrono, no bloqueante) vs. FastAPI (síncrono) es consistente con el ADR #1 (monolito FastAPI) y el principio de no añadir latencia al flujo del usuario.

**Radio de detección de duplicados — Correcto:** El radio de 100 m para `aggregateDuplicateReports` y el radio de 15 m para el campo `location` del reporte son conceptos distintos (radio de búsqueda de duplicados vs. radio de la zona reportada) y no son contradictorios.

---

## Tabla resumen

| ID | Sección | Descripción breve | Gravedad | Acción requerida |
|---|---|---|---|---|
| ERROR-01 | §4.2.5–4.2.8 | Renumeración de contenedores no documentada; referencia §4.2.5 ambigua | Crítica | Añadir nota de integración con instrucciones de renumeración |
| ERROR-02 | §4.2.5 | `.firebaserc` listado dentro de `functions/` en vez de en la raíz | Crítica | Mover a raíz; añadir `firebase.json` |
| ERROR-03 | §4.2 | Firebase RTDB (§4.2.4) no aparece como "sin cambios" | Moderada | Añadir subsección §4.2.4 declarando sin cambios |
| ERROR-04 | §4.2.2 | CU-06: validación de proximidad del validador (4 km) no documentada | Moderada | Documentar la validación y cómo se obtiene la ubicación del validador |
| ERROR-05 | §4.2.2 | CU-04: no se verifica `stop_requests` activas del vendedor | Moderada | Añadir verificación de la colección `stop_requests` |
| ERROR-06 | §4.1 | Soft-hyphen invisible en nombre `aggregateDuplicateReports` en flowchart | Menor | Reescribir el label eliminando el carácter U+00AD |
| ERROR-07 | §4.2.7 | Sin evento FCM para cambio de estado confirmed/dismissed en reportes | Menor | Agregar evento o documentar la decisión de no emitirlo |

---

*Revisión generada el 24/04/2026 — Los Borbotones / UBISAFE Iteración 2*
