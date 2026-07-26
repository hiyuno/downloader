# DESIGN_FROST — Downloader

> Estilo para macOS 14–15 (Sonoma / Sequoia) — materiales SwiftUI / `NSVisualEffectView`.
> Última actualización: 2026-07-26.
> Tipografía, color semántico, espaciado, radios y **todas las animaciones**: ver `DESIGN_LIQUID.md` — idénticos en ambas versiones. Esta app no tiene motion "solo de Liquid Glass"; el único motion adicional en 26+ sería el materializado especular del glass, que Frost no intenta imitar (ver Materiales abajo).

---

## Qué cambia respecto a `DESIGN_LIQUID.md`

Solo el **material del panel launcher**. Todo lo demás — dimensiones, radios (24/12/12), tipografía, color semántico, layout de filas, contenido de Settings, throttle del menu bar, curvas y duraciones de animación — es exactamente lo mismo. Frost no es una versión "reducida" del diseño, es el mismo diseño con una superficie translúcida distinta por debajo.

---

## Materiales — Panel launcher (macOS 14–15)

El `NSPanel` (`LauncherPanel`, TRD sección 2) tiene `backgroundColor = .clear` en ambas versiones — el fondo visual vive en la SwiftUI root view vía el mismo `.glassPanelBackground()` de `DESIGN_LIQUID.md`, ramificado con `#available`:

```swift
extension View {
    func frostPanelBackground() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
    }
}
```

- **Material:** `.ultraThinMaterial` de SwiftUI (que internamente es un `NSVisualEffectView`) — no un `.hudWindow` custom vía AppKit puenteado; SwiftUI's `.background(material:)` ya resuelve esto sin código AppKit adicional, consistente con la nota del TRD ("ya es el estándar de macOS pre-26, no hay que construir nada custom").
- **Stroke de definición:** Liquid Glass tiene highlights especulares dinámicos que definen el borde del panel contra el fondo; `.ultraThinMaterial` solo no los tiene, así que un `strokeBorder` de 1pt blanco al 15% de opacidad reemplaza esa función — sin este borde, el panel se puede leer como un rectángulo borroso sin límite claro sobre fondos oscuros o con mucho contraste detrás.
- **Sin variante "clear"** — no existe tal cosa en `.ultraThinMaterial`; no aplica la distinción Regular/Clear de Liquid Glass.

## Materiales — Filas y contenido interno

Sin cambios respecto a Liquid Glass: las filas (`DownloadRowView`) y el input **nunca** llevaron material propio en ninguna versión — son fills planos (`Color.primary.opacity(0.04)`, `Color.red.opacity(0.08)` para failed) sobre el único glass del panel. Esto es idéntico en Frost.

## Materiales — Ventana de Settings

Sin cambios — `Form` con `.formStyle(.grouped)` ya usa el fondo de grupo estándar de macOS 14+, no dependiente de Liquid Glass.

## Sombras (compensan la ausencia de especularidad de Liquid Glass)

Liquid Glass separa el panel del fondo con luz; Frost necesita algo más de sombra para lograr el mismo efecto de "flotar":

```swift
.shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 8)  // panel launcher completo
```

Esta sombra **no existe** en la versión Liquid Glass (el glass ya se separa visualmente por sí solo vía refracción/blur dinámico) — es una adición específica de Frost, no un valor compartido.

---

## Menu bar — sin cambios

El ícono del `NSStatusItem` (idle / descargando / error, sección "Menu bar" de `DESIGN_LIQUID.md`) es idéntico en ambas versiones: son `NSImage` template dibujados directamente, no dependen de Liquid Glass en absoluto — un `NSStatusItem` nunca tuvo glass, en ninguna versión de macOS.

---

## Accesibilidad — diferencias respecto a Liquid Glass

| Ajuste | Liquid Glass (26+) | Frost (14–15) |
|---|---|---|
| Reduce Transparency | Glass → fill opaco `Color(nsColor: .windowBackgroundColor)` | `.ultraThinMaterial` → mismo fill opaco `Color(nsColor: .windowBackgroundColor)`, se quita también el `strokeBorder` (ya no hace falta, el fondo opaco define el límite por sí solo) |
| Increase Contrast | Fuerza Reduce Transparency + stroke de 1pt separator | Igual — el stroke que Frost ya tiene por defecto (blanco 15%) se reemplaza por `Color(nsColor: .separatorColor)` a 1pt, mismo tratamiento que Liquid Glass en este modo |
| Reduce Motion | Ver tabla en `DESIGN_LIQUID.md` | Idéntico — el motion no depende del material de fondo |

---

## Decisiones registradas

| Fecha | Decisión | Razón |
|-------|----------|-------|
| 2026-07-26 | `.ultraThinMaterial` de SwiftUI en vez de `NSVisualEffectView` puenteado a mano | SwiftUI ya expone el material correcto sin código AppKit adicional; el `NSPanel` solo necesita `backgroundColor = .clear` y dejar que la vista SwiftUI pinte encima |
| 2026-07-26 | Se agrega `strokeBorder` blanco 15% + sombra 24pt/25% que no existen en la versión Liquid Glass | Compensan la ausencia de especularidad dinámica del glass real — sin esto el panel se ve "plano" y sin límite definido en Frost |
| 2026-07-26 | Botones "Cambiar…"/"Quitar" de Settings (`DownloaderButtonStyle`) usan `.thinMaterial` en Frost, no fill plano `Color.primary.opacity(...)` como estaba antes del review de Larry | No era intencional — era una inconsistencia entre ramas: en macOS 26+ el mismo botón ya es `.glassEffect(.regular)` (translúcido), pero el fallback pre-26 era un fill sólido opaco, dando dos tratamientos visuales distintos para el mismo componente según versión de OS. La regla general de Jonny (tabla de compatibilidad: "Botón secundario" → `.glass` en 26+, `.background(.thinMaterial, in: Capsule())` antes) ya definía el fallback correcto; `DownloaderButtonStyle` simplemente no la seguía. Esto **no** choca con la regla de "nunca material sobre material" del panel launcher — el botón vive en la ventana de Settings, sobre un `Form` con fondo de ventana opaco de sistema, no sobre el glass del panel, así que no hay stacking de materiales. Feedback de press se simplificó a `.opacity(configuration.isPressed ? 0.7 : 1)` en ambas ramas, igualando el tratamiento que ya usaba la rama Liquid Glass, en vez de variar la opacidad del fill. |
