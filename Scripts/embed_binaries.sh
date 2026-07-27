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

  # Los binarios de terceros (yt-dlp/ffmpeg) llegan con su propia firma
  # (ad-hoc o de su propio Team ID). Si no se elimina antes de re-firmar,
  # el binario embebido queda con un Team ID distinto al del proceso que
  # lo carga (nuestro .app), y dyld/AMFI lo rechaza en runtime:
  #   "code signature not valid... different Team IDs".
  # Solución: quitar siempre la firma original y volver a firmar con la
  # MISMA identidad que usará el resto del bundle, sea ad-hoc ("-") o una
  # identidad real de Developer ID/Distribution.
  codesign --remove-signature "${DEST_DIR}/${tool}" 2>/dev/null || true

  if [ "${CODE_SIGNING_ALLOWED:-YES}" = "YES" ]; then
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

    codesign --force --options runtime ${timestamp_flag} \
      --entitlements "${SRCROOT}/Downloader/Downloader.entitlements" \
      --sign "${sign_identity}" \
      "${DEST_DIR}/${tool}" \
      || echo "warning: no se pudo firmar ${tool}"
  else
    echo "note: firma deshabilitada (CODE_SIGNING_ALLOWED=NO) — ${tool} queda sin firmar"
  fi
done

if [ "${missing}" = "1" ]; then
  echo "warning: la app compila pero no podrá descargar hasta que los binarios estén presentes"
fi

exit 0
