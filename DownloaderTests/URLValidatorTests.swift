import Foundation
import Testing

@testable import Downloader

@Suite("URLValidator")
struct URLValidatorTests {

    @Test("Acepta URLs http/https bien formadas")
    func acceptsWellFormedURLs() {
        #expect(URLValidator.validate("https://www.youtube.com/watch?v=abc") != nil)
        #expect(URLValidator.validate("http://vimeo.com/12345") != nil)
        #expect(URLValidator.validate("  https://youtu.be/abc  ") != nil)
    }

    @Test("Normaliza links sin scheme")
    func normalizesSchemelessURLs() {
        let url = URLValidator.validate("youtu.be/dQw4w9WgXcQ")
        #expect(url?.scheme == "https")
        #expect(url?.host == "youtu.be")
    }

    @Test("Rechaza lo que no es una URL")
    func rejectsNonURLs() {
        #expect(URLValidator.validate("") == nil)
        #expect(URLValidator.validate("   ") == nil)
        #expect(URLValidator.validate("solo texto suelto") == nil)
        #expect(URLValidator.validate("sinpunto") == nil)
        #expect(URLValidator.validate("ftp://example.com/file") == nil)
        #expect(URLValidator.validate("file:///Users/me/video.mp4") == nil)
    }

    @Test("Detecta el sitio a partir del host")
    func detectsSites() throws {
        func site(_ raw: String) throws -> SupportedSite {
            let url = try #require(URLValidator.validate(raw))
            return SupportedSite.detect(from: url)
        }

        #expect(try site("https://www.youtube.com/watch?v=abc") == .youtube)
        #expect(try site("https://youtu.be/abc") == .youtube)
        #expect(try site("https://www.instagram.com/reel/abc") == .instagram)
        #expect(try site("https://www.tiktok.com/@user/video/1") == .tiktok)
        #expect(try site("https://x.com/user/status/1") == .twitter)
        #expect(try site("https://twitter.com/user/status/1") == .twitter)
        #expect(try site("https://vimeo.com/12345") == .other)
    }

    @Test("Un sitio no reconocido no bloquea — solo deja de estar reconocido")
    func unrecognizedSiteIsNotBlocking() throws {
        let url = try #require(URLValidator.validate("https://ejemplo.tv/video/1"))
        #expect(SupportedSite.detect(from: url) == .other)
        #expect(SupportedSite.other.isRecognized == false)
    }
}
