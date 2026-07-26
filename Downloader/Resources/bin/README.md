# Resources/bin — binarios empaquetados

Esta carpeta debe contener **dos binarios Mach-O universales (arm64 + x86_64)**.
No están en el repo (pesan ~100 MB juntos y tienen su propia licencia); hay que
colocarlos a mano una vez.

| Archivo | Qué es | De dónde bajarlo |
|---|---|---|
| `yt-dlp` | Motor de descarga | Release oficial de yt-dlp, asset **`yt-dlp_macos`** — https://github.com/yt-dlp/yt-dlp/releases/latest |
| `ffmpeg` | Merge de video+audio en calidades altas | Build estática universal de macOS — https://evermeet.cx/ffmpeg/ (arm64 + x86_64, unir con `lipo`) o https://www.osxexperts.net |

> El nombre del archivo importa: la app busca exactamente `yt-dlp` y `ffmpeg`
> (`Services/BundledBinaries.swift`). Renombra `yt-dlp_macos` → `yt-dlp`.

## Instalación

```bash
cd Downloader/Resources/bin

# yt-dlp
curl -L -o yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos
chmod +x yt-dlp

# ffmpeg: bajar las dos arquitecturas y unirlas si la build no es universal
# (ejemplo con dos binarios ya descargados)
# lipo -create ffmpeg-arm64 ffmpeg-x86_64 -output ffmpeg
chmod +x ffmpeg
```

## Verificación obligatoria antes de continuar

```bash
lipo -info yt-dlp ffmpeg
# Debe decir: "Architectures in the fat file: ... are: x86_64 arm64"
```

Si alguno es de una sola arquitectura, la app no correrá en Macs Intel.

## Firma

`Scripts/embed_binaries.sh` los copia a `Contents/MacOS/bin` dentro del `.app` y
los firma con `CODE_SIGN_IDENTITY`. Para notarizar hay que usar una identidad
**Developer ID Application** real (con `-` ad-hoc la app corre local pero no pasa
Gatekeeper en otra Mac).

Verificar después de compilar:

```bash
codesign -dvvv "build/Downloader.app/Contents/MacOS/bin/yt-dlp"
spctl --assess --type execute -vv build/Downloader.app
```

## Si faltan

La app **compila y arranca igual**, pero:

- El launcher muestra un chip rojo: "Falta yt-dlp — colócalo en Resources/bin".
- Enter no dispara ninguna descarga.
- Settings muestra la sección "Motor de descarga" con la misma advertencia.
