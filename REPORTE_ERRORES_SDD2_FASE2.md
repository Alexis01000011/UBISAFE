# Reporte de Errores — SDD2_FASE2_UBISAFE.md
**Revisado por:** Claude (Cowork) · **Fecha:** 24/04/2026  
**Documentos base consultados:** BB_SRS_V2.1.md · BB_SDD_V1.0.md · BB_SDS_V1.5.md

---

## Resumen ejecutivo

Se identificaron **9 errores** en `SDD2_FASE2_UBISAFE.md`: 4 críticos, 3 moderados y 2 menores. El error más grave es el timeout incorrecto de CU-04 (el documento usa 60 s pero el SRS define 15 s en CA-04.3). El segundo más grave es la omisión total de la validación de proximidad para CU-06, que el SRS exige explícitamente como precondición. Adicionalmente, se referencian dos ADRs (#7 y #11) que no existen en ningún documento base.

---

## ❌ Errores CRÍTICOS

---

### Error C-1 · Timeout de CU-04 incorrecto — valor 60 s en lugar de 15 s

**Ubicación en SDD2:** PASO 2'.3 § RideRequestModule · PASO 2'.3 § RideRouter (tabla de endpoints)

**Texto con error:**
> *"RideRequestModule inicia un temporizador de **60 segundos** (CA-04.3): si el vendedor no responde antes, cancela la solicitud automáticamente con `PATCH /rides/{id}/status → expired`"*

> *(En la tabla de endpoints de RideRouter)* `POST /rides` → *"Timeout: **60 s** gestionado por el cliente."*

**Evidencia del SRS (BB_SRS_V2.1.md, línea 350):**
> *"CA-04.3: Dado que el vendedor no responde, cuando transcurran **15 segundos** desde la solicitud, entonces UBISAFE cancela automáticamente la petición y notifica al comprador."*

**Origen de la confusión:** El timeout de **60 segundos** corresponde a **CU-01 (solicitud de parada)**, definido en BB_SDD_V1.0.md (línea 968) y BB_SDS_V1.5.md (línea 199). El documento SDD2 copió ese valor sin advertir que CU-04 tiene su propio criterio de aceptación con un tiempo distinto.

**Corrección:** Cambiar `60 segundos` por `15 segundos` en todas las menciones de CU-04 (RideRequestModule, RideRouter POST /rides, y la nota de CA-04.3).

---

### Error C-2 · ADR #7 y ADR #11 no existen en los documentos base

**Ubicación en SDD2:** PASO 2'.3 § CommunityReportRouter — endpoint POST /community-reports

**Texto con error:**
> *"Crea documento en `community_reports` con `status: pending_validation`, `radius_m: 15` (fijo, **ADR #7/ADR #11**)"*

**Evidencia (BB_SDD_V1.0.md, líneas 211–215 — índice de ADRs):**  
El documento base únicamente define **ADR #1** (Monolito vs. microservicios), **ADR #2** (GPS vía FastAPI vs. directo a RTDB) y **ADR #3** (Firestore + RTDB). No existe ningún ADR #7 ni ADR #11.

**Impacto:** Una decisión de diseño clave —el radio fijo de 15 m para reportes comunitarios— queda sin justificación trazable. Cualquier revisor que consulte los documentos base no encontrará el sustento de esa decisión.

**Corrección:** O bien crear y documentar formalmente ADR #7 y ADR #11 en el repositorio de ADRs, o bien cambiar la referencia por la justificación inline del valor (ej. "radio fijo de 15 m según decisión de diseño de iter. 2 — pendiente formalizar como ADR").

---

### Error C-3 · Omisión de validación de proximidad en CU-06

**Ubicación en SDD2:** PASO 2'.3 § ReportValidationModule (Flutter) y § ReportValidationRouter (FastAPI)

**Texto con error (ReportValidationRouter):**  
Las reglas de negocio detalladas (anti-voto propio, anti-doble-voto, registro del voto, transición de estado) **no incluyen** verificación de la ubicación del usuario.

**Evidencia del SRS (BB_SRS_V2.1.md, línea 381):**
> *"Pre-condiciones [CU-06]: El vendedor/comprador se encuentra dentro de un radio máximo de **4 km del reporte**."*

**Impacto:** Un usuario podría validar un reporte de foco de infección estando en el otro extremo de la ciudad. La regla de negocio más básica de CU-06 está ausente tanto en el cliente como en la API.

**Corrección:**
- En `ReportValidationModule` (Flutter): añadir validación de proximidad (≤ 4 km del reporte) como tercer punto de las validaciones de negocio en cliente, antes de enviar el voto.
- En `ReportValidationRouter` (FastAPI): añadir como regla #1 en la lógica de negocio detallada: *"Proximidad: si la distancia entre `validator_location` y `report.location` es > 4 km → `403 Forbidden` con mensaje 'Debes estar a menos de 4 km del reporte para validarlo'"*.

---

### Error C-4 · Operador `===` inválido en Python y Dart

**Ubicación en SDD2:** PASO 2'.3 — aparece dos veces:

1. § ReportValidationRouter: *"si `validator_uid === report.reporter_uid` → 403 Forbidden"*
2. § ReportValidationModule (Flutter): *"si `report.reporter_uid === currentUser.uid`"*

**Problema:** El operador `===` (igualdad estricta sin coerción de tipo) es **exclusivo de JavaScript/TypeScript**. Ni Python ni Dart lo implementan:
- **Python** usa `==` para comparación de igualdad y `is` para identidad de objeto.
- **Dart** usa `==` para igualdad de valor.

En Python, escribir `a === b` es un **SyntaxError**. En Dart, también.

**Corrección:** Reemplazar todos los `===` por `==` en las descripciones de lógica de negocio de Python (FastAPI) y Dart (Flutter).

---

## ⚠️ Errores MODERADOS

---

### Error M-1 · Inconsistencia interna en el conteo de eventos FCM de iter. 1

**Ubicación en SDD2:** PASO 2'.4 § NotificationHandler vs. § NotificationService

**Contradicción interna:**
- `NotificationHandler` (Flutter): *"Maneja **7** tipos de evento: **3 iter.1** + 4 iter.2"*
- `NotificationService` (FastAPI): *"Total de métodos en NotificationService tras iter. 2: **8** (**4 iter.1** + 4 nuevos)"*

El mismo documento afirma simultáneamente que iter. 1 tiene **3** eventos FCM (en el Handler) y **4** eventos (en el Service).

**Evidencia (BB_SDD_V1.0.md, líneas 876–879):** La `NotificationService` de iter. 1 define exactamente **4 métodos FCM**:
1. `notify_stop_request_incoming`
2. `notify_stop_request_accepted`
3. `notify_stop_request_rejected`
4. `notify_risk_zone_alert`

El conteo de `NotificationHandler` ("3 iter.1") agrupa `stop_request_accepted` y `stop_request_rejected` como un solo tipo de evento, lo cual es una interpretación posible pero inconsistente con cómo el `NotificationService` los contabiliza.

**Corrección:** Unificar el criterio. Lo más correcto es alinear con la definición del `NotificationService` (fuente de verdad en BB_SDD): iter.1 tiene **4** métodos FCM. Por tanto, el total de `NotificationHandler` en iter. 2 es **8** (4+4), no 7.

---

### Error M-2 · Riverpod presentado como paquete nuevo en iter. 2

**Ubicación en SDD2:** PASO 2'.5 § 11.1 — tabla "Paquetes nuevos en iter. 2":

> *"| `riverpod` | ^2.x | State management (...) | [nuevo iter. 2]"*
> *"| `flutter_riverpod` | ^2.x | Integración Flutter con Riverpod | [nuevo iter. 2]"*

**Evidencia (BB_SDD_V1.0.md):**
- Línea 649: *"StreamProvider\<GpsStatus\> gpsStatusProvider — Provider Riverpod que emite el estado actual de disponibilidad del GPS para toda la app."*
- Línea 655: *"Dependencias: (...) **Riverpod** (para gpsStatusProvider)."*
- Línea 888–889: `GpsRequiredEmptyState` — *"Tipo: Widget Flutter (**ConsumerWidget Riverpod**)"*

Riverpod ya es una dependencia declarada de `GPSService` y `GpsRequiredEmptyState` en **iteración 1**. Agregarlo a la tabla de "paquetes nuevos de iter. 2" es incorrecto y puede generar conflictos de versión si se intenta añadir un paquete ya declarado.

**Corrección:** Eliminar `riverpod` y `flutter_riverpod` de la tabla de paquetes nuevos. Si el estado management de Riverpod *se amplía* en iter. 2 (nuevos providers), documentarlo como "ampliación del uso de Riverpod" en § PASO 2'.4.

---

### Error M-3 · Verificación incompleta de disponibilidad del vendedor en POST /rides

**Ubicación en SDD2:** PASO 2'.3 § RideRouter — "Reglas de negocio críticas"

**Texto actual:**
> *"Si el vendedor ya tiene una solicitud de parada activa (`stop_requests` con estado `pending` o `accepted`), `POST /rides` responde `409 Conflict` con mensaje 'Vendedor ocupado con otra solicitud activa'."*

**Evidencia del SRS (BB_SRS_V2.1.md, línea 348 — CU-04 Condición 3A):**
> *"UBISAFE detecta que el vendedor tiene una solicitud a parada activa, **ya está dando un raite** o la zona de la solicitud no es segura — UBISAFE notifica al comprador que el vendedor no tiene disponibilidad."*

El SRS exige verificar también si el vendedor ya tiene un **ride activo** (`rides` con estado `pending`, `accepted` o `in_progress`). El SDD2 solo verifica `stop_requests`.

**Corrección:** Añadir a las reglas de negocio del `RideRouter`: *"Si el vendedor ya tiene un ride activo (`rides` con estado `pending`, `accepted` o `in_progress`), `POST /rides` también responde `409 Conflict`."* El método `get_active_rides_for_vendor()` ya está definido en `FirestoreService` — solo falta usarlo en la precondición.

---

## 🔵 Errores MENORES

---

### Error N-1 · Tipo de foco `zona_sucia` no corresponde exactamente al vocabulario del SRS

**Ubicación en SDD2:** PASO 2'.3 § CommunityReportModule, § CommunityReportRouter

**SDD2 usa:** `threat_type: "animal_muerto" | "zona_sucia"`

**SRS (BB_SRS_V2.1.md, línea 363):**
> *"El comprador/vendedor selecciona el tipo de foco (**animal muerto, basura dispersa por perros**)"*

El SRS nombra el segundo tipo como "basura dispersa por perros", no "zona sucia". Si bien `zona_sucia` es una generalización razonable como identificador técnico, la etiqueta visible para el usuario en la UI debería reflejar el lenguaje del SRS ("Basura dispersada por perros" o similar) y el valor del enum debería estar alineado con el SRS o documentar explícitamente por qué se cambia.

**Corrección (menor):** Verificar con el equipo si `zona_sucia` como valor de `threat_type` es la decisión final. Si es así, añadir una nota de diseño explicando la generalización. Si no, cambiar a `basura_dispersa` o similar.

---

### Error N-2 · CA-04.4 (pérdida de conexión durante el raite) no tiene implementación documentada

**Ubicación en SDD2:** PASO 2'.3 § RideRequestModule

**SRS (BB_SRS_V2.1.md, línea 349 — CU-04 Excepción E1):**
> *"Pérdida de conexión por parte del comprador o vendedor: UBISAFE muestra la última ubicación conocida. Se notifica a ambos usuarios. El sistema intenta reconectar automáticamente."*

**SRS CA-04.4:**
> *"Dado que el acompañamiento está en curso, cuando ocurre una pérdida de conexión, entonces el sistema muestra la última ubicación conocida y notifica a los usuarios."*

El SDD2 describe el flujo de raite en detalle pero no menciona el comportamiento ante pérdida de conexión durante el viaje (CA-04.4). `StopRequestModule` en iter. 1 sí documenta su comportamiento ante desconexión.

**Corrección:** Añadir en la descripción de `RideRequestModule` un párrafo sobre el manejo de CA-04.4: mostrar última ubicación conocida, notificar a ambos actores y reintentar reconexión automática (comportamiento análogo al ya definido en CU-01).

---

## Tabla resumen de errores

| # | Tipo | Sección SDD2 | Descripción breve | Fuente |
|---|---|---|---|---|
| C-1 | ❌ Crítico | RideRequestModule · RideRouter | Timeout CU-04: 60 s en SDD2 vs **15 s** en SRS CA-04.3 | BB_SRS línea 350 |
| C-2 | ❌ Crítico | CommunityReportRouter POST | ADR #7 y ADR #11 referenciados pero **no existen** en docs base | BB_SDD índice ADRs |
| C-3 | ❌ Crítico | ReportValidationModule · ReportValidationRouter | **Omisión** de validación de proximidad ≤ 4 km para votar (CU-06 precondición) | BB_SRS línea 381 |
| C-4 | ❌ Crítico | ReportValidationRouter · ReportValidationModule | Operador `===` inválido en **Python** y **Dart** (es de JavaScript) | — |
| M-1 | ⚠️ Moderado | NotificationHandler · NotificationService | Iter. 1 tiene **4** eventos FCM, no 3. Total: 8, no 7. | BB_SDD líneas 876–879 |
| M-2 | ⚠️ Moderado | §11.1 paquetes Flutter | Riverpod **no es nuevo** en iter. 2 — ya estaba en iter. 1 | BB_SDD líneas 649, 655, 888 |
| M-3 | ⚠️ Moderado | RideRouter reglas de negocio | Falta verificar **rides activos** del vendedor (solo verifica stop_requests) | BB_SRS línea 348 |
| N-1 | 🔵 Menor | CommunityReportModule · CommunityReportRouter | `zona_sucia` vs. "basura dispersa por perros" del SRS | BB_SRS línea 363 |
| N-2 | 🔵 Menor | RideRequestModule | CA-04.4 (pérdida de conexión durante raite) sin implementación documentada | BB_SRS línea 349 |

---

*Reporte generado con base en lectura cruzada de BB_SRS_V2.1.md, BB_SDD_V1.0.md y BB_SDS_V1.5.md contra SDD2_FASE2_UBISAFE.md*
