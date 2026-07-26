import Foundation
import Testing

@testable import Downloader

/// Casos hostiles para URLValidator/SupportedSite: lo que un usuario real pega desde
/// la barra de direcciones, notas, o un chat — no solo el camino feliz.
@Suite("URLValidator — casos hostiles")
struct URLValidatorHostileTests {

    // MARK: - Espacios y whitespace

    @Test("Espacios internos rechazan la URL entera, no solo se recortan")
    func internalWhitespaceIsRejected() {
        #expect(URLValidator.validate("https://www.youtube.com/watch?v=a b") == nil)
    }

    @Test(
        "Nota de comportamiento: un tab embebido (no espacio literal) sobrevive al guard y Foundation lo percent-encodea"
    )
    func embeddedTabIsPercentEncodedNotRejected() throws {
        // El guard de URLValidator solo revisa `.contains(" ")` (espacio literal), no
        // whitespace arbitrario en medio de la URL. Un tab embebido pasa el guard y
        // `URL(string:)` lo percent-encodea a %09 en vez de que el validador lo rechace.
        // Documentado aquí como comportamiento real, no como bug bloqueante: el resultado
        // sigue siendo una URL bien formada al mismo host, no un host distinto.
        let url = try #require(URLValidator.validate("https://youtu.be/abc\tdef"))
        #expect(url.host == "youtu.be")
        #expect(url.absoluteString.contains("%09"))
    }

    @Test("Tabs y saltos de línea alrededor se recortan igual que espacios")
    func tabsAndNewlinesAroundAreTrimmed() {
        #expect(URLValidator.validate("\n\thttps://youtu.be/dQw4w9WgXcQ\t\n") != nil)
        #expect(URLValidator.validate("\r\nhttps://www.youtube.com/watch?v=abc\r\n") != nil)
    }

    @Test("Un string de solo whitespace no es una URL")
    func onlyWhitespaceIsRejected() {
        #expect(URLValidator.validate("\t\t") == nil)
        #expect(URLValidator.validate("\n") == nil)
    }

    // MARK: - Esquemas raros

    @Test("Rechaza esquemas que no son http/https (con '://' explícito o sin dominio)")
    func rejectsExoticSchemes() {
        #expect(URLValidator.validate("javascript:alert(1)") == nil)
        #expect(URLValidator.validate("ftp://example.com/file.mp4") == nil)
        #expect(URLValidator.validate("file:///Users/me/video.mp4") == nil)
        #expect(URLValidator.validate("data:text/html,<script>1</script>") == nil)
        #expect(URLValidator.validate("rtsp://example.com/stream") == nil)
    }

    @Test("Esquemas de un solo dos-puntos (mailto:, tel:, sms:) se rechazan")
    func singleColonSchemesAreRejected() {
        #expect(URLValidator.validate("mailto:me@example.com") == nil)
        #expect(URLValidator.validate("tel:+1234567890") == nil)
        #expect(URLValidator.validate("sms:+1234567890") == nil)
    }

    @Test("El scheme es case-insensitive")
    func schemeIsCaseInsensitive() {
        let url = URLValidator.validate("HTTPS://www.youtube.com/watch?v=abc")
        #expect(url != nil)
        #expect(url?.scheme?.lowercased() == "https")
    }

    // MARK: - youtu.be, shorts, playlists, subdominios

    @Test("Acepta youtu.be corto y lo detecta como YouTube")
    func acceptsShortYoutubeLink() throws {
        let url = try #require(URLValidator.validate("https://youtu.be/dQw4w9WgXcQ"))
        #expect(SupportedSite.detect(from: url) == .youtube)
    }

    @Test("Acepta YouTube Shorts")
    func acceptsYoutubeShorts() throws {
        let url = try #require(URLValidator.validate("https://www.youtube.com/shorts/abc12345678"))
        #expect(SupportedSite.detect(from: url) == .youtube)
    }

    @Test("URLs de playlist se aceptan a nivel de validación — el PRD las descarta en la ejecución (--no-playlist), no en el validador")
    func playlistURLsAreAcceptedByValidator() throws {
        let playlistOnly = try #require(URLValidator.validate("https://www.youtube.com/playlist?list=PLabcdefgh"))
        #expect(SupportedSite.detect(from: playlistOnly) == .youtube)

        let watchWithList = try #require(
            URLValidator.validate("https://www.youtube.com/watch?v=abc123&list=PLxyz&index=3"))
        #expect(SupportedSite.detect(from: watchWithList) == .youtube)
    }

    @Test("Detecta subdominios móviles y de compartir como el sitio principal")
    func detectsMobileAndShareSubdomains() throws {
        func site(_ raw: String) throws -> SupportedSite {
            let url = try #require(URLValidator.validate(raw))
            return SupportedSite.detect(from: url)
        }

        #expect(try site("https://m.youtube.com/watch?v=abc") == .youtube)
        #expect(try site("https://vm.tiktok.com/ZMabcdef/") == .tiktok)
        #expect(try site("https://www.instagram.com/reel/abc123/") == .instagram)
        #expect(try site("https://mobile.twitter.com/user/status/1") == .twitter)
    }

    @Test("Tolera query params extra (tracking, índices, timestamps) sin romper la detección")
    func toleratesExtraQueryParams() throws {
        let url = try #require(
            URLValidator.validate(
                "https://www.youtube.com/watch?v=abc123&t=45s&feature=share&utm_source=x&fbclid=y"))
        #expect(SupportedSite.detect(from: url) == .youtube)
    }

    @Test("Tolera userinfo y puerto explícito en la URL")
    func toleratesUserinfoAndPort() throws {
        let url = try #require(URLValidator.validate("https://user:pass@www.youtube.com:8443/watch?v=abc"))
        #expect(SupportedSite.detect(from: url) == .youtube)
    }

    // MARK: - Texto que no es URL / sitios no soportados

    @Test("Texto libre sin forma de URL se rechaza")
    func rejectsFreeformText() {
        #expect(URLValidator.validate("mira este video que encontré") == nil)
        #expect(URLValidator.validate("😂😂😂 buenísimo") == nil)
        #expect(URLValidator.validate("¿viste esto?") == nil)
    }

    @Test("Host con punto final se rechaza (FQDN mal formado)")
    func rejectsTrailingDotHost() {
        #expect(URLValidator.validate("https://youtube.com./watch?v=abc") == nil)
    }

    @Test(
        "Sitio no soportado por la lista conocida se acepta igual — la UI decide mostrar el chip de 'se intentará de todas formas' (TRD §7)"
    )
    func unsupportedButWellFormedSitesAreAccepted() throws {
        for raw in [
            "https://www.dailymotion.com/video/x1abc",
            "https://www.reddit.com/r/videos/comments/1abc/title/",
            "https://streamable.com/abc123",
            "https://www.facebook.com/watch/?v=123456",
        ] {
            let url = try #require(URLValidator.validate(raw), "debería validar como URL: \(raw)")
            let site = SupportedSite.detect(from: url)
            #expect(site == .other)
            #expect(!site.isRecognized)
        }
    }
}
