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

  if [ "${CODE_SIGNING_ALLOWED:-YES}" = "YES" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    codesign --force --options runtime --timestamp=none \
      --entitlements "${SRCROOT}/Downloader/Downloader.entitlements" \
      --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
      "${DEST_DIR}/${tool}" \
      || echo "warning: no se pudo firmar ${tool}"
  else
    echo "note: sin identidad de firma — ${tool} queda sin firmar (no notarizable)"
  fi
done

if [ "${missing}" = "1" ]; then
  echo "warning: la app compila pero no podrá descargar hasta que los binarios estén presentes"
fi

exit 0
