import Foundation

enum URLValidator {
    /// Valida la *forma* de una URL, sin decir nada sobre si el sitio está soportado.
    /// Un string sin scheme pero con host plausible (`youtu.be/abc`) se normaliza a `https://`
    /// porque copiar links sin scheme desde la barra de direcciones es común.
    static func validate(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }

        if let url = normalizedHTTPURL(trimmed) { return url }
        guard !trimmed.contains("://"), trimmed.contains("."), !trimmed.hasPrefix(".") else { return nil }
        return normalizedHTTPURL("https://" + trimmed)
    }

    private static func normalizedHTTPURL(_ candidate: String) -> URL? {
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              host.contains("."),
              !host.hasSuffix(".")
        else { return nil }
        return url
    }
}
