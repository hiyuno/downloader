# PRD — Downloader

> Última actualización: 2026-07-26. Versión: 1.0
> Todo lo que no está aquí no está definido.

---

## Resumen

**One-liner:** Descarga video de YouTube, Instagram, TikTok y más con un atajo de teclado, pegar el link y Enter — sin abrir el navegador ni una app pesada.

**El problema:** Descargar un video hoy significa: copiar el link, abrir una app o web de terceros, elegir formato entre opciones que no importan, esperar, y luego buscar el archivo manualmente para editarlo. Para alguien que descarga clips varias veces al día (creadores, editores, community managers), esa fricción repetida rompe el flujo de trabajo.

**Usuario objetivo:** Personas que descargan video con frecuencia para editar o republicar — editores de video freelance, creadores de contenido, community managers — que ya viven en el teclado y quieren cero pasos intermedios entre "vi un video" y "lo tengo en mi editor".

---

## Plataforma y distribución

- **Plataforma:** macOS
- **Versión mínima:** macOS 14 (Sonoma)
- **Distribución:** Directo (DMG notarizado vía GitHub/web), fuera del App Store — necesario porque yt-dlp empaquetado y acceso sin sandbox a otras apps instaladas no son viables bajo las reglas del App Store
- **Sync:** Ninguno — la app es local, sin cuenta, sin backend
- **Monetización:** Sin definir en este PRD (fuera de alcance de v1; producto se valida primero como herramienta gratuita/directa)

---

## Stack preferido

- **Framework:** SwiftUI + AppKit para integración de menu bar/ventana flotante — SwiftUI resuelve la UI, AppKit cubre lo que SwiftUI no expone bien (NSStatusItem, paneles flotantes sin foco de Dock, materiales de ventana)
- **Arquitectura:** MVVM con `@Observable`
- **Bundle ID base:** [pendiente — definir cuando se registre Team ID]
- **Team ID Apple Developer:** [XXXXXXXXXX]

---

## Features — MVP

En orden de prioridad:

| # | Feature | Por qué en MVP | Criterio de aceptación |
|---|---------|---------------|----------------------|
| 1 | Hotkey global + ícono en menu bar (sin Dock) | Es la razón de ser de la app: acceso instantáneo desde cualquier contexto | Presionar el atajo desde cualquier app abre la ventana flotante centrada en <200ms; ícono visible en menu bar; sin ícono en Dock |
| 2 | Auto-detección de link en clipboard | Elimina el paso de pegar manualmente — el 90% del uso es "vi un link, quiero descargarlo ya" | Al abrir el launcher, si el clipboard contiene una URL soportada, el campo aparece pre-cargado con ella |
| 3 | Flujo core: pegar/detectar link → Enter → descarga MP4 mejor calidad | Es el producto. Cero fricción, cero decisiones en el camino feliz | Desde link válido hasta descarga iniciada: un solo Enter, sin diálogos intermedios |
| 4 | Validación de URL + detección de sitio soportado | Evita confusión cuando el link no es válido o el sitio no está soportado por yt-dlp | Al pegar un link, la UI muestra el sitio detectado (ej. "YouTube") o un error claro si no es soportado |
| 5 | Progreso visible de descargas activas en el launcher | Sin esto el usuario no sabe si la descarga está viva, se congeló, o falló | Barra o porcentaje de progreso por descarga activa, visible mientras la ventana está abierta |
| 6 | Notificación nativa post-descarga | Confirma que terminó sin que el usuario tenga que vigilar la ventana | Notificación del sistema al completar, con nombre del archivo |
| 7 | Apertura automática en app configurada post-descarga | Cierra el ciclo completo: link → archivo listo en el editor, sin tocar Finder | Si hay app configurada en Settings, el archivo se abre ahí automáticamente al terminar; si no hay app configurada, solo notificación |
| 8 | Settings: carpeta de descarga, app de destino, calidad/formato default | Necesario para que el flujo cero-fricción tenga un default correcto para cada usuario | Cambios en Settings persisten y se aplican a la siguiente descarga sin reiniciar la app |
| 9 | yt-dlp empaquetado dentro de la app | Sin dependencia de instalación externa (Homebrew, Python) — la app funciona out-of-the-box | La app descarga exitosamente en una Mac limpia sin yt-dlp preinstalado |
| 10 | Notarización y firma para distribución directa | Sin esto Gatekeeper bloquea la app y el producto es inutilizable para casi cualquier usuario | DMG notarizado se instala y abre sin advertencias de Gatekeeper |

---

## Features — Fuera del MVP

Explícitamente descartadas para V1:

- **Historial persistente de descargas** — el PRD original ya lo descarta explícitamente. Justificación adicional: mantener la app "sin memoria" simplifica el modelo mental (es una herramienta de un solo uso, no un gestor de descargas) y evita construir UI de gestión (buscar, filtrar, borrar entradas) que no es el problema que resolvemos en v1.
- **Cola avanzada de descargas** (reordenar, pausar/reanudar, límites de concurrencia configurables, prioridades) — v1 soporta múltiples descargas simultáneas mostrando su progreso, pero sin controles de gestión de cola. Justificación: la mayoría de descargas son de 1 en 1; construir gestión de cola sin validar que el usuario la necesita es esfuerzo especulativo.
- **Descarga de playlists completas** — yt-dlp lo soporta técnicamente, pero abre preguntas de producto (¿cuántos archivos? ¿dónde? ¿cómo se muestra el progreso de 50 videos en una ventana flotante pensada para 1?) que no encajan con "cero fricción". Se evalúa para v2 si hay demanda real.
- **Selector de solo-audio / extracción de MP3 como feature destacada** — el producto es explícitamente de video (target: editores de video). Meter audio-only como opción visible en el flujo principal diluye el propósito y añade una decisión al camino feliz que el PRD prohíbe. Puede vivir como opción secundaria dentro de Settings en v2, nunca en el flujo core.
- **Selector de calidad/formato en el flujo de descarga** — decisión ya tomada en el brief: solo existe como default en Settings, no como paso interactivo.
- **Login / autenticación con sitios (contenido privado, cuentas, cookies de sesión)** — añade superficie de seguridad y soporte (manejo de cookies, expiración de sesión, contenido geo-restringido) que no es necesaria para el caso de uso principal de video público.
- **Atajos de teclado personalizables / múltiples hotkeys** — v1 usa un atajo global fijo (configurable como valor único, no un sistema de keybindings). Personalización completa es pulido de v2.
- **Sync entre Macs / iCloud** — la app es una herramienta local de un solo dispositivo; no hay estado que valga la pena sincronizar en v1.
- **Soporte Windows/Linux** — fuera de alcance por decisión de plataforma (macOS nativo, sin Electron).
- **Localización a otros idiomas** — v1 en un solo idioma (el del desarrollador/mercado inicial); localización es esfuerzo de v2+ una vez validado el producto.
- **Auto-update integrado (Sparkle o similar)** — importante para el ciclo de vida del producto, pero no bloquea el uso de v1. Se prioriza justo después del lanzamiento inicial (early v1.x), no antes.

---

## Fases de desarrollo

**Fase 1 — MVP**
- Meta: Validar el flujo core end-to-end en la propia máquina del desarrollador — hotkey, clipboard, descarga, notificación, apertura en app externa.
- Estado final: El usuario puede presionar un atajo, ver un link auto-detectado o pegar uno, presionar Enter, y terminar con el MP4 en su carpeta configurada (y abierto en su editor si configuró uno) — sin tocar el navegador ni Finder.

**Fase 2 — Experiencia completa**
- Meta: Cubrir los bordes del flujo core — errores de red, sitios no soportados, actualizaciones de yt-dlp cuando un sitio cambia su estructura, múltiples descargas simultáneas robustas, manejo de la ventana flotante en multi-monitor y Spaces.
- Estado final: La app se siente confiable en uso diario real, no solo en el happy path de demo. Empaquetado y firmado, listo para notarización.

**Fase 3 — Polish y lanzamiento**
- Meta: Liquid Glass en macOS 26+, Frost en 14–15, accesibilidad (VoiceOver, Dynamic Type donde aplique), revisión HIG, notarización final, DMG y página de descarga.
- Estado final: DMG notarizado publicado en GitHub/web, instalable por un usuario externo sin fricción ni advertencias de Gatekeeper.

---

## Riesgos

- **Dependencia de yt-dlp** — es el motor completo de la app; cualquier bug, cambio de licencia, o abandono del proyecto upstream nos deja sin producto. Mitigación: empaquetar una versión específica y testeada, monitorear releases de yt-dlp, y diseñar el binario como reemplazable (proceso externo, no lib enlazada) para poder actualizarlo sin recompilar toda la app.
- **Sitios cambian su estructura constantemente** (YouTube en particular rompe extractores con frecuencia) — una descarga que funcionaba ayer puede fallar hoy sin que sea un bug nuestro. Mitigación: mecanismo simple de auto-actualización del binario yt-dlp embebido (o notificación al usuario de que hay una versión nueva), y mensajes de error que distingan "sitio cambió, actualiza yt-dlp" de "link inválido".
- **Notarización y distribución fuera del App Store sin sandbox** — Apple es cada vez más estricto con apps no-sandboxed; hay riesgo de fricción en el proceso de notarización o de que Gatekeeper trate la app con más sospecha por acceder a otras apps instaladas (para abrir el archivo post-descarga) y a rutas de descarga fuera del sandbox. Mitigación: seguir el flujo de notarización estándar temprano (no dejarlo para el final), probar en una Mac limpia antes de cada release.
- **Aspectos legales/ToS de scraping de video** (especialmente Instagram, TikTok, Twitter/X son agresivos deshabilitando descargas de terceros) — riesgo de que ciertos sitios bloqueen requests de yt-dlp periódicamente, generando percepción de "la app no funciona" cuando es un bloqueo del sitio. Mitigación: comunicar en la UI cuando el fallo es del sitio, no de la app; no prometer soporte permanente de ningún sitio específico.
- **Ventana flotante global + hotkey compitiendo con otras apps** (Spotlight, Raycast, Alfred, otros launchers) — riesgo de conflictos de atajo de teclado o de fricción si el usuario ya tiene un launcher que "hace de todo". Mitigación: atajo default poco común y fácilmente configurable, posicionar el producto como complemento (descarga de video) no como reemplazo de Spotlight/Raycast.

---

## Decisiones registradas

| Fecha | Decisión | Razón |
|-------|----------|-------|
| 2026-07-26 | PRD inicial v1 creado | Formaliza las decisiones ya tomadas con el usuario antes de que Avie defina arquitectura |
| 2026-07-26 | Sin historial persistente en v1 | Mantener la app como herramienta de un solo uso, no un gestor de descargas; simplifica UI y modelo mental |
| 2026-07-26 | Sin cola avanzada de descargas en v1 | Uso típico es 1 descarga a la vez; evitar construir gestión especulativa sin validar demanda |
| 2026-07-26 | Sin soporte de playlists en v1 | Rompe el modelo de "ventana flotante para 1 descarga"; abre preguntas de UX no resueltas |
| 2026-07-26 | Solo-audio no es feature destacada en v1 | Producto está posicionado para video; meterlo en el flujo core diluye el propósito y añade fricción prohibida por el brief |
| 2026-07-26 | Distribución fuera del App Store, sin sandbox | yt-dlp empaquetado y apertura automática en apps de terceros no son compatibles con las restricciones del App Store |
| 2026-07-26 | Monetización sin definir en v1 | Validar el producto primero como herramienta gratuita antes de comprometerse a un modelo de negocio |
