import AppKit
import Observation
import OSLog
import SwiftUI

@MainActor
@Observable
final class LauncherViewModel {
    /// Estados del frame único (DESIGN_LIQUID §2). `.input` es el default cuando no
    /// hay una descarga viva; los otros tres reflejan `currentDownload.state`.
    enum FrameState: Equatable, Hashable {
        case input
        case downloading
        case completed
        case error
    }

    var inputText = "" {
        didSet { guard inputText != oldValue else { return }; refreshDetection() }
    }
    private(set) var detectedURL: URL?
    private(set) var detectedSite: SupportedSite?
    /// Una sola descarga a la vez — vive en el actor incluso si el panel se cierra.
    private(set) var currentDownload: DownloadTask?
    private(set) var focusToken = 0
    /// Se incrementa en cada rechazo de input durante `.downloading` — la view lo
    /// observa para disparar el shake (o el pulso de opacity bajo Reduce Motion).
    private(set) var rejectionTick = 0
    var isVisible = false

    /// El panel AppKit se entera del alto y del estado agregado por closures —
    /// no hay una segunda fuente de verdad ni observación cruzada.
    var onHeightChange: ((CGFloat) -> Void)?
    var onAggregateStateChange: ((MenuBarIconRenderer.State) -> Void)?
    var onRequestClose: (() -> Void)?

    private var lastReportedHeight: CGFloat = 0
    private var lastReportedState: MenuBarIconRenderer.State = .idle

    let placeholder = "Paste a YouTube, TikTok, Instagram… link"

    var binariesMissing: Bool { !BundledBinaries.isReady }

    var showsUnrecognizedSiteChip: Bool {
        frameState == .input && detectedURL != nil && detectedSite == .other
    }

    var chip: (kind: InlineChip.Kind, symbol: String, text: String)? {
        guard frameState == .input else { return nil }
        if binariesMissing {
            return (.error, "exclamationmark.triangle", "yt-dlp missing — place it in Resources/bin (see README)")
        }
        if showsUnrecognizedSiteChip {
            return (.warning, "questionmark.circle", "Site not recognized — will try anyway")
        }
        return nil
    }

    var frameState: FrameState {
        guard let currentDownload else { return .input }
        switch currentDownload.state {
        case .queued, .downloading: return .downloading
        case .completed: return .completed
        case .failed: return .error
        }
    }

    /// Título mostrado en `.downloading` — "Preparando…" hasta que yt-dlp reporte el
    /// título real (DESIGN_LIQUID §2, tabla de `.downloading`).
    var downloadingTitle: String {
        currentDownload?.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Preparing…"
    }

    var downloadingTitleIsPlaceholder: Bool {
        (currentDownload?.title ?? "").isEmpty
    }

    var downloadingPercent: Double {
        currentDownload?.state.percent ?? 0
    }

    var completedTitle: String {
        currentDownload?.displayTitle ?? ""
    }

    var completedFileURL: URL? {
        if case .completed(let fileURL) = currentDownload?.state { return fileURL }
        return nil
    }

    var errorMessage: String {
        guard case .failed(let reason) = currentDownload?.state else { return "" }
        if let title = currentDownload?.title, !title.isEmpty {
            return "\(title) — \(reason.message)"
        }
        return reason.message
    }

    /// Fórmula exacta de DESIGN_LIQUID §1 — solo dos valores posibles en toda la app.
    var panelHeight: CGFloat {
        chip != nil ? Theme.Size.panelHeightWithChip : Theme.Size.panelHeightBase
    }

    // MARK: - Ciclo del panel

    func panelWillShow() {
        // `.completed`/`.error` no sobreviven a un cierre del panel — solo una
        // descarga en curso (`.queued`/`.downloading`) sigue viéndose al reabrir.
        if let currentDownload, !currentDownload.state.isActive {
            self.currentDownload = nil
        }

        if frameState == .input {
            if let clipboardURL = ClipboardService.detectURLOnPasteboard() {
                inputText = clipboardURL.absoluteString
            }
            refreshDetection()
            focusToken += 1
        }
        publishHeight()
        publishAggregateState()
    }

    func panelDidHide() {
        // La descarga sigue viva en el actor; solo se limpia la UI de entrada.
        if frameState == .input {
            inputText = ""
        }
    }

    func requestClose() {
        onRequestClose?()
    }

    // MARK: - Submit

    func submit() {
        guard frameState == .input else { return }
        guard let url = detectedURL else { return }
        guard !binariesMissing else {
            publishHeight()
            return
        }

        let folder = AppSettings.downloadFolder
        let task = DownloadTask(
            sourceURL: url,
            site: detectedSite ?? .other,
            destinationFolder: folder
        )
        currentDownload = task
        inputText = ""
        publishHeight()
        publishAggregateState()

        let quality = AppSettings.quality
        Task { await run(task: task, quality: quality) }
    }

    private func run(task: DownloadTask, quality: DownloadQuality) async {
        let id = task.id
        // El acceso security-scoped debe cubrir toda la descarga, no solo la resolución
        // de la URL — por eso se abre/cierra a mano en vez de usar el helper con scope.
        let scoped = task.destinationFolder.startAccessingSecurityScopedResource()
        defer { if scoped { task.destinationFolder.stopAccessingSecurityScopedResource() } }

        do {
            let fileURL = try await YTDLPService.shared.download(
                task: task,
                quality: quality,
                progress: { progress in
                    Task { @MainActor [weak self] in
                        self?.apply(progress: progress, to: id)
                    }
                },
                titleUpdate: { title in
                    Task { @MainActor [weak self] in
                        self?.apply(title: title, to: id)
                    }
                }
            )

            update(id: id) { $0.state = .completed(fileURL: fileURL) }
            publishHeight()
            publishAggregateState()
            await NotificationService.shared.notifyCompleted(fileURL: fileURL)
            await FileOpenerService.openIfConfigured(fileURL)
        } catch let error as YTDLPError {
            Logger.launcher.error("Descarga falló: \(error.localizedDescription, privacy: .public)")
            update(id: id) { $0.state = .failed(reason: error.failureReason) }
            publishHeight()
            publishAggregateState()
        } catch {
            update(id: id) { $0.state = .failed(reason: .siteBlockedOrChanged) }
            publishHeight()
            publishAggregateState()
        }
    }

    func cancel(taskID: UUID) {
        Task { await YTDLPService.shared.cancel(taskID: taskID) }
        update(id: taskID) { $0.state = .failed(reason: .cancelled) }
        publishHeight()
        publishAggregateState()
    }

    // MARK: - Input durante `.downloading`/`.completed`/`.error` (una sola descarga a la vez)

    /// Se llama desde el monitor de `keyDown` a nivel de ventana (`LauncherPanelController`)
    /// mientras el campo de texto real no existe (frame fuera de `.input`).
    /// Retorna `true` si el evento fue consumido.
    @discardableResult
    func handleFrameKeyDown(_ event: NSEvent) -> Bool {
        switch frameState {
        case .input:
            return false
        case .downloading:
            guard event.keyCode != Keycode.escape else { return false }
            rejectInputDuringDownload()
            return true
        case .completed, .error:
            guard event.keyCode != Keycode.escape else { return false }
            if isPasteCommand(event) {
                resumeInputFromPasteboard()
                return true
            }
            if let characters = printableCharacters(from: event) {
                resumeInput(with: characters)
                return true
            }
            return false
        }
    }

    private func rejectInputDuringDownload() {
        rejectionTick += 1
        AccessibilityNotification.Announcement("Wait for the current download to finish").post()
    }

    private func resumeInputFromPasteboard() {
        let pasted = NSPasteboard.general.string(forType: .string) ?? ""
        resumeInput(with: pasted)
    }

    private func resumeInput(with text: String) {
        currentDownload = nil
        inputText = text
        refreshDetection()
        focusToken += 1
        publishHeight()
        publishAggregateState()
    }

    private func isPasteCommand(_ event: NSEvent) -> Bool {
        event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "v"
    }

    private func printableCharacters(from event: NSEvent) -> String? {
        guard event.type == .keyDown, !event.modifierFlags.contains(.command) else { return nil }
        guard let characters = event.characters, let scalar = characters.unicodeScalars.first else { return nil }
        let value = scalar.value
        // Excluye control chars (<0x20, incluye Return/Tab/Escape), Delete (0x7F) y el
        // rango privado de teclas de función que usa AppKit para flechas/F-keys.
        guard value >= 0x20, value != 0x7F, !(0xF700...0xF8FF).contains(value) else { return nil }
        return characters
    }

    /// Texto anunciado por VoiceOver en cada transición de estado del frame — se posta
    /// una sola vez por transición, nunca en cada tick de `%` (DESIGN_LIQUID §VoiceOver).
    func announcement(from old: FrameState, to new: FrameState) -> String? {
        guard old != new else { return nil }
        switch new {
        case .downloading:
            return "Downloading"
        case .completed:
            return "Download completed: \(completedTitle)"
        case .error:
            return "Error: \(errorMessage)"
        case .input:
            return nil
        }
    }

    // MARK: - Privado

    private func refreshDetection() {
        let url = URLValidator.validate(inputText)
        detectedURL = url
        detectedSite = url.map(SupportedSite.detect(from:))
        publishHeight()
    }

    private func apply(progress: DownloadProgress, to id: UUID) {
        update(id: id) {
            $0.state = .downloading(percent: progress.percent, speed: progress.speed, eta: progress.eta)
        }
        publishAggregateState()
    }

    private func apply(title: String, to id: UUID) {
        update(id: id) { $0.title = title }
    }

    private func update(id: UUID, _ mutate: (inout DownloadTask) -> Void) {
        guard var task = currentDownload, task.id == id else { return }
        mutate(&task)
        currentDownload = task
    }

    private func publishHeight() {
        let height = panelHeight
        guard height != lastReportedHeight else { return }
        lastReportedHeight = height
        onHeightChange?(height)
    }

    /// Prioridad error > descargando > idle (DESIGN_LIQUID §4). Con una sola descarga
    /// posible, `aggregateState` ya no promedia `%` entre varias — refleja directamente
    /// `currentDownload.state`.
    private func publishAggregateState() {
        let state = aggregateState
        guard state != lastReportedState else { return }
        lastReportedState = state
        onAggregateStateChange?(state)
    }

    private var aggregateState: MenuBarIconRenderer.State {
        guard let currentDownload else { return .idle }
        switch currentDownload.state {
        case .failed(let reason):
            return reason == .cancelled ? .idle : .error
        case .downloading(let percent, _, _):
            return .downloading(percent: percent)
        case .queued:
            return .downloading(percent: 0)
        case .completed:
            return .idle
        }
    }
}

private enum Keycode {
    static let escape: UInt16 = 53
}
