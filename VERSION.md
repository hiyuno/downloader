# Versionado — Downloader

## Estado actual

- **Publicado actualmente:** ninguno. No hay releases en `hiyuno/downloader_updates` todavía.
- **En el repo (sin publicar):** `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` (valores base en `project.yml`, no corresponden a un release real).
- **Próxima versión sugerida:** `1.0.0` build `1` — primer release público.

## Historial de releases

| Versión | Build | Fecha | Notas |
|---------|-------|-------|-------|
| — | — | — | (todavía no hay releases publicados) |

## Regla de oro

**El build number lo dicta el appcast remoto + 1.**

`Scripts/release.sh` lee `sparkle:version` del `appcast.xml` publicado en
`hiyuno/downloader_updates`, toma el mayor valor encontrado, y usa `+1` como
`CURRENT_PROJECT_VERSION` del nuevo build. Si el appcast no existe o no tiene
items, el próximo build es `1`.

Este archivo (`VERSION.md`) es **informativo** — se actualiza al final de cada
release para que el equipo tenga una referencia rápida sin tener que consultar
GitHub. **El appcast remoto es la única fuente de verdad** sobre qué build
number sigue. Si este archivo y el appcast alguna vez no coinciden, gana el
appcast.
