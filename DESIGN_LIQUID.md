# DESIGN_LIQUID — Downloader

> Estilo para macOS 26+ (Tahoe, Liquid Glass).
> Fuente de verdad de diseño. Última actualización: 2026-07-27.
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
| Texto terciario | `.tertiary` | hints |
| Separadores | `Color(nsColor: .separatorColor)` | entre filas, si se usan (ver Componentes) |
| Éxito | `Color.green` | check de completado |
| Error | `Color.red` | icono y subtítulo de failed |
| Advertencia no bloqueante | `Color.orange` | chip "sitio no reconocido" |

### Color de acento

- **No hay accent color custom.** Se usa `Color.accentColor` del sistema — respeta el accent color que el usuario eligió en System Settings. Esta app no tiene identidad de marca que defender; es una herramienta que vive en el sistema del usuario, debe verse como una extensión de él, no como un producto con logo. Cualquier desviación de esto se registra en "Decisiones registradas".
- **Uso:** botón submit implícito (Enter), progress ring/bar, selección de texto en el campo (system default), estado activo en Settings.

### Colores custom
Ninguno de marca propia. Fuera de alcance para v1 — ver principio de identidad visual arriba. Sí existen colores de marca de *terceros* (ver tabla siguiente), que es un caso distinto: no es identidad visual de esta app, es reflejar de qué sitio viene el contenido.

### Tinte del sitio detectado — solo en `.input`

El fondo del frame (`Theme.Palette.rowFill`, normalmente `Color.primary.opacity(0.04)`) cambia de hue al color de marca del sitio en cuanto `SupportedSite.detect` reconoce la URL pegada/escrita — **únicamente mientras el frame está en `.input`**. En `.downloading`, `.completed` y `.error` el fondo vuelve a ser el neutro de siempre (`.error` además ya tiene su propio rojo, que no debe competir con un color de marca).

| Sitio | Color de marca | Hex |
|---|---|---|
| YouTube | rojo, plano | `#FF0000` |
| Instagram | **gradiente real de marca**, diagonal (`.topLeading → .bottomTrailing`), 5 paradas | `#FEDA75 → #FA7E1E → #D62976 → #962FBF → #4F5BD5` |
| TikTok | rojo/rosa de acento, plano | `#FE2C55` |
| X (Twitter) | negro (marca actual post-rebrand), plano | `#000000` |
| Sitio no reconocido (`.other`) | sin tinte — se mantiene `Theme.Palette.rowFill` neutro | — |

**Opacidad:** `0.18` normal, `0.28` con Reduce Transparency (`Theme.Palette.siteTint(for:reduceTransparency:)`) — marcada, no sutil (pedido directo del usuario, iteración sobre la versión anterior que usaba `0.04`/`0.08`, la misma magnitud que el fill neutro). Sigue siendo un tinte del fondo, no un logo ni un banner — el resto de la fila (texto, ícono) no cambia.

**Por qué solo en `.input` y no persiste durante la descarga:** pedido directo del usuario, con esta razón de diseño: el tinte es información de *detección* ("reconocí este link"), no de *identidad de la descarga*. Una vez que el Enter dispara `.downloading`, lo relevante ya es el progreso, no de qué sitio vino — y mantener el tinte ahí competiría con la señal de `.error` (rojo) si la descarga falla.

**Riesgo conocido, no resuelto:** el negro de X (`#000000`) sobre un fill que ya parte de un panel oscuro (`Color.primary.opacity(0.04)` en Dark Mode es blanco al 4%, no negro — pero el panel de fondo detrás sí es oscuro) puede resultar casi imperceptible en Dark Mode, que es probablemente el modo más común de uso de esta app. Queda documentado, no corregido — ver "Sin definir aún".

## Tipografía

**Sistema:** SF Pro vía `.system(size:weight:design:)`. **No** se usan los text styles grandes de iOS (`.largeTitle`, `.title`) — son demasiado grandes para una superficie compacta de 560pt de ancho. Se define una escala propia, fija en puntos, porque esta es una utilidad de sistema con dimensiones de ventana controladas por AppKit (`NSPanel` de tamaño fijo), no una vista que reflowea con Dynamic Type de iOS.

**Accesibilidad tipográfica:** aun con tamaños fijos, todo texto usa `@ScaledMetric` sobre su tamaño base para no ignorar por completo "Larger Text" de macOS (Accessibility → Display → Text Size), con un techo de escala de 1.3x para no romper el layout fijo del panel.

### Jerarquía

| Elemento | Tamaño / peso | Uso |
|----------|--------------|-----|
| Input del launcher | 14pt Regular, `.rounded` design | texto que el usuario pega o escribe |
| Placeholder del input | 14pt Regular, `.secondary` | "Pega un link…" |
| Sitio detectado (badge, solo nombre) | 12pt Medium | "YouTube", "TikTok", a la izquierda del input (sin ícono) |
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
| Padding interno del panel (margen del contenido respecto al borde del glass) | 6pt |
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
| Panel launcher (glass completo) | 24pt | 6pt | — | forma raíz, no anidada |
| Frame único (`.input`/`.downloading`/`.completed`/`.error`, hijo directo del panel) | — | — | **18pt** = 24 − 6 | conciliado con el padding del panel |
| Ícono/badge de sitio (si se reintroduce un tile) | — | 8pt (inset del ícono respecto al borde del frame) | **10pt** = 18 − 8 | valor de reserva — hoy el nombre del sitio es texto plano, sin tile |
| Chip "sitio no reconocido" | 999pt (pill) | — | — | pill, no participa del anidado |
| Progress bar (track y fill) | 999pt (pill) | — | — | pill en ambas capas |
| Botón submit implícito / botones de Settings | 10pt | — | — | independiente, no vive anidado en otro contenedor redondeado |
| Ventana de Settings, contenedor de sección | 16pt | 12pt | **4pt** = 16 − 12 | controles internos son nativos (`Form`), no compiten por radio propio |

**Por qué 24/6/18 y no el default 20/16/8 de otras apps:** el panel del launcher es una superficie mucho más chica que una pantalla de contenido — el margen entre el borde del glass y el frame interior se redujo a la mitad (de 12pt a 6pt) por pedido directo, para que el frame ocupe más del ancho disponible y el aro de glass visible alrededor sea más discreto. 6pt de padding + 24pt de radio exterior da un r_inner de 18pt — el frame se ve más redondeado que antes (18pt vs. 12pt), lo cual es coherente: menos padding alrededor de una forma con el mismo radio exterior siempre sube el r_inner.

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

**REDISEÑO 2026-07-27 — un solo frame, sin lista.** La lista de filas debajo del input desaparece por completo. Todo lo que la app comunica sobre la descarga en curso ocurre **dentro de la misma superficie del input** — un único frame que atraviesa una máquina de estados (`.input` → `.downloading` → `.completed` / `.error` → de vuelta a `.input`). No hay una segunda superficie que aparezca debajo. Ver sección 2 para la especificación completa de los 4 estados.

**Ancho fijo:** 560pt, sin cambios. **Alto:** ahora prácticamente fijo — el frame mide **siempre 52pt** en sus 4 estados (nunca cambia de tamaño al cambiar de estado, solo su contenido). La única fuente de variación de alto que sobrevive es el chip de advertencia "sitio no reconocido", que sigue viviendo debajo del frame y solo aplica en `.input`:

| Estado del panel | Alto |
|---|---|
| Frame en `.input`, `.downloading`, `.completed` o `.error` (sin chip) | 64pt (6 padding + 52 frame + 6 padding) |
| Frame en `.input` con chip de advertencia visible | 64pt + 22pt = 86pt (el chip solo puede aparecer en `.input` — no hay detección de sitio corriendo en los otros 3 estados) |

El ancho **nunca** cambia. El alto ahora tiene solo dos valores posibles en toda la app (64pt / 86pt) en vez de una escala continua hasta 420pt — la lista, el `ScrollView` interno y el techo `panelMaxHeight` quedan retirados junto con `DownloadRowView` como componente de lista (ver Decisiones registradas).

**Layout vertical (de arriba hacia abajo):**
1. El frame (52pt) — su contenido interno cambia por completo según el estado (ver sección 2), pero su altura, radio (`r=18`, nested de `r_outer=24 − padding=6`) y fill base nunca cambian entre estados.
2. Chip de advertencia (solo si sitio no reconocido, solo en `.input`) — 22pt, aparece/desaparece con el input, no empuja layout con salto brusco (ver Animaciones).

**Estado "recién abierto" (foco inmediato):**
- Al invocar `panel.makeKeyAndOrderFront(nil)`, el `NSTextField` del input (bridge AppKit, no `TextField` de SwiftUI puro — se necesita control fino de `becomeFirstResponder` sincronizado con la aparición del panel) recibe `becomeFirstResponder()` en el mismo frame.
- Si `ClipboardService` detectó una URL: el texto se precarga **y se selecciona completo** (no solo cursor al final) — así escribir la reemplaza sin necesidad de `Cmd+A` manual.
- Si no hay URL en clipboard: campo vacío, cursor parpadeando al inicio, placeholder "Pega un link de YouTube, TikTok, Instagram…" en `.tertiary`.
- El caret debe estar visible y parpadeando en el primer frame renderizado — no hay una animación de "focus ring creciendo" ni de placeholder que se desvanece al enfocar. Cualquier chrome de foco adicional compite con la animación de aparición del panel (ver Animaciones) y viola la regla de "no animar lo que pasa cientos de veces al día".

**Qué estado muestra el frame al reabrir el panel (decisión, ver Decisiones registradas):**
- **Si no hay una descarga en curso** (frame estaba en `.completed`, `.error`, o `.input` cuando se cerró el panel): el frame **siempre vuelve a `.input`** — clipboard-detection y foco se ejecutan como en cualquier apertura. `.completed` y `.error` no sobreviven a un cierre de panel; son estados transitorios pensados para verse una vez, inmediatamente después del evento que los generó.
- **Si hay una descarga en curso** (el usuario cerró el panel mientras el frame estaba en `.downloading` — la descarga sigue viva en el actor, `panelDidHide()` no la cancela): el frame **vuelve a `.downloading`** con el progreso actual, no a `.input`. El usuario no debe reabrir el launcher y encontrar el campo de texto vacío como si nada estuviera pasando, mientras una descarga real sigue corriendo en background.

---

### 2. El frame — máquina de estados única (`.input` → `.downloading` → `.completed` / `.error` → `.input`)

**`DownloadRowView` y el concepto de lista de filas quedan retirados.** Ya no existen filas independientes por descarga ni una lista de "descargas activas" visible — solo hay **una descarga a la vez**, y su estado se muestra transformando la superficie del input mismo. Ver Decisiones registradas para el porqué y qué reemplaza a `DownloadRowView`.

**Layout base — el frame nunca cambia de tamaño ni de radio entre estados, solo su contenido:**
`52pt alto · padding horizontal 16pt · r=18pt (nested de r_outer=24, padding=6) · fill Color.primary.opacity(0.04) (Color.red.opacity(0.08) solo en `.error`)`

El frame ocupa exactamente el espacio que el input row siempre ocupó — la transición entre estados es un crossfade de contenido dentro de una caja que no se mueve ni redimensiona (misma filosofía que ya aplicaba a `DownloadRowView`: "el layout no cambia de tamaño entre estados, por eso la transición es crossfade puro sin desplazamiento").

**Ícono izquierdo del frame = anillo de progreso, mismo lenguaje visual que la menu bar (decisión 2026-07-27, ver Decisiones registradas):**

En `.downloading`/`.completed`/`.error` el ícono izquierdo (20×20pt) deja de ser un SF Symbol estático distinto por estado y pasa a ser `DownloadStateIcon` — el mismo objeto compuesto en los 3 estados: una flecha centrada dentro de un `ProgressRing` que se llena de 0 a 100%. La flecha es un `Path` propio (`DownloadArrow`), no un SF Symbol — ver "Decisiones registradas" 2026-07-27. Es el "hermano a color" del ícono monocromo de `MenuBarIconRenderer` (mismo concepto: flecha + arco de progreso, 12 en punto, sentido horario). Con esto, **hay un único indicador de progreso visible en el frame** — el `ProgressRing` que antes vivía al lado del texto "NN%" (lado derecho) queda retirado; el lado derecho de `.downloading` conserva solo el texto del porcentaje.

| Estado | Color (glifo + anillo) | Track del anillo | `percent` del anillo |
|---|---|---|---|
| `.downloading` (con título real) | Blanco | `Color.white.opacity(0.15)` | `currentDownload` en vivo |
| `.downloading` ("Preparando…", sin título aún / `.queued`) | Blanco | `Color.white.opacity(0.15)` | `0` — anillo vacío, sin animación de indeterminado; el `%` de la derecha tampoco aparece hasta que hay progreso real (ver coreografía del accesorio derecho) |
| `.completed` | Verde | `Color.green.opacity(0.15)` | `1` — anillo completo |
| `.error` | Rojo | `Color.red.opacity(0.15)` | `0` — anillo vacío (no hay un `%` significativo que congelar al fallar; el color rojo + el fill rojo del frame ya comunican el estado) |

- **El ícono nunca se desplaza** — sigue cambiando "en su lugar" exactamente como antes. El color (y, entre `.downloading`→`.completed`/`.error`, también el `percent` del anillo) crossfadea vía el mismo mecanismo ya existente: `statefulLeading` usa `.id(viewModel.frameState)` + `.transition(.opacity)`, así que el swap de estado es un crossfade de opacity — sin animar el color del glifo por separado, sin números mágicos nuevos, mismo token `Theme.Motion.rowStateCrossfade` (`.easeOut`, 200ms) que ya crossfadeaba ícono+título.
- **Dentro de `.downloading`** (sin cambio de `frameState`, solo el `%` avanzando) el anillo sí anima su propio llenado con `Theme.Motion.progressTick` (`.linear`, 200ms por tick) — igual que el ring que antes vivía a la derecha.
- **Reduce Motion:** el llenado del anillo (`ProgressRing`) se mantiene animado siempre — es un valor de datos, no decoración, así que no se desactiva bajo Reduce Motion (única excepción a la regla general de esta app de "Reduce Motion apaga animaciones espaciales"). El cambio de color entre estados sí puede saltar instantáneo bajo Reduce Motion porque va montado sobre el mismo crossfade de opacity de `statefulLeading`, que ya colapsa a un fade puro sin traslación en ese modo.
- **VoiceOver:** `DownloadStateIcon` hereda `accessibilityHidden(true)` de `ProgressRing` y además se marca `accessibilityHidden(true)` a nivel de todo el ícono compuesto — el label combinado del frame (`statefulLeading.accessibilityLabel`) ya anuncia estado y `%`, así que el ícono no genera un segundo nodo redundante.

#### Estado `.input` (base)

Sin cambios respecto al input row actual: badge de sitio (12pt Medium, `.secondary`, sin ícono) a la izquierda si `SupportedSite` reconocido, `URLInputField` ocupando el resto, sin botón de submit visible — Enter es la acción. Cursor de texto real, editable.

#### Estado `.downloading`

`[ícono 20×20pt, DownloadStateIcon (flecha + anillo de progreso, blanco)] [8pt] [título 13pt Regular, .primary, 1 línea, truncationMode .middle, centrado verticalmente] [Spacer] [trailing: "NN%" 11pt .white monospacedDigit]`

| Elemento | Valor |
|---|---|
| Título | `task.title` si ya llegó del parser de yt-dlp; si no, **"Preparando…"** en `.secondary` (mismo peso 13pt, distinto color mientras no hay título real — señal sutil de "esto todavía no es el título final") |
| Ícono | Aparece por primera vez respecto a `.input` (que no tiene ícono desde la decisión de 2026-07-27) — es la señal visual primaria de "ya no estás escribiendo, esto es de solo lectura". **Es el propio indicador de progreso** (ver "Ícono izquierdo del frame = anillo de progreso" abajo), no un símbolo estático — su anillo se llena de 0 a 100% mientras dura la descarga |
| % (trailing) | Ya no lleva ring propio — el anillo vive en el ícono izquierdo. Solo el texto `"NN%"`, `.white`, `monospacedDigit()` para evitar jitter |
| Fill del frame | Igual que `.input` — `Color.primary.opacity(0.04)`, sin cambio, para que la transición sea puramente de contenido |

**Una descarga a la vez — qué pasa si se intenta pegar/escribir/Enter mientras `.downloading`:**
- El campo de texto real no existe en este estado (fue reemplazado por el label del título) — el panel captura `keyDown`/`paste` a nivel de ventana mientras el frame está en `.downloading` y los descarta sin insertar nada en ningún buffer.
- **Feedback: shake sutil del frame**, no "nada visible". Se decide shake y no silencio porque el usuario que pega un segundo link inmediatamente después del primero espera *algún* acuse de recibo — un launcher que no reacciona en absoluto a Cmd+V se lee como colgado, no como "ocupado". El shake es la señal system-native para "acción rechazada" (mismo lenguaje que el shake de contraseña incorrecta de macOS), no una animación decorativa — no cae en la prohibición de bounce/overshoot de la sección Animaciones, que aplica a motion *de entrada/salida*, no a feedback de rechazo.
  - Especificación del shake: traslación horizontal del frame completo, ±4pt, 3 ciclos, `.easeInOut`, **160ms total**. Sin cambio de escala, sin cambio de opacity.
  - Reduce Motion: se sustituye por un pulso de opacity del frame (1 → 0.6 → 1, **150ms**, `.easeInOut`) — comunica "rechazado" sin traslación espacial.
  - Accesibilidad: se posta `AccessibilityNotification.Announcement("Espera a que termine la descarga actual")` en el momento del rechazo — el shake es puramente visual y un usuario de VoiceOver no lo percibe de otra forma.

#### Estado `.completed`

`[ícono 20×20pt, DownloadStateIcon (flecha + anillo completo, verde)] [8pt] [título 13pt Regular, .primary, 1 línea, centrado verticalmente] [Spacer] [trailing: hasta 2 botones de acción]`

**El ícono ya no cambia a un checkmark** (iteración de diseño del usuario, 2026-07-27, ver "Decisiones registradas") — es el mismo objeto flecha+anillo de `.downloading`, solo cambia de color (blanco → verde) y su anillo queda al 100%.

- Título: nombre de archivo final (mismo que `DownloadRowView.completed` mostraba).
- **Trailing accessory — dos botones, mismo diseño que tenía `DownloadRowView.completed`, con un cambio de visibilidad (ver más abajo):**
  - Ícono de la app destino (bitmap real vía `NSWorkspace.icon(forFile:)`, 12pt) — solo si hay app configurada en Settings; reabre el archivo ahí.
  - Ícono "abrir en Finder" (`folder`, SF Symbol, 12pt) — revela el archivo en Finder.
  - Mismo tap target 32×32pt cada uno (`Theme.Spacing.minimumTapTarget`), separados 2pt, orden app-destino-primero / Finder-después — sin cambios respecto a la spec anterior de `DownloadRowView`.
  - **Cambio: ambos botones ahora son visibles siempre, no solo en hover.** Antes tenía sentido ocultarlos en hover porque vivían en una fila dentro de una lista potencialmente larga — ahora el frame es la única superficie del panel y es exactamente donde el usuario ya está mirando cuando la descarga termina. Ocultar los botones detrás de hover en este único frame además es una regresión de accesibilidad real: un usuario de teclado o VoiceOver nunca dispara `onHover`, así que los botones quedaban efectivamente inalcanzables sin mouse. Siempre-visibles los hace navegables por Tab.
  - Si no hay app configurada: solo el ícono de Finder, igual que antes.

**Persistencia y cómo se sale de `.completed`:**
- El frame se queda en `.completed` **indefinidamente mientras el panel sigue abierto** — no hay timeout ni desvanecimiento automático.
- **Gesto de salida: cualquier tecla imprimible o ⌘V** transiciona el frame de vuelta a `.input` inmediatamente, insertando el carácter/pegado como si el usuario hubiera empezado a escribir en un input vacío normal — no hay paso intermedio ni una segunda pulsación necesaria.
- **Se decide NO agregar un botón ✕.** Un botón de dismiss explícito contradice el principio ya registrado en este documento ("no hay botón CTA visible en el flujo principal — Enter es la acción") y agrega una decisión visual a una superficie que ya se limpia sola con el próximo gesto natural del usuario (escribir o pegar el siguiente link, que es exactamente lo que hacía antes de esta descarga). Pedir "haz clic en ✕" es más fricción que simplemente seguir usando el campo.
- **Escape sigue cerrando el panel** (comportamiento global sin cambios) — no se sobrecarga Escape para "volver a `.input` sin cerrar", para no crear dos significados distintos de la misma tecla según el estado del frame.

#### Estado `.error`

`[ícono 20×20pt, DownloadStateIcon (flecha + anillo vacío, rojo)] [8pt] [texto de razón 13pt Regular, .red, 1 línea, centrado verticalmente] [Spacer, sin trailing accessory]`

**El ícono ya no cambia a `exclamationmark.triangle.fill`** — mismo objeto flecha+anillo que `.downloading`/`.completed`, en rojo; el anillo se muestra vacío (no hay un `%` significativo que congelar al fallar, y el estado ya se comunica con el color rojo + el fill rojo del frame).

- Fill del frame: `Color.red.opacity(0.08)` — único estado con tinte de color, señal de error, no decorativo (mismo tratamiento que tenía `.failed` en `DownloadRowView`).
- Texto: el mensaje legible de la tabla de `DownloadFailureReason` de abajo — nunca el enum crudo ni stderr de yt-dlp sin traducir. Si el título del video llegó a obtenerse antes de fallar, antecede al mensaje: "Nombre del video — mensaje de error"; si no, solo el mensaje.

**Mapeo de `DownloadFailureReason` a texto legible (sin cambios respecto a la spec anterior):**

| Caso | Texto mostrado |
|---|---|
| `.unsupportedSite` | "Este sitio no es compatible" |
| `.networkError` | "Sin conexión — reintenta" |
| `.siteBlockedOrChanged` | "El sitio cambió o bloqueó la descarga — no es un error de la app" |
| `.invalidURL` | "El link no es válido" |
| `.cancelled` | "Cancelado" |

**Cómo se vuelve al input desde `.error`: solo escribir/pegar, igual que `.completed` — sin botón "Reintentar".**
- Se decide **no** agregar un botón de reintento explícito. Razón: de los 5 casos de `DownloadFailureReason`, solo dos (`.networkError`, `.siteBlockedOrChanged`) son plausiblemente transitorios; `.invalidURL` y `.unsupportedSite` no se arreglan reintentando el mismo link, y `.cancelled` fue una decisión deliberada del usuario. Un botón "Reintentar" que solo tiene sentido en 2 de 5 casos es una superficie de UI condicionalmente útil — más complejidad que "pega el link de nuevo con ⌘V", que ya es igual de rápido y funciona para los 2 casos donde reintentar sí ayuda. Consistente con el mismo principio anti-botón que `.completed`.
- Mismo gesto exacto que `.completed`: cualquier tecla imprimible o ⌘V regresa a `.input`, insertando el carácter/pegado.

**Estado "sitio no reconocido, se intentará de todas formas" (no es un estado del frame):**
- Sin cambios respecto a la spec anterior — sigue viviendo como chip inline **debajo del frame**, solo visible cuando el frame está en `.input`. Ver sección 1 para su efecto en el alto del panel.
- Ícono `questionmark.circle`, color `.orange`, texto 11pt: "Sitio no reconocido — se intentará de todas formas". No bloquea el submit.

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

4. **About / Updates** (agregada 2026-07-28, ver Decisiones registradas)
   - Última sección del `Form`, después de "Calidad default" (y después de la sección condicional "Download Engine" si está visible).
   - Fila única: texto de versión legible a la izquierda (`"Downloader \(CFBundleShortVersionString) (\(CFBundleVersion))"`, leído del bundle en runtime — nunca hardcodeado) en 13pt `.secondary`, mismo estilo que el resto de texto de valor de las otras secciones + botón "Check for Updates…" a la derecha, mismo `DownloaderButtonStyle` pill de 28pt que "Cambiar…"/"Remove".
   - El botón se deshabilita (`disabled`) mientras Sparkle no puede iniciar una comprobación (`SPUUpdater.canCheckForUpdates == false`, típicamente porque ya hay una en curso) — nunca queda siempre habilitado. Se observa vía un pequeño `ObservableObject` (`CheckForUpdatesViewModel`) que puentea el KVO de `canCheckForUpdates` a Combine, patrón documentado por Sparkle para SwiftUI.
   - Misma acción que el ítem de menú del status item y del menú principal de la app: `SPUUpdater.checkForUpdates()` del `SPUStandardUpdaterController` ya existente en `AppDelegate` — no una segunda instancia del updater.
   - Header de sección: "About", mismo estilo 13pt Semibold que el resto.

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

**Sin cambios por el rediseño del frame único (2026-07-27).** El menu bar ring sigue reflejando `MenuBarIconRenderer.State`, derivado de `aggregateState` en `LauncherViewModel`, exactamente igual que antes — el ring no sabe ni le importa que ahora solo pueda existir una descarga a la vez en vez de N; sigue leyendo el mismo estado agregado (`idle` / `downloading(percent)` / `error`) que ya calculaba. Con una sola descarga posible, `aggregateState` deja de necesitar promediar `%` entre varias descargas activas, pero la superficie visible del menu bar — glyph, tamaño, throttle de redibujado, prioridad error > descargando > idle — no cambia en absoluto.

---

## Componentes del sistema

### Botones
- No hay botón CTA visible en el flujo principal — Enter es la acción (PRD: "cero fricción, cero diálogos intermedios"). Cualquier botón visible es secundario (Settings, menú).
- **Settings — botones de acción ("Cambiar…"):** `.buttonStyle(.glass)` en macOS 26+, pill, altura 28pt.
- **Destructivo:** no aplica en v1 (no hay delete de historial ni de filas — no hay historial).

### Listas y filas — retirado

**Ya no hay lista.** Esta sección documentaba `DownloadRowView` como componente de lista (`VStack` de filas, sin separadores, sin swipe actions). Desde el rediseño de 2026-07-27 (ver sección "Pantallas y componentes" → "El frame") no existe una lista de descargas activas — hay un único frame que muestra el estado de la única descarga en curso. No hay nada que listar, ordenar ni scrollear.

### Iconografía
- SF Symbols exclusivamente, excepto el ícono izquierdo del frame en `.downloading`/`.completed`/`.error` (`DownloadStateIcon`), que compone una flecha dibujada a mano como `Path` (`DownloadArrow`, no SF Symbol — ver "Decisiones registradas" 2026-07-27) con un anillo de progreso dibujado a mano (`ProgressRing`) — mismo lenguaje visual que `MenuBarIconRenderer`, ver sección "Ícono izquierdo del frame = anillo de progreso" arriba.
- Peso: `.regular` en filas y menu bar; `.medium` en el chip de advertencia para que destaque ligeramente más que el texto secundario adyacente.
- Estilo: outline por defecto (`clock`, `folder`, etc.); no hay más glyphs `.fill` en el frame — el ícono de estado izquierdo ya no cambia de símbolo entre `.downloading`/`.completed`/`.error`, solo de color, así que la distinción "afirmativo = glyph sólido" del sistema anterior queda retirada para ese ícono en particular.

---

## Animaciones

**Principio rector:** el panel se abre con una tecla, cientos de veces al día. Esa acción se trata como el caso "100+ veces/día" del framework de decisión de motion — la respuesta por defecto es **no animar**, y cuando se anima, el mínimo posible. Todo lo demás (transiciones de estado de fila, progreso) sí es "ocasional" y sí recibe motion completo.

| Interacción | Trigger | Motion | Duración/curva | Por qué |
|---|---|---|---|---|
| **Aparición del panel** | Hotkey / click en menu bar | Opacity 0→1 + scale 0.96→1.0, sin bounce | `.easeOut`, **120ms** | Acción disparada por teclado cientos de veces/día — se trata como Raycast/Spotlight: casi nada, solo lo suficiente para no sentirse como un "pop" abrupto. Nunca spring con overshoot: el overshoot se reserva para gestos con momentum real, y aquí no hay gesto, hay una tecla |
| **Cierre del panel** | Escape / pérdida de foco (`windowDidResignKey`) | Solo opacity 1→0, sin scale | `.easeIn` es aceptable únicamente aquí porque es una salida sin necesidad de sentirse "responsiva" — el usuario ya decidió irse | **80ms** | Salida siempre más rápida que la entrada (asimetría deliberada: entrar puede tener un ápice de materialización, salir debe sentirse instantáneo — el usuario no espera nada de la app al cerrar) |
| **Cambio de alto del panel** (aparece/desaparece el chip de advertencia — única causa restante desde el rediseño de frame único) | Reactivo a estado | Animar el alto del contenedor, `.spring(response: 0.35, dampingFraction: 1.0)` — sin bounce | ~280ms de asentamiento | Es reposicionamiento de contenido, no un gesto — tabla de Apple: "Move/reposition → damping 1.0, response 0.4"; se usa 0.35 por ser una superficie pequeña |
| **Transición entre estados del frame** (`.input` → `.downloading` → `.completed`/`.error` → `.input`) | Cambio de estado del frame | Crossfade de ícono + texto + trailing accessory (opacity, sin mover posición), `.easeOut` | **200ms** | Ocasional por descarga, no repetitivo — amerita motion completo, pero sin desplazamiento porque el frame **nunca** cambia de tamaño entre sus 4 estados (regla nueva del rediseño: el frame mide 52pt siempre) |
| **Shake de rechazo** (se pega/escribe/Enter mientras el frame está en `.downloading`) | Intento de input durante descarga activa | Traslación horizontal ±4pt, 3 ciclos, `.easeInOut` | **160ms** | Feedback de acción rechazada, no motion decorativo de entrada/salida — mismo lenguaje que el shake de contraseña incorrecta de macOS; no está sujeto a la prohibición de bounce/overshoot de esta tabla porque no es un gesto con momentum, es un acuse de recibo de "no" |
| **Progreso del ring dentro de `.downloading`** (ahora en el ícono izquierdo del frame, `DownloadStateIcon`) | Cada tick de `--progress-template` (~1/seg) | Animar el arco del `ProgressRing` hacia el nuevo `percent`, `.linear` | **200ms** por tick | Es un valor de datos entrando, no un gesto — un tween lineal corto entre el valor viejo y el nuevo evita el salto brusco de un `%` a otro sin fingir un progreso continuo que no existe. Se anima siempre, incluso bajo Reduce Motion (ver tabla de Reduce Motion) |
| **Ring de progreso del menu bar** | Cada redraw permitido (throttle de la sección Menu bar) | Sin animación explícita — es un redraw directo del valor actual | — | Redibujar un `NSImage` estático no es interpolable de forma barata; el throttle (≥2pp o 400ms) ya evita que se vea como un salto — animarlo encima sería gastar CPU en un lugar que el usuario mira de reojo, no de frente |
| **Cambio de ícono de menu bar entre estados** (idle↔downloading↔error) | Cambio de estado agregado de las descargas | Crossfade corto del `NSImage` vía `CALayer` transition | **150ms** | Evita el parpadeo de un swap instantáneo de imagen, sin ser perceptible como "animación" — dura menos que un parpadeo consciente |
| **Chip "sitio no reconocido" aparece/desaparece** | Detección de sitio en cada cambio del input, solo en `.input` | Opacity + height juntos, mismo spring que el cambio de alto del panel | ~280ms | Es parte de la misma familia de "el contenido cambia de alto" — consistencia de motion en todo el panel, un solo tipo de curva para todo lo que crece/encoge |
| **Accesorio derecho del frame — entrada** (llega el primer progreso real, `percent` pasa de 0 a >0) | Progreso real entrante en `.downloading` | `[% + ring]` desliza desde el borde trailing del frame + fade (`.move(edge: .trailing).combined(with: .opacity)`) | `.easeOut`, **220ms** (`Theme.Motion.accessorySlideDuration`) | Antes el % y el ring aparecían desde el primer instante, incluso mostrando "0%" junto a "Preparando…" — información sin sentido (0% de un progreso que ni empezó a reportarse). Ocultarlos hasta que hay un dato real y hacerlos entrar con un slide marca ese momento como un evento distinto de "empezó la descarga", no como parte del estado inicial |
| **Accesorio derecho del frame — salida** (`.downloading` → `.completed` o `.downloading` → `.error`) | Fin de la descarga | `[% + ring]` desliza hacia el borde trailing + fade, mismo par move+opacity que la entrada | `.easeOut`, **220ms** | Simetría con la entrada — el bloque se va por donde vino |
| **Accesorio derecho del frame — íconos de acción entran** (solo tras completar, nunca en error) | El slide de salida del `[% + ring]` **terminó** (no el cambio de estado en sí) | Los 2 botones de acción entran deslizando desde el trailing + fade | `.easeOut`, **220ms**, arrancando solo al `completion` del slide de salida — **encadenamiento secuencial estricto, sin solape** | Pedido explícito del usuario: el bloque de progreso no puede cruzarse visualmente con los botones de acción — deben leerse como dos eventos distintos, no como un intercambio simultáneo. Se implementa con `withAnimation(_:completion:)` (macOS 14+) en vez de un `DispatchQueue.asyncAfter` con la duración como número mágico: el `completion` está atado a la animación que realmente corrió, no a una estimación de cuánto debería tardar |
| **Ícono izquierdo del frame** (`DownloadStateIcon`: mismo objeto flecha+anillo, cambia de color blanco → verde/rojo entre `.downloading` y `.completed`/`.error`) | Cambio de estado del frame | Crossfade puro en su lugar (opacity, sin desplazamiento) — desacoplado del accesorio derecho, corre en paralelo sin esperar su coreografía | `.easeOut`, **200ms** (mismo `rowStateCrossfade` de siempre) | El ícono nunca se mueve — solo el bloque derecho tiene motion espacial. Vive fuera de la coreografía secuencial del accesorio derecho porque son dos regiones visuales distintas del frame, no un solo bloque atómico. El color ya no se anima por separado — va montado sobre el mismo crossfade de opacity del ícono+título (`.id(frameState)`), no hay una animación de color independiente que inventar |

**Reglas explícitas heredadas de las skills de motion (Emil / Apple) aplicadas aquí:**
- Nunca se usa `ease-in`/`.easeIn` para algo que **entra** — la única excepción documentada arriba es el cierre del panel, que **sale**, no entra.
- Ninguna animación en esta app supera 300ms — la más larga (280ms, spring de alto) sigue dentro del techo.
- Ninguna animación tiene bounce/overshoot — no hay un solo gesto de arrastre en toda la app (no hay drag-to-dismiss, no hay swipe); todo el motion es reactivo a datos o a teclado, así que todo usa `dampingFraction: 1.0` o easing simple, nunca `bounce > 0`. El shake de rechazo no es una excepción a esta regla porque no es un gesto de arrastre — es feedback de "acción no aceptada", una categoría distinta (ver fila de la tabla arriba).
- El progreso (ring) se trata como dato, no como decoración — se anima con `.linear`/redraw directo, nunca con una curva "bonita" que falsee la velocidad real de la descarga.

### Reduce Motion

`@Environment(\.accessibilityReduceMotion)` en `LauncherView` y en el `AppDelegate` (vía `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`, ya que el fade del menu bar vive en AppKit puro, fuera del entorno de SwiftUI):

| Animación normal | Con Reduce Motion |
|---|---|
| Aparición del panel (opacity+scale, 120ms) | Solo opacity, sin scale, misma duración |
| Cierre del panel (opacity, 80ms) | Sin cambio — ya es solo opacity |
| Spring de alto del panel (chip de advertencia) | Cross-fade de opacity únicamente, sin animar el alto (el alto salta directo al valor final) |
| Crossfade de estado del frame | Se mantiene — es opacity pura, no movimiento, no causa mareo |
| **Shake de rechazo (input durante `.downloading`)** | **Se reemplaza** por un pulso de opacity del frame (1 → 0.6 → 1, 150ms, `.easeInOut`) — sin traslación espacial. La traslación repetida es exactamente el tipo de motion que Reduce Motion existe para evitar; el pulso de opacity comunica "rechazado" sin movimiento |
| Progreso del ring (`.linear`, ahora en el ícono izquierdo) | Se mantiene siempre animado, sin excepción — es un arco llenándose (dato), no un desplazamiento espacial. Única animación de esta app que **no** se desactiva ni se sustituye bajo Reduce Motion |
| Crossfade de ícono de menu bar | Se mantiene, misma duración — swap de imagen estática, no movimiento |
| **Accesorio derecho del frame — entrada/salida del `[% + ring]` y de los íconos de acción** | Se sustituye el slide (`.move(edge: .trailing)`) por un fade puro (`.opacity`), misma duración (220ms) y **el mismo orden secuencial estricto** (salida del progreso → entrada de los íconos de acción, sin solape) — solo cambia la geometría de la transición, no el encadenamiento |

### Reduce Transparency

`@Environment(\.accessibilityReduceTransparency)`:

- El glass del panel (`.glassEffect(.regular)`) se reemplaza por un fill sólido y opaco: `Color(nsColor: .windowBackgroundColor)` a 100% de opacidad, con el mismo `cornerRadius: 24, style: .continuous`.
- Las filas (`Color.primary.opacity(0.04)`) suben a `Color.primary.opacity(0.08)` para mantener el mismo contraste relativo contra un fondo ahora opaco en vez de translúcido.
- No afecta a Settings (`Form` grouped ya es prácticamente opaco por defecto).

### Increase Contrast

Fuerza Reduce Transparency ON (ya cubierto arriba) y además: el borde del panel gana un `strokeBorder` de 1pt en `Color(nsColor: .separatorColor)` para no depender solo de la sombra para definir el límite del panel contra el fondo del escritorio.

### VoiceOver — el frame como una sola máquina de estados anunciada

El frame es **un único elemento de accesibilidad combinado** (`.accessibilityElement(children: .combine)`), igual que ya lo era cada `DownloadRowView` — pero ahora, como es el único elemento que cambia de "personalidad" varias veces durante su vida, las **transiciones entre estados se anuncian explícitamente**, no solo se reflejan pasivamente en el `accessibilityLabel`. VoiceOver no relee automáticamente un label que cambia si el foco de VoiceOver no está sobre el elemento en ese instante — y el foco real casi siempre está en el campo de texto (`.input`) o en ningún lado (el usuario alejó la mano del teclado mientras espera). Por eso cada transición dispara un `AccessibilityNotification.Announcement(...)` además de actualizar el label:

| Transición | Anuncio posteado | Label combinado resultante del frame |
|---|---|---|
| `.input` → `.downloading` | "Descargando" | "\(título o "Preparando"). Descargando, \(N) por ciento." — el `%` se incluye en el label combinado pero **no** se re-anuncia en cada tick (ver abajo), solo queda disponible si el usuario navega manualmente al elemento |
| `.downloading` → `.completed` | "Descarga completada: \(título)" | "\(título). Completado." |
| `.downloading` → `.error` | "Error: \(mensaje de la tabla de razones)" | "\(título o razón). Falló: \(mensaje)." |
| `.completed`/`.error` → `.input` (por tipear/pegar) | Ninguno — no hace falta: el usuario que acaba de tipear/pegar ya sabe lo que hizo, y el campo de texto real retoma el foco de VoiceOver de forma natural al recibir el carácter | "\(placeholder o texto actual)" (comportamiento nativo del `NSTextField`, sin cambios) |
| Shake de rechazo (input durante `.downloading`) | "Espera a que termine la descarga actual" | Sin cambio de label — es un anuncio puntual, el frame sigue anunciando "Descargando" |

- **El `%` no se anuncia en cada tick.** El ring (`ProgressRing`) ya es `accessibilityHidden(true)` (heredado de la spec anterior) y el texto "NN%" tampoco dispara un anuncio propio — solo el `AccessibilityNotification.Announcement` de la transición `.input → .downloading` se posta una vez. Anunciar cada cambio de porcentaje (~1/seg) sería spam constante para un usuario de VoiceOver; el valor sigue disponible pasivamente en el label si navegan al elemento con VO+flechas.
- **Los 2 botones de acción de `.completed` son elementos de accesibilidad independientes**, no absorbidos por el `.combine` del frame — cada uno mantiene su propio `accessibilityLabel` ya definido ("Abrir \(título) en \(app)", "Mostrar \(título) en Finder") y, por ser **siempre visibles** desde este rediseño (no hover-gated, ver sección "El frame" → `.completed`), quedan en el **orden de Tab natural** inmediatamente después del frame — antes este par de botones era inalcanzable sin mouse porque dependía de `onHover`; ahora es navegable por teclado y por VoiceOver sin ninguna acción adicional.
- **`.error` gana un `accessibilityHint`**: "Escribe o pega un nuevo link para continuar" — comunica el mecanismo de salida (que es puramente gestual/visual, "empieza a escribir") a un usuario que no puede inferirlo de la pantalla.
- El badge de sitio detectado en `.input` (12pt, texto del nombre del sitio) mantiene su `accessibilityLabel` propio sin cambios — sigue siendo parte del mismo elemento combinado que el campo de texto en ese estado.

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
| 2026-07-26 | Fila downloading: % en subtítulo izquierdo + ring circular en vez de barra | Pedido directo del usuario; consistencia visual con el ring del menu bar |
| 2026-07-26 | El % se muestra junto al ring (trailing accessory), no en el subtítulo | Iteración de diseño del usuario — mejora legibilidad (subtítulo = speed · eta solo) y alineación visual con el ring |
| 2026-07-26 | Fila downloading sin subtítulo de velocidad/ETA | Iteración de diseño del usuario — menos ruido visual, solo [icono] [título] [spacer] [% + ring] con título centrado |
| 2026-07-26 | Badge del sitio al lado izquierdo del input | Iteración de diseño del usuario — layout: [ícono + nombre del sitio] [campo de URL] en lugar de [ícono] [campo] [nombre] |
| 2026-07-27 | Input sin ícono de sitio — solo el nombre | Iteración de diseño del usuario — layout: [nombre del sitio] [campo de URL], quita ícono de SF Symbol; reduce visual clutter en una ventana compacta |
| 2026-07-27 | % y ring de la fila .downloading en blanco en vez de accentColor/secondary | Iteración de diseño del usuario — mejor contraste sobre el glass |
| 2026-07-27 | Fila .queued sin subtítulo visible | Iteración de diseño del usuario — menos ruido visual, solo título centrado; la accesibilidad sigue anunciando "En cola" |
| 2026-07-27 | Fila .completed sin subtítulo — el check verde comunica el estado | Iteración de diseño del usuario — el check verde ya es suficiente para indicar completado, el subtítulo es ruido visual redundante; la accesibilidad sigue anunciando "Completado" |
| 2026-07-27 | Fila .completed: se agrega ícono de la app destino (12pt) junto al ícono de Finder en hover | Pedido directo del usuario — permite reabrir el archivo en la app configurada sin depender solo del auto-open al completar; app destino va primero (más cerca del texto), Finder queda como respaldo |
| 2026-07-27 | **Rediseño: la lista de `DownloadRowView` queda retirada.** Todo el estado de la descarga vive en un único frame que reemplaza el input row — máquina de estados `.input` → `.downloading` → `.completed`/`.error` → `.input`, sin lista debajo. Solo una descarga a la vez. | Pedido directo del usuario. El panel es una superficie de 560pt de ancho que se abre y cierra en segundos — una lista que crece hasta 420pt para mostrar descargas concurrentes contradecía el propio principio de identidad visual de este documento ("instantánea, silenciosa, utilitaria... cualquier elemento que no ayude a pegar/detectar → Enter → confirmar que algo pasa está de más"). Restringir a una descarga a la vez elimina la necesidad de la lista, del `ScrollView` interno y de gestionar N filas simultáneas — el usuario ve exactamente una cosa: qué está pasando con el único link que pegó |
| 2026-07-27 | El frame mide 52pt fijo en sus 4 estados — nunca cambia de tamaño al cambiar de estado | Elimina la necesidad de animar alto por cambio de estado del frame (antes: "nueva fila insertada" con spring de 280ms); todas las transiciones de estado del frame son crossfade puro, más simple y más rápido de percibir que un contenedor que crece |
| 2026-07-27 | Rechazo de input durante `.downloading`: shake sutil (±4pt, 3 ciclos, 160ms), no "nada visible" | Un launcher que no reacciona en absoluto a un Cmd+V se lee como colgado, no como "ocupado" — el shake es lenguaje system-native de "acción rechazada" (mismo patrón que contraseña incorrecta de macOS), con override de opacity-pulse bajo Reduce Motion |
| 2026-07-27 | Salida de `.completed`/`.error` hacia `.input`: cualquier tecla imprimible o ⌘V — sin botón ✕ ni botón "Reintentar" | Consistente con el principio ya registrado "no hay botón CTA visible en el flujo principal — Enter es la acción". El siguiente gesto natural del usuario (escribir/pegar el próximo link) ya limpia el frame solo; un botón de reintento además solo sería útil en 2 de 5 `DownloadFailureReason`, haciendo su utilidad condicional e inconsistente |
| 2026-07-27 | Botones de acción de `.completed` (app destino + Finder) pasan de hover-only a siempre-visibles | Corrección de accesibilidad real, no solo preferencia visual: hover-only los hacía inalcanzables por teclado/VoiceOver (nunca disparan `onHover`). Al ser ahora el único frame del panel (no una fila más entre varias), mostrarlos siempre no compite por atención con nada más — y los hace navegables por Tab |
| 2026-07-27 | Al reabrir el panel: `.completed`/`.error` **no sobreviven**, siempre vuelve a `.input` — excepto si hay una descarga real en curso, que vuelve a `.downloading` con su progreso actual | Resuelve el ítem "Sin definir aún" heredado sobre persistencia de filas completadas. `.completed`/`.error` son confirmaciones pensadas para verse una vez, inmediatamente después del evento; si el usuario ya cerró el panel, se asume que las vio. Pero una descarga que sigue corriendo en background no debe "desaparecer" visualmente solo porque se cerró y reabrió el panel |
| 2026-07-27 | Coreografía de slide del accesorio derecho del frame (entra al iniciar progreso, sale al completar, secuencial estricto con los íconos de acción) | Iteración de diseño del usuario — antes el % y el ring se mostraban desde el primer instante de `.downloading` (incluso junto a "Preparando…" con 0%, sin sentido); ahora aparecen solo cuando hay un dato real, y al completar salen del cuadro antes de que entren los íconos de abrir/revelar, para que ambos bloques nunca se vean cruzándose. El contenedor derecho reserva un ancho fijo (`Theme.Size.rowTrailingAccessoryWidth`, 66pt) en los 3 estados no-`.input` para que el título nunca salte al aparecer/ocultarse el contenido |
| 2026-07-27 | Padding interno del panel reducido a la mitad: 12pt → 6pt (`Theme.Spacing.panelPadding`) | Pedido directo del usuario — el aro de glass visible alrededor del frame se sentía demasiado ancho. Cascada obligatoria por la regla `r_inner = r_outer − padding`: el radio del frame sube de 12pt a **18pt** (`Theme.Radius.row`, sigue siendo 24 − 6), y las dos alturas fijas del panel bajan de 76/98pt a **64/86pt** (`Theme.Size.panelHeightBase` / `panelHeightWithChip`). El radio de reserva del tile de ícono de sitio (hoy sin uso, ver sección 2) se actualiza en paralelo a 10pt (18 − 8) para no quedar inconsistente si se reintroduce |
| 2026-07-27 | Tipografía del input (texto y placeholder) baja de 20pt a **14pt** (`Theme.Font.input`) | Pedido directo del usuario. Se mantiene `.rounded` design y peso Regular — solo cambia el tamaño. No se tocó `Theme.Spacing.inputRowHeight` (sigue en 52pt): a 14pt el texto queda con más aire vertical dentro del frame en vez de sentirse apretado, que es el lado seguro si el criterio cambia después |
| 2026-07-27 | Placeholder del input sube de `.tertiaryLabelColor` a `.secondaryLabelColor` (`URLInputField.placeholderString`) | Pedido directo del usuario — más contraste/visibilidad contra el glass. Se probó blanco literal (`NSColor.white`) primero, pero se revirtió: era ilegible en Light Mode por no ser semántico. `.secondaryLabelColor` sí se adapta solo (≈ blanco 55% en Dark Mode, gris oscuro en Light Mode) — más visible que `.tertiary` en ambos modos, sin el riesgo de un color fijo. Sigue distinto de `.labelColor` (texto real escrito), así que la distinción placeholder/contenido no se pierde |
| 2026-07-27 | Fondo del frame se tiñe con el color de marca del sitio detectado, solo en `.input` (`Theme.Palette.siteTint`) | Pedido directo del usuario. Decisiones tomadas junto con el usuario: (1) solo en `.input`, no persiste en `.downloading`/`.completed`/`.error` — es señal de detección, no de identidad de la descarga; (2) intensidad sutil, misma opacidad (0.04 / 0.08 con Reduce Transparency) que el fill neutro que reemplaza, solo cambia el hue; (3) Instagram usa un solo color representativo (`#E1306C`) en vez del gradiente real de su logo, consistente con que los demás sitios también usan un tono sólido; (4) X usa negro (`#000000`, marca post-rebrand) en vez del azul histórico de Twitter — con el riesgo conocido de que sea casi invisible en Dark Mode, documentado en "Sin definir aún" |
| 2026-07-27 | Tinte del sitio: Instagram pasa de color plano representativo al **gradiente real de marca** (5 paradas), y la opacidad sube de 0.04/0.08 a **0.18/0.28** para todos los sitios | Pedido directo del usuario — el tinte anterior se sentía demasiado sutil, casi imperceptible. `frameFill` cambió de tipo `Color` a `AnyShapeStyle` (`LauncherView.swift`) para poder devolver indistintamente un color plano o un `LinearGradient` desde la misma propiedad computada — es la forma correcta en SwiftUI de unificar dos `ShapeStyle` concretos distintos sin duplicar la vista. El riesgo de X en Dark Mode (ver entrada anterior) mejora con la opacidad más alta pero no se resuelve del todo — sigue en "Sin definir aún" |
| 2026-07-27 | Ícono de app reemplazado por arte aportado por el usuario (squircle morado con flecha 3D) | Iteración de diseño del usuario |
| 2026-07-27 | Ícono izquierdo del frame = anillo de progreso estilo menu bar, con color por estado (blanco/verde/rojo); el anillo derecho se retira y queda solo el % | Iteración de diseño del usuario — antes el ícono izquierdo era un SF Symbol distinto por estado (`arrow.down.circle`/`checkmark.circle.fill`/`exclamationmark.triangle.fill`, azul/verde/rojo) y el progreso vivía en un `ProgressRing` separado junto al `%` a la derecha, duplicando el concepto visual de "anillo" en dos lugares del mismo frame. Ahora hay un único anillo de progreso, en el mismo objeto que ya ocupaba el espacio del ícono izquierdo, replicando el lenguaje visual de `MenuBarIconRenderer` (flecha + anillo) — el frame se lee como el "hermano a color" de la menu bar. `ProgressRing.swift` se generaliza (gana un parámetro `diameter`) y gana un nuevo componente, `DownloadStateIcon`, que compone la flecha (`arrow.down`) sobre el ring; ninguno de los dos queda sin uso |
| 2026-07-27 | Flecha del ícono de estado dibujada como Path con el mismo lineWidth del anillo | El peso del SF Symbol no coincidía con el trazo del aro — reporte del usuario. `DownloadStateIcon` sustituye `Image(systemName: "arrow.down")` por `DownloadArrow`, un `Shape` propio (asta + punta en "V") trazado con `StrokeStyle(lineWidth: Theme.Size.progressRingLineWidth, lineCap: .round, lineJoin: .round)` — el mismo token que usa `ProgressRing`, así el grosor es idéntico por construcción. Geometría proporcional al radio del `rect` (`halfHeight = radius × 0.42`, `armSpan = radius × 0.30`, `armDrop = radius × 0.34`), no hardcodeada para 20pt, así el componente sigue funcionando a cualquier diámetro. `MenuBarIconRenderer.progressRing(percent:)` tenía el mismo defecto (flecha a 1.6pt contra un anillo de 2pt) y se corrigió con la misma fórmula y el mismo `lineWidth` que el ring, para mantener los dos íconos coherentes |
| 2026-07-28 | Check for Updates disponible en el menú principal de la app y en Settings, además del menú del status item | Pedido del usuario |

---

## Ícono de app

**REEMPLAZADO 2026-07-27 — arte aportado por el usuario, ya no generado programáticamente.** La sección anterior describía un ícono dibujado por script (`CoreGraphics`/`AppKit`, squircle azul→cian con flecha+bandeja) que queda obsoleto. El ícono actual es arte final entregado por el usuario: `Downloader/Resources/AppIcon-source.png` (1024×1024, RGBA, Display P3, canvas transparente con el squircle ya recortado). Es la fuente de verdad — no hay script generador que reconstruya el arte, solo el paso de composición/escalado descrito abajo.

**Concepto:** squircle morado con degradado y una flecha de descarga en 3D con acabado brillante/cromado (sin bandeja, sin texto, sin logotipo) — sigue comunicando la misma acción única que el ícono anterior ("descargar"), pero con un tratamiento visual más ilustrativo/dimensional en vez de flat.

**Colores dominantes (del arte fuente, muestreados):** degradado de fondo diagonal de azul-violeta (`~#3B82F6`–`#5B4FE0` en la esquina superior) a púrpura profundo (`~#3D1A78`–`#241050` hacia el borde inferior/exterior), con el centro del squircle más claro/saturado (halo violeta alrededor de la flecha) que los bordes, que oscurecen hacia las esquinas. La flecha es acabado cromado/glass — blanco y gris-azulado con reflejos especulares y sombra propia, no un blanco plano — lo que le da el look "3D brillante" que pidió el usuario, distinto del blanco flat al 96% del ícono anterior.

**Regla de proporción aplicada — reescalado centrado, no 1:1:** el arte fuente llena el lienzo de borde a borde en el eje horizontal/vertical medio (el squircle toca los 4 bordes a la altura y ancho medios del canvas 1024×1024 — no deja el margen de aire que Apple especifica para íconos de macOS). Se verificó con un análisis de canal alfa (`Pillow`/`numpy`): a `y=512` y `x=512` el alfa es >200 desde el píxel 0 hasta el 1023 en ambos ejes — el squircle ocupa el 100% del ancho/alto en su punto más ancho, contra el ~80% que especifica Apple. Sin corrección, el ícono se vería notablemente más grande que sus vecinos en el Dock.

Se aplicó la regla oficial de Apple para macOS Big Sur+: **el arte ocupa 824×824pt dentro de un lienzo de 1024×1024pt (80.47%)**, centrado. El arte fuente (1024×1024 con el squircle ya recortado) se reescala completo — squircle, degradado, flecha y sombra, sin recortar ni redibujar nada — a 824×824 y se centra sobre un canvas transparente de 1024×1024 antes de generar cada tamaño final. Este 80.47% es el valor oficial de Apple, ligeramente más conservador que el 82.4% que usaba el ícono generado anteriormente (que era una aproximación propia, no la cifra exacta de Apple) — se prefirió el valor oficial ahora que hay arte real de producción en juego.

**Generación:** script Python (`Pillow`, `Downloader/Resources/AppIcon-source.png` como único input) que, para cada uno de los 10 slots del `AppIcon.appiconset`, reescala el master 1024×1024 **directamente** al tamaño de arte final de ese slot (`canvas × 0.8047`, redondeado) con remuestreo LANCZOS — sin cadena de downscalings intermedios — y lo pega centrado sobre un canvas transparente del tamaño de canvas final (16, 32, 64, 128, 256, 512, 1024). Mismo principio que el generador anterior (rasterizar cada tamaño a su resolución final, no derivar unos de otros) pero partiendo de arte de trama en vez de `CGPath` vectoriales, porque ahora la fuente es una imagen, no geometría paramétrica.

**Por qué esta paleta y no gris/monocromo como el ícono de menu bar:** sin cambios respecto a la razón ya registrada — el ícono de menu bar es template (monocromo, se re-tinta con el sistema) porque vive dentro del chrome de macOS; el ícono de app vive en Dock/Finder/App Switcher junto a íconos de otras apps con colores propios y sí necesita identidad de color reconocible a simple vista.

**Coherencia con el menu bar:** el glifo del menu bar (`arrow.down.circle` en idle, flecha simple dibujada a mano dentro del ring en `.downloading`, ver sección "Menu bar" arriba) ya es una flecha hacia abajo sin bandeja — la misma familia visual que la flecha del ícono nuevo (que tampoco tiene bandeja, a diferencia del ícono anterior). No se requirió ningún cambio en `MenuBarIconRenderer.swift`: el glifo ya es coherente con el concepto nuevo, y sigue siendo obligatoriamente monocromo/template por la razón de HIG ya documentada — no se reemplaza por una versión a color del ícono de app.

---

## Sin definir aún

- [ ] UI de captura de atajo de teclado (hotkey) en Settings — el TRD define las claves de `AppSettings` pero esta pasada de diseño se limitó a las 3 secciones pedidas (app destino, carpeta, calidad)
- [ ] Qué pasa visualmente si `RegisterEventHotKey` falla porque el atajo ya está tomado (TRD menciona "mostrar alerta clara en Settings" pero no está diseñada)
- [ ] Estado de "verificando yt-dlp" al iniciar la app (`YTDLPUpdateService`) — si debe reflejarse en algún lado de la UI o es completamente silencioso
- [ ] Qué pasa si el usuario intenta cerrar el panel (Escape) mientras el frame está en `.downloading` y luego lo reabre desde el menu bar en vez de la hotkey — el comportamiento especificado (vuelve a `.downloading` con progreso) asume el mismo flujo de apertura sin diferenciar la fuente; no debería importar, pero no fue verificado contra el AppDelegate
- [ ] Copy exacto del `AccessibilityNotification.Announcement` en inglés para VoiceOver internacional (esta pasada solo definió el copy en español, consistente con el resto de la UI, pero no revisó si el sistema debe localizar los anuncios además de las labels)
- [ ] Tinte de X (`#000000`) puede ser casi imperceptible en Dark Mode contra el panel oscuro — evaluar si necesita un tratamiento distinto (ej. blanco/gris claro) o si se acepta que sea el tinte más sutil de los cuatro
