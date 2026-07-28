import Foundation

enum DownloadState: Sendable, Equatable {
    case queued
    case downloading(percent: Double, speed: String?, eta: String?)
    case completed(fileURL: URL)
    case failed(reason: DownloadFailureReason)

    var isActive: Bool {
        switch self {
        case .queued, .downloading: true
        case .completed, .failed: false
        }
    }

    var percent: Double? {
        if case .downloading(let percent, _, _) = self { return percent }
        return nil
    }
}

enum DownloadFailureReason: Sendable, Equatable {
    case unsupportedSite
    case networkError
    case siteBlockedOrChanged
    case invalidURL
    case cancelled
    case toolingUnavailable

    /// Nunca se muestra el enum crudo ni el stderr de yt-dlp sin traducir (DESIGN_LIQUID §2).
    var message: String {
        switch self {
        case .unsupportedSite: "This site isn't supported"
        case .networkError: "No connection — try again"
        case .siteBlockedOrChanged: "The site changed or blocked the download — not an app error"
        case .invalidURL: "That link isn't valid"
        case .cancelled: "Cancelled"
        case .toolingUnavailable: "Download engine missing — check Resources/bin"
        }
    }
}
