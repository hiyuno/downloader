# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
y este proyecto usa [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
