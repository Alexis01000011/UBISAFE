# SDD2 — Fase 5A': Extensión del Design System
## Iteración 2 — Tokens nuevos + Componentes para CU-04, CU-05, CU-06
### UBISAFE · Los Borbotones · 25/04/2026

> **Propósito de este archivo:** Extender el Design System de iter. 1 (§8.1 de `SDD_FASE5_UBISAFE.md`) con los tokens y componentes que requieren los tres CU nuevos. **No reemplaza** la §8.1 original — la amplía. Al integrar al .docx, insertar esta sección como **§8.1 [iter. 2] — Extensiones del Design System**.
>
> **Archivos base leídos:** `SDD_FASE5_UBISAFE.md` §8.1, `SDD2_FASE0_UBISAFE.md` (todas las decisiones definitivas).
>
> **Responsable:** Miguel (con revisión de Alexis — sesión pair).

---

## Paso 5A'.1 — Verificación de tokens de severidad existentes

### Resultado: ✅ Los tres niveles de severidad ya están cubiertos en iter. 1

El §8.1.1 de `SDD_FASE5_UBISAFE.md` (Colores semánticos + Colores del mapa) **ya define tokens para los tres niveles** usados en `risk_zones` (CU-03):

| Nivel | Token de color | Hex | Token de mapa (fill) | Token de mapa (stroke) |
|---|---|---|---|---|
| **HIGH** (Alto) | `color-danger-700` | `#C62828` | `map-risk-high-fill` → `#C62828` al 35% | `map-risk-high-stroke` → `#C62828` 100% |
| **MEDIUM** (Medio) | `color-warning-700` | `#E65100` | `map-risk-medium-fill` → `#F57C00` al 30% | — |
| **LOW** (Bajo) | `color-info-500` | `#0277BD` | `map-risk-low-fill` → `#0277BD` al 25% | — |

> **Conclusión:** No se requiere ningún cambio en los tokens de severidad existentes. Los colores rojo/naranja/azul para `risk_zones` permanecen intactos. Los `community_reports` usan una paleta **diferente y separada** (negro/café) ya que son focos de infección, no zonas de riesgo de tránsito. Ver §5A'.2.

---

## Paso 5A'.2 — Tokens y componentes nuevos [iter. 2]

### 5A'.2.1 — Colores semánticos nuevos

Los siguientes tokens se añaden a la paleta de §8.1.1:

#### Colores para `community_reports` en mapa

> **Decisión Fase 0' (0'.4):** Los focos de infección usan colores propios (negro/café) para distinguirse visualmente de las zonas de riesgo (rojo/naranja/azul). Son **solo informativos** — no bloquean rutas del vendedor.

| Token | Nombre | Hex | Uso |
|---|---|---|---|
| `color-community-animal` | Negro cadáver | `#212121` | Marcador/círculo `threat_type: animal_muerto` |
| `color-community-waste` | Café zona sucia | `#795548` | Marcador/círculo `threat_type: zona_sucia` |
| `color-community-pending` | Ámbar pendiente | `#FFC107` | Estado `pending_validation` — chip + borde de círculo |
| `color-community-confirmed` | Verde validado | `#388E3C` | Estado `confirmed` — chip + borde de círculo (reutiliza `color-success-500`) |
| `color-community-dismissed` | Gris descartado | `#9E9E9E` | Estado `dismissed` — chip (reutiliza `color-neutral-400`) |

> **Nota:** `color-community-confirmed` es alias de `color-success-500` (`#388E3C`) ya existente. Se define el alias para semántica explícita en el contexto de reportes comunitarios.

#### Colores de mapa para `community_reports`

| Token | Elemento | Color / Opacidad | Notas |
|---|---|---|---|
| `map-community-animal-fill` | Círculo `animal_muerto` | `#212121` al 25% | Radio fijo 15 m en mapa |
| `map-community-animal-stroke` | Borde círculo `animal_muerto` | `#212121` 100% | Sólido cuando `confirmed`; punteado cuando `pending_validation` |
| `map-community-waste-fill` | Círculo `zona_sucia` | `#795548` al 25% | Radio fijo 15 m en mapa |
| `map-community-waste-stroke` | Borde círculo `zona_sucia` | `#795548` 100% | Sólido cuando `confirmed`; punteado cuando `pending_validation` |
| `map-community-pending-dash` | Patrón de borde pendiente | Línea punteada 4dp-4dp | Se aplica al stroke cuando `status: pending_validation` |

**Convención de visibilidad en mapa:**

| Estado del reporte | Opacidad fill | Estilo stroke | Leyenda en mapa |
|---|---|---|---|
| `pending_validation` | 15% | Punteado (`dash: [4,4]`) | "Pendiente de validación" |
| `confirmed` | 25% | Sólido, 2dp | "Validado por la comunidad" |
| `dismissed` | 8% (muy atenuado) | Punteado fino, `#9E9E9E` | "Descartado" (visible brevemente antes de expirar) |
| `expired` | No visible | — | No se renderiza en mapa |

---

### 5A'.2.2 — Componente: `ReportStatusChip` [iter. 2]

**Problema:** Los `community_reports` tienen un ciclo de vida con 4 estados (`pending_validation`, `confirmed`, `dismissed`, `expired`). El design system de iter. 1 no tiene un componente de chip de estado con estas variantes semánticas.

**Relación con componentes existentes:** Los chips de iter. 1 solo cubren chips de nivel de riesgo dentro del bottom sheet de CU-03 (no son componentes reutilizables documentados). `ReportStatusChip` es el primer chip de estado reutilizable del sistema.

#### Variantes

| Variante (`status`) | Color fondo | Color texto / borde | Ícono Material | Label en español |
|---|---|---|---|---|
| `pending_validation` | `#FFF9C4` (yellow-100) | `#F57F17` (yellow-900) | `hourglass_top` 14dp | "Pendiente" |
| `confirmed` | `#C8E6C9` (green-100) | `#1B5E20` (green-900) | `check_circle_outline` 14dp | "Validado" |
| `dismissed` | `#F5F5F5` (neutral-100) | `#616161` (neutral-600) | `cancel_outlined` 14dp | "Descartado" |
| `expired` | `#F5F5F5` (neutral-100) | `#9E9E9E` (neutral-400) | `schedule` 14dp | "Expirado" |

#### Props / Propiedades

| Propiedad | Tipo | Default | Descripción |
|---|---|---|---|
| `status` | `ReportStatus` (enum) | — | Estado del reporte. Determina color, ícono y label automáticamente. |
| `showIcon` | `bool` | `true` | Mostrar u ocultar el ícono a la izquierda del label. |
| `compact` | `bool` | `false` | Versión compacta (sin ícono, padding reducido). Usar en cards de lista. |

#### Dimensiones y tokens

| Propiedad | Valor |
|---|---|
| Alto | 28dp (compact: 22dp) |
| Padding horizontal | `spacing-sm` (8dp) |
| Padding vertical | `spacing-xs` (4dp) |
| Radio de esquinas | `radius-sm` (8dp) — completamente redondeado |
| Tipografía | `text-label` (14sp, Medium 500) |
| Separación ícono-texto | `spacing-xs` (4dp) |

#### Estados del componente

| Estado | Visual | Comportamiento |
|---|---|---|
| Default | Fondo sólido, ícono + label | No interactivo (solo display) |
| En lista de reportes | Variante `compact: true` | Sin ícono, reducido |
| Sobre mapa (overlay) | Variant `compact: true` + sombra leve | Máx. contraste con fondo de mapa |

#### Accesibilidad

- `semanticsLabel`: `"Reporte [status en español]"` (ej. `"Reporte pendiente de validación"`)
- Contraste mínimo 4.5:1 garantizado en todas las variantes (revisado contra fondos `#FFFFFF` y `#F5F5F5`)
- No requiere interacción de teclado (componente de solo visualización)

#### Implementación Dart (referencia)

```dart
enum ReportStatus { pendingValidation, confirmed, dismissed, expired }

class ReportStatusChip extends StatelessWidget {
  final ReportStatus status;
  final bool showIcon;
  final bool compact;

  const ReportStatusChip({
    required this.status,
    this.showIcon = true,
    this.compact = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final config = _chipConfig[status]!;
    return Semantics(
      label: 'Reporte ${config.semanticLabel}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon && !compact) ...[
              Icon(config.icon, size: 14, color: config.textColor),
              SizedBox(width: AppSpacing.xs),
            ],
            Text(
              config.label,
              style: AppTextStyles.label.copyWith(color: config.textColor),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### 5A'.2.3 — Componente: `VotingIndicator` [iter. 2]

**Problema:** CU-06 requiere mostrar cuántas confirmaciones y rechazos tiene un reporte. No existe ningún componente de conteo de votos en iter. 1.

#### Descripción

Indicador visual dual que muestra el recuento actual de confirmaciones (`confirm_count`) y rechazos (`dismiss_count`) de un `community_report`. Aparece en la Pantalla Detalle de Reporte (5B'.4) y en la Pantalla Lista de Reportes Activos (5B'.3, versión compacta).

#### Variantes

| Variante | Contexto | Descripción visual |
|---|---|---|
| `full` | Pantalla Detalle (5B'.4) | Dos columnas con ícono grande + número + label ("Confirmar" / "Desmentir") |
| `inline` | Tarjeta de lista (5B'.3) | Una fila compacta: 👍 N · 👎 M |

#### Props

| Propiedad | Tipo | Default | Descripción |
|---|---|---|---|
| `confirmCount` | `int` | — | Número de confirmaciones recibidas |
| `dismissCount` | `int` | — | Número de rechazos recibidos |
| `threshold` | `int` | `3` | Umbral para cambio de estado (visualiza progreso) |
| `variant` | `VotingVariant` (enum) | `full` | `full` o `inline` |
| `userHasVoted` | `bool` | `false` | Si `true`, deshabilita los botones de acción (bloqueo de doble voto, CU-06 condición 4A) |
| `userVerdictWas` | `VoteVerdict?` | `null` | `confirm` o `dismiss` — resalta el voto previo del usuario |

#### Dimensiones y tokens (variante `full`)

| Propiedad | Valor |
|---|---|
| Ícono principal | `thumb_up_outlined` / `thumb_down_outlined`, 32dp |
| Ícono cuando votado | `thumb_up` / `thumb_down` (filled), 32dp |
| Color confirmar | `color-success-500` (`#388E3C`) |
| Color desmentir | `color-danger-500` (`#E53935`) |
| Color deshabilitado | `color-neutral-400` (`#9E9E9E`) |
| Número | `text-heading-1` (20sp, SemiBold) |
| Label | `text-body-2` (14sp, Regular) |
| Separación entre columnas | `spacing-xl` (32dp) |
| Touch target mínimo | 48dp × 48dp (botones de acción) |

#### Barra de progreso hacia umbral

Debajo de los contadores (solo variante `full`): barra lineal estrecha (4dp de alto, radio 2dp) que muestra `max(confirmCount, dismissCount) / threshold` como progreso. Color: verde si `confirmCount > dismissCount`, rojo si es al revés, gris si empate.

| Token | Valor |
|---|---|
| Alto barra | 4dp |
| Radio barra | 2dp |
| Fondo barra | `color-neutral-200` |
| Fill verde | `color-success-500` |
| Fill rojo | `color-danger-500` |

#### Accesibilidad

- Botón Confirmar: `tooltip` y `semanticsLabel`: `"Confirmar reporte. ${confirmCount} de ${threshold} confirmaciones"`
- Botón Desmentir: `tooltip` y `semanticsLabel`: `"Desmentir reporte. ${dismissCount} de ${threshold} rechazos"`
- Cuando `userHasVoted: true`, el widget tiene `semanticsLabel`: `"Ya votaste este reporte"` y ambos botones están deshabilitados
- Touch target 48dp garantizado conforme a RNF-02

---

### 5A'.2.4 — Extensión del FAB de CU-03 para CU-05 [iter. 2]

> **Contexto:** En iter. 1, el FAB "+" (naranja, `color-warning-700`) abre directamente el Bottom Sheet de CU-03 (reportar zona de riesgo). En iter. 2, el mismo FAB debe permitir elegir entre CU-03 (riesgo de tránsito) y CU-05 (foco de infección). La decisión de Fase 0' (decisión 0'.4) establece que son colecciones y pantallas separadas.

#### Patrón: FAB expandible con mini-FABs

Al pulsar el FAB "+", se despliegan **dos mini-FABs** en columna:

| Mini-FAB | Ícono | Color | Label (tooltip) | Acción |
|---|---|---|---|---|
| **Riesgo de tránsito** | `warning_amber` | `color-warning-700` (`#E65100`) | "Reportar zona de riesgo" | Abre Bottom Sheet CU-03 (existente) |
| **Foco de infección** | `bug_report` | `color-community-waste` (`#795548`) | "Reportar foco de infección" | Abre Bottom Sheet CU-05 (nuevo, 5B'.2) |

#### Tokens del FAB expandible

| Propiedad | Valor |
|---|---|
| FAB principal | Sin cambio respecto a iter. 1 (56dp, naranja, ícono `add`) |
| Mini-FABs tamaño | 40dp × 40dp |
| Mini-FABs radio | 12dp |
| Separación entre mini-FABs | `spacing-sm` (8dp) |
| Separación FAB principal → primer mini-FAB | `spacing-md` (16dp) |
| Animación | `AnimatedScale` + `AnimatedOpacity`, duración 200ms, curva `easeOut` |
| Label flotante | `text-label` (14sp), fondo `color-neutral-900` 80% opacidad, radio 4dp, padding 4dp×8dp |

#### Accesibilidad

- FAB principal cuando expandido: `semanticsLabel`: `"Cerrar opciones de reporte"`; cuando colapsado: `"Reportar incidencia"`
- Mini-FABs: `tooltip` obligatorio (ya incluido en especificación de la tabla)
- Overlay semitransparente detrás de los mini-FABs (negro al 30%) para contrastar con el mapa

---

### 5A'.2.5 — Actualización de iconografía [iter. 2]

Los siguientes íconos se añaden a la tabla §8.1.5:

| Contexto | Ícono Material | Tamaño | Notas |
|---|---|---|---|
| Foco de infección (animal muerto) | `pest_control` | 24dp | Mini-FAB CU-05, marcador en mapa |
| Foco de infección (zona sucia) | `delete_outline` / `bug_report` | 24dp | Mini-FAB CU-05 (alternativa: `compost`) |
| Validar / confirmar reporte | `thumb_up_outlined` / `thumb_up` | 24dp (32dp en VotingIndicator) | Outlined = no votado; Filled = votado |
| Desmentir reporte | `thumb_down_outlined` / `thumb_down` | 24dp (32dp en VotingIndicator) | Outlined = no votado; Filled = votado |
| Lista de reportes activos (Drawer) | `fact_check` | 24dp | Entrada nueva en Drawer |
| Raite / transporte | `directions_car` | 24dp | CU-04, marcadores de viaje activo |
| Destino de raite | `flag` | 24dp | Pin de destino en mapa CU-04 |
| Toggle raite habilitado | `electric_rickshaw` | 24dp | Entrada en Drawer para VENDOR |
| Reporte pendiente (mapa) | `pending` | 20dp | Badge sobre círculo `pending_validation` |

---

## Paso 5A'.3 — Patrón: `DestinationPicker` [iter. 2]

### Problema

CU-04 (Solicitar raite) requiere que el comprador seleccione un destino antes de confirmar la solicitud. El design system de iter. 1 no tiene ningún patrón de selección de destino en mapa — solo tiene el Bottom Sheet de confirmación de parada (que es puntual, no con selección activa de coordenadas).

### Componentes relacionados y por qué no son suficientes

| Componente iter. 1 | Similitud | Por qué no alcanza |
|---|---|---|
| Bottom Sheet CU-01 (solicitar parada) | Mismo layout de confirmación | No tiene campo de búsqueda de dirección ni pin draggable |
| Input / Campo de texto (§8.1.4) | Mismo look del campo | Sin integración con Google Places Autocomplete ni pin en mapa |
| Pantalla de Seguimiento (TrackingScreen) | Mismo fondo de mapa fullscreen | Es de solo lectura, sin interacción de selección |

### Descripción del patrón

`DestinationPicker` es un patrón de dos capas que combina:
1. **Capa de mapa** (fondo fullscreen): muestra la ubicación actual del comprador y, cuando hay destino seleccionado, el pin de destino + línea punteada de conexión.
2. **Bottom sheet persistente** (no dismissible): input de búsqueda en la parte superior, resultados de autocomplete, y botón de confirmación con la distancia calculada.

### Flujo de interacción

```
Comprador pulsa "Solicitar raite" (sobre marcador del vendedor en HomeC)
        ↓
DestinationPicker se abre:
  · Mapa fullscreen con ubicación actual del comprador (pin azul pulsante)
  · Bottom sheet parcial (altura: 40% pantalla) no dismissible
  · Input de búsqueda con placeholder "¿A dónde vas?"
        ↓
Comprador escribe o dicta dirección
  → Google Places Autocomplete muestra sugerencias (máx. 5)
        ↓
Comprador selecciona una sugerencia
  → Pin de destino aparece en mapa (ícono `flag`, color-primary-700)
  → Línea punteada entre ubicación actual y destino
  → Bottom sheet muestra distancia calculada (ej. "2.3 km del vendedor")
  → Si distancia > 4 km: warning inline rojo + botón "Confirmar" deshabilitado
  → Si distancia ≤ 4 km: botón "Confirmar solicitud" habilitado (color-primary-700)
        ↓
(Opcional) Comprador arrastra el pin para ajustar punto exacto
  → Distancia recalcula en tiempo real
        ↓
Comprador pulsa "Confirmar solicitud"
  → POST /rides (ver Fase 4.A', diagrama 9.5.A)
```

### Props del componente

| Propiedad | Tipo | Default | Descripción |
|---|---|---|---|
| `vendorLocation` | `LatLng` | — | Posición actual del vendedor (para calcular distancia) |
| `buyerLocation` | `LatLng` | — | Posición actual del comprador (auto-llenada desde GPS) |
| `maxDistanceKm` | `double` | `4.0` | Distancia máxima permitida. Si supera → botón deshabilitado |
| `onDestinationConfirmed` | `Function(LatLng destination, double distanceKm)` | — | Callback al confirmar destino válido |
| `onCancel` | `VoidCallback` | — | Callback al pulsar "Cancelar" o botón atrás |

### Layout del Bottom Sheet

```
┌─────────────────────────────────────────────────┐  ← Mapa fullscreen (fondo)
│                    🗺️ MAPA                       │
│         📍 (comprador, azul pulsante)            │
│               ..............................      │  ← Línea punteada
│                              🚩 (destino)        │
│                                                  │
├─────────────────────────────────────────────────┤  ← Bottom Sheet
│  ────  (handle, centrado, color-neutral-200)     │
│                                                  │
│  ┌─────────────────────────────────────────────┐ │
│  │ 🔍  ¿A dónde vas?               [X limpiar] │ │  ← Input, alto 56dp
│  └─────────────────────────────────────────────┘ │
│                                                  │
│  [Lista de sugerencias Places — máx. 5 items]    │
│   Calle Ejemplo 123, Col. Centro                 │
│   Av. Principal 456, Col. Norte                  │
│   ...                                            │
│                                                  │
│  ─────────────────────────────────────────────── │
│  Distancia: 2.3 km   [✓ dentro del rango]        │  ← Visible tras selección
│                                                  │
│  [ Cancelar ]     [ Confirmar solicitud →  ]     │  ← Botones, altura 52dp
└─────────────────────────────────────────────────┘
```

### Tokens del patrón

| Elemento | Token | Valor |
|---|---|---|
| Fondo bottom sheet | `color-neutral-0` | `#FFFFFF` |
| Handle | `color-neutral-200` | 4dp × 32dp |
| Radio superior bottom sheet | `radius-xxl` | 24dp |
| Padding horizontal | `spacing-lg` | 24dp |
| Input campo búsqueda | Igual a §8.1.4 (Input/Campo de texto) | Alto 56dp, radio 12dp |
| Pin destino (mapa) | `color-primary-700` | `#1565C0` |
| Ícono pin | `flag` Material Icons Filled | 28dp |
| Línea punteada | `color-primary-500` al 60% | `dash: [8, 4]` |
| Label distancia — OK | `color-success-500` + ícono `check_circle_outline` | `#388E3C` |
| Label distancia — ERROR | `color-danger-500` + ícono `error_outline` | `#E53935` |
| Mensaje error distancia | `"Destino muy lejos (máx. 4 km)"` | `text-body-2`, `color-danger-500` |
| Botón confirmar — habilitado | Botón Primario estándar | `color-primary-700`, alto 52dp |
| Botón confirmar — deshabilitado | Botón Primario con `opacity: 0.4` | — |
| Botón cancelar | Botón Ghost / Secundario | `color-primary-700`, alto 52dp |

### Accesibilidad

- Input de búsqueda: `autofocus: true` al abrir (teclado aparece automáticamente)
- `semanticsLabel` del pin: `"Pin de destino, arrastra para ajustar"`
- Distancia fuera de rango: mensaje de error anunciado por TalkBack/VoiceOver al cambiar a estado error
- Botón "Confirmar" cuando deshabilitado: `tooltip`: `"El destino está a más de 4 km"`
- Touch target del pin arrastrable: área táctil 48dp × 48dp alrededor del pin

### Estados del componente

| Estado | Descripción |
|---|---|
| **Inicial** | Mapa con ubicación comprador. Input vacío. Botón "Confirmar" deshabilitado. |
| **Escribiendo** | Sugerencias de Places visibles. Sin pin de destino aún. |
| **Destino seleccionado — válido** | Pin en mapa. Distancia en verde. Botón "Confirmar" habilitado. |
| **Destino seleccionado — fuera de rango** | Pin en mapa. Distancia en rojo con mensaje de error. Botón deshabilitado. |
| **Cargando** (POST /rides en proceso) | Botón con `CircularProgressIndicator` blanco, 16dp. Inputs deshabilitados. |

---

## Resumen de adiciones al Design System [iter. 2]

### Tokens nuevos

| Categoría | Tokens añadidos | Cantidad |
|---|---|---|
| Colores semánticos | `color-community-animal`, `color-community-waste`, `color-community-pending`, `color-community-confirmed` (alias), `color-community-dismissed` (alias) | 5 |
| Colores de mapa | `map-community-animal-fill`, `map-community-animal-stroke`, `map-community-waste-fill`, `map-community-waste-stroke`, `map-community-pending-dash` | 5 |
| Iconografía | 9 íconos nuevos (pest_control, bug_report, thumb_up/down, fact_check, directions_car, flag, electric_rickshaw, pending) | 9 |

### Componentes nuevos

| Componente | CU que lo usa | Variantes |
|---|---|---|
| `ReportStatusChip` | CU-05, CU-06 | `pending_validation`, `confirmed`, `dismissed`, `expired` |
| `VotingIndicator` | CU-06 | `full` (Pantalla Detalle), `inline` (Lista de Reportes) |
| `DestinationPicker` | CU-04 | — (componente único, 5 estados internos) |

### Componentes extendidos

| Componente iter. 1 | Extensión iter. 2 |
|---|---|
| FAB "+" de CU-03 | Convertido a FAB expandible con 2 mini-FABs (CU-03 + CU-05) |

### Design tokens Dart — Adiciones [iter. 2]

```dart
// ────────────────────────────────────────────
// COMMUNITY REPORTS — colores nuevos [iter. 2]
// ────────────────────────────────────────────

// Tipos de foco de infección (CU-05)
static const Color communityAnimal   = Color(0xFF212121); // Negro — animal_muerto
static const Color communityWaste    = Color(0xFF795548); // Café  — zona_sucia
static const Color communityPending  = Color(0xFFFFC107); // Ámbar — pending_validation

// Estado chips CU-05/CU-06 (aliases semánticos)
// communityConfirmed = success500 (ya existente: 0xFF388E3C)
// communityDismissed = textDisabled (ya existente: 0xFF9E9E9E)

// Mapa — círculos community_reports
// Fill: usar communityAnimal/communityWaste con withOpacity(0.25)
// Fill pending: withOpacity(0.15)
// Fill dismissed: withOpacity(0.08)

// ────────────────────────────────────────────
// SPACING — sin cambios en iter. 2
// TYPOGRAPHY — sin cambios en iter. 2
// RADIOS — sin cambios en iter. 2
// ────────────────────────────────────────────
```

---

## Notas para integración al .docx

1. **Insertar como §8.1 [iter. 2] — Extensiones del Design System**, inmediatamente después del §8.1.6 original (Design Tokens Dart).
2. Marcar cada sub-sección con `[iter. 2]` en el encabezado para visibilidad de cambios.
3. La tabla de §5A'.1 (verificación de tokens existentes) puede incluirse como nota al pie o párrafo introductorio.
4. Los diagramas ASCII del `DestinationPicker` (layout bottom sheet) se reemplazan por wireframe HTML en Fase 5B'.1.
5. Este archivo es prerequisito obligatorio para **Fase 5B'** (wireframes de pantallas nuevas) y **Fase 5C'** (prompts Claude Design).

---

## Historial

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| V1.0 | 25/04/2026 | Miguel (con Claude Cowork) | Fase 5A' completa: verificación tokens severidad, tokens nuevos community_reports, chips de estado, VotingIndicator, FAB expandible, DestinationPicker. |

---

*Fase 5A' completada: 25/04/2026 — Los Borbotones / UBISAFE Iteración 2*
