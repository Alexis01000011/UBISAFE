# SDD UBISAFE — Fase 0 · Pasos 0.5 y 0.6: Bounded Contexts + ADR #4
## Los Borbotones · Iteración 1
### Adición retroactiva [V2] — 17/04/2026

> **Nota de integración:** Este documento contiene dos adiciones retroactivas a la Fase 0.
> - **Paso 0.5** genera la nueva **Sección 2.5** del SDD (insertar entre §2 y §3).
> - **Paso 0.6** genera el **ADR #4**, que se agrega a la **Sección 10** del SDD junto con los ADRs #1, #2 y #3.

---

# PASO 0.5 — SECCIÓN 2.5: ORGANIZACIÓN POR DOMINIOS (BOUNDED CONTEXTS)

> **Nota de integración:** Esta es la Sección 2.5 del SDD. Insertar inmediatamente después de la Sección 2 (Stakeholders y Concerns) y antes de la Sección 3 (C4 Nivel 1 — Vista de Contexto).

---

## 2.5. Organización por Dominios (Bounded Contexts)

UBISAFE organiza su lógica de negocio en **cinco dominios** inspirados en el patrón de *Bounded Contexts* de Domain-Driven Design (DDD). Esta organización aplica tanto a la estructura de carpetas de la App Flutter como a la estructura de módulos de la API FastAPI, y permite que cada área de negocio evolucione de forma independiente entre iteraciones.

La elección de esta organización **reemplaza la división técnica por capas** (screens/, services/, models/ al mismo nivel) que habría generado acoplamiento cruzado entre funcionalidades de negocio distintas a medida que el sistema crece en las Iteraciones 2 y 3.

---

### 2.5.1. Tabla de dominios

| ID         | Dominio               | Responsabilidad                                                                                                                                          | Componentes Flutter (iter. 1)                      | Componentes FastAPI (iter. 1)                            |
| ---------- | --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- | -------------------------------------------------------- |
| **D-01**   | **Identity & Access** | Gestión de identidad del usuario: registro, login, sesión persistente y cierre de sesión. Control de acceso diferenciado por rol (Comprador / Vendedor). | AuthModule, DrawerModule                           | AuthMiddleware, AuthRouter                               |
| **D-02**   | **Presence**          | Localización y visibilidad de vendedores en tiempo real: publicación GPS del vendedor y suscripción reactiva desde el comprador.                         | GPSService, VendorTracker                          | *(ninguno — GPS fluye directo a RTDB, ver ADR #2)*       |
| **D-03**   | **Dispatching**       | Orquestación del encuentro entre Comprador y Vendedor: mapa interactivo, solicitud de parada, aceptación/rechazo y seguimiento en tiempo real.           | MapScreenBuyer, MapScreenVendor, StopRequestModule | StopRequestRouter                                        |
| **D-04**   | **Safety**            | Reporte, almacenamiento y difusión de zonas de riesgo activo en el mapa comunitario.                                                                     | RiskReportModule                                   | RiskZoneRouter                                           |
| **D-05**   | **Community**         | Funcionalidades de comunidad: reputación, reseñas, reportes colaborativos ampliados. *(Vacío en iter. 1; previsto para Iteraciones 2-3)*                 | —                                                  | —                                                        |
| **Shared** | **Transversal**       | Infraestructura compartida: notificaciones push, cliente HTTP, inicialización Firebase, acceso a Firestore.                                              | NotificationHandler                                | FirebaseAdminInit, FirestoreService, NotificationService |

---

### 2.5.2. Mapeo Caso de Uso → Dominio

| Caso de Uso                                 | Descripción                                                                                              | Dominio principal | Dominios participantes                                                             |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ----------------- | ---------------------------------------------------------------------------------- |
| **Auth — Registro**                         | El usuario crea una cuenta con nombre, teléfono, rol y credenciales.                                     | Identity & Access | —                                                                                  |
| **Auth — Login**                            | El usuario inicia sesión y accede a su Home según su rol.                                                | Identity & Access | —                                                                                  |
| **CU-01 — Solicitar parada**                | El Comprador selecciona un vendedor en el mapa y solicita que se detenga en su domicilio.                | Dispatching       | Presence (localización del vendedor), Identity (JWT), Shared (notificación FCM)    |
| **CU-02 — Activar radar de visibilidad**    | El Vendedor activa su transmisión GPS para aparecer en el mapa del Comprador.                            | Presence          | Identity (JWT para validar inicio), Dispatching (mapa del vendedor), Shared (RTDB) |
| **CU-03 — Bloquear zona por riesgo activo** | Cualquier usuario reporta una amenaza georreferenciada que restringe o advierte el tránsito en esa zona. | Safety            | Identity (JWT), Shared (notificación FCM a usuarios cercanos)                      |

---

### 2.5.3. Principios de diseño por dominio

El equipo seguirá estos principios al implementar cada dominio:

**Encapsulamiento:** cada dominio gestiona su propio estado y sus propios modelos de datos. Un componente del dominio Dispatching no accede directamente a los internos del dominio Presence; lo hace a través de las interfaces públicas definidas (ej. `VendorTracker.vendorStream`).

**Independencia de despliegue:** en la Iteración 1, todos los dominios viven en el mismo monolito Flutter y la misma instancia FastAPI. La organización por dominios no implica microservicios ahora, sino que facilita su extracción en el futuro si fuera necesario.

**Evolución aislada:** los dominios Community y Presence (lado servidor) están vacíos en iter. 1. Su ausencia no afecta al resto. Cuando se activen en iter. 2 o 3, el impacto sobre los demás dominios será mínimo.

**Referencia de implementación:** la estructura de carpetas correspondiente a esta organización se detalla en la **Sección 11** del presente documento.

---

---

# PASO 0.6 — ADR #4: STATE MANAGEMENT EN FLUTTER

> **Nota de integración:** Este es el ADR #4. Agregar a la **Sección 10** del SDD (Decisiones Arquitectónicas), después de los ADRs #1, #2 y #3.

---

## ADR #4 — Gestión de Estado en Flutter: Adopción de Riverpod

| Campo | Valor |
|---|---|
| **ID** | ADR-004 |
| **Título** | Gestión de Estado en Flutter: Adopción de Riverpod |
| **Estado** | ✅ Aceptado |
| **Fecha** | 17/04/2026 |
| **Autores** | Los Borbotones — UBISAFE Iteración 1 |
| **Revisión arquitectónica** | Sesión del 17/04/2026 |

---

### Contexto

La App Móvil Flutter de UBISAFE gestiona estado reactivo de naturaleza compleja y multi-pantalla:

- **Estado de autenticación:** si hay sesión activa, qué rol tiene el usuario, cuándo expira el JWT.
- **Estado del GPS del vendedor:** activo / inactivo / error (sin señal) — necesario tanto en MapScreenVendor como en GPSService y potencialmente en la AppBar.
- **Stream de vendedores activos:** lista de `VendorMarker` actualizada en tiempo real desde RTDB — consumida por MapScreenBuyer.
- **Estado del ciclo de vida de una solicitud de parada:** pending → accepted/rejected → completed — consumido por StopRequestModule, MapScreenBuyer y la pantalla de seguimiento.
- **Lista de zonas de riesgo activo:** consultada al iniciar las HomeScreens y actualizada al recibir alertas FCM.

Compartir este estado entre múltiples widgets usando solo `setState` nativo requeriría pasar callbacks y datos a través de árboles de widgets profundos (*prop drilling*), generando código frágil y difícil de mantener. Alguna forma de **gestión de estado global y reactiva** es necesaria.

El equipo de Los Borbotones **no tiene experiencia previa** con ningún patrón de gestión de estado en Flutter (ni Provider, ni Riverpod, ni Bloc). El contexto es académico, con tres desarrolladores y un alcance limitado a tres casos de uso. Se priorizó una solución con curva de aprendizaje baja, documentación abundante y cero costo.

---

### Opciones consideradas

| # | Opción | Curva de aprendizaje | Ventajas | Desventajas |
|---|---|---|---|---|
| **A** | `setState` + `InheritedWidget` | Muy baja (nativo Flutter) | Sin dependencias externas | Extremadamente verboso para estado global; no apto para streams multi-pantalla |
| **B** | **Provider** | Baja (~1 día) | Paquete oficial de Flutter, bien documentado, patrón simple de ChangeNotifier | Depende del `context` de Flutter; errores en tiempo de ejecución difíciles de depurar; no type-safe en acceso |
| **C** | **Riverpod** *(opción elegida)* | Baja-media (~2-3 días) | Sin dependencia de `context`; type-safe en tiempo de compilación; mejor soporte para streams (ej. RTDB); mismos conceptos que Provider pero más robusto | Requiere aprender un nuevo paradigma; sintaxis diferente a Provider |
| **D** | Bloc / Cubit | Alta (~1 semana) | Patrón bien establecido para apps grandes; testeable | Excesivamente verboso para el alcance del proyecto; sobreingeniería para 3 CUs |
| **E** | GetX | Baja | Sintaxis muy concisa | Controversia en la comunidad Flutter; antipatrones; dificulta testing; no recomendado por mantenedores de Flutter |

---

### Decisión

Se adopta **Riverpod** como solución de gestión de estado para la App Flutter de UBISAFE Iteración 1.

Si el equipo evalúa al inicio del sprint de desarrollo que la curva de aprendizaje de Riverpod representa un riesgo para el calendario de entrega, se permite usar **Provider** como fallback temporal, dado que comparte los mismos conceptos fundamentales (proveedores, consumidores, estado reactivo) y la migración a Riverpod en una iteración posterior sería de bajo impacto.

**La decisión final entre Riverpod y Provider se toma al inicio del primer sprint de implementación**, no antes.

---

### Justificación de Riverpod sobre Provider

**1. Sin dependencia del árbol de widgets (context-free):**
Provider requiere un `BuildContext` válido para acceder al estado, lo que puede causar errores en tiempo de ejecución si el contexto no está montado (ej. dentro de callbacks asíncronos de GPS o FCM). Riverpod elimina esta dependencia: los providers son accesibles desde cualquier lugar, incluyendo servicios de fondo como `GPSService` o `NotificationHandler`.

**2. Soporte nativo de streams:**
El estado más crítico de UBISAFE son streams reactivos: el `vendorStream` de VendorTracker (posiciones GPS en tiempo real desde RTDB) y `authStateChanges` de Firebase Auth. Riverpod tiene el tipo `StreamProvider` específico para este caso, que maneja automáticamente los estados `loading`, `data` y `error` del stream sin código boilerplate adicional.

**3. Seguridad en tiempo de compilación:**
Los accesos a providers en Riverpod son verificados en tiempo de compilación. Un error de tipo en el acceso al estado produce un error del compilador, no un crash en producción. Esto es especialmente valioso para un equipo sin experiencia previa que aprende el patrón sobre la marcha.

**4. Curva de aprendizaje aceptable:**
Con la documentación oficial de Riverpod y los ejemplos de la comunidad, el equipo puede adoptar los providers básicos (`StateProvider`, `StreamProvider`, `FutureProvider`) en 2-3 días. No se requiere conocimiento avanzado de Riverpod para cubrir los 3 CUs de iter. 1.

---

### Mapa de providers por dominio

| Dominio | Provider | Tipo Riverpod | Estado que gestiona |
|---|---|---|---|
| **Identity & Access** | `authStateProvider` | `StreamProvider<User?>` | Usuario autenticado actual (stream de Firebase Auth) |
| **Identity & Access** | `userProfileProvider` | `FutureProvider<UserProfile>` | Perfil del usuario en Firestore (nombre, rol, uid) |
| **Presence** | `gpsStateProvider` | `StateProvider<GPSServiceState>` | Estado del GPS del vendedor: `active / inactive / error` |
| **Presence** | `vendorMarkersProvider` | `StreamProvider<List<VendorMarker>>` | Lista de vendedores activos desde RTDB (tiempo real) |
| **Dispatching** | `stopRequestProvider` | `StateNotifierProvider<StopRequest?>` | Estado del ciclo de vida de la solicitud activa |
| **Safety** | `activeRiskZonesProvider` | `FutureProvider<List<RiskZone>>` | Zonas de riesgo activo consultadas al API |

---

### Consecuencias

**Positivas:**

- El estado reactivo de GPS, RTDB y Auth queda centralizado y es accesible desde cualquier parte de la app sin prop drilling.
- Los widgets se reconstruyen solo cuando cambia el estado relevante, mejorando el rendimiento.
- El código de lógica de negocio (GPSService, StopRequestModule) queda separado de los widgets de UI.
- Testing de providers aislado del árbol de widgets de Flutter.

**Negativas / Riesgos:**

- El equipo deberá invertir 2-3 días en aprender Riverpod antes del primer sprint. Si este tiempo no está disponible, se activa el fallback a Provider.
- Riesgo de sobre-provisioning: sin disciplina, el equipo podría crear providers globales para estado que debería ser local a un widget. Se recomienda: **usar `setState` para estado local de un solo widget** (ej. si el campo de texto tiene foco) y **Riverpod solo para estado compartido entre pantallas**.
- La versión de Riverpod a usar es **Riverpod 2.x** (con `riverpod_annotation` opcional). Se recomienda la versión sin generación de código para reducir la configuración inicial.

---

### Dependencia a agregar (pubspec.yaml)

```yaml
dependencies:
  flutter_riverpod: ^2.5.1    # Riverpod para Flutter (incluye StateProvider, StreamProvider, etc.)
  # Si se opta por el fallback:
  # provider: ^6.1.2
```

---

### Referencias

- Riverpod — documentación oficial: https://riverpod.dev
- Flutter State Management — docs.flutter.dev/data-and-backend/state-mgmt/options
- Comparativa Provider vs Riverpod — Remi Rousselet (autor de ambos paquetes)
- ADR #1 (este documento, Sección 10): justifica el monolito FastAPI — misma filosofía de simplicidad para iter. 1.

---

## Resumen de cobertura — Fase 0 (actualización V2)

| Paso | Output generado | Sección del SDD | Marcos cubiertos |
|---|---|---|---|
| 0.1 | Stakeholders y Concerns | §2 | F1: Design Stakeholders & Concerns |
| 0.2 | Stack técnico confirmado | Referencia interna + §4, §10 | F3: consistencia técnica |
| 0.3 | Design System (paleta, tipografía, tokens) | §7.1 | F1: Interface Viewpoint · F2: coherencia visual |
| 0.4 | Sección 1 completa (Introducción) | §1 | F1: Identificación del SDD |
| **0.5 [V2]** | **Organización por dominios (Bounded Contexts)** | **§2.5 (nueva)** | F1: Rationale Viewpoint · F3: consistencia arquitectónica |
| **0.6 [V2]** | **ADR #4 — State Management Flutter (Riverpod)** | **§10 (ADR #4)** | F1: Rationale Viewpoint · F2: decisiones justificadas |

**Fase 0 completada al 100% (incluyendo adiciones retroactivas V2).**

---

*Documento generado: 17/04/2026 — Los Borbotones / UBISAFE Iteración 1 — Pasos 0.5 y 0.6 [V2]*
