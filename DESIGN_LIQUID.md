# DESIGN_LIQUID — Downloader

> Estilo para macOS 26+ (Tahoe, Liquid Glass).
> Fuente de verdad de diseño. Última actualización: 2026-07-26.
> Todo lo que no está aquí no está decidido.

---

## Plataforma y versión target

- **Plataforma:** macOS únicamente
- **Versión mínima del proyecto:** macOS 14.0 (Sonoma) — este documento cubre macOS 26+; ver `DESIGN_FROST.md` para 14–15
- **Sistema de diseño:** Liquid Glass (macOS 26+) con fallback Frost (`.ultraThinMaterial` / `NSVisualEffectView`, macOS 14–15)
- **Modos soportados:** Light + Dark, automático, sin variantes manuales
- **Superficies de la app:** ventana launcher (`NSPanel`), menu bar (`NSStatusItem`), ventana de Settings — no hay Dock icon, no hay ventana principal

---

## Identidad visual

**Sensación general:** instantánea, silenciosa, utilitaria — se abre, hace una cosa, desaparece. Nunca decorativa.

**Inspiración:** Spotlight y Raycast en el gesto de apertura (invisible, sin ceremonia); System Settings de macOS en la superficie de Settings (grupos, no formularios densos).

**Principio rector para esta app específicamente:** el launcher se abre cientos de veces al día con una tecla. Cualquier elemento — visual o de motion — que no ayude a "pegar/detectar → Enter → confirmar que algo pasa" está de más. Esto se aplica más estrictamente aquí que en una app de contenido normal.

---

## Color

### Paleta semántica (usar siempre estos, nunca hex hardcoded)

| Rol | Token SwiftUI | Uso |
|-----|--------------|-----|
| Fondo del panel launcher | Glass (ver Materiales) | superficie flotante completa |
| Fondo de fila (queued/downloading/completed) | `Color.primary.opacity(0.04)` sobre el glass | agrupa visualmente sin crear una segunda capa de material |
| Fondo de fila failed | `Color.red.opacity(0.08)` | única fila con tinte de color — señal de error, no decorativa |
| Texto primario | `.primary` | título de fila, texto del campo |
| Texto secundario | `.secondary` | subtítulo (% / velocidad / ETA / razón de error), sitio detectado |
| Texto terciario | `.tertiary` | placeholder del campo, hints |
| Separadores | `Color(nsColor: .separatorColor)` | entre filas, si se usan (ver Componentes) |
| Éxito | `Color.green` | check de completado |
| Error | `Color.red` | icono y subtítulo de failed |
| Advertencia no bloqueante | `Color.orange` | chip "sitio no reconocido" |

### Color de acento

- **No hay accent color custom.** Se usa `Color.accentColor` del sistema — respeta el accent color que el usuario eligió en System Settings. Esta app no tiene identidad de marca que defender; es una herramienta que vive en el sistema del usuario, debe verse como una extensión de él, no como un producto con logo. Cualquier desviación de esto se registra en "Decisiones registradas".
- **Uso:** botón submit implícito (Enter), progress ring/bar, selección de texto en el campo (system default), estado activo en Settings.

### Colores custom
Ninguno. Fuera de alcance para v1 — ver principio de identidad visual arriba.

---

## Tipografía

**Sistema:** SF Pro vía `.system(size:weight:design:)`. **No** se usan los text styles grandes de iOS (`.largeTitle`, `.title`) — son demasiado grandes para una superficie compacta de 560pt de ancho. Se define una escala propia, fija en puntos, porque esta es una utilidad de sistema con dimensiones de ventana controladas por AppKit (`NSPanel` de tamaño fijo), no una vista que reflowea con Dynamic Type de iOS.

**Accesibilidad tipográfica:** aun con tamaños fijos, todo texto usa `@ScaledMetric` sobre su tamaño base para no ignorar por completo "Larger Text" de macOS (Accessibility → Display → Text Size), con un techo de escala de 1.3x para no romper el layout fijo del panel.

### Jerarquía

| Elemento | Tamaño / peso | Uso |
|----------|--------------|-----|
| Input del launcher | 20pt Regular, `.rounded` design | texto que el usuario pega o escribe |
| Placeholder del input | 20pt Regular, `.tertiary` | "Pega un link…" |
| Sitio detectado (badge) | 12pt Medium | "YouTube", "TikTok", junto al input |
| Título de fila (nombre de archivo / título del video) | 13pt Regular | línea principal de `DownloadRowView` |
| Subtítulo de fila (%, velocidad, ETA, razón de error) | 11pt Regular, `.secondary` | línea secundaria de la fila |
| Chip de advertencia ("sitio no reconocido") | 11pt Regular, `.orange` | bajo el input, no bloqueante |
| Encabezado de sección (Settings) | 13pt Semibold | "App destino", "Carpeta de descarga", "Calidad" |
| Texto de control (Settings) | 13pt Regular | labels de picker/botones |
| Hint / footnote (Settings) | 11pt Regular, `.secondary` | explicación bajo un control |

**Nunca:** pesos custom fuera de esta tabla, fuentes que no sean SF Pro, tamaños que no estén en esta lista.

---

## Espaciado

**Base:** 4pt (más fino que el estándar de 8pt de Jonny para otras apps — un panel de 560×~90–420pt no tiene margen para desperdiciar en múltiplos de 8 en cada fila).

| Contexto | Valor |
|----------|-------|
| Padding interno del panel (margen del contenido respecto al borde del glass) | 12pt |
| Altura del input row (vacío) | 52pt |
| Padding horizontal dentro del input row | 16pt |
| Espacio entre input row y la lista de descargas | 8pt |
| Altura de cada `DownloadRowView` | 48pt |
| Espacio vertical entre filas | 4pt |
| Padding horizontal dentro de cada fila | 12pt |
| Espacio entre ícono de fila y texto | 10pt |
| Espacio entre chip de advertencia y el input | 6pt |
| Padding de sección en Settings | 16pt |
| Espacio entre secciones en Settings | 20pt |
| Tap target mínimo (botones, filas clicables) | 32×32pt (menor que el estándar de 44pt de iOS — macOS con puntero preciso no lo necesita; ver Jonny: "macOS compacto pero respirable") |

---

## Forma — Continuous Corners

**Regla absoluta:** `RoundedRectangle(cornerRadius: x, style: .continuous)` en todo. **NUNCA** `style: .circular`. Los círculos puros (progress ring del menu bar) están exentos porque no son rectángulos redondeados — un círculo no tiene "esquina" que continuous-corner pueda suavizar.

### Sistema de radios — Downloader

| Elemento | r_outer | Padding del contenedor | r_inner resultante | Nota |
|----------|---------|------------------------|---------------------|------|
| Panel launcher (glass completo) | 24pt | 12pt | — | forma raíz, no anidada |
| Input row / cada `DownloadRowView` (hijos directos del panel) | — | — | **12pt** = 24 − 12 | conciliado con el padding del panel |
| Ícono/badge de sitio dentro de una fila | — | 8pt (inset del ícono respecto al borde de la fila) | **4pt** = 12 − 8 | tile pequeño, casi cuadrado — intencional |
| Chip "sitio no reconocido" | 999pt (pill) | — | — | pill, no participa del anidado |
| Progress bar (track y fill) | 999pt (pill) | — | — | pill en ambas capas |
| Botón submit implícito / botones de Settings | 10pt | — | — | independiente, no vive anidado en otro contenedor redondeado |
| Ventana de Settings, contenedor de sección | 16pt | 12pt | **4pt** = 16 − 12 | controles internos son nativos (`Form`), no compiten por radio propio |

**Por qué 24/12/12 y no el default 20/16/8 de otras apps:** un panel de ~90–420pt de alto con filas de 48pt no tiene espacio para un padding de 16pt sin que las filas se vean apretadas contra el borde. 12pt de padding + 24pt de radio exterior da un r_inner de 12pt — suficientemente redondeado para que el input y las filas no se vean como rectángulos duros, sin robar ancho útil al contenido.

---

## Materiales y profundidad — Liquid Glass (macOS 26+)

### Regla de capas aplicada a Downloader

| Superficie | Capa | Glass |
|---|---|---|
| Panel launcher completo (`LauncherPanel`) | Navigation/floating layer — es un panel transitorio tipo HUD, no contenido persistente | ✅ Sí — `Regular` |
| Filas de descarga (`DownloadRowView`) individuales | Content layer — son la lista de resultados, no chrome | ❌ No — fill plano semitransparente sobre el glass del panel (ver Color) |
| Input del launcher | Vive dentro del panel, es controlador de la acción principal | Fill plano (mismo tratamiento que las filas), **no** un segundo glass anidado sobre el glass del panel — apilar glass sobre glass rompe legibilidad (regla de Jonny) |
| Ventana de Settings — fondo | Window background | Automático del sistema |
| Ventana de Settings — contenedores de sección | Podría leerse como "panel" pero es contenido de formulario, no chrome flotante | ❌ No — `Form` con `.formStyle(.grouped)`, fondo de grupo nativo |

**Por qué solo el panel completo lleva glass y nada anidado dentro de él:** el panel ya es la única superficie flotante de toda la app. Meter glass en el input o en las filas produciría dos materiales translúcidos apilados — exactamente lo que la regla de capas prohíbe ("nunca stackear light translucent surface sobre otra"). Todo lo de adentro es opaco/semi-opaco sobre un único glass base.

### Variante

- **Regular**, siempre. No hay caso para `Clear` — el panel no está sobre contenido media-rich, está sobre lo que sea que el usuario tenía abierto (código, un browser, Finder); `Clear` ahí sería ilegible de forma impredecible.

### Implementación

```swift
// UI/GlassBackground.swift — único punto de ramificación #available
struct GlassPanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .glassEffect(.regular)
            }
        } else {
            content.frostPanelBackground() // ver DESIGN_FROST.md
        }
    }
}
```

- El `NSPanel` en sí (`LauncherPanel`, `backgroundColor = .clear`) no pinta nada — todo el fondo visual vive en la `SwiftUI` root view vía `.glassPanelBackground()`, para que el mismo modifier controle Liquid Glass y Frost sin lógica duplicada en AppKit.

---

## Pantallas y componentes

### 1. Ventana launcher — dimensiones y estados

**Ancho fijo:** 560pt. **Alto:** variable, calculado por contenido:

| Estado | Alto |
|---|---|
| Vacío (solo input, sin clipboard detectado) | 76pt (12 padding + 52 input + 12 padding) |
| Link pegado / detectado, sitio reconocido | 76pt (badge de sitio vive inline en el input, no agrega alto) |
| Link pegado, sitio no reconocido | 76pt + 22pt (chip de advertencia) = 98pt |
| 1 descarga activa | 12 (padding) + 52 (input) + 8 (spacing) + 48 (fila) + 12 (padding) = 132pt |
| N descargas activas | 76 + 8 + N×(48+4) − 4, hasta un máximo de **420pt** |
| Más filas de las que caben en 420pt | la lista de filas se vuelve un `ScrollView` interno; el panel deja de crecer |

El ancho **nunca** cambia — solo el alto. Esto evita que el panel "salte" horizontalmente y rompa la posición centrada calculada al abrir (TRD sección 2: centrado en la pantalla del cursor).

**Layout vertical (de arriba hacia abajo):**
1. Input row (52pt) — ícono de sitio a la izquierda (16×16pt SF Symbol) si hay URL válida, campo de texto ocupando el resto, sin botón de submit visible (Enter es la acción, no hay affordance visual redundante — coherente con "cero fricción, cero decisiones" del PRD)
2. Chip de advertencia (solo si sitio no reconocido) — 22pt, aparece/desaparece con el input, no empuja layout con salto brusco (ver Animaciones)
3. Lista de `DownloadRowView`, una por descarga activa, orden: más reciente arriba

**Estado "recién abierto" (foco inmediato):**
- Al invocar `panel.makeKeyAndOrderFront(nil)`, el `NSTextField` del input (bridge AppKit, no `TextField` de SwiftUI puro — se necesita control fino de `becomeFirstResponder` sincronizado con la aparición del panel) recibe `becomeFirstResponder()` en el mismo frame.
- Si `ClipboardService` detectó una URL: el texto se precarga **y se selecciona completo** (no solo cursor al final) — así escribir la reemplaza sin necesidad de `Cmd+A` manual.
- Si no hay URL en clipboard: campo vacío, cursor parpadeando al inicio, placeholder "Pega un link de YouTube, TikTok, Instagram…" en `.tertiary`.
- El caret debe estar visible y parpadeando en el primer frame renderizado — no hay una animación de "focus ring creciendo" ni de placeholder que se desvanece al enfocar. Cualquier chrome de foco adicional compite con la animación de aparición del panel (ver Animaciones) y viola la regla de "no animar lo que pasa cientos de veces al día".

---

### 2. Fila de descarga — `DownloadRowView`, 4+1 estados de un mismo componente

**No son pantallas separadas.** Es un único componente con un `switch` interno sobre `DownloadState`, más una advertencia inline que vive en el input (no en la fila) para el caso "sitio no reconocido".

**Layout base (48pt alto, común a todos los estados):**
`[ícono 20×20pt] [8pt] [título 13pt + subtítulo 11pt, VStack] [trailing accessory, alineado a la derecha]`

| Estado | Ícono | Color ícono | Título | Subtítulo | Trailing accessory | Fondo de fila |
|---|---|---|---|---|---|---|
| `.queued` | `clock` | `.secondary` | Nombre de archivo estimado o "Preparando…" | "En cola" | — | `Color.primary.opacity(0.04)` |
| `.downloading(percent, speed, eta)` | `arrow.down.circle` (o el ring de progreso, ver abajo) | `Color.accentColor` | Título del video | "\(speed) · \(eta)" o "Descargando… (sin progreso detallado)" si `speed`/`eta` son `nil` (fallback del parser, TRD riesgo #3) | Progress bar pill, 64pt ancho, a la derecha | `Color.primary.opacity(0.04)` |
| `.completed(fileURL)` | `checkmark.circle.fill` | `.green` | Nombre de archivo final | "Completado" | — (o ícono de "abrir en Finder" 16pt, secundario, si el usuario hace hover — ver Interacciones) | `Color.primary.opacity(0.04)` |
| `.failed(reason)` | `exclamationmark.triangle.fill` | `.red` | Título del video (si se alcanzó a obtener) o la URL cruda | Mensaje legible por `DownloadFailureReason` (tabla abajo) | — | `Color.red.opacity(0.08)` |

**Mapeo de `DownloadFailureReason` a texto legible (nunca mostrar el enum crudo ni el stderr de yt-dlp sin traducir):**

| Caso | Subtítulo mostrado |
|---|---|
| `.unsupportedSite` | "Este sitio no es compatible" |
| `.networkError` | "Sin conexión — reintenta" |
| `.siteBlockedOrChanged` | "El sitio cambió o bloqueó la descarga — no es un error de la app" |
| `.invalidURL` | "El link no es válido" |
| `.cancelled` | "Cancelado" |

Esta distinción es la que el PRD pide explícitamente (riesgo: "sitio cambió" vs. "link inválido" son mensajes distintos, no un genérico "Error").

**Estado "sitio no reconocido, se intentará de todas formas" (no es un `DownloadState`):**
- Vive como chip inline **debajo del input**, no como fila — aparece en cuanto `URLValidator` confirma que el texto es una URL válida pero `SupportedSite.detect` devuelve `.other`.
- Ícono `questionmark.circle`, color `.orange`, texto 11pt: "Sitio no reconocido — se intentará de todas formas".
- **No bloquea el submit.** Enter funciona igual; el chip es puramente informativo. Si el usuario da Enter, el chip desaparece y aparece la fila en `.queued` como con cualquier otro sitio.

**Progress bar de la fila `.downloading` (pill, 999pt de radio en ambas capas):**
- Track: `Color.primary.opacity(0.1)`, 4pt de alto, 64pt de ancho
- Fill: `Color.accentColor`, mismo alto, ancho = `percent * 64pt`
- El fill se redondea igual en ambos extremos (pill) incluso cuando `percent` es bajo — nunca un rectángulo con una esquina recta

---

### 3. Ventana de Settings

**Dimensiones:** 480×360pt, tamaño fijo, no resizable (patrón estándar de ventanas de Settings de macOS — `Window` con `.windowResizability(.contentSize)`).

**Estructura:** `Form` con `.formStyle(.grouped)` — usa el agrupamiento nativo de macOS 14+ (fondo de sección automático, ya correcto en Liquid Glass sin trabajo extra), tres secciones en este orden:

1. **App destino**
   - Fila: ícono de la app seleccionada (16×16pt, vía `NSWorkspace.icon(forFile:)`) + nombre + botón "Cambiar…" que abre `NSOpenPanel` sobre `/Applications`
   - Estado vacío: "Ninguna — solo se notificará al terminar" en `.secondary`, sin ícono
   - Footnote 11pt bajo la fila: "El archivo se abrirá automáticamente aquí al completar la descarga."

2. **Carpeta de descarga**
   - Fila: ícono de carpeta genérico + path abreviado (`~/Downloads` en vez de la ruta absoluta completa) + botón "Cambiar…"
   - Default: `~/Downloads` si el usuario nunca configuró nada

3. **Calidad default**
   - `Picker` estilo segmentado (`.pickerStyle(.segmented)`) con 3 opciones legibles: **Mejor calidad** / **1080p máx** / **720p máx** — nunca se expone la sintaxis de formato de yt-dlp (TRD, sección "Qué NO hacer")
   - Footnote 11pt: "Se usa siempre — no se pregunta en cada descarga."

**Nota para Woz:** el atajo de teclado global (hotkey) tiene claves de `AppSettings` ya definidas en el TRD pero **no tiene UI diseñada en esta pasada** — queda en "Sin definir aún" al final de este documento. No inventar una cuarta sección sin que Jonny la diseñe.

---

### 4. Menu bar — ícono y estados

Todos los íconos son **template images** (monocromáticos, se re-tintan solos con light/dark y con el resto de la menu bar) — nunca color hardcodeado en el ícono del status item, eso rompería la convención de HIG de que la menu bar es monocroma.

**Tamaño objetivo:** 18pt (dentro del rango 16–22pt pedido por Avie; 18 es el punto medio que se ve nítido en Retina sin verse más grande que los íconos de sistema vecinos).

| Estado | Representación | Detalle de implementación |
|---|---|---|
| **Idle** (sin descargas activas) | SF Symbol `arrow.down.circle`, weight `.regular`, template, 18pt | `NSImage(systemSymbolName:)` + `.isTemplate = true`, sin redraw dinámico |
| **Descargando** (≥1 descarga activa) | Ring de progreso dibujado a mano — circulo de track (`Color.primary.opacity(0.2)` equivalente en template) + arco de progreso (opaco, se re-tinta solo) empezando a las 12 en punto, sentido horario, con una flecha `arrow.down` de 8pt centrada | `NSImage` custom vía `NSGraphicsContext` / `Core Graphics`, redibujado **solo** cuando el `%` cambia ≥2pp o cada 400ms (lo que ocurra primero) — nunca en cada tick del parser, para no quemar CPU redibujando 10×/segundo |
| **Error** (última descarga activa terminó en `.failed`, sin descargas nuevas iniciadas aún) | SF Symbol `exclamationmark.circle`, template, 18pt | Se limpia automáticamente en cuanto el usuario abre el launcher de nuevo o inicia otra descarga — nunca queda "pegado" indefinidamente sin que el usuario haya podido verlo |

- Si hay múltiples descargas simultáneas en distintos estados, el ícono refleja el **más urgente primero**: error > descargando > idle. Con 2 descargando y 1 en error, se muestra error — el usuario necesita saber que algo requiere atención, el progreso se ve al abrir el panel.
- El menú del click (`NSMenu`) es siempre el mismo (Abrir Downloader / Ajustes… / separador / Salir), independiente del estado del ícono — el estado no cambia la estructura del menú, solo el glyph del botón.
- Círculos del ring de progreso están exentos de la regla de Continuous Corners (no son rectángulos redondeados).

---

## Componentes del sistema

### Botones
- No hay botón CTA visible en el flujo principal — Enter es la acción (PRD: "cero fricción, cero diálogos intermedios"). Cualquier botón visible es secundario (Settings, menú).
- **Settings — botones de acción ("Cambiar…"):** `.buttonStyle(.glass)` en macOS 26+, pill, altura 28pt.
- **Destructivo:** no aplica en v1 (no hay delete de historial ni de filas — no hay historial).

### Listas y filas
- La lista de descargas activas no es un `List` nativo de SwiftUI (que trae su propio material/separadores pensados para contenido largo) — es un `VStack` simple dentro del panel, porque son máximo un puñado de filas visibles a la vez y `List` introduce chrome (separadores, insets de sistema) que no aporta nada aquí.
- Sin separadores entre filas — el espacio de 4pt entre filas ya crea la separación visual necesaria; una línea divisoria sería ruido adicional.
- Sin swipe actions, sin contextMenu de borrado — no hay nada que borrar (sin historial).

### Iconografía
- SF Symbols exclusivamente.
- Peso: `.regular` en filas y menu bar; `.medium` en el chip de advertencia para que destaque ligeramente más que el texto secundario adyacente.
- Estilo: outline por defecto (`arrow.down.circle`, `clock`, `exclamationmark.triangle`); `.fill` solo para el estado positivo de éxito (`checkmark.circle.fill`) — el único momento donde vale la pena un glyph más "sólido" y afirmativo.

---

## Animaciones

**Principio rector:** el panel se abre con una tecla, cientos de veces al día. Esa acción se trata como el caso "100+ veces/día" del framework de decisión de motion — la respuesta por defecto es **no animar**, y cuando se anima, el mínimo posible. Todo lo demás (transiciones de estado de fila, progreso) sí es "ocasional" y sí recibe motion completo.

| Interacción | Trigger | Motion | Duración/curva | Por qué |
|---|---|---|---|---|
| **Aparición del panel** | Hotkey / click en menu bar | Opacity 0→1 + scale 0.96→1.0, sin bounce | `.easeOut`, **120ms** | Acción disparada por teclado cientos de veces/día — se trata como Raycast/Spotlight: casi nada, solo lo suficiente para no sentirse como un "pop" abrupto. Nunca spring con overshoot: el overshoot se reserva para gestos con momentum real, y aquí no hay gesto, hay una tecla |
| **Cierre del panel** | Escape / pérdida de foco (`windowDidResignKey`) | Solo opacity 1→0, sin scale | `.easeIn` es aceptable únicamente aquí porque es una salida sin necesidad de sentirse "responsiva" — el usuario ya decidió irse | **80ms** | Salida siempre más rápida que la entrada (asimetría deliberada: entrar puede tener un ápice de materialización, salir debe sentirse instantáneo — el usuario no espera nada de la app al cerrar) |
| **Cambio de alto del panel** (aparece/desaparece el chip de advertencia, se agrega una fila) | Reactivo a estado | Animar el alto del contenedor, `.spring(response: 0.35, dampingFraction: 1.0)` — sin bounce | ~280ms de asentamiento | Es reposicionamiento de contenido, no un gesto — tabla de Apple: "Move/reposition → damping 1.0, response 0.4"; se usa 0.35 por ser una superficie pequeña |
| **Transición entre estados de una fila** (`.queued` → `.downloading` → `.completed`/`.failed`) | Cambio de `DownloadState` | Crossfade de ícono + texto (opacity, sin mover posición), `.easeOut` | **200ms** | Ocasional (una vez por descarga, no repetitivo), amerita motion completo — pero sin desplazamiento porque el layout de la fila no cambia de tamaño entre estados |
| **Nueva fila insertada en la lista** | Se dispara una nueva descarga con otra ya en curso | Height 0→48pt + opacity 0→1 juntos, `.spring(response: 0.35, dampingFraction: 1.0)` | ~280ms | Igual razonamiento que el cambio de alto del panel — es la misma familia de animación (el contenedor crece), no una animación aparte |
| **Progreso de la barra dentro de `.downloading`** | Cada tick de `--progress-template` (~1/seg) | Animar el ancho del fill hacia el nuevo `percent`, `.linear` | **200ms** por tick | Es un valor de datos entrando, no un gesto — un tween lineal corto entre el valor viejo y el nuevo evita el salto brusco de un `%` a otro sin fingir un progreso continuo que no existe |
| **Ring de progreso del menu bar** | Cada redraw permitido (throttle de la sección Menu bar) | Sin animación explícita — es un redraw directo del valor actual | — | Redibujar un `NSImage` estático no es interpolable de forma barata; el throttle (≥2pp o 400ms) ya evita que se vea como un salto — animarlo encima sería gastar CPU en un lugar que el usuario mira de reojo, no de frente |
| **Cambio de ícono de menu bar entre estados** (idle↔downloading↔error) | Cambio de estado agregado de las descargas | Crossfade corto del `NSImage` vía `CALayer` transition | **150ms** | Evita el parpadeo de un swap instantáneo de imagen, sin ser perceptible como "animación" — dura menos que un parpadeo consciente |
| **Chip "sitio no reconocido" aparece/desaparece** | Detección de sitio en cada cambio del input | Opacity + height juntos, mismo spring que las filas | ~280ms | Es parte de la misma familia de "el contenido cambia de alto" — consistencia de motion en todo el panel, un solo tipo de curva para todo lo que crece/encoge |

**Reglas explícitas heredadas de las skills de motion (Emil / Apple) aplicadas aquí:**
- Nunca se usa `ease-in`/`.easeIn` para algo que **entra** — la única excepción documentada arriba es el cierre del panel, que **sale**, no entra.
- Ninguna animación en esta app supera 300ms — la más larga (280ms, spring de alto) sigue dentro del techo.
- Ninguna animación tiene bounce/overshoot — no hay un solo gesto de arrastre en toda la app (no hay drag-to-dismiss, no hay swipe); todo el motion es reactivo a datos o a teclado, así que todo usa `dampingFraction: 1.0` o easing simple, nunca `bounce > 0`.
- El progreso (barra y ring) se trata como dato, no como decoración — se anima con `.linear`/redraw directo, nunca con una curva "bonita" que falsee la velocidad real de la descarga.

### Reduce Motion

`@Environment(\.accessibilityReduceMotion)` en `LauncherView` y en el `AppDelegate` (vía `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`, ya que el fade del menu bar vive en AppKit puro, fuera del entorno de SwiftUI):

| Animación normal | Con Reduce Motion |
|---|---|
| Aparición del panel (opacity+scale, 120ms) | Solo opacity, sin scale, misma duración |
| Cierre del panel (opacity, 80ms) | Sin cambio — ya es solo opacity |
| Spring de alto del panel / inserción de fila | Cross-fade de opacity únicamente, sin animar el alto (el alto salta directo al valor final) |
| Crossfade de estado de fila | Se mantiene — es opacity pura, no movimiento, no causa mareo |
| Progreso de barra (`.linear`) | Se mantiene — es una barra llenándose, no un desplazamiento espacial |
| Crossfade de ícono de menu bar | Se mantiene, misma duración — swap de imagen estática, no movimiento |

### Reduce Transparency

`@Environment(\.accessibilityReduceTransparency)`:

- El glass del panel (`.glassEffect(.regular)`) se reemplaza por un fill sólido y opaco: `Color(nsColor: .windowBackgroundColor)` a 100% de opacidad, con el mismo `cornerRadius: 24, style: .continuous`.
- Las filas (`Color.primary.opacity(0.04)`) suben a `Color.primary.opacity(0.08)` para mantener el mismo contraste relativo contra un fondo ahora opaco en vez de translúcido.
- No afecta a Settings (`Form` grouped ya es prácticamente opaco por defecto).

### Increase Contrast

Fuerza Reduce Transparency ON (ya cubierto arriba) y además: el borde del panel gana un `strokeBorder` de 1pt en `Color(nsColor: .separatorColor)` para no depender solo de la sombra para definir el límite del panel contra el fondo del escritorio.

---

## Decisiones registradas

| Fecha | Decisión | Razón |
|-------|----------|-------|
| 2026-07-26 | Sistema de radios propio 24/12/12 en vez del default 20/16/8 | El panel es mucho más chico que una pantalla de contenido normal; 16pt de padding dejaba las filas de 48pt apretadas contra el borde |
| 2026-07-26 | Sin accent color custom — se usa `Color.accentColor` del sistema | La app no tiene identidad de marca que defender; debe sentirse como parte del sistema del usuario, no como un producto con logo propio |
| 2026-07-26 | Apertura del panel: 120ms opacity+scale sin bounce, cierre: 80ms solo opacity | Acción de teclado repetida cientos de veces/día (framework de Emil) — se trata como Spotlight/Raycast: el mínimo motion posible, nunca decorativo |
| 2026-07-26 | Ningún componente usa spring con bounce | No existe un solo gesto de arrastre en la app v1 (sin drag-to-dismiss, sin swipe) — el bounce se reserva para momentum real que aquí no existe |
| 2026-07-26 | "Sitio no reconocido" es un chip inline en el input, no una fila ni un `DownloadState` | Ocurre antes del submit, es puramente informativo y no bloqueante — mezclarlo con los 4 estados de `DownloadState` (que sí representan el ciclo de vida de una descarga real) confundiría el modelo |
| 2026-07-26 | Menu bar: ring de progreso redibujado por threshold (≥2pp o 400ms), no en cada tick | `NSStatusItem` no anima gratis (nota de Avie) — redibujar un `NSImage` en cada tick del parser (~1/seg puede ser más frecuente en descargas rápidas) desperdicia CPU en algo que el usuario mira de reojo |
| 2026-07-26 | Ícono de menu bar prioriza error > descargando > idle cuando hay múltiples descargas | El usuario necesita saber que algo falló sin tener que abrir el panel; el progreso de las que sí van bien se ve al abrir |
| 2026-07-26 | Corregida tabla de alturas (doble conteo de panelPadding) | Detectado por Woz al aplicar review de Larry; el layout real usa 8pt entre input y lista |
| 2026-07-26 | Ícono de sitio en el input (`LauncherView`, frame 16×16) se mantiene a **13pt**, no se sube a 16pt como propuso Larry en review | El frame de 16×16 es una caja de alineación compartida (`Theme.Size.siteIcon`, reusada en Settings para íconos de 16×16), no una instrucción de "llena el cuadro". 13pt es el mismo tamaño de símbolo que usa `DownloadRowView` (que tampoco fuerza el símbolo al tamaño de su frame de 20pt) y empareja ópticamente con el badge "sitio detectado" de 12pt Medium que aparece junto al ícono — son la misma familia de metadata visual. Subir a 16pt (ratio 1:1 con el frame) rompería esa consistencia y, para símbolos con arte más ancho, puede desbordar ópticamente el frame en vez de quedar bien inscrito — un símbolo a `size: 16` no siempre cabe con margen dentro de una caja de 16pt, mientras que un ratio símbolo:frame de ~0.8 (13/16) es el que produce el inset correcto que ya usa el resto de la app. |

---

## Ícono de app

**Concepto:** flecha hacia una bandeja — el glifo universal de "descargar" (el mismo lenguaje que el ícono de descargas de cualquier navegador), sin texto ni logotipo. Coherente con la identidad de la app ("instantánea, silenciosa, utilitaria"): el ícono comunica la única acción que la app hace, nada más.

**Geometría (canvas 1024×1024, grid de ícono macOS Big Sur+):**
- Squircle de fondo: superelipse (aproximación de continuous corner, exponente 5), ocupa el 82.4% del canvas (≈844×844pt), centrado — sigue el grid oficial de Apple para íconos de macOS, no un cuadrado con esquinas circulares.
- Glifo centrado dentro del squircle, escalado al 72% del squircle (≈607pt): tallo vertical rematado en semicírculo + cabeza triangular con la punta redondeada (radio 9pt en un sistema lógico de 100pt) + una bandeja en forma de cápsula debajo, separada por un espacio — no es solo una flecha suelta, la bandeja ancla visualmente el gesto de "aterrizar/guardar".
- Sombra suave debajo del glifo (offset y blur proporcionales al canvas) para separarlo del fondo sin verse pegado.

**Colores exactos:**
- Gradiente de fondo, diagonal (esquina superior-izquierda → inferior-derecha): `#3B82F6` (azul, arriba) → `#0891B2` (cian, abajo) — paleta "stream/red", distinta del `Color.accentColor` neutro que usa el resto de la app (el ícono es la única superficie de la app con identidad de color propia; ver Color > Colores custom, que sigue en "ninguno" para la UI interna).
- Glifo (flecha + bandeja): blanco `#FFFFFF` al 96% de opacidad.
- Gloss superior: radial blanco al 22% de opacidad desvaneciendo a 0%, centrado en el tercio superior del squircle — separación especular sutil, no un brillo iOS plano.
- Sombra interior inferior: gradiente negro de 0% a 16% de opacidad en el tercio inferior — ancla el squircle ópticamente, evita que se vea flotando sin peso.
- Sombra del glifo: negro al 35% de opacidad, blur y offset proporcionales al canvas.

**Por qué esta paleta y no gris/monocromo como el ícono de menu bar:** el ícono de menu bar es template (monocromo, se re-tinta con el sistema) porque vive dentro del chrome de macOS y debe mimetizarse — regla ya registrada en "Menu bar". El ícono de app vive en Dock/Finder/App Switcher, junto a íconos de otras apps con colores propios; ahí sí necesita una identidad de color reconocible a simple vista, aunque la UI interna de la app deliberadamente no tenga una.

**Generación:** script Swift (`CoreGraphics`/`AppKit`, sin dependencias) que dibuja la superelipse y el glifo como `CGPath` vectoriales y rasteriza cada tamaño requerido directamente a su resolución final (no downscaling de un solo master), para AA nítido en 16pt tanto como en 1024pt. Archivos en `Downloader/Resources/Assets.xcassets/AppIcon.appiconset/`.

---

## Sin definir aún

- [ ] UI de captura de atajo de teclado (hotkey) en Settings — el TRD define las claves de `AppSettings` pero esta pasada de diseño se limitó a las 3 secciones pedidas (app destino, carpeta, calidad)
- [ ] Qué pasa visualmente si `RegisterEventHotKey` falla porque el atajo ya está tomado (TRD menciona "mostrar alerta clara en Settings" pero no está diseñada)
- [ ] Comportamiento de filas `.completed` tras varios minutos con el panel abierto (¿se desvanecen solas? ¿quedan indefinidamente hasta que se cierra el panel?) — no está definido en el PRD
- [ ] Estado de "verificando yt-dlp" al iniciar la app (`YTDLPUpdateService`) — si debe reflejarse en algún lado de la UI o es completamente silencioso
