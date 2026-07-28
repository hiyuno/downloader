# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
y este proyecto usa [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **Check for Updates.** You can now check for new versions of Downloader
  directly from the app's main menu, and from a new section in Settings that
  shows the currently installed version alongside a button to check for
  updates.

## [1.2.0] - 2026-07-28

### Fixed

- **Instagram videos now play correctly.** Some Instagram downloads were
  saved in a codec (VP9) that QuickTime and Finder can't preview or play.
  Downloader now picks Instagram's progressive H.264 streams instead, so
  every downloaded video opens and plays normally.

### Changed

- **New app icon.** A fresh squircle icon with a 3D arrow, in every required
  size.
- **Redesigned progress indicator.** The arrow icon on the left of the
  download panel now sits inside a ring that fills in as the download
  progresses — white while downloading, green when it finishes, red if it
  fails. The separate progress ring on the right side was removed, leaving
  just the percentage.

## [1.1.1] - 2026-07-28

### Changed

- **Transición más clara al descargar y al completar.** El panel ahora anima
  con más intención el paso de "Preparando…" a la descarga en curso: el
  porcentaje y el anillo de progreso dejan de aparecer prematuramente y
  entran deslizándose apenas arranca el progreso real. Al completar la
  descarga, ese mismo indicador se retira antes de que aparezcan los
  accesos para abrir el archivo y revelarlo en Finder, evitando que todo
  cambie de golpe. El ícono de estado a la izquierda pasa de flecha a check
  con un fundido suave, sin saltos. Si ocurre un error, el indicador
  simplemente se retira. Quienes tienen activado "Reducir movimiento" ven
  la misma secuencia con fundidos en vez de deslizamientos.

## [1.1.0] - 2026-07-27

### Changed

- **Rediseño del launcher: ahora es un solo panel, no una lista.** Downloader
  deja atrás la lista de descargas con historial y pasa a un panel compacto
  de una sola pieza que muestra siempre la descarga activa — sin scroll, sin
  filas acumulándose.
- **Una descarga a la vez.** Si pegas una URL nueva mientras hay una descarga
  en curso, el panel la rechaza con una pequeña animación de rebote en vez de
  encolarla o reemplazarla en silencio — así siempre sabes qué se está
  descargando.
- **Acciones siempre visibles.** Los botones para abrir el archivo en Finder
  y para abrir la app de destino ya no dependen de pasar el mouse por
  encima ni de expandir una fila: están presentes desde que la descarga
  arranca.
- **Título con estado claro mientras carga.** Mientras yt-dlp resuelve la
  información del video, el panel muestra "Preparando…" en vez de dejar el
  título en blanco.
- **Transiciones pensadas para accesibilidad.** Los cambios de estado
  (esperando URL → descargando → completado/error) usan animaciones breves
  y con propósito, respetando "Reducir movimiento" del sistema.

## [1.0.0] - 2026-07-27

### Added

- Launcher macOS para descargar videos con yt-dlp, con lista de descargas y
  progreso en vivo por fila (`DownloadRowView`).
- Descarga y conversión de video/audio embebiendo binarios de `yt-dlp` y
  `ffmpeg` firmados dentro del bundle de la app (`Scripts/embed_binaries.sh`).
- Pantalla de Settings manual.
- Validador de URLs robusto (soporta esquemas de un solo colon).
- Revisión de accesibilidad (VoiceOver, Dynamic Type) y ajustes de HIG en
  materiales/botones del tema "Frost".
- Icono de app.
- Suite de tests unitarios (63/63 verdes).
- Actualizaciones automáticas vía Sparkle 2.6.4 (SPM), con
  `SPUStandardUpdaterController` integrado en `AppDelegate`, feed en
  `hiyuno/downloader_updates` y firma de builds Release con identidad
  Developer ID (team 449S639443).
- Pipeline de distribución directa: `project.yml` con firma Release real,
  Debug ad-hoc, `Makefile` con targets `gen/build/test/archive/export-direct`,
  y `ExportOptions/Direct.plist`.

### Pending

- Generar y publicar el par de claves EdDSA de Sparkle (`SUPublicEDKey` sigue
  vacío en `Info.plist`).
- Primer release público (`1.0.0` build `1`).
