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
        // Rechaza strings que ya contienen un scheme URI (incluso de un solo colon, ej. mailto:, tel:, sms:)
        // El patrón omite "." para no rechazar puertos como "example.com:8080"
        if trimmed.range(of: "^[A-Za-z][A-Za-z0-9+-]*:", options: .regularExpression) != nil {
            return nil
        }
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
