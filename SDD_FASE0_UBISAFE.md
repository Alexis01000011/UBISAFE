# SDD UBISAFE — Fase 0: Preparación y Alineación
## Los Borbotones · Iteración 1
### Outputs listos para integrar al documento final

---

# PASO 0.4 — SECCIÓN 1: INTRODUCCIÓN

> **Nota de integración:** Esta es la Sección 1 del SDD. Pegar al inicio del documento después de la portada e índice.

---

## 1. Introducción

Esta sección establece el contexto general del Sistema de Diseño de Software (SDD) de **UBISAFE**, describiendo su propósito, alcance, audiencia prevista, referencias normativas y glosario de términos relevantes para la comprensión del diseño del sistema.

### 1.1. Propósito

El propósito de este documento es describir el diseño de software del sistema **UBISAFE** para su primera iteración de desarrollo, de acuerdo con el estándar **IEEE 1016-2009 (SDD)**. El documento especifica la arquitectura del sistema, las vistas de diseño relevantes (contexto, contenedores, componentes, datos, interfaces e interacciones), las decisiones arquitectónicas tomadas y su justificación.

Este SDD sirve como puente entre los requisitos definidos en el documento **BB_SRS_V1.6** y la implementación técnica del sistema. Toda decisión de diseño documentada aquí tiene trazabilidad directa hacia uno o más requisitos funcionales o no funcionales del SRS.

### 1.2. Alcance

Este documento cubre el diseño completo de la **Iteración 1** de UBISAFE, que comprende los siguientes tres casos de uso funcionales:

- **CU-01 — Solicitar parada a puerta:** Flujo por el que un comprador solicita al vendedor detenerse en su domicilio.
- **CU-02 — Activar radar de visibilidad:** Flujo por el que el vendedor transmite su ubicación GPS en tiempo real al mapa comunitario.
- **CU-03 — Bloquear zonas por riesgo activo:** Flujo por el que cualquier usuario reporta una amenaza georreferenciada que restringe o advierte el tránsito en esa zona.

Adicionalmente, se documenta el flujo de autenticación (registro y login), ya que es precondición de todos los casos de uso anteriores.

UBISAFE requiere acceso a la ubicación del dispositivo para sus funciones principales (mapa, transmisión GPS, solicitud de parada, reporte de zona). Las pantallas de gestión de cuenta (Perfil, Historial) son accesibles sin GPS mediante el Drawer.

**Fuera del alcance de este SDD:**

- Funcionalidades planificadas para iteraciones 2 y 3 (CU-04 al CU-09).
- Procesamiento de pagos, mensajería directa o gestión de inventario de productos.
- Reglas de seguridad de Firestore, índices y scripts de inicialización de datos (se documentan en artefactos técnicos separados).

### 1.3. Audiencia prevista

| Audiencia | Interés principal en este documento |
|---|---|
| **Equipo de desarrollo (Los Borbotones)** | Entender la arquitectura del sistema, la organización de componentes, el modelo de datos y los flujos de interacción para guiar la implementación |
| **Profesor evaluador** | Verificar el cumplimiento del estándar IEEE 1016-2009, el uso correcto del modelo C4 y UML, la consistencia del diseño y su alineación con los requisitos del SRS |
| **Líderes técnicos futuros / mantenedores** | Comprender las decisiones de diseño y sus justificaciones para extender el sistema en iteraciones posteriores |

### 1.4. Definiciones, acrónimos y abreviaturas

| Término | Definición |
|---|---|
| **SDD** | Software Design Document — Documento de Diseño de Software |
| **SRS** | Software Requirements Specification — documento BB_SRS_V1.6 de UBISAFE |
| **IEEE 1016-2009** | Estándar IEEE para la descripción de diseño de software |
| **C4** | Modelo de arquitectura de software de cuatro niveles: Contexto, Contenedores, Componentes y Código |
| **ADR** | Architecture Decision Record — registro formal de una decisión arquitectónica con su contexto, decisión y consecuencias |
| **Flutter** | Framework de desarrollo de aplicaciones móviles multiplataforma de Google |
| **FastAPI** | Framework de Python para construir APIs REST de alto rendimiento |
| **Firestore** | Base de datos NoSQL de documentos de Firebase, utilizada para datos estructurados persistentes |
| **RTDB** | Firebase Realtime Database — base de datos en tiempo real, utilizada para transmisión continua de posiciones GPS |
| **FCM** | Firebase Cloud Messaging — servicio de notificaciones push |
| **Firebase Auth** | Servicio de autenticación de Firebase |
| **GPS** | Global Positioning System — sistema de posicionamiento global |
| **Permiso de ubicación** | Concesión otorgada por el sistema operativo del dispositivo (Android/iOS) para que UBISAFE acceda a la ubicación del dispositivo. Es independiente del estado del GPS: el permiso puede estar concedido aunque el GPS esté apagado, y viceversa |
| **GPS activo** | Estado del servicio de localización a nivel del sistema operativo, independiente del permiso otorgado a UBISAFE. El GPS puede estar apagado aunque UBISAFE tenga permiso de ubicación. UBISAFE requiere ambas condiciones (permiso concedido **y** GPS activo) para sus funciones de mapa y transmisión de posición |
| **Modo limitado** | Estado navegacional de UBISAFE cuando el GPS no está disponible (permiso denegado o GPS apagado). En modo limitado, solo las pantallas del Drawer (Perfil, Historial, Cerrar Sesión) son accesibles; las pantallas de mapa muestran el componente `GpsRequiredEmptyState` hasta que la precondición se resuelva |
| **CU** | Caso de Uso |
| **RF** | Requisito Funcional |
| **RNF** | Requisito No Funcional |
| **Zona de riesgo activo** | Área geográfica con un reporte vigente de amenaza (jauría u otro) que restringe o advierte sobre el tránsito |
| **Polígono de exclusión** | Delimitación geográfica en el mapa que bloquea rutas a través de una zona de riesgo activo nivel Alto |
| **Radar de visibilidad** | Funcionalidad que muestra la ubicación en tiempo real de vendedores activos en el mapa comunitario |
| **Parada a puerta** | Servicio en el que el vendedor se detiene frente al domicilio del comprador a petición de este |
| **Design Viewpoint** | Perspectiva de diseño definida por IEEE 1016-2009; cada una documenta un aspecto particular del sistema |
| **Design Element** | Elemento de diseño dentro de un Viewpoint: puede ser un diagrama, tabla, texto descriptivo o código de referencia |

### 1.5. Referencias

| # | Documento | Versión |
|---|---|---|
| [R1] | BB_SRS_V1.6 — Especificación de Requisitos de Software de UBISAFE | v1.6, 11/04/2026 |
| [R2] | IEEE Std 1016-2009 — IEEE Standard for Information Technology — Systems Design — Software Design Descriptions | 2009 |
| [R3] | IEEE Std 830-1998 — IEEE Recommended Practice for Software Requirements Specifications | 1998 |
| [R4] | Modelo C4 — Simon Brown (c4model.com) | — |
| [R5] | Material Design 3 — Google (m3.material.io) | — |
| [R6] | Flutter Documentation — docs.flutter.dev | — |
| [R7] | FastAPI Documentation — fastapi.tiangolo.com | — |
| [R8] | Firebase Documentation — firebase.google.com/docs | — |

### 1.6. Visión general del documento

Este SDD está organizado siguiendo las **Design Views** definidas por IEEE 1016-2009, adaptadas al contexto académico del proyecto:

- **Sección 2** define los stakeholders del documento y sus preocupaciones de diseño.
- **Secciones 3–5** cubren la arquitectura del sistema mediante el modelo C4 (Context, Containers, Components).
- **Sección 6** documenta el diseño de la capa de datos (Firestore + RTDB).
- **Sección 7** presenta el diseño de interfaces de usuario y el sistema de diseño visual.
- **Sección 8** documenta los flujos dinámicos mediante diagramas de secuencia por caso de uso.
- **Sección 9** presenta el diagrama de navegación completo de la aplicación.
- **Sección 10** compila las decisiones arquitectónicas (ADRs) y sus justificaciones.
- **Sección 11** describe la estructura de paquetes y módulos del proyecto.
- **Sección 12** establece la trazabilidad entre requisitos del SRS y elementos de diseño.
- **Sección 13** registra el historial de versiones de este documento.

---

# PASO 0.1 — SECCIÓN 2: STAKEHOLDERS Y CONCERNS DE DISEÑO

> **Nota de integración:** Esta es la Sección 2 del SDD. Pegar inmediatamente después de la Sección 1.

---

## 2. Stakeholders y Concerns de Diseño

Esta sección identifica a los actores que encuentran en este SDD y especifica qué aspectos del diseño les resultan relevantes, siguiendo el marco de **Design Stakeholders & Concerns** de IEEE 1016-2009.

### 2.1. Stakeholders del SDD

| ID        | Stakeholder                               | Descripción                                                                                                                                                                                                 |
| --------- | ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **DS-01** | Equipo de desarrollo — Los Borbotones     | Miguel Esaú Rivera Román (líder técnico), Héctor Alexis Córdova Salas (líder de equipo), Leonardo Fernández Morales (líder de calidad). Equipo responsable de diseñar e implementar el sistema.             |
| **DS-02** | Profesor evaluador                        | Docente responsable de evaluar el documento según los criterios cualitativos del curso de TSP.                                                                                                              |
| **DS-03** | Comprador (Habitante rural)               | Usuario final que solicita paradas y consulta el mapa. Sus necesidades de usabilidad y accesibilidad deben reflejarse en las decisiones de diseño de interfaces. Representado indirectamente.               |
| **DS-04** | Vendedor (Comerciante)                    | Usuario final que activa su visibilidad GPS y recibe solicitudes de parada. Sus necesidades de confiabilidad y retroalimentación en tiempo real deben reflejarse en el diseño. Representado indirectamente. |
| **DS-05** | Futuros mantenedores / equipo iteración 2 | Desarrolladores que extenderán el sistema en iteraciones futuras. Necesitan comprender las decisiones y la estructura del código para no romper el diseño base.                                             |

### 2.2. Concerns de diseño por stakeholder

#### DS-01 — Equipo de desarrollo

| ID   | Concern                                                                                        | Secciones del SDD que lo abordan |
| ---- | ---------------------------------------------------------------------------------------------- | -------------------------------- |
| C-01 | ¿Cómo se estructura el sistema a alto nivel y qué responsabilidades tiene cada parte?          | Secciones 3, 4, 5 (C4 L1-L3)     |
| C-02 | ¿Cómo se organiza la base de datos y qué modelos de datos maneja el sistema?                   | Sección 6                        |
| C-03 | ¿Cómo se ven y comportan las pantallas? ¿Qué componentes de UI usar?                           | Secciones 7, 9                   |
| C-04 | ¿Cuáles son los flujos de interacción detallados entre frontend, backend y servicios externos? | Sección 8                        |
| C-05 | ¿Por qué se eligió este stack y no otro? ¿Cuáles son los trade-offs?                           | Sección 10 (ADRs)                |
| C-06 | ¿Cómo se organiza el código en carpetas y módulos?                                             | Sección 11                       |

#### DS-02 — Profesor evaluador

| ID | Concern | Secciones del SDD que lo abordan |
|---|---|---|
| C-07 | ¿El SDD cubre todas las vistas requeridas por IEEE 1016-2009? | Estructura completa del documento |
| C-08 | ¿Se utiliza el modelo C4 y/o diagramas UML para describir la arquitectura? | Secciones 3, 4, 5, 8 |
| C-09 | ¿El diseño de base de datos es consistente y está bien documentado? | Sección 6 |
| C-10 | ¿El diseño de interfaces es coherente con los requisitos de usabilidad del SRS? | Sección 7 |
| C-11 | ¿Los componentes y sus relaciones están claramente definidos y son consistentes entre vistas? | Secciones 4, 5, 8, 12 |
| C-12 | ¿Se identifican claramente los contenidos correspondientes a esta iteración? | Secciones 1.2, 12, 13 |

#### DS-03 — Comprador (Habitante rural)

| ID   | Concern                                                                                          | Secciones del SDD que lo abordan         |
| ---- | ------------------------------------------------------------------------------------------------ | ---------------------------------------- |
| C-13 | ¿La interfaz es accesible para adultos mayores (contraste, tamaño de elementos, lenguaje claro)? | Sección 7 (Design System, accesibilidad) |
| C-14 | ¿El flujo de solicitar una parada es simple (máx. 3 pasos desde el mapa)?                        | Secciones 8 (CU-01), 9 (navegación)      |
| C-15 | ¿El mapa muestra claramente los vendedores disponibles y las zonas de riesgo?                    | Secciones 7, 8                           |

#### DS-04 — Vendedor (Comerciante)

| ID   | Concern                                                                           | Secciones del SDD que lo abordan                |
| ---- | --------------------------------------------------------------------------------- | ----------------------------------------------- |
| C-16 | ¿El sistema se comporta de forma confiable ante pérdidas de GPS o conexión?       | Sección 8 (flujos alternativos/excepción CU-02) |
| C-17 | ¿El vendedor recibe retroalimentación visual inmediata al activar su visibilidad? | Secciones 7 (feedback visual), 8 (CU-02)        |
| C-18 | ¿La navegación propuesta evita automáticamente zonas de riesgo activo?            | Sección 8 (CU-01, CU-03)                        |

#### DS-05 — Futuros mantenedores

| ID | Concern | Secciones del SDD que lo abordan |
|---|---|---|
| C-19 | ¿El diseño es extensible para incorporar CU-04 a CU-09 sin refactorización mayor? | Secciones 5, 10 (ADRs) |
| C-20 | ¿Las decisiones arquitectónicas están justificadas y documentadas? | Sección 10 |

---

# PASO 0.2 — CONFIRMACIÓN DEL STACK TÉCNICO

> **Nota de integración:** Este contenido no es una sección independiente del SDD. Sirve como artefacto de referencia interna del equipo. Los detalles del stack se mencionan en las secciones 4 y 10 del SDD.

---

## Stack Técnico Confirmado — UBISAFE Iteración 1

| Capa                          | Tecnología                                                                  | Versión objetivo              | Justificación en el diseño                                                                      |
| ----------------------------- | --------------------------------------------------------------------------- | ----------------------------- | ----------------------------------------------------------------------------------------------- |
| **Frontend / App**            | Flutter (Dart)                                                              | Flutter 3.x / Dart 3.x        | Framework multiplataforma; objetivo inicial Android (API 29+) según RNF-04                      |
| **Backend / API**             | FastAPI (Python)                                                            | FastAPI 0.110+ / Python 3.11+ | API REST de alta performance; monolito para iter. 1 (ver ADR #1 en Sección 10)                  |
| **Autenticación**             | Firebase Authentication                                                     | SDK v5.x                      | Gestión de sesiones sin servidor propio; integración directa con Firebase                       |
| **Base de datos principal**   | Cloud Firestore                                                             | SDK v4.x                      | Datos estructurados: usuarios, vendedores, solicitudes de parada, zonas de riesgo (ver ADR #3)  |
| **Base de datos tiempo real** | Firebase Realtime Database (RTDB)                                           | SDK v10.x                     | Transmisión continua de posiciones GPS con latencia mínima (ver ADR #3)                         |
| **Notificaciones push**       | Firebase Cloud Messaging (FCM)                                              | SDK v9.x                      | Notificaciones de llegada, aceptación/rechazo de parada, alertas de riesgo                      |
| **Mapas y navegación**        | Google Maps SDK (Flutter) + Directions API                                  | Maps SDK 2.x                  | Visualización del mapa, marcadores de vendedores, polígonos de riesgo, trazado de rutas seguras |
| **Protocolo de comunicación** | HTTPS / REST (app ↔ FastAPI) + WebSocket/SSE candidato (GPS en tiempo real) | —                             | RTDB maneja sincronización en tiempo real; FastAPI expone endpoints REST para operaciones CRUD  |
| **Infraestructura**           | Firebase Hosting (API) + Firebase gratuito (BD, Auth, FCM)                  | —                             | Limitado al tier gratuito según restricciones del proyecto (SRS §2.4)                           |

**Notas de diseño:**

- El **GPS en tiempo real** (CU-02) fluye directamente desde la app Flutter hacia RTDB, sin pasar por FastAPI, para minimizar latencia. FastAPI solo interviene en operaciones que requieren lógica de negocio (ej. validar zonas de riesgo en CU-01, registrar reportes en CU-03).
- **Firebase Auth** emite tokens JWT que FastAPI verifica en cada request protegido, cumpliendo RNF-05 (Seguridad).
- La arquitectura de monolito FastAPI está justificada para iter. 1 dado el equipo de 3 personas y el alcance acotado (ver ADR #1).

---

# PASO 0.3 — SISTEMA DE DISEÑO VISUAL

> **Nota de integración:** Este contenido alimenta la Sección 7 del SDD (Diseño de Interfaces de Usuario). Se puede presentar como Sección 7.1 — Design System / Design Tokens.

---

## 7.1. Sistema de Diseño Visual — UBISAFE

El sistema de diseño de UBISAFE sigue una dirección visual de **seguridad y confianza**, utilizando una paleta de azules y verdes que transmite protección, calma y pertenencia comunitaria. El diseño prioriza la accesibilidad para adultos mayores conforme a RNF-02.

---

### 7.1.1. Paleta de Colores

#### Colores primarios

| Token | Nombre | Hex | Uso |
|---|---|---|---|
| `color-primary-900` | Azul profundo | `#0D47A1` | Texto sobre fondo claro, énfasis máximo |
| `color-primary-700` | Azul base | `#1565C0` | Color de marca principal, AppBar, botones primarios |
| `color-primary-500` | Azul medio | `#1E88E5` | Estados hover, íconos activos |
| `color-primary-100` | Azul claro | `#BBDEFB` | Bordes de selección, fondos de input activos |
| `color-primary-50` | Azul superficie | `#E3F2FD` | Fondos de tarjetas, chips, fondos secundarios |

#### Colores secundarios (estados seguros / positivos)

| Token | Nombre | Hex | Uso |
|---|---|---|---|
| `color-secondary-700` | Verde base | `#2E7D32` | Indicadores "vendedor activo", zonas seguras, confirmaciones |
| `color-secondary-500` | Verde medio | `#43A047` | Marcadores de vendedor en el mapa, badges de estado "disponible" |
| `color-secondary-100` | Verde claro | `#C8E6C9` | Fondos de notificaciones de éxito |
| `color-secondary-50` | Verde superficie | `#F1F8E9` | Fondo del Home del Vendedor |

#### Colores semánticos (estados y alertas)

| Token | Nombre | Hex | Uso |
|---|---|---|---|
| `color-danger-700` | Rojo riesgo | `#C62828` | Zonas de riesgo Alto (polígonos), errores críticos |
| `color-danger-500` | Rojo base | `#E53935` | Mensajes de error, botones destructivos |
| `color-warning-700` | Naranja riesgo | `#E65100` | Zonas de riesgo Medio, advertencias importantes |
| `color-warning-500` | Naranja base | `#F57C00` | Etiquetas de riesgo Medio, badges de precaución |
| `color-info-500` | Azul info | `#0277BD` | Zonas de riesgo Bajo/Informativo, mensajes informativos |
| `color-success-500` | Verde éxito | `#388E3C` | Confirmaciones de acción, notificaciones de llegada |

#### Colores neutros

| Token | Nombre | Hex | Uso |
|---|---|---|---|
| `color-neutral-900` | Texto principal | `#212121` | Texto de cuerpo, encabezados |
| `color-neutral-600` | Texto secundario | `#616161` | Subtítulos, labels, texto de soporte |
| `color-neutral-400` | Texto deshabilitado | `#9E9E9E` | Elementos inactivos, placeholders |
| `color-neutral-200` | Borde | `#E0E0E0` | Divisores, bordes de inputs inactivos |
| `color-neutral-100` | Fondo | `#F5F5F5` | Fondo general de la app |
| `color-neutral-0` | Superficie | `#FFFFFF` | Tarjetas, modales, bottom sheets |

#### Colores del mapa (polígonos y marcadores)

| Token | Elemento | Color / Opacidad | Descripción |
|---|---|---|---|
| `map-risk-high-fill` | Zona riesgo Alto | `#C62828` al 35% | Relleno del polígono de exclusión |
| `map-risk-high-stroke` | Borde zona riesgo Alto | `#C62828` 100% | Contorno del polígono |
| `map-risk-medium-fill` | Zona riesgo Medio | `#F57C00` al 30% | Relleno del polígono de precaución |
| `map-risk-low-fill` | Zona riesgo Bajo | `#0277BD` al 25% | Relleno del polígono informativo |
| `map-vendor-active` | Marcador vendedor activo | `#43A047` | Ícono circular verde con borde blanco 2dp |
| `map-vendor-inactive` | Marcador vendedor desconectado | `#9E9E9E` | Estado gris, sin interacción |
| `map-buyer-location` | Ubicación del comprador | `#1565C0` | Punto azul pulsante |

---

### 7.1.2. Tipografía

**Familia:** [Inter](https://fonts.google.com/specimen/Inter) (Google Fonts, licencia OFL) — seleccionada por su excelente legibilidad en pantallas pequeñas y en condiciones de baja visión.

| Token | Uso | Familia | Peso | Tamaño | Interlineado |
|---|---|---|---|---|---|
| `text-display` | Títulos de pantalla principales (splash, bienvenida) | Inter | Bold (700) | 24sp | 32sp |
| `text-heading-1` | Encabezados de sección | Inter | SemiBold (600) | 20sp | 28sp |
| `text-heading-2` | Subtítulos de tarjetas | Inter | SemiBold (600) | 18sp | 24sp |
| `text-body-1` | Texto principal de contenido | Inter | Regular (400) | 16sp | 24sp |
| `text-body-2` | Texto de soporte, descripciones | Inter | Regular (400) | 14sp | 20sp |
| `text-button` | Etiquetas de botones | Inter | SemiBold (600) | 16sp | 20sp |
| `text-label` | Labels de inputs, chips | Inter | Medium (500) | 14sp | 18sp |
| `text-caption` | Texto auxiliar, timestamps | Inter | Regular (400) | 12sp | 16sp |

**Regla de accesibilidad:** Ningún texto funcional podrá tener tamaño menor a 14sp (RNF-02). Los textos de acción crítica (botones primarios, mensajes de error) usarán mínimo 16sp.

---

### 7.1.3. Espaciado — Sistema de 8px Grid

| Token | Valor | Uso típico |
|---|---|---|
| `spacing-xs` | 4dp | Separación entre ícono y texto dentro de un chip |
| `spacing-sm` | 8dp | Padding interno de chips, separación entre elementos pequeños |
| `spacing-md` | 16dp | Padding horizontal de tarjetas, separación entre secciones |
| `spacing-lg` | 24dp | Padding horizontal de pantallas (margen lateral estándar) |
| `spacing-xl` | 32dp | Separación entre bloques de contenido grandes |
| `spacing-xxl` | 48dp | Margen superior de pantallas con imagen hero |

---

### 7.1.4. Componentes Base

#### Botones

| Variante | Alto | Radio | Padding H | Color fondo | Color texto | Uso |
|---|---|---|---|---|---|---|
| **Primario** | 52dp | 12dp | 24dp | `color-primary-700` | `#FFFFFF` | Acción principal (Solicitar parada, Activar visibilidad) |
| **Secundario** | 52dp | 12dp | 24dp | Transparente + borde `color-primary-700` | `color-primary-700` | Acción alternativa (Cancelar, Ver más) |
| **Peligro** | 52dp | 12dp | 24dp | `color-danger-500` | `#FFFFFF` | Acciones destructivas (Cerrar sesión, Cancelar solicitud) |
| **Ghost** | 44dp | 8dp | 16dp | Transparente | `color-primary-700` | Acciones de bajo énfasis (links textuales) |

#### Inputs / Campos de texto

| Propiedad | Valor |
|---|---|
| Alto | 56dp |
| Radio de esquinas | 12dp |
| Borde inactivo | `color-neutral-200`, 1dp |
| Borde activo/focus | `color-primary-700`, 2dp |
| Borde error | `color-danger-500`, 2dp |
| Label flotante | `text-label`, `color-neutral-600` |
| Padding interno | 16dp horizontal, 16dp vertical |

#### Tarjetas (Cards)

| Propiedad | Valor |
|---|---|
| Radio de esquinas | 16dp |
| Elevación | 2dp (sombra suave) |
| Padding interno | 16dp |
| Fondo | `color-neutral-0` |

#### FAB (Floating Action Button) — Botón "+" de reporte de riesgo (CU-03)

| Propiedad | Valor |
|---|---|
| Tamaño | 56dp × 56dp |
| Radio | 16dp |
| Color | `color-warning-700` (`#E65100`) |
| Ícono | `add` (Material Icons Outlined), blanco, 24dp |
| Posición | Bottom-right, margen 16dp |

#### Bottom Sheets

| Propiedad | Valor |
|---|---|
| Radio superior | 24dp |
| Handle visual | 4dp × 32dp, `color-neutral-200`, centrado, margin-top 12dp |
| Padding interno | 24dp horizontal, 20dp vertical |
| Fondo | `color-neutral-0` |

#### Modales / Dialogs

| Propiedad | Valor |
|---|---|
| Radio | 20dp |
| Margen horizontal | 24dp desde los bordes de pantalla |
| Padding interno | 24dp |
| Fondo | `color-neutral-0` |
| Overlay | Negro al 50% |

---

### 7.1.5. Iconografía

**Biblioteca:** [Material Design Icons](https://fonts.google.com/icons) — estilo **Outlined** (bordes definidos, mejor contraste en tamaños medianos).

| Contexto | Ícono Material sugerido | Tamaño |
|---|---|---|
| Menú lateral (drawer) | `menu` | 24dp |
| Perfil de usuario | `person_outline` | 24dp |
| Historial | `history` | 24dp |
| Cerrar sesión | `logout` | 24dp |
| Activar visibilidad | `visibility` / `visibility_off` | 24dp |
| Reportar riesgo (FAB) | `add` | 24dp |
| Ubicación actual | `my_location` | 24dp |
| Vendedor (marcador mapa) | `storefront` | 28dp (marcador) |
| Zona de riesgo | `warning_amber` | 20dp (badge sobre polígono) |
| Notificación de llegada | `notifications_active` | 24dp |
| GPS activo | `gps_fixed` | 20dp |
| GPS inactivo | `gps_not_fixed` | 20dp |
| Seguimiento en tiempo real | `directions_run` | 24dp |
| Confirmación / éxito | `check_circle_outline` | 24dp |
| Error / rechazo | `cancel` | 24dp |

**Regla:** No mezclar estilos de íconos (Filled + Outlined). Toda la app usa **Outlined** excepto en estados activos/seleccionados donde se usa la variante **Filled** del mismo ícono para indicar activación.

---

### 7.1.6. Resumen de Design Tokens (para referencia de implementación)

```dart
// Colores primarios
static const Color primary700 = Color(0xFF1565C0);
static const Color primary50  = Color(0xFFE3F2FD);

// Colores secundarios
static const Color secondary700 = Color(0xFF2E7D32);
static const Color secondary500 = Color(0xFF43A047);
static const Color secondary50  = Color(0xFFF1F8E9);

// Semánticos
static const Color danger500  = Color(0xFFE53935);
static const Color warning700 = Color(0xFFE65100);
static const Color warning500 = Color(0xFFF57C00);
static const Color info500    = Color(0xFF0277BD);
static const Color success500 = Color(0xFF388E3C);

// Neutros
static const Color textPrimary   = Color(0xFF212121);
static const Color textSecondary = Color(0xFF616161);
static const Color textDisabled  = Color(0xFF9E9E9E);
static const Color border        = Color(0xFFE0E0E0);
static const Color background    = Color(0xFFF5F5F5);
static const Color surface       = Color(0xFFFFFFFF);

// Espaciados
static const double spacingXS  = 4.0;
static const double spacingSM  = 8.0;
static const double spacingMD  = 16.0;
static const double spacingLG  = 24.0;
static const double spacingXL  = 32.0;
static const double spacingXXL = 48.0;

// Radios
static const double radiusSM  = 8.0;
static const double radiusMD  = 12.0;
static const double radiusLG  = 16.0;
static const double radiusXL  = 20.0;
static const double radiusXXL = 24.0;
```

---

## Resumen de cobertura — Fase 0

| Paso | Output generado                                                                  | Sección del SDD                       |
| ---- | -------------------------------------------------------------------------------- | ------------------------------------- |
| 0.1  | Stakeholders y Concerns documentados                                             | Sección 2                             |
| 0.2  | Stack técnico confirmado con notas de diseño                                     | Referencia interna + Secciones 4 y 10 |
| 0.3  | Design system: paleta, tipografía, espaciados, componentes, tokens Dart          | Sección 7.1                           |
| 0.4  | Sección 1 completa: propósito, alcance, audiencia, glosario, referencias, visión | Sección 1                             |

**Fase 0 completada. Lista para avanzar a Fase 1 (C4 L1-L2).**

---

*Documento generado: 11/04/2026 — Los Borbotones / UBISAFE Iteración 1*
