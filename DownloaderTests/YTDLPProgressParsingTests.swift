import Foundation
import Testing

@testable import Downloader

@Suite("Parsing de --progress-template")
struct YTDLPProgressParsingTests {

    @Test("Parsea una línea completa")
    func parsesFullLine() throws {
        let progress = try #require(DownloadProgress.parse("[dl]  42.3%|  3.40MiB/s|00:12"))
        #expect(abs(progress.percent - 0.423) < 0.0001)
        #expect(progress.speed == "3.40MiB/s")
        #expect(progress.eta == "00:12")
    }

    @Test("Trata N/A y Unknown como ausencia de dato, no como texto")
    func treatsUnknownFieldsAsNil() throws {
        let progress = try #require(DownloadProgress.parse("[dl] 0.0%|N/A|Unknown ETA"))
        #expect(progress.percent == 0)
        #expect(progress.speed == nil)
        #expect(progress.eta == nil)
    }

    @Test("Clampea el porcentaje a 0…1")
    func clampsPercent() throws {
        #expect(try #require(DownloadProgress.parse("[dl] 100.0%|1MiB/s|00:00")).percent == 1)
        #expect(try #require(DownloadProgress.parse("[dl] 140.0%|1MiB/s|00:00")).percent == 1)
        #expect(try #require(DownloadProgress.parse("[dl] -3.0%|1MiB/s|00:00")).percent == 0)
    }

    @Test("Devuelve nil ante formato inesperado en vez de crashear")
    func returnsNilOnUnexpectedFormat() {
        #expect(DownloadProgress.parse("") == nil)
        #expect(DownloadProgress.parse("[download] 42% of 10MiB at 3MiB/s") == nil)
        #expect(DownloadProgress.parse("[dl] no-es-un-numero|x|y") == nil)
        #expect(DownloadProgress.parse("[file]/Users/me/Downloads/clip.mp4") == nil)
        #expect(DownloadProgress.parse("[title]Un video") == nil)
    }

    @Test("Tolera campos faltantes")
    func toleratesMissingFields() throws {
        let progress = try #require(DownloadProgress.parse("[dl] 7.5%"))
        #expect(abs(progress.percent - 0.075) < 0.0001)
        #expect(progress.speed == nil)
        #expect(progress.eta == nil)
    }

    @Test("Clasifica el stderr en la causa correcta")
    func classifiesFailureReasons() {
        #expect(DownloadFailureReason.classify(stderr: "ERROR: Unsupported URL: https://x") == .unsupportedSite)
        #expect(DownloadFailureReason.classify(stderr: "urlopen error timed out") == .networkError)
        #expect(DownloadFailureReason.classify(stderr: "ERROR: '' is not a valid URL") == .invalidURL)
        #expect(DownloadFailureReason.classify(stderr: "ERROR: Sign in to confirm you're not a bot") == .siteBlockedOrChanged)
        #expect(DownloadFailureReason.classify(stderr: "Interrupted by user") == .cancelled)
    }

    @Test("Ningún mensaje de error expone el enum crudo ni el stderr")
    func messagesAreHumanReadable() {
        let reasons: [DownloadFailureReason] = [
            .unsupportedSite, .networkError, .siteBlockedOrChanged,
            .invalidURL, .cancelled, .toolingUnavailable,
        ]
        for reason in reasons {
            #expect(!reason.message.isEmpty)
            #expect(!reason.message.contains("ERROR:"))
        }
    }
}
