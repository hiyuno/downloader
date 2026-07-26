# TRD — Downloader

> Última actualización: 2026-07-26. Basado en PRD v1.0.
> Decisiones técnicas vinculantes. Cambiar algo aquí requiere actualizar este documento.

---

## Stack técnico

Swift nativo confirmado por el PRD (sección "Stack preferido") — sin debate, feel 100% Apple, acceso a AppKit para paneles sin foco de Dock, y distribución fuera del App Store no impone restricciones de sandboxing que compliquen nada.

| Área | Decisión | Justificación |
|------|----------|---------------|
| UI Framework | SwiftUI + AppKit puntual | SwiftUI resuelve el 95% de la UI (launcher, settings, progreso); AppKit cubre lo que SwiftUI no expone: `NSPanel` sin foco de Dock, `NSStatusItem`, hotkey global, `NSWorkspace` |
| Estado | `@Observable` (Observation framework) | Swift 6 nativo, menos boilerplate que `ObservableObject`, integra bien con `@MainActor` |
| Persistencia | `UserDefaults` vía `@AppStorage` | Sin historial persistente en v1 (decisión de producto) — solo Settings necesita persistir, y son 3 valores simples |
| Sync | Ninguno | App local, sin cuenta, sin backend (PRD) |
| Concurrencia | Swift Concurrency (`async/await`, `actor`, `@MainActor`) | Swift 6 strict concurrency desde día 1 — evita deuda técnica de migración posterior |
| Proceso externo | `Foundation.Process` + `Pipe` | Único mecanismo soportado para invocar binarios embebidos sin dependencias de terceros |

---

## 1. Estructura del proyecto Xcode

**Un solo target de app** (`Downloader`), sin extensiones ni frameworks separados — la app es pequeña y no hay superficie compartida entre procesos que justifique modularización. Un segundo target de tests (`DownloaderTests`, Swift Testing) para Bertrand.

```
Downloader.xcodeproj
Downloader/
├── DownloaderApp.swift                # @main, arma Scene: MenuBarExtra + Settings, sin WindowGroup
├── AppDelegate.swift                  # NSApplicationDelegate: registra hotkey, crea/gestiona el NSPanel, LSUIElement
├── Info.plist                         # LSUIElement = YES (sin Dock, sin menu bar de app estándar)
├── Downloader.entitlements            # sin sandbox — ver sección Notarización
│
├── Features/
│   ├── Launcher/
│   │   ├── LauncherPanel.swift        # NSPanel subclass: nivel, comportamiento, centrado
│   │   ├── LauncherPanelController.swift # NSWindowController: show/hide/toggle, foco
│   │   ├── LauncherView.swift         # SwiftUI: campo de texto, estado detectado, lista de descargas activas
│   │   ├── LauncherViewModel.swift    # @Observable @MainActor: orquesta detección, submit, estado de descargas
│   │   └── DownloadRowView.swift      # fila de progreso por descarga activa
│   │
│   └── Settings/
│       ├── SettingsView.swift         # Settings scene, TabView si crece; v1 una sola pantalla
│       ├── SettingsViewModel.swift    # @Observable: lee/escribe AppStorage, valida selección de carpeta/app
│       └── AppPickerView.swift        # NSOpenPanel wrapper para elegir app destino
│
├── Core/
│   ├── DownloadTask.swift             # struct DownloadTask: Identifiable, Sendable — modelo de una descarga
│   ├── DownloadState.swift            # enum: .idle, .detecting, .downloading(progress), .completed(url), .failed(reason)
│   ├── SupportedSite.swift            # enum SupportedSite: caso por sitio + regex/heurística de detección
│   └── URLValidator.swift             # valida y clasifica un string como URL soportada
│
├── Services/
│   ├── YTDLPService.swift             # actor: wrapea Process + Pipe, parsing de progreso, cancelación
│   ├── YTDLPUpdateService.swift       # verifica versión embebida vs. última disponible, reemplaza binario
│   ├── ClipboardService.swift         # lee NSPasteboard, detecta URL al abrir el launcher
│   ├── HotkeyService.swift            # registra/desregistra hotkey global (Carbon), notifica al AppDelegate
│   ├── NotificationService.swift      # wrapea UserNotifications: pide permiso, dispara notificación post-descarga
│   └── FileOpenerService.swift        # NSWorkspace.open(_:withApplicationAt:) post-descarga
│
├── UI/
│   ├── GlassBackground.swift          # ViewModifier con #available: Liquid Glass 26+ vs Frost 14-15
│   ├── Theme.swift                    # constantes de espaciado, tipografía, radios
│   └── Components/                    # botones, progress ring, etc. compartidos entre Launcher y Settings
│
├── Resources/
│   ├── bin/
│   │   ├── yt-dlp                     # binario Mach-O universal, firmado, empaquetado
│   │   └── ffmpeg                     # binario Mach-O universal, firmado, empaquetado
│   └── Assets.xcassets                # ícono de menu bar (template image), ícono de app
│
└── Support/
    ├── AppSettings.swift              # enum de claves @AppStorage + defaults centralizados
    └── Logger+Downloader.swift        # extensión de os.Logger con subsistema/categorías

DownloaderTests/
├── URLValidatorTests.swift
├── YTDLPProgressParsingTests.swift
└── AppSettingsTests.swift
```

**Justificación de capas:** `Features/` por pantalla (Launcher, Settings) porque son las únicas dos superficies de UI de la app — no hay más features que ameriten carpeta propia en v1. `Core/` son tipos de dominio puros sin dependencia de AppKit/proceso, testeables sin mocks pesados. `Services/` son los integradores con el sistema (proceso externo, pasteboard, notificaciones, hotkey) — cada uno aislado para poder testear `LauncherViewModel` inyectando protocolos falsos. `UI/` es lo compartido de presentación, separado para que Jonny y Larry lo encuentren sin bucear en lógica.

---

## 2. Ventana launcher flotante

**Decisión: `NSPanel` subclase, no `NSWindow` ni `Window`/`WindowGroup` de SwiftUI.**

Razón: SwiftUI `Window` no permite `.nonactivatingPanel`, no permite quitar el foco de Dock al mostrarse, y no da control fino sobre `canBecomeKey`. Un launcher tipo Spotlight necesita exactamente ese control — `NSPanel` es el único camino sin dependencias de terceros.

```swift
final class LauncherPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 90),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating                       // por encima de ventanas normales, no sobre otros paneles de sistema
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isReleasedWhenClosed = false            // se reutiliza la misma instancia, no se recrea
    }

    override var canBecomeKey: Bool { true }    // necesita foco de teclado para el campo de texto
    override var canBecomeMain: Bool { false }
}
```

- **Nivel:** `.floating`. No `.statusBar` ni `.popUpMenu` — esos compiten con menús de sistema reales; `.floating` es suficiente para estar sobre apps normales y detrás de nada crítico.
- **Activación/foco:** `nonactivatingPanel` evita que la app se active completa (no aparece en Cmd+Tab, no roba foco de la app anterior salvo el panel mismo). Al mostrarse: `panel.makeKeyAndOrderFront(nil)` + `NSApp.activate(ignoringOtherApps: true)` solo si se requiere foco de teclado inmediato en el campo de texto — se hace, porque el flujo es "pegar/Enter" y el campo debe tener foco desde el primer frame.
- **Centrado:** centrado en la pantalla donde está el cursor del mouse en el momento del hotkey, no en la pantalla principal. Usar `NSScreen.screens` + `NSEvent.mouseLocation` para determinar la pantalla activa, luego `panel.center()` ajustado a ese `NSScreen.frame`. Esto cubre el caso multi-monitor sin lógica adicional: Spotlight y Raycast hacen lo mismo.
- **Pérdida de foco:** el panel se oculta (no se cierra) cuando deja de ser key window. Implementar `windowDidResignKey` en el `NSWindowController` y llamar `panel.orderOut(nil)`. Reutilizar la instancia entre aperturas (no destruir/recrear) para que reabrir sea instantáneo (<200ms del criterio de aceptación).
- **Multi-Space:** `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` para que aparezca en el Space actual sin importar cuál sea, incluyendo cuando hay una app en full screen activa.
- **Tecla Escape:** cierra el panel sin descartar una descarga en curso (la descarga sigue en background vía el `actor` de `YTDLPService`; solo se oculta la UI).

---

## 3. Hotkey global

**Decisión: Carbon `RegisterEventHotKey`, no `NSEvent.addGlobalMonitorForEvents`.**

Justificación de la disyuntiva:
- `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` es la opción "moderna" pero tiene dos problemas serios para este caso: (1) requiere permisos de Accesibilidad en algunas configuraciones para capturar combinaciones que otras apps también escuchan, y (2) no *consume* el evento — si el usuario tiene otra app escuchando el mismo atajo, ambas disparan, generando conflictos silenciosos exactamente en el escenario que el PRD identifica como riesgo (Spotlight/Raycast/Alfred).
- `RegisterEventHotKey` (Carbon, disponible sin puentes de terceros vía `import Carbon.HIToolbox`) sigue siendo la API que usan Alfred, Raycast y Spotlight-likes en 2026 porque es la única que registra el atajo a nivel de sistema con prioridad y bloqueo real de reasignación — si otra app ya lo tiene registrado, `RegisterEventHotKey` devuelve error inmediatamente y la app puede avisar al usuario en vez de fallar en silencio.
- Carbon sigue soportado en macOS 26 para esta API específica (no está deprecada para hotkeys globales); no requiere entitlements de Accesibilidad.

```swift
// HotkeyService.swift
import Carbon.HIToolbox

@MainActor
final class HotkeyService {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onHotkeyPressed: (() -> Void)?

    func register(keyCode: UInt32, modifiers: UInt32) throws {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            let service = Unmanaged<HotkeyService>.fromOpaque(userData!).takeUnretainedValue()
            DispatchQueue.main.async { service.onHotkeyPressed?() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)

        let hotKeyID = EventHotKeyID(signature: OSType(fourCharCode: "Dwnl"), id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else { throw HotkeyError.registrationFailed(status) }
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
    }
}
```

- **Default:** `⌥⌘Space` — poco común, no choca con Spotlight (`⌘Space`) ni con el default de Raycast (`⌥Space`). Configurable en Settings vía un campo de captura de atajo (grabar `keyDown` con `NSEvent.addLocalMonitorForEvents` solo mientras el campo de captura tiene foco, no como monitor global permanente).
- Si `RegisterEventHotKey` falla (atajo ya tomado), mostrar alerta clara en Settings, no fallar silenciosamente.

---

## 4. Menu bar

**Decisión: `NSStatusItem` vía AppKit, no `MenuBarExtra` de SwiftUI.**

Justificación: `MenuBarExtra` es la opción por defecto y normalmente ganaría, pero acá se descarta porque el ícono de menu bar necesita reflejar estado (idle / descargando con progreso) actualizando su imagen dinámicamente con baja latencia, y necesita coexistir con un `NSPanel` custom controlado imperativamente (mostrar/ocultar/centrar en pantalla del cursor) — mezclar el ciclo de vida de `MenuBarExtra` (que SwiftUI gestiona) con un `NSPanel` gestionado a mano por `AppDelegate` genera dos fuentes de verdad para "qué ventana está visible". Con `NSStatusItem` todo el control de ventanas vive en un solo lugar (`AppDelegate` + `LauncherPanelController`), consistente con cómo ya se maneja el panel.

```swift
// dentro de AppDelegate
private var statusItem: NSStatusItem!

func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Downloader")
    statusItem.button?.image?.isTemplate = true
    statusItem.menu = buildMenu()   // NSMenu simple: "Abrir Downloader", "Ajustes…", separador, "Salir"
}
```

- El ícono cambia a un símbolo con progreso (`arrow.down.circle` → variante con badge o `ProgressIndicator` renderizado a `NSImage`) cuando hay descargas activas — se actualiza desde `LauncherViewModel` vía closure/callback hacia `AppDelegate`, no acoplando `Services/` a AppKit directamente.
- El menú del `NSStatusItem` es secundario (clic derecho o clic normal abre menú de opciones); el clic principal para abrir el launcher es el hotkey, no el ícono — pero clicar el ícono también abre el panel (fallback para quien olvidó el atajo).

---

## 5. Wrapper de yt-dlp

### Proceso y pipes

`YTDLPService` es un `actor` (aísla el estado mutable de procesos en vuelo, seguro bajo Swift 6 strict concurrency):

```swift
actor YTDLPService {
    private var runningProcesses: [UUID: Process] = [:]

    func download(task: DownloadTask, progress: @Sendable @escaping (DownloadProgress) -> Void) async throws -> URL {
        let process = Process()
        process.executableURL = Bundle.main.url(forResource: "yt-dlp", withExtension: nil, subdirectory: "bin")
        process.environment = ["PATH": Bundle.main.resourcePath! + "/bin"]  // para que yt-dlp encuentre ffmpeg embebido
        process.arguments = [
            task.url.absoluteString,
            "-f", "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/b",     // mejor calidad MP4, con fallback
            "--ffmpeg-location", Bundle.main.resourcePath! + "/bin/ffmpeg",
            "-o", "\(task.destinationFolder.path)/%(title)s.%(ext)s",
            "--newline",
            "--progress-template", "download:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "--no-playlist",
            "--no-color"
        ]

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let line = String(data: handle.availableData, encoding: .utf8) ?? ""
            if let parsed = DownloadProgress.parse(line) { progress(parsed) }
        }

        runningProcesses[task.id] = process
        try process.run()
        process.waitUntilExit()
        runningProcesses.removeValue(forKey: task.id)

        guard process.terminationStatus == 0 else { throw YTDLPError.processFailed(process.terminationStatus) }
        return outputFileURL(for: task)   // resuelto vía --print after_move:filepath (ver nota abajo)
    }

    func cancel(taskID: UUID) {
        runningProcesses[taskID]?.terminate()
    }
}
```

- **Parsing de progreso:** `--progress-template` con formato fijo y delimitado por `|` (no JSON, no depender de columnas de texto libre que cambian entre versiones de yt-dlp). `DownloadProgress.parse(_:)` en `Core/` es una función pura, testeable sin proceso real.
- **Ruta del archivo final:** no confiar en construir el nombre a mano (títulos con caracteres especiales rompen el match). Usar `--print after_move:filepath` como línea adicional de output — yt-dlp imprime la ruta final exacta tras el post-procesamiento, se lee de stdout con un prefijo reconocible.
- **Cancelación:** `process.terminate()` (SIGTERM) vía el actor; yt-dlp maneja la señal y limpia archivos parciales `.part` razonablemente bien por defecto.

### Empaquetado y firma

- Los binarios de `yt-dlp` y `ffmpeg` van en `Resources/bin/` y se copian al bundle vía una **Build Phase "Copy Files"** con destino `Executables` (no `Resources` directo, para que Xcode los incluya en la fase de firma automática del bundle).
- **Arquitectura:** empaquetar binarios **universal (arm64 + x86_64)** — yt-dlp se distribye como binario standalone PyInstaller multi-arch o se puede compilar; ffmpeg tiene builds universales estáticos disponibles (evolvess builds). Decisión: usar binarios prebuilt universales de fuentes confiables (`yt-dlp` release oficial trae `yt-dlp_macos` universal; `ffmpeg` desde una build estática universal reconocida) en vez de compilar desde cero — reduce superficie de mantenimiento.
- **Firma:** ambos binarios deben firmarse individualmente con el mismo Developer ID Application antes del build, con Hardened Runtime y el entitlement `com.apple.security.cs.allow-unsigned-executable-memory` si PyInstaller lo requiere (típico en binarios yt-dlp empaquetados con PyInstaller). Comando en un script de build phase:
  ```bash
  codesign --force --options runtime --timestamp \
    --entitlements Downloader/Downloader.entitlements \
    --sign "Developer ID Application: [Nombre] ([TeamID])" \
    "$BUILT_PRODUCTS_DIR/$EXECUTABLE_FOLDER_PATH/bin/yt-dlp"
  ```
  Igual para `ffmpeg`. Esto debe ocurrir **después** de que Xcode copie los archivos y **antes** de la firma del bundle completo, como Run Script Phase con orden explícito (`Input Files` / `Output Files` declarados para que Xcode respete el orden).
- **Notarización:** el notary service escanea binarios embebidos también — si no están firmados con Hardened Runtime, la notarización de la app completa falla. Validar con `codesign -dvvv` cada binario antes de subir a `notarytool`.

### Estrategia de actualización del binario

- v1: **sin auto-actualización silenciosa** — el PRD marca esto como riesgo pero no como bloqueante de v1 (`YTDLPUpdateService` existe como estructura pero solo con la función "verificar", no "reemplazar en caliente" en Fase 1).
- `YTDLPUpdateService` corre `yt-dlp --version` embebido al iniciar la app (async, no bloquea el launcher), lo compara contra un valor conocido embebido en build time o (Fase 2) contra el último release de GitHub vía `URLSession` a la API pública de GitHub releases.
- Si hay versión más nueva: notificación pasiva en Settings ("Hay una actualización de yt-dlp disponible") — no descarga ni reemplaza binarios automáticamente en v1, porque reemplazar un binario firmado dentro de un bundle ya firmado y notarizado rompe la firma del bundle (invalidaría Gatekeeper hasta el siguiente launch completo re-notarizado). Reemplazo en caliente de binario firmado es una features de Fase 2+ que requiere descargar a `Application Support/` (fuera del bundle) y apuntar `YTDLPService` ahí en vez de a `Resources/bin/` si existe una versión más nueva descargada — este mecanismo se diseña en Fase 2, no en v1.

### ffmpeg — se empaqueta sí

Decisión: **sí se empaqueta ffmpeg.** yt-dlp necesita ffmpeg para hacer merge de video+audio cuando la mejor calidad disponible en el sitio viene en streams separados (el caso común en YouTube para calidades >720p). Sin ffmpeg embebido, el criterio de aceptación #9 del PRD ("funciona en una Mac limpia sin nada preinstalado") se rompe silenciosamente para la mayoría de descargas de YouTube en alta calidad. No usar el ffmpeg del sistema (`/usr/bin/ffmpeg` no existe en macOS por defecto, y no se puede asumir Homebrew).

---

## 6. Modelo de datos y estado

```swift
// Core/DownloadTask.swift
struct DownloadTask: Identifiable, Sendable {
    let id: UUID
    let sourceURL: URL
    let site: SupportedSite
    let destinationFolder: URL
    var state: DownloadState
}

// Core/DownloadState.swift
enum DownloadState: Sendable, Equatable {
    case queued
    case downloading(percent: Double, speed: String?, eta: String?)
    case completed(fileURL: URL)
    case failed(reason: DownloadFailureReason)
}

enum DownloadFailureReason: Sendable, Equatable {
    case unsupportedSite
    case networkError
    case siteBlockedOrChanged   // distingue del riesgo #3 del PRD: "sitio cambió" vs "link inválido"
    case invalidURL
    case cancelled
}
```

- **`LauncherViewModel`** es `@MainActor @Observable`, mantiene `var activeDownloads: [DownloadTask]` (array chico, v1 no necesita persistencia ni límite de cola explícito más allá de lo que el usuario dispare manualmente). Recibe actualizaciones de progreso desde `YTDLPService` (actor) vía closures marcados `@Sendable` que hacen `await MainActor.run { ... }` internamente, o mejor: el callback ya se invoca dentro de un `Task { @MainActor in ... }` para no forzar al llamador a saber de aislamiento.
- **Concurrencia:** cada descarga corre en su propio `Task` lanzado desde el `LauncherViewModel`, delegando el trabajo pesado al `actor YTDLPService`. Múltiples descargas simultáneas son múltiples `Task` concurrentes, cada uno con su propia entrada en `runningProcesses` dentro del actor — el actor serializa el acceso al diccionario, no las descargas en sí (los `Process` corren en paralelo real, el actor solo protege el estado compartido).
- **Sendable:** `DownloadTask`, `DownloadState`, `DownloadFailureReason`, `SupportedSite` son todos `Sendable` por diseño (structs/enums de solo datos) — cruzan el límite entre el actor `YTDLPService` y el `@MainActor` `LauncherViewModel` sin warnings bajo Swift 6 strict concurrency.
- **Sin persistencia de `DownloadTask`** entre sesiones — al cerrar la app se pierde el estado de la lista (decisión de producto: sin historial).

---

## 7. Validación de URL y detección de clipboard

```swift
// Core/SupportedSite.swift
enum SupportedSite: String, CaseIterable, Sendable {
    case youtube, instagram, tiktok, twitter, other

    static func detect(from url: URL) -> SupportedSite {
        guard let host = url.host?.lowercased() else { return .other }
        if host.contains("youtube.com") || host.contains("youtu.be") { return .youtube }
        if host.contains("instagram.com") { return .instagram }
        if host.contains("tiktok.com") { return .tiktok }
        if host.contains("twitter.com") || host.contains("x.com") { return .twitter }
        return .other
    }
}
```

- La detección de "sitio soportado" en v1 es una **lista de hosts conocidos** mantenida a mano, no una llamada a yt-dlp (`yt-dlp --list-extractors` sería la fuente de verdad completa pero es lento de invocar por cada tecla). Si el host no está en la lista, la UI muestra "Sitio no reconocido — se intentará de todas formas" en vez de bloquear, porque yt-dlp soporta cientos de extractores y no queremos falsos negativos; el error real (si lo hay) lo reporta yt-dlp al ejecutar.
- **`URLValidator`** valida forma de URL (`URL(string:)` no nil + scheme http/https) antes de intentar nada — separa "no es una URL" de "es una URL pero el sitio no está en la lista corta".
- **`ClipboardService.detectURLOnPasteboard() -> URL?`** se llama cada vez que el `LauncherPanel` se muestra (en `windowDidBecomeKey` o al invocar el toggle desde `AppDelegate`), lee `NSPasteboard.general.string(forType: .string)`, intenta `URLValidator.validate`. Si hay match, pre-carga el campo de texto y selecciona el texto completo (para que escribir lo reemplace si el usuario quiere pegar otra cosa).

---

## 8. Post-descarga

- **Apertura en app configurada:** `NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())` — API async moderna (macOS 10.15+), no la variante deprecada `open(_:withApplicationAt:options:configuration:)` antigua ni `NSWorkspace.launchApplication`.
- **Notificaciones:** `UNUserNotificationCenter` (framework `UserNotifications`, funciona en apps sin bundle de Mac App Store siempre que la app esté firmada correctamente — requiere que el bundle identifier esté bien configurado, no requiere entitlement especial fuera de sandbox). Pedir permiso (`requestAuthorization(options: [.alert, .sound])`) la primera vez que se necesita, no al lanzar la app (evita el prompt en el primer launch antes de que el usuario haya hecho nada).
- Si no hay app configurada en Settings: solo notificación, sin intento de apertura (criterio de aceptación #7 del PRD).
- Notificación incluye nombre del archivo; tap en la notificación abre el Finder en la carpeta de descarga (`NSWorkspace.shared.activateFileViewerSelecting([fileURL])`) como acción secundaria útil, no mencionada explícitamente en PRD pero consistente con "cerrar el ciclo sin tocar Finder manualmente" — el usuario solo lo usa si quiere confirmar visualmente.

---

## 9. Settings

- **Almacenamiento:** `@AppStorage` sobre `UserDefaults.standard`, claves centralizadas en `AppSettings.swift`:
  ```swift
  enum AppSettings {
      static let downloadFolderKey = "downloadFolderBookmark"   // security-scoped bookmark, no solo path string
      static let destinationAppBundleIDKey = "destinationAppBundleID"
      static let defaultQualityKey = "defaultQuality"           // v1: un solo valor fijo "best mp4", ver nota
      static let hotkeyKeyCodeKey = "hotkeyKeyCode"
      static let hotkeyModifiersKey = "hotkeyModifiers"
  }
  ```
- **Carpeta de descarga:** aunque la app corre sin sandbox (no hay App Sandbox activo, PRD lo confirma), sigue siendo buena práctica guardar un **security-scoped bookmark** (`URL.bookmarkData(options: .withSecurityScope, ...)`) en vez de un path plano, para sobrevivir renombrados/movidos de carpeta y ser robusto si en el futuro se sandboxa la app. Selección vía `NSOpenPanel` con `canChooseDirectories = true`, `canChooseFiles = false`.
- **App destino:** `NSOpenPanel` apuntado a `/Applications` (`directoryURL = URL(fileURLWithPath: "/Applications")`), `allowedContentTypes = [.application]`, `canChooseDirectories = false`. Se guarda el **bundle identifier** de la app elegida (leído vía `Bundle(url:)?.bundleIdentifier`), no el path — más robusto si la app se mueve o actualiza de ubicación.
- **Calidad default:** v1 tiene un único valor real ("mejor calidad MP4 disponible", hardcoded en el argumento `-f` de `YTDLPService`). El PRD lista "calidad/formato default" en Settings (#8) pero también descarta explícitamente selector de calidad en el flujo — se interpreta como: Settings puede tener un picker simple (ej. "Mejor calidad" / "1080p máx" / "720p máx") que mapea a distintos strings de formato yt-dlp, sin exponer la sintaxis de formato de yt-dlp al usuario. Confirmar con Scott si el alcance real de v1 incluye más de una opción o solo "mejor calidad" fijo — este documento asume que Settings expone al menos 2-3 opciones simples porque el PRD lo lista como feature de MVP, no como placeholder.

---

## 10. Estrategia #available — Liquid Glass vs Frost

```swift
// UI/GlassBackground.swift
struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 20))   // Liquid Glass API
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))  // Frost — NSVisualEffectView vía material de SwiftUI
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.15), lineWidth: 1))
        }
    }
}

extension View {
    func downloaderGlass() -> some View { modifier(GlassBackground()) }
}
```

- Todo material de fondo (panel del launcher, fondo de filas de progreso, Settings) pasa por `.downloaderGlass()` — un único punto de ramificación `#available`, no dispersar checks de versión por toda la UI.
- macOS 14-15: `.ultraThinMaterial` / `.regularMaterial` de SwiftUI (que internamente usa `NSVisualEffectView`) es el "Frost" del PRD — ya es el estándar de macOS pre-26, no hay que construir nada custom.
- macOS 26+: API real de Liquid Glass (`glassEffect`) cuando estén disponibles los símbolos — este bloque se ajusta cuando Jonny y Woz tengan el SDK de macOS 26 con nombres finales de API confirmados; el nombre de método exacto (`glassEffect` vs otro) es lo único de esta sección sujeto a cambiar sin que cambie la decisión arquitectónica (un solo `ViewModifier`, un solo `#available`).
- Esto es trabajo de Fase 3 según el PRD — no bloquea Fase 1/2, pero el `ViewModifier` se crea desde Fase 1 con la rama Frost únicamente, dejando el `#available(macOS 26, *)` como no-op (mismo Frost) hasta que Fase 3 lo active, para no tener que retrofit la UI entera al final.

---

## Riesgos técnicos

- **`NSPanel` + `nonactivatingPanel` con foco de teclado real es una combinación delicada** — hay historial de bugs de AppKit donde paneles no-activantes no reciben `keyDown` correctamente en ciertas versiones de macOS. Mitigación: probar el foco del `NSTextField` explícitamente en macOS 14 y 15 desde la Fase 1 (no asumir que funciona igual que en versiones más nuevas); si falla, fallback documentado es `activationPolicy = .accessory` + activación completa breve de la app en vez de `nonactivatingPanel`.
- **PyInstaller-built yt-dlp binario y Hardened Runtime no siempre son compatibles out-of-the-box** (yt-dlp empaquetado con PyInstaller a veces necesita memoria ejecutable no firmada). Mitigación: validar la firma y notarización del binario yt-dlp de forma aislada (`codesign` + `spctl`) antes de integrarlo al proyecto completo, en la primera semana de Fase 1 — es el mayor riesgo de bloqueo de todo el TRD.
- **Carbon `RegisterEventHotKey` es una API C antigua sin bridging Swift moderno** — el manejo de puntero de contexto (`Unmanaged.fromOpaque`) es propenso a errores de memoria si no se retiene correctamente. Mitigación: `HotkeyService` mantiene una única instancia viva durante todo el ciclo de vida de la app (no se crea/destruye), y se testea con un test manual de estrés (registrar/desregistrar repetidamente) antes de Fase 2.
- **Parsing de progreso de yt-dlp depende de un formato de texto que Apple/nosotros no controlamos** — si una actualización de yt-dlp cambia el comportamiento de `--progress-template`, el parser falla silenciosamente. Mitigación: `DownloadProgress.parse` devuelve `nil` en vez de crashear ante formato inesperado, y la UI cae a un estado "descargando… (sin progreso detallado)" en vez de romperse; se loggea el mismatch con `os.Logger` para diagnóstico.
- **Notarización de app sin sandbox con binarios ejecutables embebidos que hacen red y acceden a `/Applications`** — mayor escrutinio de Apple según el PRD. Mitigación: usar Hardened Runtime con el mínimo set de entitlements (no pedir `allow-jit` ni excepciones amplias salvo la estrictamente necesaria para PyInstaller), y correr notarización real desde la Fase 1, no dejarlo para el final.
- **Multi-Space / full screen apps y `NSPanel` global** — el panel puede no aparecer o aparecer en el Space equivocado si `collectionBehavior` no está bien configurado en combinación con Mission Control. Mitigación: test manual explícito en Fase 2 con una app en full screen activa y con múltiples Spaces, es un escenario listado explícitamente en el PRD como parte de Fase 2.

---

## Qué NO hacer

- No usar `MenuBarExtra` de SwiftUI — pierde control fino sobre el ícono dinámico y duplica gestión de ventanas con el `NSPanel` custom.
- No usar `NSEvent.addGlobalMonitorForEvents` para el hotkey — no bloquea el evento para otras apps, generando exactamente el conflicto con Spotlight/Raycast/Alfred que el PRD marca como riesgo.
- No usar `Window`/`WindowGroup` de SwiftUI para el launcher — no permite panel no-activante ni control de nivel de ventana.
- No compilar yt-dlp/ffmpeg desde cero como parte del build — usar binarios prebuilt firmados; compilar desde cero es esfuerzo especulativo que no cambia el producto.
- No implementar reemplazo en caliente de binarios firmados dentro del bundle en v1 — invalida la firma del bundle; se difiere a Fase 2 con un directorio externo (`Application Support/`).
- No guardar rutas de carpeta como `String` planos en `UserDefaults` — usar security-scoped bookmarks desde el día 1, es el mismo costo de implementación y evita romper Settings si la carpeta se mueve.
- No exponer la sintaxis de formato de yt-dlp (`-f bv*+ba/b`) directamente al usuario en Settings — mapear a 2-3 opciones legibles.
- No construir historial, cola avanzada, ni soporte de playlists — explícitamente fuera de alcance según el PRD; no hay necesidad de dejar "ganchos" para ellos en el modelo de datos de v1 (`DownloadTask` sin campo de playlist, sin persistencia).

---

## Setup inicial

1. Crear proyecto Xcode nuevo: macOS App, SwiftUI, mínimo deployment target macOS 14.0, nombre `Downloader`, sin Core Data, sin tests de UI (solo Unit Tests con Swift Testing).
2. Configurar `Info.plist`: `LSUIElement = YES` (sin ícono de Dock, sin menú de app estándar).
3. Crear la estructura de carpetas `Features/`, `Core/`, `Services/`, `UI/`, `Support/`, `Resources/bin/` descrita arriba como grupos de Xcode que reflejen carpetas físicas en disco (File > New > Group, no "Group without folder").
4. Descargar `yt-dlp` (release oficial, binario standalone `yt-dlp_macos`) y una build estática universal de `ffmpeg`; colocar en `Resources/bin/`. Verificar arquitectura con `lipo -info` antes de continuar (deben ser universal arm64+x86_64).
5. Agregar Build Phase "Copy Files" (destination: Executables) para `bin/yt-dlp` y `bin/ffmpeg`.
6. Agregar Run Script Phase después del Copy Files que firme ambos binarios con Developer ID Application (ver comando en sección 5), condicionado a que exista una identidad de firma configurada — dejar el script tolerante a fallo en builds de desarrollo sin certificado, para no bloquear a Woz mientras aún no hay Team ID.
7. Implementar `HotkeyService` y `LauncherPanel`/`LauncherPanelController` primero, antes que cualquier feature de descarga — es el riesgo técnico #1 y #3 de esta lista; validar que el panel recibe foco de teclado correctamente en macOS 14 y 15 antes de construir el resto de la UI encima.
8. Validar el pipeline completo de `Process` + `yt-dlp` embebido con una descarga real de YouTube en un target de macOS 14 limpio antes de construir la UI de progreso — es el riesgo #2 (firma del binario PyInstaller) y no vale la pena avanzar en UI si esto no funciona.
9. Configurar el entitlements file sin App Sandbox (`com.apple.security.app-sandbox = NO` — de hecho, sin sandbox significa no incluir el entitlement en absoluto), con Hardened Runtime activado a nivel de proyecto desde el inicio (Signing & Capabilities > Hardened Runtime), para no descubrir problemas de notarización recién en Fase 3.

---

## Decisiones registradas

| Fecha | Decisión | Razón |
|-------|----------|-------|
| 2026-07-26 | Swift nativo (SwiftUI + AppKit puntual) confirmado | Ya definido en PRD; feel 100% Apple y control de ventana/hotkey que Electron/Tauri no dan sin fricción |
| 2026-07-26 | `NSPanel` (`nonactivatingPanel`) en vez de `NSWindow`/`Window` SwiftUI | Único camino para panel flotante sin foco de Dock y con nivel de ventana controlado |
| 2026-07-26 | Carbon `RegisterEventHotKey` en vez de `NSEvent` global monitor | Bloquea el atajo a nivel de sistema, evitando conflicto silencioso con Spotlight/Raycast/Alfred (riesgo explícito del PRD) |
| 2026-07-26 | `NSStatusItem` en vez de `MenuBarExtra` | Necesita ícono dinámico con estado de progreso y una sola fuente de verdad de ventanas junto al `NSPanel` custom |
| 2026-07-26 | ffmpeg se empaqueta junto a yt-dlp | Necesario para merge de video+audio en calidades altas de YouTube; sin esto el criterio "funciona en Mac limpia" se rompe en el caso más común |
| 2026-07-26 | Sin auto-reemplazo de binario en caliente en v1 | Reemplazar un binario firmado dentro de un bundle ya firmado invalida la firma; se difiere a Fase 2 con directorio externo |
| 2026-07-26 | `@AppStorage`/`UserDefaults` con security-scoped bookmarks para carpeta de descarga | Sin backend ni Core Data necesario; bookmarks son robustos a movimiento de carpetas sin costo adicional real |
| 2026-07-26 | `YTDLPService` como `actor` | Aísla estado mutable de procesos concurrentes bajo Swift 6 strict concurrency sin bloquear descargas paralelas reales |
