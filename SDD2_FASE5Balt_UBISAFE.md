# SDD UBISAFE — Fase 5B.alt': Wireframes de Extensiones a Pantallas Existentes
## Los Borbotones · Iteración 2
### Sección §8 (extensiones iter. 2) · Responsable: 🟦 Alexis
### Generado: 25/04/2026

> **Propósito de este archivo:** Documenta las modificaciones que la Iteración 2 introduce en pantallas **ya existentes** del SDD iter. 1. No incluye pantallas nuevas (eso es responsabilidad de `SDD2_FASE5B_UBISAFE.md` — Miguel). Cada sección indica el wireframe base de iter. 1 (referencia cruzada con `SDD_FASE5_UBISAFE.md`) y luego describe exactamente qué cambia.
>
> **Convención de marcado:**
> - `[iter. 2]` junto a cualquier elemento nuevo en los wireframes ASCII.
> - Anotaciones en texto con `▶ NUEVO [iter. 2]` para diferencias respecto a iter. 1.
> - El resto de la pantalla se documenta solo en la medida necesaria para dar contexto.

---

## ÍNDICE

1. [W-06b ext — Home Comprador · Estado B extendido (CU-04 + CU-05)](#w-06b-ext--home-comprador--estado-b-extendido)
2. [W-07 ext — Bottom Sheet Vendedor extendido (CU-04)](#w-07-ext--bottom-sheet-vendedor-extendido)
3. [W-11b ext — Home Vendedor · Estado B extendido (toggle raite)](#w-11b-ext--home-vendedor--estado-b-extendido)
4. [W-11c ext — Home Vendedor · Estado C extendido (solicitud de raite entrante)](#w-11c-ext--home-vendedor--estado-c-extendido)
5. [W-14b — Dialog: Solicitud de Raite Entrante [iter. 2]](#w-14b--dialog-solicitud-de-raite-entrante)
6. [W-18 ext — Drawer extendido (Reportes activos)](#w-18-ext--drawer-extendido)
7. [W-19 ext — Mi Perfil extendido (toggle "Habilitar raites")](#w-19-ext--mi-perfil-extendido)
8. [W-20 ext — Historial de Actividad extendido (tab Raites)](#w-20-ext--historial-de-actividad-extendido)

---

## W-06b ext — Home Comprador · Estado B extendido

**Base:** `W-06b` de `SDD_FASE5_UBISAFE.md` (Home Comprador GPS activo)
**Ruta go_router:** `/home/buyer` (sin cambio)
**CUs que provocan el cambio:** CU-04 (raite), CU-05 (focos de infección en el mapa)

### Cambios respecto a iter. 1

Dos cambios visuales sobre el mapa:

1. **▶ NUEVO [iter. 2] — Polígonos de reportes comunitarios (CU-05):** Los focos de infección reportados por la comunidad se representan como polígonos con relleno semitransparente (además de los círculos de riesgo de CU-03 que ya existían). Color: `warning-200` relleno / `warning-700` borde para `severity: HIGH`; `orange-200`/`orange-600` para `MEDIUM`; `blue-100`/`blue-500` para `LOW`. Icono de pin dentro del polígono: 🦠 (ícono `Icons.coronavirus_outlined` o equivalente).

2. **▶ NUEVO [iter. 2] — Botón "Solicitar raite" en bottom sheet al tocar vendedor:** Al tocar un marcador de vendedor, el bottom sheet existente (W-07) se extiende con un segundo botón si el vendedor tiene `rideEnabled: true`. Ver W-07 ext para el detalle del sheet.

```
┌─────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░ │
├─────────────────────────┤
│ ☰  UBISAFE          🔔  │  ← AppBar overlay (sin cambio)
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│  [MAPA GOOGLE MAPS]     │
│                         │
│   (V)         (!)       │  ← (V) marcador vendedor, (!) zona riesgo CU-03
│                         │    (sin cambio respecto a iter. 1)
│      ⦿                  │    ⦿ Mi ubicación
│   (V)    [!HIGH]        │
│                         │
│        ╔═══════╗        │  ← ▶ NUEVO [iter. 2]
│        ║ 🦠    ║        │    Polígono foco de infección (community_report)
│        ║  FOC  ║        │    relleno warning-200, borde warning-700
│        ╚═══════╝        │    CU-05 severity HIGH → rojo/naranja
│                         │
│      ╔═══════════╗      │  ← ▶ NUEVO [iter. 2]
│      ║ 🦠 (LOW)  ║      │    Foco severity LOW → azul claro
│      ╚═══════════╝      │    polígono más pequeño, borde blue-500
│                         │
│                      [+]│  ← FAB warning-700 (sin cambio)
└─────────────────────────┘
```

**Leyenda del mapa extendida [iter. 2]:**

| Símbolo | Qué representa | Color | Origen |
|---------|---------------|-------|--------|
| (V) círculo verde | Vendedor activo | secondary-700 | CU-02 iter. 1 |
| (!) polígono | Zona de riesgo (CU-03) | warning-700/red-700 | CU-03 iter. 1 |
| 🦠 polígono relleno | Foco de infección comunitario | warning / orange / blue | CU-05 **iter. 2** |

**Precondición GPS:** sin cambio (GPS requerido, si no → GpsRequiredEmptyState).

**Proveedor Riverpod nuevo [iter. 2]:**
```dart
// ▶ NUEVO [iter. 2]
final communityReportsProvider = StreamProvider<List<CommunityReport>>(
  (ref) => CommunityReportRepository().watchActiveReports(),
);

// En GoogleMap widget:
polygons: {
  ...riskPolygons,           // iter. 1 (CU-03)
  ...communityPolygons,      // ▶ iter. 2 (CU-05): desde communityReportsProvider
},
```

---

## W-07 ext — Bottom Sheet Vendedor extendido

**Base:** `W-07` de `SDD_FASE5_UBISAFE.md`
**Aparece cuando:** Comprador toca marcador de un vendedor en el mapa
**CU:** CU-04 (añade botón "Solicitar raite" si el vendedor tiene `rideEnabled: true`)

### Lógica condicional [iter. 2]

El bottom sheet ahora tiene **dos variantes** según el flag `rideEnabled` del vendedor:

- **Variante A (rideEnabled: false o ausente):** idéntico a iter. 1 — un solo botón "Solicitar parada aquí".
- **Variante B (rideEnabled: true):** se añade un segundo botón "Solicitar raite" debajo del primario, y la sección de información del vendedor muestra un badge `🚗 Acepta raites`.

```
VARIANTE A — sin raite (sin cambio respecto a iter. 1)
┌─────────────────────────┐
│         MAPA            │
│      (oscurecido)       │
│  ╔═════════════════════╗│
│  ║  ━━━━━━━━━━         ║│  ← handle
│  ║  🛒  Vendedor #1    ║│
│  ║      📍 450 m       ║│
│  ║      🟢 Activo      ║│
│  ║  ─────────────────  ║│
│  ║  ┌─────────────────┐║│
│  ║  │Solicitar parada ║│║│  ← ElevatedButton primary (sin cambio)
│  ║  │    aquí   →     │║│
│  ║  └─────────────────┘║│
│  ║      Cancelar       ║│
│  ╚═════════════════════╝│
└─────────────────────────┘


VARIANTE B — con raite [iter. 2]
┌─────────────────────────┐
│         MAPA            │
│      (oscurecido)       │
│  ╔═════════════════════╗│
│  ║  ━━━━━━━━━━         ║│  ← handle (sin cambio)
│  ║  🛒  Vendedor #1    ║│
│  ║      📍 450 m       ║│
│  ║      🟢 Activo      ║│
│  ║      🚗 Acepta raites║│  ← ▶ NUEVO [iter. 2] Badge info
│  ║                     ║│    Chip: bg secondary-50, texto secondary-700
│  ║  ─────────────────  ║│
│  ║  ┌─────────────────┐║│
│  ║  │Solicitar parada ║│║│  ← Botón primario (sin cambio)
│  ║  │    aquí   →     │║│
│  ║  └─────────────────┘║│
│  ║                     ║│
│  ║  ┌─────────────────┐║│  ← ▶ NUEVO [iter. 2]
│  ║  │  🚗 Solicitar   ║│║│    ElevatedButton Secundario (outlined)
│  ║  │     raite  →    │║│    bg: secondary-50, borde secondary-700
│  ║  └─────────────────┘║│    texto: secondary-700
│  ║                     ║│    onPressed → abre W-RidePicker (pantalla nueva 5B'.1)
│  ║      Cancelar       ║│
│  ╚═════════════════════╝│
└─────────────────────────┘
```

**Propiedades del botón "Solicitar raite" [iter. 2]:**
- `OutlinedButton` con borde `secondary-700`, ícono `Icons.directions_car_outlined`
- `h: 52dp`, `radius: 12dp`, full-width
- Solo se renderiza cuando `vendor.rideEnabled == true`
- `onPressed`: cierra el bottom sheet → navega a `DestinationPickerScreen` (pantalla nueva, ver `SDD2_FASE5B_UBISAFE.md §5B'.1`) pasando `vendorUid` como argumento

**Widget Flutter [iter. 2] — condicional:**
```dart
// ▶ NUEVO [iter. 2] — dentro de StopRequestBottomSheet
if (vendor.rideEnabled) ...[
  const SizedBox(height: 12),
  OutlinedButton.icon(
    icon: const Icon(Icons.directions_car_outlined),
    label: const Text('Solicitar raite'),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.secondary700,
      side: BorderSide(color: AppColors.secondary700),
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    onPressed: () {
      Navigator.pop(context);
      context.push('/ride-request', extra: {'vendorUid': vendor.uid});
    },
  ),
],
```

---

## W-11b ext — Home Vendedor · Estado B extendido

**Base:** `W-11b` de `SDD_FASE5_UBISAFE.md` (GPS activo, radar inactivo)
**CU:** CU-04 — El perfil del vendedor ahora puede tener `rideEnabled` toggle.

### Cambio respecto a iter. 1

En este estado **no hay cambio visual directo** en el mapa. El único impacto de CU-04 en el estado B del vendedor es que, si `rideEnabled: true`, el texto del botón "Activar Visibilidad" puede incluir una indicación. Sin embargo, dado que el toggle de raites vive en el **Perfil** (W-19 ext), este estado queda igual salvo que se quiera añadir un indicador de estado del toggle.

**Decisión de diseño [iter. 2]:** No se modifica el wireframe base de W-11b. El toggle de raites se gestiona exclusivamente desde Mi Perfil (W-19 ext). En el mapa del vendedor se añade únicamente un **chip informativo** en la barra inferior cuando `rideEnabled: true`:

```
┌─────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░ │
├─────────────────────────┤
│ ☰  UBISAFE          🔔  │
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│  [MAPA GOOGLE MAPS]     │
│   (zonas de riesgo)     │
│                         │
│                         │
│─────────────────────────│
│  🚗 Raite activo        │  ← ▶ NUEVO [iter. 2] solo si rideEnabled: true
│  ┌─────────────────────┐│    Chip info bg secondary-50, texto secondary-700
│  │  👁  Activar        ││    aparece encima del botón, mismo contenedor
│  │     Visibilidad     ││    (sin cambio en el botón)
│  └─────────────────────┘│
│                      [+]│
└─────────────────────────┘

  [Si rideEnabled: false → la barra inferior es idéntica a iter. 1]
```

**Widget Flutter [iter. 2] — chip condicional:**
```dart
// ▶ NUEVO [iter. 2] — en la barra inferior de HomeVendedorEstadoB
if (profile.rideEnabled)
  Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Chip(
      avatar: const Icon(Icons.directions_car_outlined, size: 16),
      label: const Text('Raite habilitado'),
      backgroundColor: AppColors.secondary50,
      labelStyle: TextStyle(color: AppColors.secondary700, fontSize: 12),
    ),
  ),
```

---

## W-11c ext — Home Vendedor · Estado C extendido

**Base:** `W-11c` de `SDD_FASE5_UBISAFE.md` (Radar activo / MapViewV)
**CU:** CU-04 — El vendedor activo puede recibir solicitudes de raite además de paradas.

### Cambio respecto a iter. 1

En Estado C, el vendedor ya escucha solicitudes de parada (FCM `stop_request_incoming` → W-14). Ahora, si `rideEnabled: true`, también escucha `ride_request_incoming` → muestra **W-14b** (nuevo dialog, ver sección siguiente).

La barra inferior se extiende con el chip indicador de raite:

```
┌─────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░ │
├─────────────────────────┤
│ ☰  UBISAFE          🔔  │
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│  [MAPA GOOGLE MAPS]     │
│      ⊙  (yo)            │
│   [!HIGH]               │
│                         │
│                         │
│─────────────────────────│
│  ● Eres Visible  [Desact]│  ← sin cambio respecto a iter. 1
│  🚗 Raite activo        │  ← ▶ NUEVO [iter. 2] chip, solo si rideEnabled: true
│                      [+]│    mismo chip que en Estado B
└─────────────────────────┘
```

**Escucha FCM en este estado [iter. 2]:**
```dart
// ▶ NUEVO [iter. 2] — en MapScreenVendor / NotificationHandler
// El handler ya existente para stop_request_incoming se extiende:
if (message.data['type'] == 'ride_request_incoming' && profile.rideEnabled) {
  showDialog(context: context, builder: (_) => RideRequestDialog(
    rideId: message.data['rideId'],
    buyerName: message.data['buyerName'],
    pickupAddress: message.data['pickupAddress'],
    destinationAddress: message.data['destinationAddress'],
    distanceMeters: int.parse(message.data['distanceMeters']),
  ));
}
```

---

## W-14b — Dialog: Solicitud de Raite Entrante

**▶ COMPLETAMENTE NUEVO [iter. 2]**
**Tipo:** `Dialog` custom — mismo patrón que `W-14` (Solicitud de Parada Entrante) de iter. 1
**Aparece en:** Home Vendedor Estado C (cuando `rideEnabled: true`)
**Cuándo:** FCM `ride_request_incoming` → `showDialog`
**Widget:** `RideRequestDialog extends StatefulWidget`

### Diferencias clave respecto a W-14 (parada)

| Elemento | W-14 (parada, iter. 1) | W-14b (raite, iter. 2) |
|----------|------------------------|------------------------|
| Ícono encabezado | `notifications_active` primary-700 | `directions_car` secondary-700 |
| Título | "Nueva solicitud de parada" | "Solicitud de raite" |
| Datos mostrados | Dirección aprox + distancia | Punto de recogida + **destino final** + distancia |
| Timeout | 60s | **15s** (CA-04.3 del SRS) |
| Color del countdown | primary-700 | warning-700 (urgencia mayor) |
| Botón aceptar | secondary-700 | secondary-700 (igual) |
| Botón rechazar | danger-500 outlined | danger-500 outlined (igual) |

```
┌─────────────────────────┐
│         MAPA            │
│   (semi-oscurecido)     │
│                         │
│  ╔═════════════════════╗│  ← Dialog custom, radio 20dp (mismo que W-14)
│  ║  🚗 Solicitud       ║│  ← ▶ NUEVO [iter. 2]
│  ║     de raite        ║│    ícono: Icons.directions_car, 28dp, secondary-700
│  ║                     ║│    título: text-heading-2, neutral-900
│  ║  ─────────────────  ║│
│  ║  📍 Recogida:       ║│  ← ▶ NUEVO: dos ubicaciones (no solo una)
│  ║  Calle Roble #12    ║│    text-body-1, neutral-900
│  ║                     ║│
│  ║  🏁 Destino:        ║│  ← ▶ NUEVO [iter. 2]
│  ║  Mercado Central    ║│    Icon(Icons.flag_outlined), secondary-700
│  ║                     ║│    text-body-1, neutral-900
│  ║  📏 450 m de aquí   ║│  ← Distancia al punto de recogida
│  ║  (~2.1 km total)    ║│    ▶ NUEVO: distancia total del raite
│  ║                     ║│    text-body-2, neutral-600
│  ║  ─────────────────  ║│
│  ║  ⏱ Responde en 00:12║│  ← ▶ Countdown 15s (CA-04.3), warning-700
│  ║                     ║│    (no 60s como en W-14)
│  ║  ┌────────────────┐ ║│  ← ElevatedButton secondary-700 (igual que W-14)
│  ║  │    Aceptar     │ ║│    onPressed → POST /rides/{id}/accept
│  ║  └────────────────┘ ║│
│  ║                     ║│
│  ║  ┌────────────────┐ ║│  ← OutlinedButton danger-500 (igual que W-14)
│  ║  │    Rechazar    │ ║│    onPressed → POST /rides/{id}/reject
│  ║  └────────────────┘ ║│
│  ╚═════════════════════╝│
└─────────────────────────┘
  barrierDismissible: false
```

**Propiedades visuales:**
- Estructura del Dialog: idéntica a W-14 (`Dialog`, `radius: 20dp`, `insetPadding: h:24`)
- Ícono encabezado: `Icons.directions_car`, `28dp`, `secondary700`
- Countdown: `15s` (CA-04.3 exige respuesta en 15 segundos), `text-heading-2`, `warning700`
- Fila de datos ampliada: recogida + destino + distancia al punto de recogida + distancia total
- Botones: mismo estilo que W-14 (aceptar → `secondary700`, rechazar → `danger500`)

**Comportamiento:**
| Acción | Resultado |
|--------|-----------|
| "Aceptar" | `PATCH /rides/{id}` status: `accepted` + FCM `ride_accepted` al comprador → cierra dialog → HomeV pasa a estado Navegación Raite (pantalla nueva 5B'.1, ver `SDD2_FASE5B_UBISAFE.md`) |
| "Rechazar" | `PATCH /rides/{id}` status: `rejected` + FCM `ride_rejected` al comprador → cierra dialog → permanece en Estado C |
| Timer = 0 | Dialog se cierra automáticamente, `status: expired` → comprador recibe notificación de timeout |

---

## W-18 ext — Drawer extendido

**Base:** `W-18` de `SDD_FASE5_UBISAFE.md`
**CU:** CU-06 — Se añade entrada "Reportes activos" para acceder a la lista de reportes comunitarios.

### Cambio respecto a iter. 1

Se inserta un nuevo `ListTile` entre "Historial" y el `Divider` de "Cerrar sesión":

```
┌─────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░ │
│╔═══════════════╗        │
│║               ║        │  ← DrawerHeader sin cambio
│║  👤           ║        │
│║  Juan Pérez   ║        │
│║  +51 987654321║        │
│║  [Comprador]  ║        │
│╠═══════════════╣        │
│║               ║        │
│║ 👤 Mi perfil  ║        │  ← sin cambio
│║               ║        │
│║ 📋 Historial  ║        │  ← sin cambio
│║               ║        │
│║ 🛡 Reportes   ║        │  ← ▶ NUEVO [iter. 2]
│║    activos    ║        │    ListTile, Icon(Icons.shield_outlined)
│║          [N]  ║        │    trailing: Badge con contador de reportes sin validar
│║               ║        │    onTap → Navigator.push /community-reports
│║───────────────║        │  ← Divider (sin cambio)
│║               ║        │
│║ 🚪 Cerrar     ║        │  ← sin cambio
│║    sesión     ║        │
│╚═══════════════╝        │
└─────────────────────────┘
```

**Propiedades del nuevo ListTile [iter. 2]:**
- `Icon(Icons.shield_outlined)` como leading, color `secondary700`
- Título: `'Reportes activos'`, `text-body-large`
- Trailing: Badge con número de reportes `pending_validation` cercanos al usuario (obtenido de `communityReportsProvider`). Si 0 → no se muestra el badge.
- `onTap`: cierra Drawer → navega a `/community-reports` (pantalla nueva 5B'.3 de Miguel)

**Widget Flutter [iter. 2]:**
```dart
// ▶ NUEVO [iter. 2] — dentro del ListView del Drawer, entre Historial y Divider
ListTile(
  leading: const Icon(Icons.shield_outlined, color: AppColors.secondary700),
  title: const Text('Reportes activos'),
  trailing: pendingCount > 0
    ? Badge(
        label: Text('$pendingCount'),
        backgroundColor: AppColors.warning700,
        child: const SizedBox(width: 8),
      )
    : null,
  onTap: () {
    Navigator.pop(context);
    context.push('/community-reports');
  },
),
```

**Posición en el Drawer:**
```
Mi perfil
Historial
▶ Reportes activos  [iter. 2]
──────────────
Cerrar sesión
```

**Nota de accesibilidad [iter. 2]:** `semanticsLabel: 'Reportes activos, $pendingCount reportes pendientes de validación'` cuando el badge es visible; `'Reportes activos'` cuando no hay pendientes.

---

## W-19 ext — Mi Perfil extendido

**Base:** `W-19` de `SDD_FASE5_UBISAFE.md`
**CU:** CU-04 — Se añade toggle "Habilitar raites" **exclusivo para vendedores** (`role == VENDOR`).

### Cambio respecto a iter. 1

Se inserta una nueva sección de configuración entre el campo "Rol" y el `Divider` inferior. Solo visible cuando `profile.role == VENDOR`.

```
┌─────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░ │
│╔═══════════════════════╗│
│║ ← Mi Perfil           ║│  ← AppBar sin cambio
│╚═══════════════════════╝│
│         👤              │
│   Juan Pérez            │
│   [Vendedor]            │  ← Chip rol secondary-50 (sin cambio)
│─────────────────────────│
│ Nombre completo         │  ← sin cambio
│ Juan Pérez              │
│                         │
│ Teléfono                │  ← sin cambio
│ +51 987 654 321         │
│                         │
│ Rol                     │  ← sin cambio
│ Vendedor                │
│                         │
│─────────────────────────│  ← Divider nuevo (separa datos de configuración)
│                         │
│ Configuración           │  ← ▶ NUEVO [iter. 2] — sección solo VENDOR
│  de servicios           │    Label: text-body-small, neutral-500
│                         │    (oculto si role == BUYER)
│ ┌─────────────────────┐ │  ← ▶ NUEVO [iter. 2]
│ │ 🚗 Habilitar raites │ │    SwitchListTile
│ │                 [●] │ │    leading: Icon(Icons.directions_car_outlined)
│ └─────────────────────┘ │    title: "Habilitar raites"
│ Al activarlo, los       │    subtitle: texto explicativo
│ compradores podrán      │    value: profile.rideEnabled
│ solicitarte un raite.   │    onChanged: → PATCH /users/{uid} rideEnabled
│                         │
│─────────────────────────│  ← Divider inferior (sin cambio)
│ ┌─────────────────────┐ │
│ │  Cerrar sesión      │ │  ← OutlinedButton error-700 (sin cambio)
│ └─────────────────────┘ │
└─────────────────────────┘
```

**Propiedades del SwitchListTile [iter. 2]:**
- `leading`: `Icon(Icons.directions_car_outlined)`, `secondary700`
- `title`: `Text('Habilitar raites')`, `text-body-large`, `neutral-900`
- `subtitle`: `Text('Al activarlo, los compradores podrán solicitarte un raite.')`, `text-body-small`, `neutral-600`
- `value`: `profile.rideEnabled` (desde `userProfileProvider`)
- `activeColor`: `secondary700`
- `onChanged`: `(val) => ref.read(profileNotifierProvider.notifier).setRideEnabled(val)`
  - Internamente: `PATCH /users/{uid}` con `{ rideEnabled: val }` → actualiza Firestore → snackbar de confirmación

**Estados del toggle:**
| Estado | Descripción |
|--------|-------------|
| ON (verde) | El vendedor aparece con badge 🚗 en el bottom sheet del comprador (W-07 ext) |
| OFF (gris) | El vendedor no recibe solicitudes de raite aunque esté activo en el radar |

**Renderizado condicional:**
```dart
// ▶ NUEVO [iter. 2] — en ProfileScreen, después de los _InfoRow
if (profile.role == UserRole.vendor) ...[
  const Divider(height: 40),
  Text(
    'Configuración de servicios',
    style: bodySmall.copyWith(color: neutral500),
  ),
  const SizedBox(height: 12),
  SwitchListTile(
    secondary: const Icon(Icons.directions_car_outlined),
    title: const Text('Habilitar raites'),
    subtitle: const Text(
      'Al activarlo, los compradores podrán solicitarte un raite.'
    ),
    value: profile.rideEnabled,
    activeColor: AppColors.secondary700,
    onChanged: (val) =>
      ref.read(profileNotifierProvider.notifier).setRideEnabled(val),
  ),
],
```

**Tokens:**
- Sección label: `text-body-small` (12sp), `neutral-500`
- `SwitchListTile` height: ~72dp (2 líneas de texto en subtitle)
- Ícono leading: `secondary700`, 24dp
- Toggle activo: `secondary700` (mismo color que el rol de vendedor)

**Accesibilidad [iter. 2]:**
- `Semantics(label: 'Habilitar raites, ${profile.rideEnabled ? "activado" : "desactivado"}')` en el switch
- El cambio de estado emite un snackbar: `'Raites ${val ? "habilitados" : "deshabilitados"}'` — retroalimentación inmediata para usuarios con lector de pantalla

---

## W-20 ext — Historial de Actividad extendido

**Base:** `W-20` de `SDD_FASE5_UBISAFE.md`
**CU:** CU-04 — Se añade un tipo de ítem nuevo "Raite" al historial, y un filtro/tab para visualizarlo.

### Cambio respecto a iter. 1

Dos cambios sobre la pantalla de historial:

1. **▶ NUEVO [iter. 2] — Filtro por tipo de actividad:** Se añade una barra de `FilterChip`s en la parte superior de la lista para filtrar entre "Todo", "Paradas", "Raites" y "Reportes".

2. **▶ NUEVO [iter. 2] — Cards de Raite:** Nuevo tipo de card para entradas de tipo `ride`, con ícono 🚗 y los chips de estado correspondientes.

```
┌─────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░ │
│╔═══════════════════════╗│
│║ ← Historial           ║│  ← AppBar sin cambio
│╚═══════════════════════╝│
│                         │
│ [Todo][Paradas][Raites] │  ← ▶ NUEVO [iter. 2] FilterChips horizontales
│ [Reportes]              │    ScrollableRow, chip seleccionado: bg primary/secondary-700
│                         │    texto blanco; no seleccionado: bg neutral-100, texto neutral-700
│ ┌──────────────────────┐│  ← Card parada (sin cambio)
│ │🛒  Vendedor #2       ││
│ │    Solicitud aceptada ││
│ │    Hace 2 horas  [✅]││
│ └──────────────────────┘│
│                         │
│ ┌──────────────────────┐│  ← ▶ NUEVO [iter. 2] Card de Raite
│ │🚗  Raite completado  ││    leading: Icon(directions_car)
│ │    Mercado Central   ││    title: "Raite completado" / "Raite rechazado"
│ │    Hace 1 hora  [✅] ││    subtitle: nombre del destino + tiempo relativo
│ └──────────────────────┘│    trailing: Chip de estado (mismo sistema que paradas)
│                         │
│ ┌──────────────────────┐│  ← Card parada rechazada (sin cambio)
│ │🛒  Vendedor #1       ││
│ │    Solicitud rechazada│
│ │    Ayer · 14:32  [✕] ││
│ └──────────────────────┘│
│                         │
│ ┌──────────────────────┐│  ← Card reporte CU-03 (sin cambio)
│ │⚠️  Zona reportada    ││
│ │    Robo/Asalto        │
│ │    Hace 3 días   [📋] ││
│ └──────────────────────┘│
│                         │
└─────────────────────────┘
```

**Barra de filtros [iter. 2]:**
```dart
// ▶ NUEVO [iter. 2] — encima del ListView en HistoryScreen
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Row(
    children: HistoryFilter.values.map((filter) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(filter.label),   // "Todo", "Paradas", "Raites", "Reportes"
        selected: activeFilter == filter,
        onSelected: (_) => ref.read(historyFilterProvider.notifier).set(filter),
        selectedColor: isVendor ? secondary700 : primary700,
        labelStyle: TextStyle(
          color: activeFilter == filter ? Colors.white : neutral700,
        ),
      ),
    )).toList(),
  ),
),
```

**Tipos de card extendidos [iter. 2]:**

| Tipo | Ícono líder | Chip trailing | Color chip | CU |
|------|-------------|---------------|------------|----|
| Stop aceptada | 🛒 | ✅ Aceptada | `success-50`/`success-700` | CU-01 iter. 1 |
| Stop rechazada | 🛒 | ✕ Rechazada | `error-50`/`error-700` | CU-01 iter. 1 |
| Stop expirada | 🛒 | ⏱ Expirada | `warning-50`/`warning-700` | CU-01 iter. 1 |
| Zona reportada | ⚠️ | 📋 Reportada | `neutral-100`/`neutral-700` | CU-03 iter. 1 |
| **Raite completado** | 🚗 | ✅ Completado | `success-50`/`success-700` | **CU-04 iter. 2** |
| **Raite rechazado** | 🚗 | ✕ Rechazado | `error-50`/`error-700` | **CU-04 iter. 2** |
| **Raite cancelado** | 🚗 | ✕ Cancelado | `error-50`/`error-700` | **CU-04 iter. 2** |

**Datos del card de raite [iter. 2]:**
- `title`: `'Raite completado'` / `'Raite rechazado'` / `'Raite cancelado'`
- `subtitle` línea 1: destino del raite (ej. `'Mercado Central'`)
- `subtitle` línea 2: tiempo relativo (ej. `'Hace 1 hora'`)
- `trailing`: Chip de estado (mismo sistema de colores que los stops)

**Provider extendido [iter. 2]:**
```dart
// ▶ NUEVO [iter. 2] — extensión de historyProvider
// El endpoint GET /history devuelve ahora también entradas de tipo 'ride'
// El provider ya existente se adapta para parsear el nuevo tipo.
// Se añade historyFilterProvider para el estado del chip seleccionado.
final historyFilterProvider = StateProvider<HistoryFilter>(
  (ref) => HistoryFilter.all,
);

enum HistoryFilter {
  all('Todo'),
  stops('Paradas'),
  rides('Raites'),
  reports('Reportes');

  const HistoryFilter(this.label);
  final String label;
}
```

**Estado vacío por filtro [iter. 2]:**
Si el filtro activo no tiene resultados, el empty state muestra un ícono y texto específico:
- Filtro "Raites" sin datos: `Icon(Icons.directions_car_outlined, 64dp, neutral-300)` + `'Sin raites aún'`
- Filtro "Paradas" sin datos: ícono `🛒` + `'Sin paradas aún'`

---

## Resumen de cambios [iter. 2]

| Wireframe base (iter. 1) | ID extensión | Cambio principal | CU |
|--------------------------|--------------|------------------|-----|
| W-06b — Home Comprador | W-06b ext | Polígonos de focos de infección en mapa | CU-05 |
| W-07 — Bottom Sheet Vendedor | W-07 ext | Botón "Solicitar raite" condicional | CU-04 |
| W-11b — Home Vendedor B | W-11b ext | Chip "Raite activo" en barra inferior | CU-04 |
| W-11c — Home Vendedor C | W-11c ext | Chip "Raite activo" + escucha FCM ride_request | CU-04 |
| — *(pantalla nueva)* | W-14b | Dialog "Solicitud de Raite Entrante" (15s timeout) | CU-04 |
| W-18 — Drawer | W-18 ext | ListTile "Reportes activos" con badge contador | CU-06 |
| W-19 — Mi Perfil | W-19 ext | SwitchListTile "Habilitar raites" (solo VENDOR) | CU-04 |
| W-20 — Historial | W-20 ext | FilterChips + nuevo tipo card "Raite" | CU-04 |

---

## Handoff para Miguel

**Qué debes recibir de este archivo para Fase 5C' (mockups):**
- El layout de W-19 ext (Perfil con toggle) es candidato a mockup por ser la única pantalla con elemento de configuración nuevo.
- W-14b (Dialog de raite) requiere mockup propio al ser distinto a W-14.
- Para el resto de extensiones (polígonos en mapa, chips en barras inferiores, Drawer), los mockups de iter. 1 sirven como base y se anotan las diferencias.

**Archivos que este output consume:**
- `SDD_FASE5_UBISAFE.md` (wireframes iter. 1)
- `BB_SRS_V2.1.md` (CU-04/05/06)

**Archivos que este output produce:**
- `SDD2_FASE5Balt_UBISAFE.md` ← este archivo

---

*Fase 5B.alt' completada: 25/04/2026 — Los Borbotones / UBISAFE Iteración 2*
*Responsable: 🟦 Alexis Córdova*
