import AppKit
import Observation
import OSLog

@MainActor
@Observable
final class LauncherViewModel {
    var inputText = "" {
        didSet { guard inputText != oldValue else { return }; refreshDetection() }
    }
    private(set) var detectedURL: URL?
    private(set) var detectedSite: SupportedSite?
    private(set) var activeDownloads: [DownloadTask] = []
    private(set) var focusToken = 0
    var isVisible = false

    /// El panel AppKit se entera del alto y del estado agregado por closures —
    /// no hay una segunda fuente de verdad ni observación cruzada.
    var onHeightChange: ((CGFloat) -> Void)?
    var onAggregateStateChange: ((MenuBarIconRenderer.State) -> Void)?
    var onRequestClose: (() -> Void)?

    private var lastReportedHeight: CGFloat = 0
    private var lastReportedState: MenuBarIconRenderer.State = .idle

    let placeholder = "Pega un link de YouTube, TikTok, Instagram…"

    var binariesMissing: Bool { !BundledBinaries.isReady }

    var showsUnrecognizedSiteChip: Bool {
        detectedURL != nil && detectedSite == .other
    }

    var chip: (kind: InlineChip.Kind, symbol: String, text: String)? {
        if binariesMissing {
            return (.error, "exclamationmark.triangle", "Falta yt-dlp — colócalo en Resources/bin (ver README)")
        }
        if showsUnrecognizedSiteChip {
            return (.warning, "questionmark.circle", "Sitio no reconocido — se intentará de todas formas")
        }
        return nil
    }

    /// Fórmula exacta de la tabla de dimensiones de DESIGN_LIQUID §1.
    var panelHeight: CGFloat {
        var height = Theme.Spacing.panelPadding * 2 + Theme.Spacing.inputRowHeight
        if chip != nil {
            height += Theme.Spacing.inputToChip + Theme.Spacing.chipHeight
        }
        if !activeDownloads.isEmpty {
            let rows = CGFloat(activeDownloads.count)
            height += Theme.Spacing.inputToList
            height += rows * Theme.Spacing.rowHeight + (rows - 1) * Theme.Spacing.betweenRows
        }
        return min(height, Theme.Size.panelMaxHeight)
    }

    var listExceedsPanel: Bool {
        guard !activeDownloads.isEmpty else { return false }
        var height = Theme.Spacing.panelPadding * 2 + Theme.Spacing.inputRowHeight
        if chip != nil { height += Theme.Spacing.inputToChip + Theme.Spacing.chipHeight }
        let rows = CGFloat(activeDownloads.count)
        height += Theme.Spacing.inputToList
        height += rows * Theme.Spacing.rowHeight + (rows - 1) * Theme.Spacing.betweenRows
        return height > Theme.Size.panelMaxHeight
    }

    // MARK: - Ciclo del panel

    func panelWillShow() {
        if let clipboardURL = ClipboardService.detectURLOnPasteboard() {
            inputText = clipboardURL.absoluteString
        }
        refreshDetection()
        focusToken += 1
        publishHeight()
        publishAggregateState()
    }

    func panelDidHide() {
        // La descarga sigue viva en el actor; solo se limpia la UI de entrada.
        inputText = ""
    }

    func requestClose() {
        onRequestClose?()
    }

    // MARK: - Submit

    func submit() {
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
        activeDownloads.insert(task, at: 0)
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
            publishAggregateState()
            await NotificationService.shared.notifyCompleted(fileURL: fileURL)
            await FileOpenerService.openIfConfigured(fileURL)
        } catch let error as YTDLPError {
            Logger.launcher.error("Descarga falló: \(error.localizedDescription, privacy: .public)")
            update(id: id) { $0.state = .failed(reason: error.failureReason) }
            publishAggregateState()
        } catch {
            update(id: id) { $0.state = .failed(reason: .siteBlockedOrChanged) }
            publishAggregateState()
        }
    }

    func cancel(taskID: UUID) {
        Task { await YTDLPService.shared.cancel(taskID: taskID) }
        update(id: taskID) { $0.state = .failed(reason: .cancelled) }
        publishAggregateState()
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
        guard let index = activeDownloads.firstIndex(where: { $0.id == id }) else { return }
        mutate(&activeDownloads[index])
    }

    private func publishHeight() {
        let height = panelHeight
        guard height != lastReportedHeight else { return }
        lastReportedHeight = height
        onHeightChange?(height)
    }

    /// Prioridad error > descargando > idle (DESIGN_LIQUID §4).
    private func publishAggregateState() {
        let state = aggregateState
        guard state != lastReportedState else { return }
        lastReportedState = state
        onAggregateStateChange?(state)
    }

    private var aggregateState: MenuBarIconRenderer.State {
        let downloading = activeDownloads.compactMap(\.state.percent)
        if activeDownloads.contains(where: {
            if case .failed(let reason) = $0.state { return reason != .cancelled }
            return false
        }) {
            return .error
        }
        if !downloading.isEmpty {
            return .downloading(percent: downloading.reduce(0, +) / Double(downloading.count))
        }
        if activeDownloads.contains(where: { $0.state == .queued }) {
            return .downloading(percent: 0)
        }
        return .idle
    }

    /// El estado de error del menu bar no queda pegado: se limpia al reabrir el launcher.
    func clearFinishedFailures() {
        activeDownloads.removeAll {
            if case .failed = $0.state { return true }
            return false
        }
        publishHeight()
        publishAggregateState()
    }
}
