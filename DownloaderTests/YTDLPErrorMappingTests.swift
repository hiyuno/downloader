import Foundation
import Testing

@testable import Downloader

/// Cada `YTDLPError` debe terminar en un `DownloadFailureReason` correcto y en un
/// mensaje en español legible — nunca stderr crudo, nunca el nombre del enum.
@Suite("Mapeo de errores yt-dlp → DownloadFailureReason")
struct YTDLPErrorMappingTests {

    // MARK: - Exit codes → razón

    @Test("Exit code de SIGTERM (143) se mapea a cancelado, sin importar el stderr")
    func sigtermExitCodeMapsToCancelled() {
        let error = YTDLPError.processFailed(status: 143, stderr: "ERROR: Unsupported URL: https://x")
        #expect(error.failureReason == .cancelled)
    }

    @Test("Exit code -15 (señal directa) también se mapea a cancelado")
    func negativeSignalExitCodeMapsToCancelled() {
        let error = YTDLPError.processFailed(status: -15, stderr: "")
        #expect(error.failureReason == .cancelled)
    }

    @Test("Cancelación tiene prioridad sobre el contenido del stderr")
    func cancellationTakesPriorityOverStderrContent() {
        // Si el proceso murió por señal, no debería importar que el stderr también
        // contenga texto de "unsupported url" — la causa real es la cancelación.
        let error = YTDLPError.processFailed(
            status: 143, stderr: "ERROR: Unsupported URL: https://sitio-raro.example/video")
        #expect(error.failureReason == .cancelled)
    }

    @Test("Exit codes genéricos de fallo delegan en la clasificación del stderr")
    func genericExitCodeDelegatesToStderrClassification() {
        #expect(
            YTDLPError.processFailed(status: 1, stderr: "ERROR: Unsupported URL: https://x").failureReason
                == .unsupportedSite)
        #expect(
            YTDLPError.processFailed(status: 1, stderr: "urlopen error timed out").failureReason
                == .networkError)
        #expect(
            YTDLPError.processFailed(status: 2, stderr: "ERROR: '' is not a valid URL").failureReason
                == .invalidURL)
    }

    // MARK: - Otros casos de YTDLPError

    @Test("Binario faltante y fallo de lanzamiento se reportan como herramienta no disponible")
    func toolingUnavailableCases() {
        #expect(YTDLPError.binaryMissing.failureReason == .toolingUnavailable)
        #expect(YTDLPError.launchFailed("posix_spawn failed").failureReason == .toolingUnavailable)
    }

    @Test("Ruta de salida desconocida se reporta como el sitio cambió/bloqueó, no como bug propio")
    func outputPathUnknownMapsToSiteBlocked() {
        #expect(YTDLPError.outputPathUnknown.failureReason == .siteBlockedOrChanged)
    }

    // MARK: - classify(stderr:) — variantes reales de yt-dlp

    @Test("Clasifica variantes reales de mensajes de red")
    func classifiesNetworkVariants() {
        for stderr in [
            "urlopen error [Errno -2] Name or service not known",
            "Temporary failure in name resolution",
            "Network is unreachable",
            "Connection reset by peer",
            "Read timed out.",
        ] {
            #expect(
                DownloadFailureReason.classify(stderr: stderr) == .networkError,
                "esperaba networkError para: \(stderr)")
        }
    }

    @Test("Clasifica variantes reales de sitio no soportado")
    func classifiesUnsupportedSiteVariants() {
        for stderr in [
            "ERROR: Unsupported URL: https://ejemplo.tv/video/1",
            "ERROR: No video formats found!",
        ] {
            #expect(DownloadFailureReason.classify(stderr: stderr) == .unsupportedSite)
        }
    }

    @Test("Mensajes de bloqueo/cambio de sitio (bot-check, geo-restricción, 403) caen en el fallback correcto")
    func classifiesSiteBlockedFallbackVariants() {
        for stderr in [
            "ERROR: Sign in to confirm you're not a bot",
            "ERROR: This video is not available in your country",
            "ERROR: unable to download video data: HTTP Error 403: Forbidden",
            "ERROR: Private video. Sign in if you've been granted access to this video",
            "",
        ] {
            #expect(DownloadFailureReason.classify(stderr: stderr) == .siteBlockedOrChanged)
        }
    }

    @Test("La clasificación de stderr es insensible a mayúsculas/minúsculas")
    func classificationIsCaseInsensitive() {
        #expect(DownloadFailureReason.classify(stderr: "UNSUPPORTED URL: https://x") == .unsupportedSite)
        #expect(DownloadFailureReason.classify(stderr: "URLOPEN ERROR TIMED OUT") == .networkError)
        #expect(DownloadFailureReason.classify(stderr: "INTERRUPTED BY USER") == .cancelled)
    }

    // MARK: - Mensajes nunca exponen detalles crudos

    @Test("errorDescription de YTDLPError nunca incluye el stderr crudo completo")
    func errorDescriptionNeverLeaksRawStderr() {
        let sensitiveStderr = "ERROR: traceback super largo con paths internos /Users/dev/secret/token123"
        let error = YTDLPError.processFailed(status: 1, stderr: sensitiveStderr)
        let description = error.errorDescription ?? ""
        #expect(!description.contains("token123"))
        #expect(!description.contains("/Users/dev/secret"))
    }

    @Test("El mensaje final al usuario (DownloadFailureReason.message) nunca expone el nombre del case ni 'Error:'")
    func failureReasonMessageNeverLeaksInternals() {
        let stderr = "ERROR: Unsupported URL: https://x"
        let reason = DownloadFailureReason.classify(stderr: stderr)
        #expect(!reason.message.contains("unsupportedSite"))
        #expect(!reason.message.contains("ERROR:"))
        #expect(!reason.message.contains(stderr))
    }
}
