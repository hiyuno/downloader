import Foundation

enum SupportedSite: String, CaseIterable, Sendable {
    case youtube
    case instagram
    case tiktok
    case twitter
    case other

    static func detect(from url: URL) -> SupportedSite {
        guard let host = url.host?.lowercased() else { return .other }
        if host.contains("youtube.com") || host.contains("youtu.be") { return .youtube }
        if host.contains("instagram.com") { return .instagram }
        if host.contains("tiktok.com") { return .tiktok }
        if host.contains("twitter.com") || host.contains("x.com") { return .twitter }
        return .other
    }

    var displayName: String {
        switch self {
        case .youtube: "YouTube"
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .twitter: "X"
        case .other: "Unrecognized site"
        }
    }

    var symbolName: String {
        switch self {
        case .youtube, .instagram, .tiktok, .twitter: "play.rectangle"
        case .other: "questionmark.circle"
        }
    }

    var isRecognized: Bool { self != .other }
}
