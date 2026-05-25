# Documentación Técnica — UBISAFE (CU-07, CU-08, CU-09)

Esta carpeta contiene la documentación técnica de UBISAFE **centrada en los casos de uso
7, 8 y 9** del SRS V3.1 (estándar IEEE 830). Está anclada al código real del repositorio
(rama de implementación más avanzada). Los casos CU-01 a CU-06 aparecen solo como contexto.

## Alcance

| CU | Nombre | Actor principal | Resumen |
|----|--------|-----------------|---------|
| **CU-07** | Gestionar lotes baldíos | Comprador / Vendedor | Reportar un lote baldío, que otros lo apoyen (umbral de 3 soportes) y marcarlo como resuelto. |
| **CU-08** | Suscribirse a cercanía de vendedor | Comprador | Suscribirse a un vendedor y recibir alerta cuando active su radar de visibilidad dentro de 4 km. |
| **CU-09** | Programar estancia grupal | Vendedor | Agendar una parada (punto + horario); notificar a compradores a 500 m, confirmar asistencia, validar zonas de riesgo. |

## Contenido

| Documento | Descripción | Diagramas (Mermaid) |
|-----------|-------------|---------------------|
| [01-contexto-c4.md](01-contexto-c4.md) | Arquitectura C4, niveles 1 a 3 | `C4Context`, `C4Container`, `C4Component` |
| [02-esquema-bd.md](02-esquema-bd.md) | Esquema de base de datos (Firestore + RTDB) | `erDiagram` + tablas de campos |
| [03-secuencia.md](03-secuencia.md) | Flujos de los tres casos de uso | `sequenceDiagram` (uno por CU) |
| [04-navegacion.md](04-navegacion.md) | Navegación de pantallas de la app | `flowchart` |

## Cómo leer los diagramas

- Todos los diagramas están escritos en **Mermaid** dentro de bloques ```` ```mermaid ````
  y se renderizan directamente en GitHub o en cualquier visor compatible con Mermaid.
- Términos de dominio en español; los identificadores de código (colecciones, endpoints,
  campos, rutas) se conservan en su forma original para que sean rastreables en el repo.

## Stack del sistema (resumen)

- **App móvil:** Flutter + Riverpod + GoRouter + Google Maps + Geolocator (`ubisafe_app/`).
- **API:** FastAPI (Python) desplegada en Render (`ubisafe_api/`), consumida vía Dio con
  token de Firebase como `Bearer`.
- **Firebase:** Auth, Cloud Firestore (BD principal), Realtime Database (presencia de
  vendedores), Cloud Messaging (FCM), Cloud Functions gen2 en Python (`functions/`).

## Glosario rápido

- **Apoyo / soporte:** voto de un usuario que respalda un reporte de lote baldío (CU-07).
- **Radar de visibilidad:** estado `is_active_radar` del vendedor; al activarse dispara las
  alertas de proximidad a los suscriptores (CU-08).
- **Estancia grupal:** parada programada por un vendedor en un punto y horario (CU-09).
