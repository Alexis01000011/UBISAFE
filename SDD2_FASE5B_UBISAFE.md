# SDD2 — Fase 5B': Wireframes Pantallas Nuevas [iter. 2]
## CU-04 · CU-05 · CU-06 — Cuatro pantallas nuevas
### UBISAFE · Los Borbotones · 25/04/2026

> **Propósito:** Wireframes de baja fidelidad para las **4 pantallas completamente nuevas** de Iteración 2. Mismo estilo y nivel de detalle que `SDD_FASE5_UBISAFE.md` §8.2: layout ASCII + widgets Flutter sugeridos + tokens exactos + interacciones + accesibilidad.
>
> **Pantallas de extensión** (modificaciones a pantallas existentes) son responsabilidad de Alexis en `SDD2_FASE5Balt_UBISAFE.md`.
>
> **Archivos base leídos:**
> - `SDD2_FASE5A_UBISAFE.md` (tokens y componentes nuevos — design system iter. 2)
> - `SDD_FASE5_UBISAFE.md` §8.2 (estilo y convenciones de wireframes iter. 1)
> - `SDD2_FASE3A_UBISAFE.md` (modelo `rides`, ciclo de vida CU-04)
> - `SDD2_FASE3B_UBISAFE.md` (modelo `community_reports`, ciclo de vida CU-05/06)
> - `SDD2_FASE0_UBISAFE.md` (todas las decisiones definitivas)

---

## Índice de pantallas

| ID | Pantalla | CU | Rol |
|---|---|---|---|
| [W-CU04-01](#w-cu04-01--pantalla-solicitud-de-raite) | Pantalla Solicitud de Raite | CU-04 | BUYER |
| [W-CU05-01](#w-cu05-01--pantalla-reportar-foco-de-infección) | Pantalla Reportar Foco de Infección | CU-05 | Ambos |
| [W-CU06-01](#w-cu06-01--pantalla-lista-de-reportes-activos) | Pantalla Lista de Reportes Activos | CU-06 | Ambos |
| [W-CU06-02](#w-cu06-02--pantalla-detalle--validación-de-reporte) | Pantalla Detalle + Validación de Reporte | CU-06 | Ambos |

---

## W-CU04-01 — Pantalla Solicitud de Raite

**Ruta go_router:** `/ride/request` (parámetro implícito: `vendorUid` pasado por el llamador)
**Widget raíz:** `RideRequestScreen extends ConsumerStatefulWidget`
**Patrón:** `DestinationPicker` (definido en `SDD2_FASE5A_UBISAFE.md` §5A'.3)
**Estados:** buscando_destino | destino_seleccionado_valido | destino_seleccionado_invalido | confirmando (loading)
**Navegación desde:** `HomeComprador` — al tocar el marcador del vendedor y elegir "Solicitar raite" (ver `SDD2_FASE5Balt_UBISAFE.md` W-alt-01)

---

### Estado 1 — Buscando destino (inicial)

```
┌─────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░ │  ← status bar: dark icons sobre fondo claro
│                         │
│   [  MAPA FULLSCREEN  ] │  ← GoogleMap, fullscreen, no controls
│                         │    camera centrada en buyerLocation
│        📍               │  ← Marcador comprador (punto pulsante azul)
│      (buyer)            │    color-primary-700, animación pulse
│                         │
│            🛒           │  ← Marcador vendedor (storefront, color-secondary-500)
│          (vendor)       │    posición fija del vendedor seleccionado
│                         │
│                         │
│                         │
├═════════════════════════╡  ← Bottom Sheet, altura 45% pantalla, no dismissible
│  ▬▬▬ (handle centrado)  │    handle: 4×32dp, color-neutral-200
│                         │
│  ¿A dónde vas?          │  ← Text, text-heading-2, neutral-900
│                         │
│  ┌─────────────────────┐│  ← TextFormField (Input estándar §8.1.4)
│  │ 🔍 Buscar destino   ││    autofocus: true → teclado aparece al abrir
│  │                     ││    prefixIcon: Icons.search, neutral-400
│  └─────────────────────┘│    hintText: 'Calle, colonia, punto de referencia...'
│                         │    onChanged: → llama Places Autocomplete API
│                         │
│  (sin resultados aún)   │  ← Text, text-body-2, neutral-400, centrado
│                         │
│  ┌─────────────────────┐│  ← ElevatedButton Primario deshabilitado
│  │   Confirmar raite   ││    opacity: 0.4, onPressed: null
│  └─────────────────────┘│    alto: 52dp, full-width
│                         │
│  ┌─────────────────────┐│  ← TextButton Ghost
│  │      Cancelar       ││    color-primary-700, alto: 44dp
│  └─────────────────────┘│    onTap: → context.pop() regresa a HomeC
└─────────────────────────┘
  Fondo mapa: GoogleMap sin Scaffold backgroundColor
  Bottom Sheet: color-neutral-0 (#FFFFFF), radius superior 24dp
  Padding horizontal Bottom Sheet: spacing-lg (24dp)
```

---

### Estado 2 — Destino seleccionado (válido, ≤ 4 km)

```
┌─────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░ │
│                         │
│   [  MAPA FULLSCREEN  ] │  ← Cámara ajusta bounds para mostrar
│                         │    buyer + vendor + destino
│        📍               │  ← Comprador (azul pulsante)
│      (buyer)            │
│         ............    │  ← Polyline punteada buyer→destino
│                    🚩   │  ← Pin destino: Icons.flag (filled)
│          🛒       (dest)│    color-primary-700, 28dp
│        (vendor)         │
│                         │
│                         │
├═════════════════════════╡
│  ▬▬▬                    │
│                         │
│  Destino seleccionado   │  ← Text, text-heading-2, neutral-900
│  Av. Principal 456,     │  ← Text, text-body-1, neutral-700
│  Col. Norte             │    (dirección del resultado de Places)
│                         │
│  ┌─────────────────────┐│  ← TextFormField (mismo input, con X para limpiar)
│  │ 🔍 Av. Principal... ││    suffixIcon: IconButton(Icons.clear)
│  └─────────────────────┘│    onClear: → resetea selección, vuelve a Estado 1
│                         │
│  📏  2.3 km del vendedor│  ← Row: Icon(check_circle_outline, success-500, 16dp)
│  ✓ Dentro del rango     │       + Text, text-body-2, success-500
│                         │
│  ┌─────────────────────┐│  ← ElevatedButton Primario HABILITADO
│  │   Confirmar raite → ││    color-primary-700, alto: 52dp, full-width
│  └─────────────────────┘│    onTap: → dispara POST /rides (Estado 4: loading)
│                         │
│  ┌─────────────────────┐│
│  │      Cancelar       ││
│  └─────────────────────┘│
└─────────────────────────┘
  Pin destino arrastrable: GestureDetector sobre GoogleMapController
  Al arrastrar: recalcula distancia en tiempo real con Haversine client-side
  Al soltar: si > 4 km → transición a Estado 3 (inválido)
```

---

### Estado 3 — Destino seleccionado (inválido, > 4 km)

```
├═════════════════════════╡
│  ▬▬▬                    │
│                         │
│  Destino seleccionado   │
│  Zona Industrial Norte  │
│                         │
│  ┌─────────────────────┐│
│  │ 🔍 Zona Industrial  ││
│  └─────────────────────┘│
│                         │
│  ⚠  6.1 km del vendedor │  ← Row: Icon(error_outline, danger-500, 16dp)
│  Destino muy lejos      │       + Text, text-body-2, danger-500
│  (máximo 4 km)          │
│                         │
│  ┌─────────────────────┐│  ← ElevatedButton Primario DESHABILITADO
│  │   Confirmar raite   ││    opacity: 0.4, onPressed: null
│  └─────────────────────┘│    Tooltip: 'El destino está a más de 4 km'
│                         │
│  ┌─────────────────────┐│
│  │      Cancelar       ││
│  └─────────────────────┘│
└─────────────────────────┘
```

---

### Estado 4 — Confirmando (POST /rides en proceso)

```
├═════════════════════════╡
│  ▬▬▬                    │
│                         │
│  Enviando solicitud...  │  ← Text, text-heading-2, neutral-600
│                         │
│  ┌─────────────────────┐│  ← TextFormField deshabilitado (enabled: false)
│  │ 🔍 Av. Principal... ││
│  └─────────────────────┘│
│                         │
│  📏  2.3 km del vendedor│
│  ✓ Dentro del rango     │
│                         │
│  ┌─────────────────────┐│  ← ElevatedButton en estado cargando
│  │       ◌             ││    CircularProgressIndicator, blanco, 18dp
│  └─────────────────────┘│    onPressed: null (deshabilitado)
│                         │
│  ┌─────────────────────┐│  ← Cancelar también deshabilitado
│  │      Cancelar       ││    opacity: 0.4, onPressed: null
│  └─────────────────────┘│
└─────────────────────────┘
  Tras éxito (POST /rides → status: pending):
  → context.go('/home/buyer') con state: rideRequested
  → HomeComprador muestra estado "Esperando respuesta del vendedor"
  Tras error (400 vendor_not_available, 400 route_unsafe, etc.):
  → SnackBar con mensaje de error específico
  → vuelve a Estado 2 (destino seleccionado)
```

---

### Propiedades visuales clave

| Elemento | Token / Valor |
|---|---|
| Mapa | `GoogleMap(myLocationEnabled: false, zoomControlsEnabled: false)` |
| Marcador comprador | `BitmapDescriptor` círculo azul pulsante, 20dp |
| Marcador vendedor | `Icons.storefront`, color-secondary-500, 28dp |
| Pin destino | `Icons.flag` filled, color-primary-700, 28dp |
| Línea punteada | `Polyline(patterns: [Dot(), Gap(8)], color: primary500 60%, width: 2)` |
| Bottom sheet altura | `DraggableScrollableSheet(initialChildSize: 0.45, minChildSize: 0.35, maxChildSize: 0.7)` |
| Fondo Bottom sheet | `color-neutral-0` (`#FFFFFF`) |
| Radio superior | `BorderRadius.vertical(top: Radius.circular(24))` |

### Comportamiento detallado

1. Al abrir → `autofocus: true` en el input → teclado sube → Bottom Sheet comprime mapa
2. Al escribir (debounce 400ms) → llama `PlacesAutocomplete.show()` o API REST de Places → muestra resultados en `ListView`
3. Al seleccionar resultado → geocodifica → coloca `Marker` en mapa → calcula distancia Haversine entre `vendorLocation` y `destination` → actualiza label de distancia → habilita/deshabilita botón
4. Pin arrastrable: `GoogleMapController.animateCamera` + listener de posición en tiempo real
5. "Confirmar raite" → `RideRequestModule.createRide(vendorUid, destination)` → `POST /rides` → si 200 → navegación; si error → SnackBar
6. "Cancelar" (cualquier estado) → `context.pop()` regresa a HomeC sin cambios

### Accesibilidad

- `semanticsLabel` del pin de destino: `"Pin de destino. Arrastra para ajustar."`
- Distancia: `Semantics(liveRegion: true)` — se anuncia automáticamente al cambiar
- Error de distancia: `Semantics(liveRegion: true, label: "Destino demasiado lejos, máximo 4 kilómetros")`
- Botón deshabilitado: `Tooltip` con `message: "El destino está a más de 4 km"` → accesible por TalkBack

---

## W-CU05-01 — Pantalla Reportar Foco de Infección

**Componente:** `CommunityReportBottomSheet` — bottom sheet modal (no ruta independiente)
**Widget raíz:** `CommunityReportBottomSheet extends ConsumerStatefulWidget`
**Acceso:** FAB expandible (mini-FAB "Reportar foco de infección") en HomeC y HomeV
**Estados:** seleccionando_tipo | confirmando (loading) | éxito
**Prerequisito:** GPS activo (igual que CU-03; si GPS inactivo → `GpsRequiredEmptyState`)

> **Nota de diseño:** CU-05 **no pide al usuario que dibuje un área**. UBISAFE toma su posición GPS actual automáticamente. El formulario es simple: tipo de foco + confirmación. Radio fijo 15 m, no configurable.

---

### Estado 1 — Seleccionando tipo de foco

```
┌─────────────────────────┐
│   [  MAPA FULLSCREEN  ] │  ← HomeC o HomeV (pantalla de fondo)
│   (mapa existente)      │
│                         │
│                         │
│         📍              │  ← Posición actual del usuario
│       (usuario)         │    Círculo de preview: 15 m, color según tipo
│                         │    (al seleccionar tipo, aparece el círculo preview)
│                         │
│                         │
├═════════════════════════╡  ← BottomSheet modal, altura 50% pantalla
│  ▬▬▬                    │    showModalBottomSheet(isScrollControlled: true)
│                         │
│  Reportar foco de       │  ← Text, text-heading-1, neutral-900
│  infección              │
│                         │
│  ¿Qué tipo de foco      │  ← Text, text-body-2, neutral-600
│  es?                    │
│                         │
│  ┌─────────────────────┐│  ← Card seleccionable (GestureDetector + AnimatedContainer)
│  │ 🐾  Animal muerto   ││    Seleccionado: borde 2dp communityAnimal (#212121)
│  │     Cadáver en vía  ││                 fondo: #212121 al 8%
│  │     pública         ││    No sel.: borde 1dp neutral-200, fondo: neutral-0
│  └─────────────────────┘│    Radio: 12dp, alto mínimo: 72dp
│                         │    Padding: spacing-md (16dp)
│  ┌─────────────────────┐│  ← Segunda card seleccionable
│  │ 🗑  Zona sucia      ││    Seleccionado: borde 2dp communityWaste (#795548)
│  │     Basura dispersa ││                 fondo: #795548 al 8%
│  │     por perros      ││
│  └─────────────────────┘│
│                         │
│  📍 Se usará tu ubicación│  ← Row: Icon(my_location, neutral-400, 14dp)
│  actual como punto      │       + Text, text-caption, neutral-400
│  del reporte            │    (radio automático: 15 m)
│                         │
│  ┌─────────────────────┐│  ← ElevatedButton Primario
│  │   Enviar reporte    ││    Habilitado SOLO si hay tipo seleccionado
│  └─────────────────────┘│    Deshabilitado (opacity 0.4) si ninguna card selec.
│                         │
└─────────────────────────┘
  Fondo Bottom Sheet: color-neutral-0
  Padding horizontal: spacing-lg (24dp)
  Padding vertical: spacing-md (20dp)
```

---

### Estado 1b — Con tipo seleccionado (preview en mapa)

```
│   [  MAPA FULLSCREEN  ] │
│                         │
│         📍              │  ← Usuario
│       ╔═══════╗         │  ← Círculo preview 15 m:
│       ║       ║         │    Si animal_muerto: fill #212121 15%, stroke #212121
│       ║  15m  ║         │    Si zona_sucia: fill #795548 15%, stroke #795548
│       ╚═══════╝         │    (aparece con AnimatedOpacity al seleccionar card)
│                         │
├═════════════════════════╡
│                         │
│  ✓ Animal muerto        │  ← Label del tipo seleccionado actualizado
│  seleccionado           │
│                         │
│  ┌─────────────────────┐│  ← Card con selección visual (borde + fondo tintado)
│  │ 🐾  Animal muerto   ││    checkmark: Icon(check_circle, #212121, 20dp) al extremo
│  │     Cadáver en vía  ││    derecho de la card
│  │     pública      ✓  ││
│  └─────────────────────┘│
│                         │
│  ┌─────────────────────┐│  ← Segunda card, no seleccionada
│  │ 🗑  Zona sucia      ││
│  │     ...             ││
│  └─────────────────────┘│
│                         │
│  📍 Se usará tu ubicación│
│  actual                 │
│                         │
│  ┌─────────────────────┐│  ← Botón HABILITADO
│  │   Enviar reporte    ││
│  └─────────────────────┘│
└─────────────────────────┘
```

---

### Estado 2 — Confirmando (POST /community-reports en proceso)

```
├═════════════════════════╡
│  ▬▬▬                    │
│                         │
│  Enviando reporte...    │  ← Text, text-heading-2, neutral-600
│                         │
│  [Cards deshabilitadas] │  ← opacity: 0.5, onTap: null
│                         │
│  ┌─────────────────────┐│  ← Botón en estado cargando
│  │        ◌            ││    CircularProgressIndicator, blanco, 18dp
│  └─────────────────────┘│
└─────────────────────────┘
```

---

### Estado 3 — Éxito

```
├═════════════════════════╡
│                         │
│         ✓               │  ← Icon(check_circle, success-500, 48dp), centrado
│                         │
│  ¡Reporte enviado!      │  ← Text, text-heading-1, neutral-900, centrado
│                         │
│  Tu reporte está        │  ← Text, text-body-1, neutral-600, centrado
│  pendiente de           │
│  validación por la      │
│  comunidad.             │
│                         │
│  (se cierra automático  │  ← Timer(Duration(seconds: 2), () → Navigator.pop())
│   en 2 segundos)        │    SnackBar adicional en HomeC/V: "Foco reportado"
│                         │
└─────────────────════════╡
```

---

### Propiedades visuales clave

| Elemento | Token / Valor |
|---|---|
| Card no seleccionada | borde `color-neutral-200` 1dp, fondo `color-neutral-0`, radio 12dp |
| Card animal_muerto seleccionada | borde `color-community-animal` 2dp, fondo `#21212114`, checkmark negro |
| Card zona_sucia seleccionada | borde `color-community-waste` 2dp, fondo `#79554814`, checkmark café |
| Ícono animal_muerto | `Icons.pest_control` 28dp, `color-community-animal` |
| Ícono zona_sucia | `Icons.delete_outline` 28dp, `color-community-waste` |
| Preview en mapa | `Circle` de Google Maps SDK, radio 15 m, fill con withOpacity(0.15), stroke 2dp |
| Checkmark selección | `Icons.check_circle` 20dp, esquina inferior derecha de la card |

### Comportamiento detallado

1. Bottom sheet se abre con `showModalBottomSheet(isScrollControlled: true, isDismissible: true, enableDrag: true)`
2. Al seleccionar card → `setState` actualiza selección + añade `Circle` al GoogleMap de fondo (con AnimatedOpacity)
3. "Enviar reporte" → `CommunityReportModule.createReport(threatType, currentLocation)` → `POST /community-reports`
4. FastAPI valida: distancia usuario ≤ 4 km del reporte (siempre pasa, ya que se usa ubicación actual), tipo válido
5. Respuesta 200 → Estado 3 (éxito) → timer 2s → cierra sheet
6. Error (sin GPS, fuera de radio, etc.) → SnackBar de error, permanece en Estado 1

### Accesibilidad

- Cards seleccionables: `Semantics(button: true, selected: isSelected, label: "Tipo animal muerto")` / `"Tipo zona sucia"`
- Al seleccionar: `liveRegion: true` anuncia `"Animal muerto seleccionado"` o `"Zona sucia seleccionada"`
- Preview en mapa: decorativo, no interactivo, sin semantics
- Touch target de cards: mínimo 72dp de alto (garantizado por `minHeight` del Container)

---

## W-CU06-01 — Pantalla Lista de Reportes Activos

**Ruta go_router:** `/community-reports`
**Widget raíz:** `ActiveReportsScreen extends ConsumerStatefulWidget`
**Navegación desde:** Drawer → entrada "Reportes activos" (ver `SDD2_FASE5Balt_UBISAFE.md` W-alt-04)
**Estado de Riverpod:** `communityReportsProvider` — lista de `community_reports` con `status in [pending_validation, confirmed]`

---

### Layout principal

```
┌─────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░ │  ← status bar: dark icons sobre primary-50
├─────────────────────────┤
│ ←  Reportes activos     │  ← AppBar: IconButton back + título text-heading-2
│                         │    backgroundColor: color-primary-50 (#E3F2FD)
│                         │    elevation: 0
├─────────────────────────┤
│ [Todos] [Pendiente] [✓] │  ← FilterChipGroup (Row scrollable)
│                         │    Chips: "Todos" | "Pendiente" | "Validado"
│                         │    Chip seleccionado: filled, primary-700
│                         │    Chip no selec.: outlined, neutral-400
│                         │    (filtran la lista por status)
├─────────────────────────┤
│                         │
│ ┌─────────────────────┐ │  ← Card (reporte 1)
│ │ 🐾  Animal muerto   │ │    Card estándar: radio 16dp, elevación 2dp
│ │                     │ │    Padding interno: spacing-md (16dp)
│ │ [Pendiente]  300 m  │ │    ReportStatusChip (compact) + distancia al usuario
│ │                     │ │    (Text, text-caption, neutral-600)
│ │ 👍 1  👎 0          │ │    VotingIndicator (variant: inline)
│ │ Hace 15 min         │ │    (Text, text-caption, neutral-400)
│ └─────────────────────┘ │    onTap: → context.go('/community-reports/{id}')
│                         │
│ ┌─────────────────────┐ │  ← Card (reporte 2)
│ │ 🗑  Zona sucia      │ │
│ │                     │ │
│ │ [Validado]   120 m  │ │    ReportStatusChip: variante "confirmed" (verde)
│ │                     │ │
│ │ 👍 3  👎 0          │ │    VotingIndicator inline: confirm_count=3 (umbral)
│ │ Hace 2 hrs          │ │
│ └─────────────────────┘ │
│                         │
│ ┌─────────────────────┐ │  ← Card (reporte 3)
│ │ 🐾  Animal muerto   │ │
│ │                     │ │
│ │ [Pendiente]   1.2km │ │
│ │                     │ │
│ │ 👍 0  👎 1          │ │
│ │ Hace 4 hrs          │ │
│ └─────────────────────┘ │
│                         │
│         ...             │  ← ListView.builder, carga lazy
│                         │
└─────────────────────────┘
  Fondo pantalla: color-neutral-100 (#F5F5F5)
  ListView padding: spacing-md (16dp) horizontal + vertical
  Separación entre cards: spacing-sm (8dp)
```

---

### Estado vacío (sin reportes activos cercanos)

```
├─────────────────────────┤
│                         │
│                         │
│                         │
│      ✅                 │  ← Icon(fact_check, neutral-400, 64dp), centrado
│                         │
│  No hay reportes        │  ← Text, text-heading-2, neutral-600, centrado
│  activos cerca de ti    │
│                         │
│  Tu comunidad está      │  ← Text, text-body-2, neutral-400, centrado
│  limpia en este         │
│  momento.               │
│                         │
│                         │
└─────────────────────────┘
```

---

### Estado cargando (inicial)

```
├─────────────────────────┤
│                         │
│ [████████████  ]  ←── Shimmer placeholder card 1 (loading skeleton)
│ [████  ██████  ]
│ [████████      ]
│                         │
│ [████████████  ]  ←── Shimmer placeholder card 2
│ [████  ██████  ]
│ [████████      ]
│                         │
└─────────────────────────┘
  ShimmerLoading: Container con color-neutral-200, animación horizontal
```

---

### Anatomía de la Card de reporte

```
┌──────────────────────────────────────────────────────┐
│  [ícono tipo]  [nombre tipo]            [distancia]  │  ← Row principal
│                                                      │
│  [ReportStatusChip compact]       [VotingIndicator]  │  ← Row secundaria
│                                   👍 N  👎 M         │    inline
│                                                      │
│  [timestamp relativo]                                │  ← Text caption
└──────────────────────────────────────────────────────┘
```

| Elemento | Widget / Token |
|---|---|
| Ícono tipo | `Icons.pest_control` (animal) / `Icons.delete_outline` (sucia), 24dp, color según tipo |
| Nombre tipo | `text-body-1`, `neutral-900` ("Animal muerto" / "Zona sucia") |
| Distancia | `text-caption`, `neutral-600` ("300 m" / "1.2 km") — calculada con Haversine desde ubicación del usuario |
| ReportStatusChip | Variante `compact: true` (sin ícono, reducida) |
| VotingIndicator | Variante `inline` — `Row: Icon(thumb_up, 16dp) + "N" + spacing + Icon(thumb_down, 16dp) + "M"` |
| Timestamp | `text-caption`, `neutral-400`, relativo ("Hace 15 min", "Hace 2 hrs") con `timeago` package |
| Touch target | Card completa es tappable (`InkWell` con `borderRadius: 16dp`) |

### Propiedades de filtros

| Chip de filtro | Filtra por | Valor Firestore |
|---|---|---|
| "Todos" (default) | Sin filtro — muestra `pending_validation` + `confirmed` | — |
| "Pendiente" | Solo pendientes de validación | `status == "pending_validation"` |
| "Validado" ✓ | Solo confirmados | `status == "confirmed"` |

> `dismissed` y `expired` no se muestran en la lista (excluidos del query).

### Comportamiento detallado

1. `communityReportsProvider` realiza query Firestore: `community_reports` donde `status in ["pending_validation", "confirmed"]` y `expires_at > now()`, ordenado por `created_at desc`
2. Distancia calculada client-side con Haversine entre `report.location` y `gpsStateProvider.currentPosition`
3. Tap en card → `context.go('/community-reports/${report.id}')` — pasa el objeto `CommunityReport` por `extra` en go_router
4. FilterChipGroup actualiza `StateProvider<ReportFilter>` → `communityReportsProvider` aplica filtro local (sin nueva query)
5. Pull-to-refresh: `RefreshIndicator` → invalida el provider → re-fetch

### Accesibilidad

- Card: `Semantics(button: true, label: "Reporte de animal muerto a 300 metros, estado pendiente, 1 confirmación, hace 15 minutos")`
- FilterChips: `Semantics(selected: isSelected, button: true)`
- Estado vacío: `Semantics(label: "No hay reportes activos cercanos")`
- Shimmer: `ExcludeSemantics(child: shimmerWidget)` — no anunciado por TalkBack mientras carga

---

## W-CU06-02 — Pantalla Detalle + Validación de Reporte

**Ruta go_router:** `/community-reports/:reportId`
**Widget raíz:** `ReportDetailScreen extends ConsumerStatefulWidget`
**Parámetros:** `reportId` (string) — el objeto `CommunityReport` viene por `extra` de go_router o se recarga desde Firestore
**Navegación desde:** W-CU06-01 (Lista de Reportes Activos) → tap en card

---

### Layout principal (reporte `pending_validation`, usuario no ha votado)

```
┌─────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░ │  ← status bar: dark icons
├─────────────────────────┤
│ ←  Detalle del reporte  │  ← AppBar: back + título text-heading-2
│                     ⋮   │    overflow menu: "Reportar abuso" (futuro)
│                         │    backgroundColor: neutral-100, elevation: 0
├─────────────────────────┤
│                         │
│  [   MAPA — 220dp alto  ]│  ← GoogleMap (no fullscreen, altura fija)
│                         │    Modo: solo visualización, no interactivo
│         📍              │    Marcador usuario: azul pulsante
│       ╔═══════╗         │    Círculo reporte: 15 m radio,
│       ║  15m  ║         │      fill communityAnimal 25% (o waste 25%)
│       ╚═══════╝         │      stroke 2dp, color según threat_type
│                         │    Cámara centra en report.location, zoom 17
│                         │
├─────────────────────────┤  ← Divider (color-neutral-200, 1dp)
│                         │
│  🐾  Animal muerto      │  ← Row: Icon(pest_control, 28dp, communityAnimal)
│                         │       + Text, text-heading-1, neutral-900
│  [Pendiente] • 300 m    │  ← Row: ReportStatusChip + Text caption neutral-600
│                         │
│  Reportado hace 15 min  │  ← Text, text-body-2, neutral-600
│  por un miembro de la   │    (sin mostrar nombre del reportante — privacidad)
│  comunidad              │
│                         │
├─────────────────────────┤  ← Divider
│                         │
│  Validación comunitaria │  ← Text, text-heading-2, neutral-900
│                         │
│  ¿Pudiste verificar     │  ← Text, text-body-2, neutral-600
│  este foco?             │
│                         │
│  ┌─────────────────────┐│  ← VotingIndicator (variant: full)
│  │   👍          👎   ││
│  │    1           0   ││    confirm_count = 1, dismiss_count = 0
│  │ Confirmar  Desmentir││    threshold = 3
│  │ [══════════════════]││    Barra: 33% verde (1/3 hacia confirmed)
│  └─────────────────────┘│
│                         │
│  Faltan 2 confirmaciones│  ← Text, text-body-2, neutral-600
│  para validar el reporte│    (calculado: threshold - confirm_count)
│                         │
│  ┌─────────────────────┐│  ← ElevatedButton Primario
│  │   ✓  Confirmar      ││    color-success-500 (#388E3C), alto: 52dp
│  └─────────────────────┘│    onTap: → PATCH /community-reports/{id}/validations
│                         │             verdict: "confirm"
│  ┌─────────────────────┐│  ← OutlinedButton con borde danger-500
│  │   ✕  Desmentir      ││    color texto: danger-500, alto: 52dp
│  └─────────────────────┘│    onTap: → PATCH /community-reports/{id}/validations
│                         │             verdict: "dismiss"
└─────────────────────────┘
  Scroll: SingleChildScrollView (el mapa es sticky en la parte superior)
  Padding horizontal cuerpo: spacing-lg (24dp)
  Padding vertical secciones: spacing-md (16dp)
```

---

### Estado — usuario ya votó (confirmó)

```
│  Validación comunitaria │
│                         │
│  ┌─────────────────────┐│  ← VotingIndicator: thumb_up filled (votado)
│  │   👍👈       👎     ││    userVerdictWas: "confirm"
│  │    2           0    ││    confirm_count = 2 (incluye el del usuario)
│  │ Confirmar  Desmentir││    Ícono thumb_up: filled, color-success-500
│  │ [══════════════════]││    Ícono thumb_down: outlined, color-neutral-400
│  └─────────────────────┘│
│                         │
│  ✓ Ya confirmaste este  │  ← Row: Icon(check_circle, success-500, 16dp)
│  reporte                │       + Text, text-body-2, success-500
│                         │
│  ┌─────────────────────┐│  ← Ambos botones deshabilitados (opacity: 0.4)
│  │   ✓  Confirmar      ││    onPressed: null
│  └─────────────────────┘│    Tooltip: "Ya votaste este reporte"
│                         │
│  ┌─────────────────────┐│
│  │   ✕  Desmentir      ││
│  └─────────────────────┘│
└─────────────────────────┘
```

---

### Estado — reporte ya `confirmed` (umbral alcanzado)

```
│  ┌─────────────────────┐│  ← VotingIndicator: confirm_count = 3
│  │   👍          👎   ││    Barra: 100% verde (umbral completo)
│  │    3           0   ││
│  │ Confirmar  Desmentir││
│  │ [████████████████] ││    ← Barra llena, color-success-500
│  └─────────────────────┘│
│                         │
│  ✓ Reporte validado por │  ← Banner verde (success-100 bg)
│  la comunidad           │    Container: fondo #C8E6C9, padding 12dp, radio 8dp
│                         │    Row: Icon(check_circle, success-500) + Text body-2
│  ┌─────────────────────┐│  ← Botones deshabilitados (reporte ya cerrado)
│  │   ✓  Confirmar      ││    opacity: 0.4, onPressed: null
│  └─────────────────────┘│
│  ┌─────────────────────┐│
│  │   ✕  Desmentir      ││
│  └─────────────────────┘│
```

---

### Estado — reporte propio (el usuario intentó votar su propio reporte)

> FastAPI rechaza con `403 Forbidden` si `reporter_uid == request.auth.uid`. El cliente debe detectar este caso al cargar la pantalla.

```
│  Validación comunitaria │
│                         │
│  Este es tu propio      │  ← Banner gris (neutral-100 bg)
│  reporte. No puedes     │    Container: fondo #F5F5F5, borde neutral-200 1dp
│  validarlo tú mismo.    │    Row: Icon(info_outline, neutral-600, 16dp) + Text body-2
│                         │
│  ┌─────────────────────┐│  ← Ambos botones deshabilitados permanentemente
│  │   ✓  Confirmar      ││    opacity: 0.4, onPressed: null
│  └─────────────────────┘│
│  ┌─────────────────────┐│
│  │   ✕  Desmentir      ││
│  └─────────────────────┘│
```

---

### Propiedades visuales clave

| Elemento | Token / Valor |
|---|---|
| Altura mapa | 220dp fijo (`SizedBox(height: 220)`) |
| Mapa interactividad | `GoogleMap(liteModeEnabled: true)` en Android / `myLocationEnabled: false` |
| Círculo en mapa | `Circle(radius: 15, fillColor: communityAnimal.withOpacity(0.25), strokeColor: communityAnimal, strokeWidth: 2)` |
| VotingIndicator (full) | Ver spec `SDD2_FASE5A_UBISAFE.md` §5A'.2.3 |
| Botón Confirmar | `ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.success500))` |
| Botón Desmentir | `OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger500, side: BorderSide(color: AppColors.danger500)))` |
| Banner validado | `Container(color: Color(0xFFC8E6C9), borderRadius: BorderRadius.circular(8), padding: EdgeInsets.all(12))` |
| AppBar trailing | `IconButton(Icons.more_vert)` — abre `showModalBottomSheet` con opciones (futuro) |

### Comportamiento detallado

1. Al abrir: verifica `report.reporter_uid == currentUserUid` → si es propio → muestra banner "no puedes votar" y deshabilita botones
2. Verifica si el usuario ya aparece en `report.validations[]` → si ya votó → muestra estado correspondiente y deshabilita botones
3. "Confirmar" → `ReportValidationModule.vote(reportId, "confirm")` → `PATCH /community-reports/{id}/validations`
4. FastAPI: valida que `reporter_uid != current_uid` (403), no voto duplicado (409), reporte activo (404/410), radio ≤ 4 km
5. Tras votar exitosamente → `communityReportsProvider.refresh()` → UI actualiza `confirm_count` / `dismiss_count` y `ReportStatusChip`
6. Si tras el voto se cruza umbral 3 → FastAPI cambia `status` → Riverpod re-fetch → pantalla muestra banner "reporte validado"

### Accesibilidad

- Mapa: `ExcludeSemantics` parcial — solo anuncia `"Mapa mostrando la ubicación del reporte"` (sin detalle de círculo)
- VotingIndicator (full): ver spec §5A'.2.3 — `semanticsLabel` por botón con conteo y umbral
- Banner validado: `Semantics(liveRegion: true, label: "Este reporte fue validado por la comunidad")`
- Banner propio: `Semantics(label: "No puedes validar tu propio reporte")`
- Botones deshabilitados: `Tooltip` con mensaje explicativo, anunciado por TalkBack

---

## Resumen de pantallas — Fase 5B'

| Wireframe | Pantalla | CU | Estados documentados | Navegación |
|---|---|---|---|---|
| **W-CU04-01** | Solicitud de Raite | CU-04 | 4 (buscando / válido / inválido / loading) | HomeC → `/ride/request` → HomeC |
| **W-CU05-01** | Reportar Foco de Infección | CU-05 | 3 (seleccionando / loading / éxito) | FAB expandible → BottomSheet → HomeC/V |
| **W-CU06-01** | Lista de Reportes Activos | CU-06 | 3 (cargando / contenido / vacío) | Drawer → `/community-reports` |
| **W-CU06-02** | Detalle + Validación | CU-06 | 5 (sin votar / ya votó / confirmado / propio / loading) | Lista → `/community-reports/:id` |

### Rutas go_router nuevas

| Ruta | Widget | Parámetros |
|---|---|---|
| `/ride/request` | `RideRequestScreen` | `vendorUid` (extra) |
| `/community-reports` | `ActiveReportsScreen` | — |
| `/community-reports/:reportId` | `ReportDetailScreen` | `reportId` (path param), `CommunityReport?` (extra) |

### Componentes nuevos referenciados

| Componente | Definido en | Usado en |
|---|---|---|
| `ReportStatusChip` | `SDD2_FASE5A_UBISAFE.md` §5A'.2.2 | W-CU06-01 (compact), W-CU06-02 (full) |
| `VotingIndicator` | `SDD2_FASE5A_UBISAFE.md` §5A'.2.3 | W-CU06-01 (inline), W-CU06-02 (full) |
| `DestinationPicker` | `SDD2_FASE5A_UBISAFE.md` §5A'.3 | W-CU04-01 (patrón completo) |
| `CommunityReportBottomSheet` | W-CU05-01 (este archivo) | HomeC, HomeV (via FAB expandible) |

---

## Notas para integración al .docx

1. **Insertar como §8.8–8.11 [iter. 2]** (continuación de §8.7 de iter. 1), marcando cada sección con `[iter. 2]`.
2. Los bloques ASCII se reemplazan por capturas de pantalla de los mockups (Fase 5C') en la versión final del .docx.
3. Este archivo es prerequisito para **Fase 5C'** (prompts Claude Design para mockups de alta fidelidad).
4. Coordinar con Alexis para que `SDD2_FASE5Balt_UBISAFE.md` esté disponible antes de Fase 5C' (se necesitan ambos para generar todos los prompts).

---

## Historial

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| V1.0 | 25/04/2026 | Miguel (con Claude Cowork) | Fase 5B' completa: 4 wireframes nuevos (W-CU04-01, W-CU05-01, W-CU06-01, W-CU06-02) con todos los estados, tokens, comportamientos y accesibilidad. |

---

*Fase 5B' completada: 25/04/2026 — Los Borbotones / UBISAFE Iteración 2*
