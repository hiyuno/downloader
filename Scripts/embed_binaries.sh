#!/bin/bash
# Copia yt-dlp/ffmpeg a Contents/MacOS/bin (destino "Executables") y los firma.
# Debe correr DESPUÉS de compilar y ANTES de la firma del bundle completo.
# Tolerante a fallo: si los binarios no están, avisa pero no rompe el build
# (Woz puede trabajar en la UI sin haberlos descargado todavía).

set -u

SOURCE_DIR="${SRCROOT}/Downloader/Resources/bin"
DEST_DIR="${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/bin"

mkdir -p "${DEST_DIR}"

missing=0
for tool in yt-dlp ffmpeg; do
  if [ ! -f "${SOURCE_DIR}/${tool}" ]; then
    echo "warning: ${tool} no está en Downloader/Resources/bin — ver README.md de esa carpeta"
    missing=1
    continue
  fi

  cp -f "${SOURCE_DIR}/${tool}" "${DEST_DIR}/${tool}"
  chmod +x "${DEST_DIR}/${tool}"

  if [ "${CODE_SIGNING_ALLOWED:-YES}" = "YES" ]; then
    # Los binarios de terceros llegan con su propia firma. Solo la quitamos
    # cuando podemos reemplazarla inmediatamente: dejar una copia sin firma
    # hace que AMFI la mate con SIGKILL al lanzarla desde el bundle.
    codesign --remove-signature "${DEST_DIR}/${tool}" 2>/dev/null || true

    # EXPANDED_CODE_SIGN_IDENTITY viene vacío cuando CODE_SIGN_IDENTITY="-"
    # (ad-hoc), así que hay que caer de vuelta a "-" en ese caso en vez de
    # saltarse la firma por completo.
    sign_identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
    if [ -z "${sign_identity}" ]; then
      sign_identity="-"
    fi

    # El timestamp de firma requiere red y no aplica a firma ad-hoc ("-"):
    # solo lo pedimos cuando la identidad es una identidad real (Developer ID).
    timestamp_flag="--timestamp=none"
    if [ "${sign_identity}" != "-" ]; then
      timestamp_flag="--timestamp"
    fi

    if ! codesign --force --options runtime ${timestamp_flag} \
      --entitlements "${SRCROOT}/Downloader/Downloader.entitlements" \
      --sign "${sign_identity}" \
      "${DEST_DIR}/${tool}"; then
      echo "error: no se pudo firmar ${tool}; se detiene el build para no crear una app inutilizable"
      exit 1
    fi

    if ! codesign --verify --strict "${DEST_DIR}/${tool}"; then
      echo "error: la firma de ${tool} no es válida"
      exit 1
    fi
  else
    echo "note: firma deshabilitada (CODE_SIGNING_ALLOWED=NO) — se conserva la firma original de ${tool}"
  fi
done

if [ "${missing}" = "1" ]; then
  echo "warning: la app compila pero no podrá descargar hasta que los binarios estén presentes"
fi

exit 0
