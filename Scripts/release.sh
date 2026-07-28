#!/usr/bin/env bash
#
# release.sh — pipeline de release de Downloader (distribución directa + Sparkle).
#
# Uso:
#   ./Scripts/release.sh 1.0.0
#
# Qué hace (en orden): valida el entorno, calcula el próximo build number a
# partir del appcast remoto, archiva y exporta la app firmada, la notariza,
# genera el DMG, firma el update con Sparkle, publica el release en GitHub y
# actualiza el appcast — en ese orden, para que ningún cliente vea nunca un
# appcast apuntando a un asset que todavía no existe.
#
# Requiere: xcodegen, xcodebuild, gh (autenticado), notarytool (perfil
# AC_PASSWORD en Keychain), curl, git, python3, shasum, hdiutil, codesign,
# spctl, stapler, sign_update (de Sparkle).
#
# NO se ejecuta automáticamente por CI — requiere Keychain/certificados del
# desarrollador. Se corre a mano desde la máquina que tiene la identidad
# "Developer ID Application" y el perfil de notarytool.

set -euo pipefail

# ---------------------------------------------------------------------------
# Constantes / rutas
# ---------------------------------------------------------------------------

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# xcodebuild requiere la instancia completa de Xcode (no Command Line Tools)
# para archivar/exportar apps firmadas. `make test` ya fuerza esto vía
# DEVELOPER_DIR; lo exportamos aquí también para que los xcodebuild directos
# de este script (archive, exportArchive) usen la misma toolchain sin
# depender de `xcode-select -s` global de la máquina.
if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

APP_NAME="Downloader"
SCHEME="Downloader"
PROJECT="${APP_NAME}.xcodeproj"
ARCHIVE_PATH="build/${APP_NAME}.xcarchive"
EXPORT_PATH="build/export"
EXPORT_OPTIONS="ExportOptions/Direct.plist"
INFO_PLIST="Downloader/Info.plist"
CHANGELOG="CHANGELOG.md"
VERSION_MD="VERSION.md"

TEAM_ID="449S639443"
SIGN_IDENTITY="Developer ID Application"
NOTARY_PROFILE="AC_PASSWORD"

# Esta máquina ya tenía otra clave Sparkle de otra app en el Keychain por
# defecto, así que las claves EdDSA de Downloader viven en la cuenta
# "Downloader" (generate_keys --account Downloader). TODA firma con
# sign_update DEBE pasar --account Downloader — sin ese flag, sign_update usa
# la clave por defecto (la de la otra app) y el appcast quedaría firmado con
# la clave equivocada: Sparkle validaría la firma contra SUPublicEDKey y
# fallaría en todos los clientes.
SPARKLE_KEYCHAIN_ACCOUNT="Downloader"

UPDATES_REPO_SLUG="hiyuno/downloader_updates"
UPDATES_REPO_URL="https://github.com/${UPDATES_REPO_SLUG}.git"
APPCAST_RAW_URL="https://raw.githubusercontent.com/${UPDATES_REPO_SLUG}/main/appcast.xml"
APPCAST_FILE="appcast.xml"

WORK_DIR=""
DMG_PATH=""
DMG_NAME=""
DMG_SHA_LOCAL=""
NEXT_BUILD=""
VERSION=""
RELEASE_CREATED=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

step() {
  echo ""
  echo "==> $*"
}

abort() {
  echo ""
  echo "ERROR: $*" >&2
  cleanup_on_failure
  exit 1
}

cleanup_on_failure() {
  if [ "${RELEASE_CREATED}" = "1" ]; then
    echo "" >&2
    echo "AVISO: el release v${VERSION} ya se creó en ${UPDATES_REPO_SLUG} pero el" >&2
    echo "pipeline falló DESPUÉS de ese paso. El appcast probablemente NO se" >&2
    echo "actualizó (por diseño, para no anunciar un asset roto). Antes de" >&2
    echo "reintentar, revisa manualmente:" >&2
    echo "  gh release view v${VERSION} --repo ${UPDATES_REPO_SLUG}" >&2
    echo "y decide si borrarlo (gh release delete v${VERSION} --repo ${UPDATES_REPO_SLUG} --yes)" >&2
    echo "antes de correr el script de nuevo." >&2
  fi
  if [ -n "${WORK_DIR}" ] && [ -d "${WORK_DIR}" ]; then
    echo "Directorio temporal conservado para inspección: ${WORK_DIR}" >&2
  fi
}

trap 'cleanup_on_failure' ERR

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || abort "falta el comando requerido: $1"
}

# ---------------------------------------------------------------------------
# 0. Argumentos
# ---------------------------------------------------------------------------

if [ "${#}" -ne 1 ]; then
  abort "uso: ./Scripts/release.sh <MARKETING_VERSION>   (ej: ./Scripts/release.sh 1.0.0)"
fi

VERSION="$1"

if ! [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  abort "'${VERSION}' no es un semver válido (formato esperado: X.Y.Z)"
fi

step "Release Downloader ${VERSION} — iniciando pipeline"

# ---------------------------------------------------------------------------
# 1. Pre-checks
# ---------------------------------------------------------------------------

step "1/13 — Pre-checks"

for cmd in git xcodegen xcodebuild gh curl python3 shasum hdiutil codesign spctl xcrun security; do
  require_cmd "${cmd}"
done

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "${CURRENT_BRANCH}" != "main" ]; then
  abort "debes estar en 'main' para hacer un release (rama actual: ${CURRENT_BRANCH})"
fi

if [ -n "$(git status --porcelain)" ]; then
  abort "hay cambios sin commitear. Commitea o descarta antes de hacer release:\n$(git status --porcelain)"
fi

echo "  - rama main limpia: OK"

if ! gh auth status >/dev/null 2>&1; then
  abort "gh CLI no está autenticado. Corre 'gh auth login' primero."
fi
echo "  - gh CLI autenticado: OK"

if ! security find-identity -v -p codesigning | grep -q "${SIGN_IDENTITY}"; then
  abort "no se encontró la identidad '${SIGN_IDENTITY}' en el Keychain. Verifica el certificado."
fi
echo "  - identidad '${SIGN_IDENTITY}' presente en Keychain: OK"

SPARKLE_PUBLIC_KEY="$(python3 - "${INFO_PLIST}" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as f:
    data = plistlib.load(f)
print(data.get("SUPublicEDKey", ""))
PY
)"

if [ -z "${SPARKLE_PUBLIC_KEY}" ]; then
  abort "SUPublicEDKey está vacío en ${INFO_PLIST}. Genera las claves EdDSA con \
'generate_keys' de Sparkle, pega la pública en Info.plist y guarda la privada \
en Keychain antes de hacer un release. Ver .claude/skills/updater/SKILL.md."
fi
echo "  - SUPublicEDKey presente en Info.plist: OK"

if ! security find-generic-password -a "${SPARKLE_KEYCHAIN_ACCOUNT}" -s "https://sparkle-project.org" >/dev/null 2>&1; then
  abort "no se encontró la clave privada EdDSA de Sparkle en el Keychain bajo la \
cuenta '${SPARKLE_KEYCHAIN_ACCOUNT}' (generate_keys --account ${SPARKLE_KEYCHAIN_ACCOUNT}). \
Sin esta clave, sign_update --account ${SPARKLE_KEYCHAIN_ACCOUNT} no puede firmar el update."
fi
echo "  - clave privada EdDSA en Keychain (cuenta '${SPARKLE_KEYCHAIN_ACCOUNT}'): OK"

if [ ! -f "Downloader/Resources/bin/yt-dlp" ] || [ ! -f "Downloader/Resources/bin/ffmpeg" ]; then
  abort "faltan binarios en Downloader/Resources/bin/ (yt-dlp y/o ffmpeg). \
No se puede publicar una app que no descarga."
fi
echo "  - binarios yt-dlp/ffmpeg presentes: OK"

step "2/13 — make test"
if ! make test; then
  abort "'make test' falló. No se publica un release con tests en rojo."
fi
echo "  - make test: verde"

# ---------------------------------------------------------------------------
# 2. Leer appcast remoto → calcular NEXT_BUILD, validar VERSION
# ---------------------------------------------------------------------------

step "3/13 — Leyendo appcast remoto para calcular el próximo build"

APPCAST_REMOTE_CONTENT=""
HTTP_CODE="$(curl -s -o /tmp/downloader_appcast_check.xml -w "%{http_code}" "${APPCAST_RAW_URL}" || echo "000")"

if [ "${HTTP_CODE}" = "200" ]; then
  APPCAST_REMOTE_CONTENT="$(cat /tmp/downloader_appcast_check.xml)"
fi
rm -f /tmp/downloader_appcast_check.xml

if [ -z "${APPCAST_REMOTE_CONTENT}" ]; then
  echo "  - no hay appcast remoto (o está vacío/inaccesible) → este es el primer release"
  NEXT_BUILD=1
  LAST_SHORT_VERSION=""
else
  # Extrae el mayor sparkle:version y el shortVersionString asociado al item más reciente.
  read -r LAST_BUILD LAST_SHORT_VERSION <<PY_OUT
$(python3 - <<PY
import re, sys

content = """${APPCAST_REMOTE_CONTENT}"""
# El appcast real usa sintaxis de elemento (<sparkle:version>N</sparkle:version>),
# no de atributo (sparkle:version="N") -- soportamos ambas por robustez.
versions = [int(v) for v in re.findall(r'<sparkle:version>(\\d+)</sparkle:version>', content)]
versions += [int(v) for v in re.findall(r'sparkle:version="(\\d+)"', content)]
if not versions:
    print("0 none")
else:
    max_v = max(versions)
    # shortVersionString del item con ese sparkle:version (sintaxis de elemento)
    m = re.search(
        r'<sparkle:version>%d</sparkle:version>\\s*<sparkle:shortVersionString>([^<]+)</sparkle:shortVersionString>' % max_v,
        content,
    )
    if not m:
        m = re.search(
            r'<sparkle:shortVersionString>([^<]+)</sparkle:shortVersionString>\\s*<sparkle:version>%d</sparkle:version>' % max_v,
            content,
        )
    if not m:
        # fallback a sintaxis de atributo por si algún appcast viejo la usa
        m = re.search(r'sparkle:version="%d"[^>]*sparkle:shortVersionString="([^"]+)"' % max_v, content)
    if not m:
        m = re.search(r'sparkle:shortVersionString="([^"]+)"[^>]*sparkle:version="%d"' % max_v, content)
    short = m.group(1) if m else "none"
    print(max_v, short)
PY
)
PY_OUT

  if [ "${LAST_BUILD}" = "0" ]; then
    echo "  - appcast remoto existe pero no tiene items → este es el primer release"
    NEXT_BUILD=1
    LAST_SHORT_VERSION=""
  else
    NEXT_BUILD=$((LAST_BUILD + 1))
    echo "  - último build publicado: ${LAST_BUILD} (versión ${LAST_SHORT_VERSION})"
    echo "  - próximo build: ${NEXT_BUILD}"
  fi
fi

if [ "${LAST_SHORT_VERSION}" != "" ] && [ "${LAST_SHORT_VERSION}" != "none" ]; then
  # Comparación semver estricta: VERSION debe ser mayor que LAST_SHORT_VERSION.
  HIGHER="$(python3 - "${VERSION}" "${LAST_SHORT_VERSION}" <<'PY'
import sys

def parse(v):
    parts = v.split(".")
    if len(parts) != 3 or not all(p.isdigit() for p in parts):
        return None
    return tuple(int(p) for p in parts)

new = parse(sys.argv[1])
old = parse(sys.argv[2])
if new is None:
    print("invalid_new")
elif old is None:
    # Versión previa no es semver estricto (release manual raro) — no bloquear, avisar.
    print("unknown_old")
else:
    print("yes" if new > old else "no")
PY
)"

  if [ "${HIGHER}" = "invalid_new" ]; then
    abort "'${VERSION}' no pudo parsearse como semver"
  elif [ "${HIGHER}" = "no" ]; then
    abort "la versión ${VERSION} no es estrictamente mayor que la última publicada (${LAST_SHORT_VERSION})"
  elif [ "${HIGHER}" = "unknown_old" ]; then
    echo "  - AVISO: no se pudo interpretar la versión previa (${LAST_SHORT_VERSION}) como semver estricto; continuando sin comparar"
  else
    echo "  - ${VERSION} > ${LAST_SHORT_VERSION}: OK"
  fi
fi

DMG_NAME="${APP_NAME}-${VERSION}.dmg"

# ---------------------------------------------------------------------------
# 3. xcodegen + archive
# ---------------------------------------------------------------------------

step "4/13 — xcodegen generate"
xcodegen generate

step "5/13 — xcodebuild archive (Release, build ${NEXT_BUILD}, versión ${VERSION})"
rm -rf "${ARCHIVE_PATH}"
xcodebuild -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "${ARCHIVE_PATH}" \
  CURRENT_PROJECT_VERSION="${NEXT_BUILD}" \
  MARKETING_VERSION="${VERSION}" \
  archive \
  || abort "xcodebuild archive falló"

# ---------------------------------------------------------------------------
# 4. Export
# ---------------------------------------------------------------------------

step "6/13 — xcodebuild -exportArchive"
rm -rf "${EXPORT_PATH}"
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS}" \
  || abort "xcodebuild -exportArchive falló"

APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
if [ ! -d "${APP_PATH}" ]; then
  abort "no se encontró ${APP_PATH} después del export"
fi

# ---------------------------------------------------------------------------
# 5. Verificación de firma
# ---------------------------------------------------------------------------

step "7/13 — Verificando firma de código"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}" \
  || abort "codesign --verify falló sobre ${APP_PATH}"
echo "  - codesign --verify --deep --strict: OK"

check_team_id() {
  local target="$1"
  local label="$2"
  local team
  team="$(codesign -dvv "${target}" 2>&1 | awk -F'=' '/^TeamIdentifier=/{print $2}')"
  if [ "${team}" != "${TEAM_ID}" ]; then
    abort "${label} tiene TeamIdentifier='${team}' (esperado '${TEAM_ID}'): ${target}"
  fi
  echo "  - ${label}: TeamIdentifier=${team} OK"
}

if [ -d "${APP_PATH}/Contents/MacOS/bin" ]; then
  for bin in "${APP_PATH}/Contents/MacOS/bin"/*; do
    [ -f "${bin}" ] || continue
    check_team_id "${bin}" "binario embebido $(basename "${bin}")"
  done
else
  abort "no existe ${APP_PATH}/Contents/MacOS/bin — los binarios yt-dlp/ffmpeg no se embebieron"
fi

SPARKLE_FRAMEWORK="${APP_PATH}/Contents/Frameworks/Sparkle.framework"
if [ -d "${SPARKLE_FRAMEWORK}" ]; then
  check_team_id "${SPARKLE_FRAMEWORK}" "Sparkle.framework"
else
  abort "no se encontró Sparkle.framework embebido en ${APP_PATH}/Contents/Frameworks"
fi

step "spctl -a -vv (Gatekeeper, pre-notarización — se espera 'rejected' aquí)"
spctl -a -vv "${APP_PATH}" 2>&1 || echo "  - (esperado: Gatekeeper aún rechaza porque falta notarizar)"

# ---------------------------------------------------------------------------
# 6. DMG
# ---------------------------------------------------------------------------

step "8/13 — Creando DMG"

WORK_DIR="$(mktemp -d /tmp/downloader_release.XXXXXX)"
DMG_STAGING="${WORK_DIR}/dmg_staging"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_PATH}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

mkdir -p "${EXPORT_PATH}"
DMG_PATH="${EXPORT_PATH}/${DMG_NAME}"
rm -f "${DMG_PATH}"

hdiutil create -volname "${APP_NAME}" \
  -srcfolder "${DMG_STAGING}" \
  -ov -format UDZO \
  "${DMG_PATH}" \
  || abort "hdiutil create falló"

echo "  - DMG creado: ${DMG_PATH}"

# hdiutil no firma el DMG. Sin firma, notarytool igual acepta el envío (solo
# notariza el contenido firmado dentro), pero `spctl -a --type install` sobre
# el DMG grapado falla con "no usable signature" — Gatekeeper necesita una
# firma Developer ID válida en el contenedor, no solo el ticket grapado.
codesign --force --sign "${SIGN_IDENTITY}" --timestamp "${DMG_PATH}" \
  || abort "codesign del DMG falló"
echo "  - DMG firmado con '${SIGN_IDENTITY}'"

DMG_SHA_LOCAL="$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
DMG_SIZE_BYTES="$(stat -f%z "${DMG_PATH}")"
echo "  - sha256 local (pre-notarización... se recalcula tras staple): ${DMG_SHA_LOCAL}"

# ---------------------------------------------------------------------------
# 7. Notarización
# ---------------------------------------------------------------------------

step "9/13 — Notarizando (xcrun notarytool submit --wait)"

NOTARY_LOG="${WORK_DIR}/notarytool_submit.json"
if ! xcrun notarytool submit "${DMG_PATH}" \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait \
  --output-format json \
  > "${NOTARY_LOG}" 2>&1; then
  echo "--- notarytool output ---"
  cat "${NOTARY_LOG}" >&2 || true
  abort "notarytool submit falló (ver log arriba)"
fi

cat "${NOTARY_LOG}"

SUBMISSION_ID="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('id',''))" "${NOTARY_LOG}" 2>/dev/null || echo "")"
NOTARY_STATUS="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('status',''))" "${NOTARY_LOG}" 2>/dev/null || echo "")"

if [ "${NOTARY_STATUS}" != "Accepted" ]; then
  echo "--- notarytool log (submission ${SUBMISSION_ID}) ---" >&2
  xcrun notarytool log "${SUBMISSION_ID}" --keychain-profile "${NOTARY_PROFILE}" 2>&1 >&2 || true
  abort "notarización rechazada (status: ${NOTARY_STATUS}). Ver log arriba."
fi

echo "  - notarización aceptada (submission ${SUBMISSION_ID})"

# ---------------------------------------------------------------------------
# 8. Staple + verificación Gatekeeper
# ---------------------------------------------------------------------------

step "10/13 — Grapando ticket de notarización (stapler)"

xcrun stapler staple "${DMG_PATH}" || abort "stapler staple falló sobre ${DMG_PATH}"

spctl -a -vvv --type install "${DMG_PATH}" \
  || abort "spctl -a -vvv --type install falló DESPUÉS de grapar — Gatekeeper rechazaría este DMG"
echo "  - spctl -a -vvv --type install: OK (Gatekeeper acepta el DMG grapado)"

# El staple modifica el DMG — el sha256 que se sube/publica es el POST-staple.
DMG_SHA_LOCAL="$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
DMG_SIZE_BYTES="$(stat -f%z "${DMG_PATH}")"
echo "  - sha256 final (post-staple, este es el que se publica): ${DMG_SHA_LOCAL}"
echo "  - tamaño: ${DMG_SIZE_BYTES} bytes"

# ---------------------------------------------------------------------------
# 9. Firmar update con Sparkle (sign_update)
# ---------------------------------------------------------------------------

step "11/13 — Firmando el update con sign_update (Sparkle)"

SIGN_UPDATE_BIN="$(find "${HOME}/Library/Developer/Xcode/DerivedData" \
  -path "*/Downloader-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update" \
  -print -quit 2>/dev/null || true)"

if [ -z "${SIGN_UPDATE_BIN}" ] || [ ! -x "${SIGN_UPDATE_BIN}" ]; then
  abort "no se encontró sign_update en DerivedData \
(~/Library/Developer/Xcode/DerivedData/Downloader-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update). \
Corre 'make build' al menos una vez para que SPM resuelva Sparkle, o localízalo manualmente."
fi
echo "  - sign_update: ${SIGN_UPDATE_BIN}"
echo "  - cuenta de Keychain: ${SPARKLE_KEYCHAIN_ACCOUNT} (CRÍTICO: sin --account, firma con la clave equivocada)"

SIGN_OUTPUT="$("${SIGN_UPDATE_BIN}" --account "${SPARKLE_KEYCHAIN_ACCOUNT}" "${DMG_PATH}")"
echo "  - salida de sign_update: ${SIGN_OUTPUT}"

ED_SIGNATURE="$(echo "${SIGN_OUTPUT}" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
SIGN_LENGTH="$(echo "${SIGN_OUTPUT}" | sed -n 's/.*length="\([^"]*\)".*/\1/p')"

if [ -z "${ED_SIGNATURE}" ]; then
  abort "no se pudo extraer sparkle:edSignature de la salida de sign_update: ${SIGN_OUTPUT}"
fi
if [ -z "${SIGN_LENGTH}" ]; then
  # sign_update a veces no imprime length explícito — usamos el tamaño real del DMG.
  SIGN_LENGTH="${DMG_SIZE_BYTES}"
fi
echo "  - edSignature: ${ED_SIGNATURE}"
echo "  - length: ${SIGN_LENGTH}"

# ---------------------------------------------------------------------------
# 10. Clonar/actualizar downloader_updates + generar appcast.xml nuevo
# ---------------------------------------------------------------------------

step "12/13 — Preparando appcast.xml actualizado (en clon temporal)"

UPDATES_CLONE="${WORK_DIR}/downloader_updates"
git clone --depth 50 "${UPDATES_REPO_URL}" "${UPDATES_CLONE}" \
  || abort "no se pudo clonar ${UPDATES_REPO_URL}"

APPCAST_LOCAL="${UPDATES_CLONE}/${APPCAST_FILE}"
PUB_DATE="$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")"
ENCLOSURE_URL="https://github.com/${UPDATES_REPO_SLUG}/releases/download/v${VERSION}/${DMG_NAME}"

# Extrae la sección [Unreleased] cruda en Markdown (sin convertir a HTML) —
# la misma fuente que alimenta el appcast, pero tal cual está escrita en el
# CHANGELOG. GitHub renderiza Markdown nativamente en el cuerpo del release,
# así que no hace falta pasar por el conversor HTML de más abajo.
RELEASE_NOTES_MD="$(python3 - "${CHANGELOG}" <<'PY'
import re, sys

with open(sys.argv[1], encoding="utf-8") as f:
    content = f.read()

m = re.search(r"## \[Unreleased\]\s*(.*?)(?=\n## \[|\Z)", content, re.S)
body = m.group(1).strip() if m else ""
print(body if body else "Ver CHANGELOG.md en el repo principal para el detalle de esta versión.")
PY
)"

RELEASE_NOTES_MD_FILE="${WORK_DIR}/release_notes.md"
printf '%s\n' "${RELEASE_NOTES_MD}" > "${RELEASE_NOTES_MD_FILE}"

# Release notes: sección [Unreleased] del CHANGELOG local, como HTML simple en CDATA.
RELEASE_NOTES_HTML="$(python3 - "${CHANGELOG}" <<'PY'
import re, sys, html

with open(sys.argv[1], encoding="utf-8") as f:
    content = f.read()

m = re.search(r"## \[Unreleased\]\s*(.*?)(?=\n## \[|\Z)", content, re.S)
body = m.group(1).strip() if m else "Ver CHANGELOG.md."

lines = [ln.rstrip() for ln in body.splitlines()]
html_lines = ["<html><body>"]
in_list = False
for ln in lines:
    stripped = ln.strip()
    if not stripped:
        continue
    if stripped.startswith("## "):
        if in_list:
            html_lines.append("</ul>")
            in_list = False
        html_lines.append(f"<h2>{html.escape(stripped[3:])}</h2>")
    elif stripped.startswith("### "):
        if in_list:
            html_lines.append("</ul>")
            in_list = False
        html_lines.append(f"<h3>{html.escape(stripped[4:])}</h3>")
    elif stripped.startswith("- "):
        if not in_list:
            html_lines.append("<ul>")
            in_list = True
        html_lines.append(f"<li>{html.escape(stripped[2:])}</li>")
    elif in_list:
        # Línea de continuación de un bullet envuelto en varias líneas del
        # markdown: se concatena al último <li> en vez de cerrar la lista.
        last = html_lines[-1]
        assert last.endswith("</li>")
        html_lines[-1] = last[: -len("</li>")] + " " + html.escape(stripped) + "</li>"
    else:
        html_lines.append(f"<p>{html.escape(stripped)}</p>")
if in_list:
    html_lines.append("</ul>")
html_lines.append("</body></html>")
print("\n".join(html_lines))
PY
)"

RELEASE_NOTES_FILE="${WORK_DIR}/release_notes.html"
printf '%s' "${RELEASE_NOTES_HTML}" > "${RELEASE_NOTES_FILE}"

NEW_ITEM="$(python3 - "${VERSION}" "${NEXT_BUILD}" "${PUB_DATE}" "${ENCLOSURE_URL}" "${ED_SIGNATURE}" "${SIGN_LENGTH}" "${RELEASE_NOTES_FILE}" <<'PY'
import sys

version, build, pub_date, url, ed_sig, length, notes_path = sys.argv[1:8]

with open(notes_path, encoding="utf-8") as f:
    notes = f.read().rstrip("\n")

item = f"""    <item>
      <title>Downloader {version}</title>
      <pubDate>{pub_date}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
{notes}
      ]]></description>
      <enclosure
        url="{url}"
        sparkle:edSignature="{ed_sig}"
        length="{length}"
        type="application/octet-stream" />
    </item>"""
print(item)
PY
)"

if [ -f "${APPCAST_LOCAL}" ]; then
  python3 - "${APPCAST_LOCAL}" "${NEW_ITEM}" <<'PY'
import sys

path, new_item = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    content = f.read()

if "</channel>" not in content:
    raise SystemExit(f"appcast.xml existente no tiene </channel>: {path}")

content = content.replace("</channel>", new_item + "\n  </channel>", 1)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PY
else
  cat > "${APPCAST_LOCAL}" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Downloader Updates</title>
    <link>${APPCAST_RAW_URL}</link>
    <description>Actualizaciones de Downloader</description>
    <language>en</language>
${NEW_ITEM}
  </channel>
</rss>
XML
fi

echo "  - appcast.xml actualizado en ${APPCAST_LOCAL}"

# ---------------------------------------------------------------------------
# 11. gh release create (primero el asset) + verificación byte a byte
# ---------------------------------------------------------------------------

step "13/13 — Publicando release en GitHub + verificación byte a byte"

echo "  - sha256 del DMG local (antes de subir): ${DMG_SHA_LOCAL}"

gh release create "v${VERSION}" "${DMG_PATH}" \
  --repo "${UPDATES_REPO_SLUG}" \
  --title "Downloader ${VERSION}" \
  --notes-file "${RELEASE_NOTES_MD_FILE}" \
  || abort "gh release create falló"

RELEASE_CREATED=1
echo "  - release v${VERSION} creado en ${UPDATES_REPO_SLUG}"

VERIFY_DIR="${WORK_DIR}/verify"
mkdir -p "${VERIFY_DIR}"
gh release download "v${VERSION}" \
  --repo "${UPDATES_REPO_SLUG}" \
  --pattern "${DMG_NAME}" \
  --dir "${VERIFY_DIR}" \
  || abort "no se pudo descargar de vuelta el asset recién subido para verificar"

DMG_SHA_REMOTE="$(shasum -a 256 "${VERIFY_DIR}/${DMG_NAME}" | awk '{print $1}')"

if [ "${DMG_SHA_LOCAL}" != "${DMG_SHA_REMOTE}" ]; then
  echo "" >&2
  echo "ERROR CRÍTICO: el sha256 del DMG subido (${DMG_SHA_REMOTE}) no coincide" >&2
  echo "con el local (${DMG_SHA_LOCAL}). El asset se corrompió en la subida o" >&2
  echo "GitHub sirvió una copia distinta. El appcast NO se va a actualizar." >&2
  echo "" >&2
  echo "Limpieza manual recomendada:" >&2
  echo "  1. gh release delete v${VERSION} --repo ${UPDATES_REPO_SLUG} --yes" >&2
  echo "  2. git tag -d v${VERSION} 2>/dev/null; git push --delete origin v${VERSION} 2>/dev/null || true" >&2
  echo "  3. Reintenta el release desde cero: ./Scripts/release.sh ${VERSION}" >&2
  abort "verificación byte a byte del DMG falló"
fi

echo "  - verificación byte a byte del DMG: OK (sha256 coincide)"

step "Publicando appcast.xml (después del asset, para que ningún cliente vea un appcast roto)"

git -C "${UPDATES_CLONE}" add "${APPCAST_FILE}"
git -C "${UPDATES_CLONE}" -c user.name="Downloader Release Bot" -c user.email="hi@9866.mx" \
  commit -m "Downloader ${VERSION} (build ${NEXT_BUILD})"
git -C "${UPDATES_CLONE}" push origin HEAD:main \
  || abort "no se pudo hacer push del appcast.xml actualizado a ${UPDATES_REPO_SLUG}"

echo "  - appcast.xml publicado en ${UPDATES_REPO_SLUG}"

# ---------------------------------------------------------------------------
# 12. Actualizar VERSION.md / CHANGELOG.md locales
# ---------------------------------------------------------------------------

step "Actualizando VERSION.md y CHANGELOG.md locales"

TODAY="$(date -u "+%Y-%m-%d")"

python3 - "${VERSION_MD}" "${VERSION}" "${NEXT_BUILD}" "${TODAY}" <<'PY'
import re, sys

path, version, build, today = sys.argv[1:5]
with open(path, encoding="utf-8") as f:
    content = f.read()

content = re.sub(
    r"- \*\*Publicado actualmente:\*\*.*",
    f"- **Publicado actualmente:** {version} (build {build}), publicado el {today}.",
    content,
    count=1,
)
content = re.sub(
    r"- \*\*Próxima versión sugerida:\*\*.*",
    "- **Próxima versión sugerida:** define la próxima cuando toque — este archivo se actualiza en cada release.",
    content,
    count=1,
)

row = f"| {version} | {build} | {today} | — |\n"
placeholder = "| — | — | — | (todavía no hay releases publicados) |\n"
if placeholder in content:
    content = content.replace(placeholder, row)
elif row not in content:
    # Ya hubo un release previo: agrega la fila nueva justo antes de "## Regla de oro".
    content = content.replace("## Regla de oro", f"{row}\n## Regla de oro", 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PY

python3 - "${CHANGELOG}" "${VERSION}" "${TODAY}" <<'PY'
import re, sys

path, version, today = sys.argv[1:4]
with open(path, encoding="utf-8") as f:
    content = f.read()

content = content.replace(
    "## [Unreleased]",
    f"## [Unreleased]\n\n(sin cambios todavía)\n\n## [{version}] - {today}",
    1,
)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PY

echo "  - VERSION.md y CHANGELOG.md actualizados localmente"

step "Release ${VERSION} (build ${NEXT_BUILD}) publicado con éxito"
echo ""
echo "RECORDATORIO: commitea VERSION.md y CHANGELOG.md en este repo (Downloader,"
echo "el repo privado) — el release ya está público en ${UPDATES_REPO_SLUG},"
echo "pero estos dos archivos locales todavía no están commiteados:"
echo ""
echo "    git add VERSION.md CHANGELOG.md"
echo "    git commit -m \"Release ${VERSION} (build ${NEXT_BUILD})\""
echo ""

if [ -n "${WORK_DIR}" ] && [ -d "${WORK_DIR}" ]; then
  rm -rf "${WORK_DIR}"
fi

exit 0
