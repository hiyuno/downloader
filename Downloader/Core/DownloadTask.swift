import Foundation

struct DownloadTask: Identifiable, Sendable, Equatable {
    let id: UUID
    let sourceURL: URL
    let site: SupportedSite
    let destinationFolder: URL
    var title: String?
    var state: DownloadState

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        site: SupportedSite,
        destinationFolder: URL,
        title: String? = nil,
        state: DownloadState = .queued
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.site = site
        self.destinationFolder = destinationFolder
        self.title = title
        self.state = state
    }

    /// Título de fila: el título real del video si yt-dlp ya lo imprimió, el nombre del
    /// archivo final si terminó, y la URL cruda como último recurso.
    var displayTitle: String {
        if case .completed(let fileURL) = state { return fileURL.lastPathComponent }
        if let title, !title.isEmpty { return title }
        if case .queued = state { return "Preparando…" }
        return sourceURL.absoluteString
    }
}
