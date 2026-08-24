import Foundation

/// Progreso parseado de una línea de `--progress-template`.
/// Función pura y testeable — nunca crashea ante formato inesperado, devuelve `nil`
/// y la UI cae a "Descargando… (sin progreso detallado)" (TRD riesgo #4).
struct DownloadProgress: Sendable, Equatable {
    let percent: Double
    let speed: String?
    let eta: String?

    /// Prefijos que la app inyecta en los templates de yt-dlp para poder distinguir
    /// líneas de progreso, de título y de ruta final en un único stdout.
    enum Marker {
        static let progress = "[dl]"
        static let title = "[title]"
        static let filePath = "[file]"
        static let liveStatus = "[live]"
    }

    static func parse(_ line: String) -> DownloadProgress? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(Marker.progress) else { return nil }

        let payload = trimmed.dropFirst(Marker.progress.count)
        let fields = payload.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let rawPercent = fields.first, let percent = parsePercent(rawPercent) else { return nil }

        return DownloadProgress(
            percent: percent,
            speed: sanitized(fields.count > 1 ? fields[1] : nil),
            eta: sanitized(fields.count > 2 ? fields[2] : nil)
        )
    }

    private static func parsePercent(_ raw: String) -> Double? {
        let value = raw.hasSuffix("%") ? String(raw.dropLast()) : raw
        guard let percent = Double(value), percent.isFinite else { return nil }
        return min(max(percent / 100, 0), 1)
    }

    private static func sanitized(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty, value != "N/A", value != "NA", !value.lowercased().contains("unknown") else { return nil }
        return value
    }
}

/// Interpreta el valor de `%(live_status)s` que yt-dlp imprime vía `Marker.liveStatus`.
/// `was_live` (directo ya terminado, ahora VOD) y `not_live` (video normal) sí se pueden
/// descargar — solo `is_live`/`is_upcoming` bloquean la descarga (TRD: nunca terminaría).
enum LiveStreamStatus {
    static func blocksDownload(_ rawValue: String) -> Bool {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value == "is_live" || value == "is_upcoming"
    }
}
