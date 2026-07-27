---
name: updater
description: Runbook para publicar una nueva versión de Downloader vía Sparkle (distribución directa, sin App Store). Úsalo cuando el usuario pida "publicar release", "nueva versión de Downloader", "sacar un update", "release de Downloader" o similar.
---

# Updater — publicar releases de Downloader

Downloader se distribuye fuera del App Store. Las actualizaciones se entregan
con [Sparkle](https://sparkle-project.org) vía un feed (`appcast.xml`) alojado
en el repo público `hiyuno/downloader_updates`. Este runbook cubre desde el
setup one-time hasta el flujo normal de cada release y el troubleshooting.

---

## Prerequisitos one-time

Estos pasos ya se hicieron para Downloader, pero quedan documentados por si
hay que reconstruir el entorno (Mac nuevo, clave perdida, etc.).

1. **Generar el par de claves EdDSA de Sparkle bajo una cuenta dedicada.**

   Este Mac ya tenía otra clave Sparkle de otra app guardada con la cuenta
   por defecto. Para no pisarla, la clave de Downloader se generó con una
   cuenta explícita:

   ```bash
   ./bin/generate_keys --account Downloader
   ```

   (el binario `generate_keys` viene del paquete SPM de Sparkle, en
   `~/Library/Developer/Xcode/DerivedData/Downloader-*/SourcePackages/artifacts/sparkle/Sparkle/bin/`)

   Esto:
   - Guarda la clave **privada** en el Keychain de login, bajo la cuenta
     `Downloader` (servicio `https://sparkle-project.org`).
   - Imprime la clave **pública** en base64 — esa va en `SUPublicEDKey` de
     `Downloader/Info.plist`.

   **CRÍTICO:** toda firma posterior (`sign_update`) debe usar
   `--account Downloader`. Sin ese flag, `sign_update` firma con la clave por
   defecto del Keychain (la de la otra app) y la firma no valida contra
   `SUPublicEDKey` en ningún cliente — el update parecería corrupto o
   manipulado y Sparkle lo rechazaría silenciosamente.

2. **Respaldar la clave privada.** Sparkle no tiene forma de recuperarla si
   se pierde — perder la clave privada significa no poder publicar más
   updates que los clientes existentes acepten (tendrían que reinstalar
   manualmente con una `SUPublicEDKey` nueva).

   ```bash
   ./bin/generate_keys --account Downloader -x /ruta/segura/downloader_sparkle_private_key.pem
   ```

   Guarda ese archivo fuera de este repo (gestor de contraseñas, bóveda del
   equipo, etc.) — nunca lo commitees.

3. **Repo de updates.** `hiyuno/downloader_updates` (público, en GitHub) aloja
   `appcast.xml` y los releases (DMGs). `Scripts/release.sh` lo clona,
   actualiza y publica en cada release.

4. **Perfil de notarización.** `xcrun notarytool store-credentials AC_PASSWORD`
   una vez por máquina, con el Apple ID / app-specific password del equipo.
   `release.sh` usa `--keychain-profile AC_PASSWORD`.

5. **Certificado "Developer ID Application".** Debe estar en el Keychain de
   login de la máquina que corre el release, con la clave privada asociada
   (team `449S639443`). Verificable con:

   ```bash
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

---

## Flujo normal de un release

1. **Resume los cambios en `CHANGELOG.md`.** Antes de liberar, la sección
   `[Unreleased]` debe reflejar lo que realmente se va a publicar (esa
   sección es la fuente de las release notes que terminan en el appcast).

2. **Corre el script de release:**

   ```bash
   ./Scripts/release.sh 1.0.0
   ```

   (usa el siguiente semver que corresponda; el script valida que sea
   estrictamente mayor a la última versión publicada en el appcast remoto).

   El script hace todo el pipeline en orden: pre-checks → build number desde
   el appcast remoto → archive → export → verificación de firma → DMG →
   notarización → staple → firma Sparkle (`sign_update --account Downloader`)
   → publicación en GitHub → actualización del appcast. Ver comentarios en
   `Scripts/release.sh` para el detalle paso a paso.

3. **Commitea `VERSION.md` y `CHANGELOG.md`** en este repo (privado) — el
   script los actualiza localmente pero no los commitea:

   ```bash
   git add VERSION.md CHANGELOG.md
   git commit -m "Release 1.0.0 (build N)"
   ```

   El release público en `hiyuno/downloader_updates` ya quedó publicado antes
   de este paso; este commit es solo para que el repo privado tenga registro.

---

## Rollback de una release rota

Si un release se publicó con un bug grave (crashea, binario corrupto, etc.):

1. **Quita el item del appcast** para que ningún cliente nuevo lo descargue:

   ```bash
   git clone https://github.com/hiyuno/downloader_updates.git /tmp/downloader_updates_rollback
   cd /tmp/downloader_updates_rollback
   # edita appcast.xml a mano: borra el <item> completo de la versión rota
   git add appcast.xml
   git commit -m "Rollback: quitar Downloader X.Y.Z del appcast (release rota)"
   git push origin main
   ```

2. **Borra el release de GitHub** (opcional pero recomendado, para que nadie
   lo baje manualmente):

   ```bash
   gh release delete vX.Y.Z --repo hiyuno/downloader_updates --yes
   ```

3. Si ya había clientes que actualizaron a la versión rota, prepara un
   release nuevo (build siguiente) con el fix lo antes posible — Sparkle no
   tiene "downgrade" automático, así que la única salida limpia es publicar
   la versión corregida.

---

## Troubleshooting

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| **El updater no arranca / no aparece "Check for Updates"** | `SPUStandardUpdaterController` no se inicializó en `AppDelegate`, o `SUFeedURL` falta/está mal en `Info.plist`. | Verifica que `AppDelegate` instancia el controller y que `Info.plist` tiene `SUFeedURL` apuntando a `https://raw.githubusercontent.com/hiyuno/downloader_updates/main/appcast.xml`. |
| **Appcast inaccesible** | El repo `downloader_updates` es privado, no tiene `main` con `appcast.xml`, o GitHub raw está caído/rate-limited. | `curl -I https://raw.githubusercontent.com/hiyuno/downloader_updates/main/appcast.xml` — debe dar 200. Confirma que el repo es público. |
| **Sparkle no ofrece el update aunque ya publicaste** | El build number (`sparkle:version`) del appcast no es mayor al `CURRENT_PROJECT_VERSION` instalado en el cliente. Sparkle compara `sparkle:version`, no `shortVersionString`. | Revisa que `release.sh` haya calculado `NEXT_BUILD` correctamente (mayor `sparkle:version` del appcast + 1). Si se publicó a mano, corrige el appcast. |
| **Firma inválida ("update no se puede verificar")** | Dos causas posibles: (a) el asset descargado no es byte-a-byte idéntico al firmado (subida corrupta / DMG regenerado después de firmar), o (b) se firmó con `sign_update` **sin** `--account Downloader`, usando la clave equivocada del Keychain. | Para (a): compara sha256 local vs. el descargado del release; si difieren, borra el release y repite el pipeline completo (no reutilices un DMG viejo con una firma nueva). Para (b): re-firma con `sign_update --account Downloader ruta.dmg` y actualiza `sparkle:edSignature` en el appcast — nunca mezcles firma de una cuenta con la clave pública de otra. |
| **DMG sin notarizar (Gatekeeper rechaza al abrir)** | `notarytool submit --wait` falló o se saltó, o el DMG se modificó después de notarizar/graparle el ticket. | Corre `spctl -a -vvv --type install ruta.dmg` — si rechaza, hay que notarizar de nuevo desde cero (el ticket grapado es específico de ese binario exacto). Revisa el log con `xcrun notarytool log <submission-id> --keychain-profile AC_PASSWORD`. |
| **Credenciales de notarytool vencidas** | El app-specific password asociado al perfil `AC_PASSWORD` expiró o se revocó. | Genera un app-specific password nuevo en [appleid.apple.com](https://appleid.apple.com) y vuelve a guardar el perfil: `xcrun notarytool store-credentials AC_PASSWORD`. |
| **`SUPublicEDKey` vacío en `Info.plist`** | Nunca se generaron las claves, o se generaron pero no se copió la pública al plist. | `security find-generic-password -a Downloader -s https://sparkle-project.org` confirma que existe la privada. Si existe pero el plist está vacío, recupera la pública (no se puede derivar de la privada guardada en Keychain sin el binario `generate_keys`; si se perdió, hay que generar un par nuevo y aceptar que clientes viejos no podrán validar updates firmados con la clave nueva hasta reinstalar). |
| **`--timestamp` faltante en binarios embebidos** | `Scripts/embed_binaries.sh` firmó `yt-dlp`/`ffmpeg` sin timestamp de Apple (por ejemplo, sin red durante el build), lo que puede causar problemas de confianza a largo plazo o fallos de notarización intermitentes. | Revisa la lógica condicional de `--timestamp` en `Scripts/embed_binaries.sh` — debe usarse siempre que haya conectividad; solo se omite en builds Debug/offline. Si notarización falla mencionando timestamp, re-corre el build con red disponible. |

---

## Referencia rápida

- Script de release: `Scripts/release.sh`
- Historial y regla de versionado: `VERSION.md`
- Release notes por versión: `CHANGELOG.md`
- Repo de updates (appcast + DMGs): `github.com/hiyuno/downloader_updates`
- Cuenta de Keychain para las claves EdDSA: `Downloader`
- Perfil de notarización: `AC_PASSWORD`
- Team ID de firma: `449S639443` (Developer ID Application)
