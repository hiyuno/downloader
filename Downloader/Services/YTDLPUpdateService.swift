import Foundation
import OSLog

/// v1: solo verifica, nunca reemplaza el binario en caliente (rompería la firma del
/// bundle notarizado — TRD §5 "Estrategia de actualización del binario").
@MainActor
@Observable
final class YTDLPUpdateService {
    static let shared = YTDLPUpdateService()

    private(set) var embeddedVersion: String?
    private(set) var latestVersion: String?
    private(set) var isChecking = false

    var updateAvailable: Bool {
        guard let embeddedVersion, let latestVersion else { return false }
        return embeddedVersion.compare(latestVersion, options: .numeric) == .orderedAscending
    }

    private init() {}

    /// Se dispara al iniciar la app, en background, sin bloquear el launcher.
    func check() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        embeddedVersion = await YTDLPService.shared.embeddedVersion()
        latestVersion = await Self.fetchLatestRelease()
    }

    private static func fetchLatestRelease() async -> String? {
        let url = URL(string: "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let payload = try JSONDecoder().decode(Release.self, from: data)
            return payload.tag_name
        } catch {
            Logger.ytdlp.debug("No se pudo consultar el último release: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private struct Release: Decodable {
        let tag_name: String
    }
}
