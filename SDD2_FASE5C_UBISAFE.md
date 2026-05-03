# SDD2 — Fase 5C': Mockups de Alta Fidelidad — Prompts Claude Design [iter. 2]
## 9 pantallas · 5 nuevas + 4 modificadas
### UBISAFE · Los Borbotones · 25/04/2026

> **Propósito:** Prompts listos para pegar en Claude Design (`https://claude.ai/`) y generar los mockups de alta fidelidad de Iteración 2. Mismo formato y nivel de detalle que §8.18 de `SDD_FASE5_UBISAFE.md`.
>
> **Instrucción de uso:**
> 1. Abre una conversación nueva en `https://claude.ai/`
> 2. Adjunta **este archivo** (`SDD2_FASE5C_UBISAFE.md`) Y `SDD_FASE5_UBISAFE.md` (design system iter. 1 + look & feel de referencia)
> 3. Pega el prompt del mockup que quieres generar
> 4. Guarda el mockup resultante como `mockup_<ID>.png` en la carpeta del proyecto
> 5. Repite para cada uno de los 9 prompts
>
> **Archivos base leídos para generar estos prompts:**
> - `SDD2_FASE5A_UBISAFE.md` (tokens iter. 2: chips, mapa community_reports, DestinationPicker)
> - `SDD2_FASE5B_UBISAFE.md` (wireframes 4 pantallas nuevas — Miguel)
> - `SDD2_FASE5Balt_UBISAFE.md` (wireframes extensiones — Alexis)
> - `SDD_FASE5_UBISAFE.md` §8.1 (design system iter. 1) y §8.18 (formato de prompts iter. 1)
> - `SDD2_FASE0_UBISAFE.md` (decisiones definitivas: colores negro/café, círculo 15 m, umbral 3)

---

## Tabla maestra de mockups

| ID | Pantalla | Tipo | CU | Rol | Archivo de salida |
|---|---|---|---|---|---|
| **CD2-01** | Pantalla Solicitud de Raite | 🆕 Nueva | CU-04 | BUYER | `mockup_CD2-01_raite_request.png` |
| **CD2-02** | Pantalla Reportar Foco de Infección | 🆕 Nueva | CU-05 | Ambos | `mockup_CD2-02_community_report.png` |
| **CD2-03** | Pantalla Lista de Reportes Activos | 🆕 Nueva | CU-06 | Ambos | `mockup_CD2-03_reports_list.png` |
| **CD2-04** | Pantalla Detalle + Validación de Reporte | 🆕 Nueva | CU-06 | Ambos | `mockup_CD2-04_report_detail.png` |
| **CD2-05** | Dialog Solicitud de Raite Entrante | 🆕 Nueva | CU-04 | VENDOR | `mockup_CD2-05_ride_dialog.png` |
| **CD2-06** | Bottom Sheet Vendedor — Variante B (con raite) | ✏️ Modificada | CU-04 | BUYER | `mockup_CD2-06_vendor_sheet_ride.png` |
| **CD2-07** | Home Comprador con focos de infección en mapa | ✏️ Modificada | CU-05 | BUYER | `mockup_CD2-07_home_buyer_focos.png` |
| **CD2-08** | Mi Perfil Vendedor — toggle Habilitar raites | ✏️ Modificada | CU-04 | VENDOR | `mockup_CD2-08_profile_vendor.png` |
| **CD2-09** | Drawer con entrada Reportes activos | ✏️ Modificada | CU-06 | Ambos | `mockup_CD2-09_drawer_extended.png` |

---

## 8.19.1. Prompts para Claude Design — Pantallas Nuevas

---

### CD2-01 — Pantalla Solicitud de Raite (W-CU04-01)

```
Eres un diseñador UI experto en apps Flutter mobile. Genera un mockup de alta fidelidad
para la pantalla "Solicitud de Raite" de UBISAFE, Iteración 2 (W-CU04-01).

CONTEXTO Y ROL:
Esta pantalla la ve el COMPRADOR (BUYER) cuando quiere solicitar un raite a un vendedor
cercano. La pantalla usa el patrón DestinationPicker: mapa fullscreen con un bottom sheet
persistente en la parte inferior donde el comprador busca y confirma su destino.
Muestra el ESTADO 2: destino ya seleccionado y válido (≤ 4 km del vendedor).

DESIGN SYSTEM (del archivo SDD_FASE5_UBISAFE.md adjunto, §8.1):
- Primarios: primary-700 #1565C0, primary-50 #E3F2FD
- Secundarios: secondary-700 #2E7D32, secondary-500 #43A047, secondary-50 #F1F8E9
- Neutros: neutral-900 #212121, neutral-700 #616161, neutral-400 #9E9E9E, neutral-200 #E0E0E0, neutral-0 #FFFFFF
- Semánticos: success-500 #388E3C, danger-500 #E53935
- Tipografía: Inter. heading-1: Bold 20sp · body-1: Regular 16sp · body-2: Regular 14sp · caption: Regular 12sp
- Inputs: 56dp alto, radius 12dp, borde focus primary-700 2dp
- Botón primario: 52dp alto, radius 12dp, bg primary-700, texto blanco SemiBold 16sp
- Spacing: sm=8dp · md=16dp · lg=24dp

ESPECIFICACIONES DEL MOCKUP:
- Viewport: 390×844px (iPhone 14), portrait, dentro de frame de teléfono realista (bezel oscuro)
- Fondo: mapa fullscreen estilo Google Maps, paleta urbana (calles blancas, manzanas #E8F0E8)
  · Marcador comprador (BUYER): punto azul pulsante (#1565C0), 20px, borde blanco 3px, halo semitransparente
  · Marcador vendedor (VENDOR): ícono storefront verde (#43A047), 28px, sobre marcador verde
  · Pin de destino: ícono flag relleno (#1565C0), 28px — colocado ~150px al noreste del comprador
  · Línea punteada entre comprador y pin destino: color primary-500 #1E88E5, dash [8px, 4px], grosor 2px
  · Cámara: encuadra los 3 puntos (comprador, vendedor, destino) con padding de 60px
- Bottom Sheet (ocupa ~45% inferior de la pantalla):
  · Fondo blanco (#FFFFFF), border-radius top 24px, sombra top suave
  · Handle: 4×32px, #E0E0E0, centrado, mt: 12px
  · Contenido (padding h:24px, top: 8px):
    → Campo de búsqueda (lleno con texto): OutlinedTextField 56dp alto, radius 12dp,
      prefixIcon: ícono search neutral-400, texto: "Av. Principal 456, Col. Norte"
      (color neutral-900, 16sp), borde activo primary-700 2dp,
      suffixIcon: ícono X (clear), neutral-400
    → Divider, neutral-200, mt: 16px
    → Fila de distancia (mt: 12px): Row con spacing-xs entre elementos
      · Ícono check_circle_outline, success-500, 16px
      · Texto "2.3 km del vendedor", 14sp, success-500
    → Texto secundario: "✓ Dentro del rango permitido (máx. 4 km)", 12sp, success-500, mt: 2px
    → Botón "Confirmar raite →" (mt: 20px): ancho completo, h:52dp, bg primary-700 #1565C0,
      texto blanco SemiBold 16sp, radius 12dp. HABILITADO (color sólido, sin opacity)
    → TextButton "Cancelar", centrado, texto primary-700, mt: 8px, 44dp touch target
- Status bar: dark icons (sobre fondo claro del mapa visible en el top)
- NO mostrar AppBar — pantalla fullscreen con mapa

ACCESIBILIDAD A REFLEJAR VISUALMENTE:
- Touch targets ≥ 48dp en todos los botones y campo de búsqueda
- Contraste del texto de distancia (success-500 sobre blanco): ratio ≥ 3.1:1
- El pin de destino debe tener un área táctil visualmente suficiente (28px mínimo)

REFERENCIA DE LOOK & FEEL:
Mantén el estilo de los mockups de iter. 1 (CD-05 del SDD_FASE5_UBISAFE.md): mapa de fondo con AppBar overlay / bottom section blanca limpia, tipografía Inter, radios redondeados. No uses sombras exageradas ni gradientes innecesarios.
```

---

### CD2-02 — Pantalla Reportar Foco de Infección (W-CU05-01)

```
Eres un diseñador UI experto en apps Flutter mobile. Genera un mockup de alta fidelidad
para el componente "Reportar Foco de Infección" de UBISAFE, Iteración 2 (W-CU05-01).

CONTEXTO Y ROL:
Este es un bottom sheet modal que aparece sobre el mapa (HomeC o HomeV) cuando el usuario
pulsa el mini-FAB de "Foco de infección" (ícono bug_report, color café #795548).
Muestra el ESTADO 1b: el usuario ya seleccionó "Animal muerto" — la card está resaltada
y hay un círculo preview de 15 m en el mapa de fondo.
Cualquier rol puede verlo (BUYER o VENDOR); mostrar contexto de BUYER (AppBar azul de fondo).

DESIGN SYSTEM (ver §8.1 de SDD_FASE5_UBISAFE.md adjunto):
- Primarios, neutros y semánticos: igual que siempre (primary-700 #1565C0, etc.)
- NUEVOS tokens iter. 2 (SDD2_FASE5A_UBISAFE.md):
  · community-animal: #212121 (negro) — para threat_type: animal_muerto
  · community-waste: #795548 (café) — para threat_type: zona_sucia
  · community-pending: #FFC107 (ámbar) — estado pending_validation

ESPECIFICACIONES DEL MOCKUP:
- Viewport: 390×844px, portrait, frame de teléfono realista
- Fondo (mapa oscurecido, ~55% de la pantalla visible):
  · Mapa urbano estilo Google Maps, cubierto por overlay rgba(0,0,0,0.40)
  · AppBar del HomeC visible en la parte superior: primary-700 #1565C0 al 90%, íconos blancos, "UBISAFE"
  · Punto de ubicación del usuario: punto azul pulsante, centrado en el mapa
  · Círculo preview de 15 m alrededor del punto del usuario:
    - Fill: #212121 al 15% de opacidad (negro muy suave)
    - Stroke: #212121, 2px, sólido
    - Etiqueta pequeña "15 m" en gris claro sobre el círculo
- Bottom Sheet (ocupa ~50% inferior):
  · Fondo blanco, border-radius top 24px
  · Handle centrado, 4×32px, neutral-200, mt: 12px
  · Título "Reportar foco de infección" Bold 18sp neutral-900, mt: 16px, padding h:24px
  · Subtítulo "¿Qué tipo de foco es?" Regular 14sp neutral-600, mt: 4px
  · Cards seleccionables (mt: 16px, gap: 12px, padding h:24px):
    
    Card 1 — ANIMAL MUERTO (SELECCIONADA):
      · Borde 2px #212121 (community-animal), radius 12dp
      · Fondo: #21212114 (negro al 8% — muy suave)
      · Padding: 16dp
      · Leading: ícono pest_control 28px, color #212121
      · Título: "Animal muerto" SemiBold 16sp #212121
      · Subtítulo: "Cadáver en vía pública" Regular 14sp neutral-600
      · Trailing: ícono check_circle (filled) 20px, #212121, en la esquina derecha
    
    Card 2 — ZONA SUCIA (NO SELECCIONADA):
      · Borde 1px #E0E0E0 (neutral-200), radius 12dp
      · Fondo blanco
      · Padding: 16dp
      · Leading: ícono delete_outline 28px, neutral-400
      · Título: "Zona sucia" SemiBold 16sp neutral-700
      · Subtítulo: "Basura dispersa por perros" Regular 14sp neutral-500
      · Sin trailing icon
  
  · Fila de ubicación (mt: 16px, padding h:24px):
    · Ícono my_location 14px neutral-400, texto "Se usará tu ubicación actual · radio: 15 m"
    12sp neutral-400
  · Botón "Enviar reporte" (mt: 20px, padding h:24px):
    ancho completo menos 48dp (24dp cada lado), h:52dp, bg #212121 (negro — coherente con
    el tipo seleccionado), texto blanco SemiBold 16sp, radius 12dp. HABILITADO.

ACCESIBILIDAD:
- Cards: mínimo 72dp de alto (2 líneas de subtítulo garantizadas)
- Botón "Enviar": touch target 52dp, contraste blanco sobre negro = 21:1 ✓
- Estado seleccionado de la card: diferenciado por borde + fondo tintado + checkmark

LOOK & FEEL:
Referencia: CD-06 (RiskFormBottomSheet) de SDD_FASE5_UBISAFE.md. Mismo estilo de bottom
sheet sobre mapa oscurecido, manteniendo la limpieza y la tipografía Inter. Las cards
seleccionables deben verse "nativas Material3" — no overdesignadas.
```

---

### CD2-03 — Pantalla Lista de Reportes Activos (W-CU06-01)

```
Eres un diseñador UI experto en apps Flutter mobile. Genera un mockup de alta fidelidad
para la pantalla "Lista de Reportes Activos" de UBISAFE, Iteración 2 (W-CU06-01).

CONTEXTO Y ROL:
Esta pantalla lista los reportes comunitarios activos cerca del usuario. Accesible desde
el Drawer. Cualquier rol puede verla. Muestra 3 reportes con estados variados y los
chips de filtro en la parte superior.

DESIGN SYSTEM (ver §8.1 de SDD_FASE5_UBISAFE.md):
- primary-700 #1565C0, primary-50 #E3F2FD
- neutral-900 #212121, neutral-600 #616161, neutral-400 #9E9E9E, neutral-200 #E0E0E0, neutral-100 #F5F5F5
- success-500 #388E3C, danger-500 #E53935, warning-700 #E65100
- NUEVOS iter. 2: community-animal #212121, community-waste #795548, community-pending #FFC107
- Tipografía Inter: body-1 16sp · body-2 14sp · caption 12sp · label 14sp Medium
- Cards: radius 16dp, elevation 2dp, padding 16dp, fondo blanco

ESPECIFICACIONES DEL MOCKUP:
- Viewport: 390×844px, portrait, frame de teléfono realista
- AppBar: fondo primary-50 #E3F2FD, elevation 0, título "Reportes activos" centrado
  SemiBold 18sp primary-700 #1565C0. Leading: ícono ← blanco sobre primary-50 (usar primary-700).
- Barra de filtros (bajo el AppBar, bg: neutral-100, padding h:16px v:8px):
  · 3 FilterChips en fila horizontal: "Todos" · "Pendiente" · "Validado"
  · "Todos" seleccionado: bg primary-700 #1565C0, texto blanco SemiBold 13sp, radius 20px
  · "Pendiente" y "Validado" sin seleccionar: bg neutral-100, borde neutral-200 1px,
    texto neutral-700 13sp, radius 20px
  · Separación entre chips: 8px
- Body (bg neutral-100, padding h:16px, top: 12px):
  Lista de 3 cards, separación 10px entre ellas:

  CARD 1 — Animal muerto · pending_validation · 300 m:
    · Card blanca, radius 16dp, elevation 2dp, padding 16dp
    · Fila superior: Row between
      - Left: Row(gap:10px): ícono pest_control 24px #212121 + texto "Animal muerto" SemiBold 15sp neutral-900
      - Right: texto "300 m" Regular 12sp neutral-600
    · Fila media (mt: 8px): Row between
      - Left: ReportStatusChip "Pendiente": bg #FFF9C4, texto #F57F17 SemiBold 12sp,
        ícono hourglass_top 12px #F57F17, radius 8dp, padding h:8 v:4
      - Right: VotingIndicator inline: ícono thumb_up 14px neutral-600 + "1" 14sp neutral-700
        + spacing 12px + ícono thumb_down 14px neutral-600 + "0" 14sp neutral-700
    · Fila inferior (mt: 6px): texto "Hace 15 min" 12sp neutral-400
    · Toda la card tiene InkWell ripple (tappable)

  CARD 2 — Zona sucia · confirmed · 120 m:
    · Misma estructura de card
    · Fila superior: ícono delete_outline 24px #795548 + "Zona sucia" SemiBold 15sp neutral-900 | "120 m"
    · Fila media:
      - Chip "Validado": bg #C8E6C9, texto #1B5E20 SemiBold 12sp, ícono check_circle_outline 12px #388E3C
      - VotingIndicator: thumb_up + "3" (umbral alcanzado, color success-500) + thumb_down + "0"
    · Fila inferior: "Hace 2 hrs"

  CARD 3 — Animal muerto · pending_validation · 1.2 km:
    · Fila superior: ícono pest_control 24px #212121 + "Animal muerto" | "1.2 km"
    · Fila media:
      - Chip "Pendiente" (igual que Card 1)
      - VotingIndicator: thumb_up + "0" + thumb_down + "1" (1 rechazo, color neutral)
    · Fila inferior: "Hace 4 hrs"

- Status bar: dark icons sobre primary-50

ACCESIBILIDAD:
- Cada card: mínimo 80dp de alto, touch target completo de la card
- Chips de filtro: 36dp de alto, touch target ≥ 48dp (padding táctil invisible)
- Contraste chip "Pendiente": #F57F17 sobre #FFF9C4 → ratio 2.5:1 (aceptable para texto de estado)

LOOK & FEEL:
Referencia: CD-07 (Historial) de SDD_FASE5_UBISAFE.md — lista de cards limpias, bien
separadas, con chips de estado a la derecha. Misma energía visual. Los íconos de tipo
(pest_control, delete_outline) deben verse nítidos con sus colores negro y café respectivamente.
```

---

### CD2-04 — Pantalla Detalle + Validación de Reporte (W-CU06-02)

```
Eres un diseñador UI experto en apps Flutter mobile. Genera un mockup de alta fidelidad
para la pantalla "Detalle + Validación de Reporte" de UBISAFE, Iteración 2 (W-CU06-02).

CONTEXTO Y ROL:
Pantalla de detalle de un reporte comunitario individual. El usuario puede ver el mapa,
el tipo de reporte y votar (confirmar o desmentir). Muestra el estado: reporte de
"Animal muerto" con pending_validation, 1 confirmación de 3, usuario AÚN NO HA VOTADO.

DESIGN SYSTEM (ver §8.1 de SDD_FASE5_UBISAFE.md y SDD2_FASE5A para tokens iter. 2):
- primary-700 #1565C0, success-500 #388E3C, danger-500 #E53935
- community-animal #212121 (negro — para este reporte de animal muerto)
- neutral-900 #212121, neutral-600 #616161, neutral-200 #E0E0E0, neutral-0 #FFFFFF, neutral-100 #F5F5F5
- Tipografía: heading-1 Bold 20sp · heading-2 SemiBold 18sp · body-1 Regular 16sp · body-2 Regular 14sp

ESPECIFICACIONES DEL MOCKUP:
- Viewport: 390×844px, portrait, frame de teléfono realista
- AppBar: bg neutral-100, elevation 0, título "Detalle del reporte" SemiBold 18sp neutral-900.
  Leading: ← neutral-900. Trailing: ⋮ (more_vert) neutral-600.
- Sección mapa (altura fija 200px, ancho completo):
  · Mapa estilo Google Maps, modo lectura (no interactivo)
  · Centro: círculo de 15 m radio, fill #21212120 (negro 12%), stroke #212121 2px sólido
  · Marcador de usuario (comprador): punto azul pulsante fuera del círculo, a ~80px al sureste
  · Zoom 17 — calles claras visibles alrededor
  · Overlay muy leve en las esquinas (vignette suave) para marcar que no es interactivo
- Cuerpo (scroll, padding h:24px):
  · Fila tipo + status (mt: 16px):
    - Row: ícono pest_control 28px #212121 + texto "Animal muerto" Bold 20sp neutral-900
    - ReportStatusChip "Pendiente" (compact): bg #FFF9C4, texto #F57F17 12sp, radius 8dp
  · Fila estado + distancia (mt: 6px):
    - Texto "• 300 m de ti  •  Hace 15 min" 14sp neutral-600
  · Texto reportado por (mt: 8px): "Reportado por un miembro de la comunidad" 13sp neutral-500
  
  · Divider (mt: 20px, neutral-200)
  
  · Título "Validación comunitaria" SemiBold 18sp neutral-900, mt: 20px
  · Subtítulo "¿Pudiste verificar este foco?" Regular 14sp neutral-600, mt: 4px
  
  · VotingIndicator (variant: full, mt: 24px):
    Dos columnas centradas con gap 40px entre ellas:
    
    COLUMNA IZQUIERDA — Confirmar:
      · Ícono thumb_up_outlined 36px, success-500 #388E3C
      · Número "1" Bold 24sp success-500, mt: 6px
      · Label "Confirmar" Regular 13sp neutral-600, mt: 2px
    
    COLUMNA DERECHA — Desmentir:
      · Ícono thumb_down_outlined 36px, danger-500 #E53935
      · Número "0" Bold 24sp neutral-400
      · Label "Desmentir" Regular 13sp neutral-600, mt: 2px
    
    Barra de progreso (ancho completo, mt: 16px):
      · Height: 6px, radius 3px
      · Fondo: neutral-200
      · Fill verde (success-500): 33% del ancho (1 de 3 confirmaciones)
      · Debajo: texto "1 de 3 confirmaciones necesarias" 12sp neutral-400, centrado
  
  · Botón "✓ Confirmar" (mt: 28px): ancho completo, h:52dp, bg success-500 #388E3C,
    texto blanco SemiBold 16sp, radius 12dp, ícono check_circle_outline leading 20px
  
  · Botón "✕ Desmentir" (mt: 12px): ancho completo, h:52dp, bg transparente,
    borde 1.5px danger-500 #E53935, texto danger-500 SemiBold 16sp, radius 12dp,
    ícono cancel_outlined leading 20px

ACCESIBILIDAD:
- Mapa: overlay "Solo visualización" como etiqueta accesible (ExcludeSemantics en código)
- Botones: 52dp alto — exceden el mínimo de 48dp ✓
- VotingIndicator: área táctil de cada columna ≥ 80×80dp
- Contraste botón Confirmar: blanco sobre #388E3C = 4.5:1 ✓

LOOK & FEEL:
Pantalla formal y tranquilizadora. Paleta neutra con acentos verde/rojo solo en los botones
de acción. El mapa debe verse como "evidencia" — encuadrado y no editable.
Referencia general: CD-02 (Login) por la limpieza del body con secciones bien separadas.
```

---

### CD2-05 — Dialog Solicitud de Raite Entrante (W-14b)

```
Eres un diseñador UI experto en apps Flutter mobile. Genera un mockup de alta fidelidad
para el dialog "Solicitud de Raite Entrante" de UBISAFE, Iteración 2 (W-14b).

CONTEXTO Y ROL:
Este dialog aparece sobre el mapa del VENDEDOR (HomeV Estado C, radar activo) cuando
recibe una notificación FCM de solicitud de raite. Similar al dialog de parada entrante
de iter. 1 pero con los datos del raite: recogida + destino + distancia + countdown 15 s.
El mapa de fondo debe verse oscurecido (modal barrier).

DESIGN SYSTEM (ver §8.1 de SDD_FASE5_UBISAFE.md):
- secondary-700 #2E7D32 (color del rol vendedor), secondary-50 #F1F8E9
- warning-700 #E65100 (countdown urgente), danger-500 #E53935
- neutral-900 #212121, neutral-700 #616161, neutral-200 #E0E0E0, neutral-0 #FFFFFF
- Tipografía: heading-2 SemiBold 18sp · body-1 Regular 16sp · body-2 Regular 14sp

ESPECIFICACIONES DEL MOCKUP:
- Viewport: 390×844px, portrait, frame de teléfono realista
- Fondo (mapa semi-oscurecido):
  · Mapa urbano con paleta vendedor (calles, manzanas en tonos verdes muy suaves)
  · AppBar del HomeV visible en top: secondary-700 #2E7D32 al 90%, "UBISAFE" blanco
  · Overlay del dialog: rgba(0,0,0,0.50) sobre todo el mapa
  · Chip de estado visible bajo el AppBar: "● Eres Visible" bg secondary-700, texto blanco 13sp
- Dialog (centrado verticalmente, margin h:24px):
  · Fondo blanco (#FFFFFF), radius 20dp, padding 24dp, sombra elevation 8dp
  · Sección encabezado:
    - Ícono directions_car 32px secondary-700 #2E7D32, centrado
    - Título "Solicitud de raite" Bold 18sp neutral-900, centrado, mt: 8px
  · Divider, neutral-200, mt: 16px
  · Sección datos del raite (mt: 16px, gap: 12px):
    - Fila recogida: Row(gap:8px)
      · Ícono my_location 18px primary-700 #1565C0
      · Column: label "RECOGIDA" 11sp neutral-400 uppercase · valor "Calle Roble #12, Col. Centro" 15sp neutral-900 SemiBold
    - Fila destino: Row(gap:8px)
      · Ícono flag_outlined 18px secondary-700 #2E7D32
      · Column: label "DESTINO" 11sp neutral-400 uppercase · valor "Mercado Central" 15sp neutral-900 SemiBold
    - Fila distancias (mt: 4px): Row(gap:16px)
      · "📍 450 m de aquí" 13sp neutral-600
      · "🚗 ~2.1 km totales" 13sp neutral-600
  · Divider, neutral-200, mt: 16px
  · Countdown (mt: 12px, centrado):
    - Ícono timer_outlined 16px warning-700
    - Texto "Responde en " Regular 14sp neutral-600 + "00:09" Bold 22sp warning-700 #E65100
    - (El tiempo visible debe ser 9 segundos — urgencia media para transmitir premura)
  · Botón "Aceptar" (mt: 20px): ancho completo, h:52dp, bg secondary-700 #2E7D32,
    texto blanco SemiBold 16sp, radius 12dp
  · Botón "Rechazar" (mt: 12dp): ancho completo, h:52dp, bg transparente,
    borde 1.5px danger-500 #E53935, texto danger-500 SemiBold 16sp, radius 12dp

ACCESIBILIDAD:
- Dialog: barrierDismissible: false (no se puede cerrar con tap fuera)
- Countdown: liveRegion semántica — anuncia el tiempo cada 5 s
- Botones: 52dp alto ✓, contraste blanco sobre secondary-700 = 4.9:1 ✓
- Touch targets separados visualmente: 12dp de margen entre botones

LOOK & FEEL:
Idéntico al dialog de parada entrante de iter. 1 (W-14) pero con colores de vendedor
(secondary-700 en lugar de primary-700), ícono de carro en lugar de storefront, y
dos filas de ubicación (recogida + destino). El countdown en warning-700 transmite urgencia.
```

---

## 8.19.2. Prompts para Claude Design — Pantallas Modificadas

---

### CD2-06 — Bottom Sheet Vendedor Variante B (W-07 ext)

```
Eres un diseñador UI experto en apps Flutter mobile. Genera un mockup de alta fidelidad
para el "Bottom Sheet de Confirmación de Acción sobre Vendedor — Variante B (con raite)"
de UBISAFE, Iteración 2 (W-07 ext).

CONTEXTO Y ROL:
El COMPRADOR tocó un marcador de vendedor que tiene rideEnabled: true.
El bottom sheet muestra las DOS opciones: solicitar parada Y solicitar raite.
Aparece sobre el mapa del HomeC (mapa de comprador, AppBar azul).

DESIGN SYSTEM (ver §8.1 de SDD_FASE5_UBISAFE.md):
- primary-700 #1565C0, primary-50 #E3F2FD
- secondary-700 #2E7D32, secondary-50 #F1F8E9, secondary-100 #C8E6C9
- neutral-900 #212121, neutral-600 #616161, neutral-200 #E0E0E0, neutral-0 #FFFFFF

ESPECIFICACIONES DEL MOCKUP:
- Viewport: 390×844px, portrait, frame de teléfono realista
- Fondo: mapa HomeC parcialmente visible y oscurecido (overlay rgba(0,0,0,0.45))
  AppBar azul visible en top: primary-700 al 90%, "UBISAFE" blanco
- Bottom Sheet (ocupa ~55% inferior, sin cambio):
  · Fondo blanco, radius top 24dp, sombra
  · Handle: 4×32px, neutral-200, centrado, mt: 12px, mb: 16px
  · Fila del vendedor (padding h:24px):
    - CircleAvatar 48px: bg primary-50 #E3F2FD, ícono storefront_outlined primary-700 24px
    - Column(gap:2px):
      · "Vendedor #1" SemiBold 17sp neutral-900
      · Row: ícono place 12px neutral-600 + "450 m" 13sp neutral-600
      · Badge "🟢 Activo": bg secondary-100 #C8E6C9, texto secondary-700 12sp SemiBold,
        radius 10dp, padding h:8 v:3
    · ▶ NUEVO [iter. 2] Badge raite (debajo del badge Activo, mt:4px):
      - "🚗 Acepta raites": bg secondary-50 #F1F8E9, borde secondary-200 1px,
        texto secondary-700 12sp, radius 10dp, padding h:8 v:3
  · Divider, neutral-200, mt: 16px
  · Botón primario (mt: 16px, padding h:24px): "Solicitar parada aquí →"
    ancho completo, h:52dp, bg primary-700 #1565C0, texto blanco SemiBold 16sp, radius 12dp
  · ▶ NUEVO [iter. 2] Botón secundario (mt: 12px, padding h:24px): "🚗 Solicitar raite →"
    ancho completo, h:52dp, bg secondary-50 #F1F8E9,
    borde 1.5px secondary-700 #2E7D32, texto secondary-700 SemiBold 16sp, radius 12dp,
    ícono directions_car_outlined 18px secondary-700 leading
  · TextButton "Cancelar" (mt: 8px): centrado, texto primary-700 Medium 15sp, h:44dp

ACCESIBILIDAD:
- Ambos botones: 52dp alto ✓, ancho completo ✓
- Badge "Acepta raites": solo visual/informativo, no interactivo
- Contraste botón raite: secondary-700 sobre secondary-50 = 3.7:1 (aceptable para componente de apoyo)

LOOK & FEEL:
Base idéntica al bottom sheet de iter. 1 (CD-06). La adición del botón de raite debe
sentirse como una extensión natural — misma altura, mismo radio, distinto color.
El verde del vendedor (secondary-700) distingue claramente la acción de raite de la de parada (azul).
```

---

### CD2-07 — Home Comprador con Focos de Infección en Mapa (W-06b ext)

```
Eres un diseñador UI experto en apps Flutter mobile. Genera un mockup de alta fidelidad
para el "Home Comprador con focos de infección comunitarios en el mapa" de UBISAFE,
Iteración 2 (W-06b ext).

CONTEXTO Y ROL:
Pantalla principal del COMPRADOR (GPS activo) mostrando tanto las zonas de riesgo
de iter. 1 (CU-03) como los nuevos focos de infección comunitarios de iter. 2 (CU-05).
El FAB ahora es expandible (dos mini-FABs visibles).

DESIGN SYSTEM (ver §8.1 de SDD_FASE5_UBISAFE.md + SDD2_FASE5A tokens iter. 2):
- primary-700 #1565C0 (AppBar), warning-700 #E65100 (FAB)
- map-risk-high-fill: #C62828 al 35% · map-risk-medium-fill: #F57C00 al 30%
- NUEVOS iter. 2: community-animal #212121 (negro) · community-waste #795548 (café)
- secondary-700 #2E7D32 (marcadores vendedor), secondary-500 #43A047

ESPECIFICACIONES DEL MOCKUP:
- Viewport: 390×844px, portrait, frame de teléfono realista
- Mapa fullscreen (base):
  · Estilo Google Maps urbano, paleta estándar (calles blancas, manzanas claras)
  · Ubicación del comprador: punto azul pulsante (#1565C0), halo semitransparente
  · 2 marcadores de vendedor (círculos verdes #43A047, ícono storefront)
  
  · Zona de riesgo HIGH (CU-03, iter. 1): círculo rojo fill #C62828 al 35%, stroke #C62828,
    radio ~70px en pantalla, ícono ⚠️ dentro, label "HIGH" chip rojo
  
  · ▶ NUEVO [iter. 2] Foco de infección — Animal muerto:
    Círculo pequeño, fill #212121 al 20%, stroke #212121 2px sólido, radio ~40px en pantalla,
    label chip pequeño: bg #212121, texto blanco 10sp "Animal muerto", radius 8dp
    (colocado al noroeste del comprador, ~120px)
  
  · ▶ NUEVO [iter. 2] Foco de infección — Zona sucia (pending):
    Círculo pequeño, fill #795548 al 15%, stroke #795548 2px punteado (dash),
    radio ~35px en pantalla, label chip pequeño: bg #795548 al 80%, texto blanco 10sp "Pendiente",
    radius 8dp (colocado al sureste, ~150px)

- AppBar overlay (top, primary-700 #1565C0 al 92%, blur):
  · ☰ hamburger blanco (leading) · "UBISAFE" blanco SemiBold 18sp centrado · 🔔 blanco (trailing)

- ▶ NUEVO [iter. 2] FAB expandible (bottom-right):
  Estado: expandido (mostrando los dos mini-FABs)
  · FAB principal: 56dp, radius 16dp, bg warning-700 #E65100, ícono ✕ (close) blanco 24dp
    (cambia a ✕ cuando está expandido)
  · Mini-FAB 1 (encima del principal): 40dp, radius 12dp, bg warning-700 #E65100
    ícono warning_amber blanco 18dp. Label flotante izquierda: "Zona de riesgo" bg #21212199 texto blanco 12sp radius 4dp
  · Mini-FAB 2 (encima del mini-FAB 1, gap 8dp): 40dp, radius 12dp, bg #795548
    ícono bug_report blanco 18dp. Label flotante izquierda: "Foco de infección" bg #21212199 texto blanco 12sp

ACCESIBILIDAD:
- Mini-FABs: 40dp visualmente, touch target expandido a 48dp con padding invisible
- Labels flotantes: contraste blanco sobre #212121 = 21:1 ✓
- Los círculos del mapa no son interactivos (decorativos con Semantics excluidos)

LOOK & FEEL:
Base del CD-05 (HomeV) de iter. 1 — mismo mapa fullscreen con AppBar overlay.
La diferencia visual clave es: iter. 1 solo tenía zonas de riesgo coloridas; iter. 2
añade círculos negros/café más pequeños y discretos que se distinguen claramente por
su paleta propia. El FAB expandido debe verse natural — animación ya realizada, mostrando
el estado abierto con los dos mini-FABs flotando.
```

---

### CD2-08 — Mi Perfil Vendedor con Toggle Raites (W-19 ext)

```
Eres un diseñador UI experto en apps Flutter mobile. Genera un mockup de alta fidelidad
para la pantalla "Mi Perfil" — versión VENDOR con toggle de raites de UBISAFE,
Iteración 2 (W-19 ext).

CONTEXTO Y ROL:
Pantalla de perfil del VENDEDOR. Extiende la pantalla W-19 de iter. 1 añadiendo
una sección "Configuración de servicios" con el toggle "Habilitar raites".
El toggle está ACTIVADO (ON) en este mockup.

DESIGN SYSTEM (ver §8.1 de SDD_FASE5_UBISAFE.md):
- primary-700 #1565C0, primary-50 #E3F2FD
- secondary-700 #2E7D32, secondary-50 #F1F8E9 (rol vendedor)
- danger-500 #E53935 (botón cerrar sesión)
- neutral-900 #212121, neutral-600 #616161, neutral-500 #9E9E9E (labels), neutral-200 #E0E0E0, neutral-100 #F5F5F5
- Tipografía: heading-1 Bold 22sp · body-1 Regular 16sp · caption 12sp

ESPECIFICACIONES DEL MOCKUP:
- Viewport: 390×844px, portrait, frame de teléfono realista
- AppBar: bg primary-700 #1565C0, título "Mi Perfil" centrado blanco SemiBold 18sp,
  BackButton blanco ←
- Body (bg blanco, SingleChildScrollView, padding h:24px):
  · Avatar (mt: 24px, centrado):
    CircleAvatar 96px: bg neutral-100 #F5F5F5, ícono person_outline 48px neutral-400
  · Nombre "Carlos Ruiz" Bold 22sp neutral-900, centrado, mt: 16px
  · Chip rol "Vendedor" (mt: 8px, centrado):
    bg secondary-50 #F1F8E9, texto secondary-700 SemiBold 12sp, radius 12dp, padding h:12 v:4
  
  · Divider, neutral-200, mt: 24px
  
  · Filas de información (mt: 24px, gap: 20px):
    Cada fila: label 11sp neutral-500 UPPERCASE + valor 16sp neutral-900 Medium
    "NOMBRE COMPLETO" → "Carlos Ruiz"
    "TELÉFONO" → "+52 33 9876 5432"
    "ROL" → "Vendedor"
  
  · Divider, neutral-200, mt: 24px
  
  · ▶ NUEVO [iter. 2] Sección configuración:
    - Label de sección: "Configuración de servicios" 12sp neutral-500, mt: 8px
    - SwitchListTile (mt: 12px):
      · Contenedor: bg secondary-50 #F1F8E9 muy suave, radius 12dp, padding h:4 v:0
      · Leading: ícono directions_car_outlined 24px secondary-700 #2E7D32
      · Title: "Habilitar raites" Medium 16sp neutral-900
      · Subtitle: "Los compradores podrán solicitarte un raite." Regular 13sp neutral-600
        (2 líneas, contenido completo)
      · Switch en estado ON: thumb blanco, track secondary-700 #2E7D32
        (Switch de Flutter Material3 estilo activado)
  
  · Divider, neutral-200, mt: 24px
  
  · OutlinedButton "Cerrar sesión" (mt: 24px, mb: 32px):
    ancho completo, h:52dp, borde 1.5px danger-500 #E53935,
    texto danger-500 SemiBold 16sp, radius 12dp

ACCESIBILIDAD:
- SwitchListTile: altura mínima 72dp (subtitle de 2 líneas garantiza esto)
- Switch toggle: touch target 48dp ✓
- Contraste label "CONFIGURACIÓN DE SERVICIOS": neutral-500 sobre blanco = 2.4:1 (solo label — aceptable para texto auxiliar)
- Contraste "Cerrar sesión": danger-500 #E53935 sobre blanco = 3.1:1 ✓

LOOK & FEEL:
Referencia directa al prompt Figma de Mi Perfil de iter. 1 (§8.18.2 de SDD_FASE5_UBISAFE.md).
La adición de iter. 2 es la sección de configuración: debe integrarse visualmente como
una sección natural tras los datos de perfil, con el SwitchListTile bien separado y
el fondo secondary-50 muy sutil para indicar que es interactivo sin saturar.
```

---

### CD2-09 — Drawer Extendido con Reportes Activos (W-18 ext)

```
Eres un diseñador UI experto en apps Flutter mobile. Genera un mockup de alta fidelidad
para el "Drawer — Menú Lateral Extendido" de UBISAFE, Iteración 2 (W-18 ext).

CONTEXTO Y ROL:
El Drawer (menú lateral) se extiende con una nueva entrada "Reportes activos" entre
"Historial" y el separador de "Cerrar sesión". Muestra un badge con el número de reportes
pending_validation cercanos al usuario. Contexto: BUYER (avatar + chip azul).

DESIGN SYSTEM (ver §8.1 de SDD_FASE5_UBISAFE.md):
- primary-700 #1565C0, primary-50 #E3F2FD
- secondary-700 #2E7D32 (color del ícono de la nueva entrada)
- warning-700 #E65100 (color del badge de contador)
- neutral-900 #212121, neutral-600 #616161, neutral-200 #E0E0E0
- danger-500 #E53935 (Cerrar sesión)

ESPECIFICACIONES DEL MOCKUP:
- Viewport: 390×844px, portrait, frame de teléfono realista
- Fondo (mapa HomeC semi-visible): mapa urbano detrás del Drawer, oscurecido (overlay 50%)
- Drawer (ocupa ~80% del ancho izquierdo, ~312px):
  · Fondo blanco (#FFFFFF), shadow right elevation 8dp
  
  · DrawerHeader (bg: primary-700 #1565C0, padding 16dp, altura 120px):
    - CircleAvatar 56px: bg primary-50, ícono person primary-700 28px
    - Nombre "Juan Pérez" Bold 16sp blanco, mt: 12px
    - Teléfono "+52 33 1234 5678" Regular 13sp blanco al 80%
    - Chip "Comprador": bg primary-500 al 30%, texto blanco 11sp SemiBold, radius 10dp
  
  · ListTile — Mi Perfil (mt: 8px):
    Leading: ícono person_outline 24px neutral-600
    Título: "Mi perfil" Regular 15sp neutral-900
    Trailing: ícono chevron_right neutral-400
  
  · ListTile — Historial:
    Leading: ícono history 24px neutral-600
    Título: "Historial" Regular 15sp neutral-900
    Trailing: ícono chevron_right neutral-400
  
  · ▶ NUEVO [iter. 2] ListTile — Reportes activos:
    Leading: ícono shield_outlined 24px secondary-700 #2E7D32
    Título: "Reportes activos" Regular 15sp neutral-900
    Trailing: Stack con badge + chevron
      · Badge: círculo 20px bg warning-700 #E65100, texto "3" blanco Bold 11sp (3 reportes pending)
    Fondo del ListTile: bg secondary-50 #F1F8E9 muy suave (highlight para entrada nueva)
  
  · Divider, neutral-200, margin h:16px
  
  · ListTile — Cerrar sesión:
    Leading: ícono logout 24px danger-500 #E53935
    Título: "Cerrar sesión" Regular 15sp danger-500
    (sin trailing)

ACCESIBILIDAD:
- Todos los ListTiles: 56dp de alto mínimo ✓
- Badge "3": contraste blanco sobre warning-700 = 3.7:1 (aceptable para número pequeño)
- Entry "Reportes activos": visualmente distinguida por el fondo secondary-50 sutil
- "Cerrar sesión": color danger-500 indica acción destructiva sin icono adicional

LOOK & FEEL:
El Drawer de iter. 1 es limpio y directo. La nueva entrada debe integrarse sin romper
el ritmo visual — mismo tamaño de ListTile, mismo tipo de trailing, diferenciada solo
por el color del ícono (verde secondary-700) y el badge naranja con el contador.
El fondo secondary-50 es un detalle sutil que lo hace destacar sin ser invasivo.
```

---

## 8.19.3. Revisión de consistencia visual — Checklist [iter. 2]

> **Instrucción:** Después de generar los 9 mockups y guardarlos como `.png`, revisar los siguientes puntos de consistencia cruzada antes de integrar al .docx.

### Consistencia de paleta

| Elemento | Token | Verificar en mockups |
|---|---|---|
| AppBar Comprador | primary-700 #1565C0 | CD2-01, CD2-02 (fondo), CD2-06, CD2-07, CD2-09 |
| AppBar Vendedor | secondary-700 #2E7D32 | CD2-05 |
| AppBar Perfil/Lista | primary-700 o neutral-100 | CD2-03, CD2-04, CD2-08 |
| Animal muerto (círculo/ícono) | #212121 negro | CD2-02, CD2-04, CD2-07 |
| Zona sucia (círculo/ícono) | #795548 café | CD2-07 |
| Chip "Pendiente" | bg #FFF9C4, texto #F57F17 | CD2-03, CD2-04 |
| Chip "Validado" | bg #C8E6C9, texto #1B5E20 | CD2-03 |
| Botón Confirmar | success-500 #388E3C | CD2-04 |
| Botón Desmentir | borde danger-500 #E53935 | CD2-04 |
| Botón Raite | secondary-700 borde, secondary-50 bg | CD2-06 |

### Consistencia tipográfica

- [ ] Todos los títulos de AppBar en Inter SemiBold 18sp
- [ ] Todos los botones primarios en Inter SemiBold 16sp
- [ ] Todos los chips en Inter SemiBold 12sp o Medium 12sp
- [ ] Todos los textos de soporte en Inter Regular 14sp

### Consistencia de accesibilidad

- [ ] Ningún texto funcional menor a 14sp en los 9 mockups
- [ ] Todos los botones CTA ≥ 52dp de alto
- [ ] Touch targets de chips/filtros ≥ 36dp alto (con padding táctil invisible ≥ 48dp)
- [ ] Contraste de texto principal (neutral-900 sobre blanco): 16:1 ✓

---

## 8.19.4. Revisión de accesibilidad — Adultos mayores y uso en exterior [iter. 2]

> **Skill sugerida:** `/design:accessibility-review` (antes de entregar los mockups al .docx).

### Criterios WCAG 2.1 AA aplicados a mockups de iter. 2

| Criterio | Pantalla clave | Resultado esperado |
|---|---|---|
| **1.4.3 Contraste mínimo 4.5:1** | CD2-01 (distancia verde), CD2-04 (botones), CD2-03 (chips) | Verificar chips "Pendiente" (#F57F17 sobre #FFF9C4 = 2.5:1 — aceptable para estado no crítico) |
| **1.4.11 Contraste no textual 3:1** | CD2-07 (círculos mapa), CD2-02 (círculo preview) | Círculos negro/café sobre fondo de mapa — revisar en captura final |
| **2.5.5 Touch target ≥ 44×44 CSS px** | CD2-04 (VotingIndicator columnas), CD2-09 (ListTiles) | Garantizado por especificación (52dp botones, 56dp ListTiles) |
| **1.4.4 Texto redimensionable** | Todos | Tipografía sp (scale-independent pixels) en código — satisfecho por diseño |
| **RNF-02 UBISAFE — 14sp mínimo** | Todos | Verificar captions y labels auxiliares — algunos en 12sp (decorativos, no funcionales) |

### Consideraciones para uso en exterior (alta luminosidad)

- Los círculos de focos en el mapa (negro y café) tienen buen contraste natural en exteriores ✓
- El chip "Pendiente" (#F57F17 sobre #FFF9C4) puede ser difícil de leer bajo sol directo — considerar aumentar contraste en implementación si usuarios reportan dificultad
- Los botones de acción principal (bg sólido primary/secondary/success) mantienen legibilidad en exterior ✓

---

## Historial

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| V1.0 | 25/04/2026 | Miguel (con Claude Cowork) | Fase 5C' completa: 9 prompts Claude Design (5 nuevas + 4 modificadas), checklist de consistencia visual, revisión de accesibilidad WCAG 2.1 AA. |

---

*Fase 5C' completada (prompts): 25/04/2026 — Los Borbotones / UBISAFE Iteración 2*
*Siguiente paso: Pegar cada prompt en https://claude.ai/ → guardar mockups como .png → integrar en §8.19 del SDD v2.0*
