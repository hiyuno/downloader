import Foundation
import Testing

@testable import Downloader

/// Streams de yt-dlp en la vida real vienen sucios: líneas cortadas por buffering,
/// warnings intercaladas, y valores numéricos que no deberían existir pero existen.
@Suite("Parsing de --progress-template — streams sucios")
struct YTDLPProgressParsingHostileTests {

    // MARK: - Porcentajes fuera de rango / no numéricos

    @Test("NaN e Infinity nunca se cuelan como porcentaje válido")
    func rejectsNaNAndInfinity() {
        #expect(DownloadProgress.parse("[dl] nan%|1MiB/s|00:00") == nil)
        #expect(DownloadProgress.parse("[dl] -nan%|1MiB/s|00:00") == nil)
        #expect(DownloadProgress.parse("[dl] inf%|1MiB/s|00:00") == nil)
        #expect(DownloadProgress.parse("[dl] -inf%|1MiB/s|00:00") == nil)
        #expect(DownloadProgress.parse("[dl] infinity%|1MiB/s|00:00") == nil)
    }

    @Test("Porcentajes extremos fuera de 0…100 se clampean, no truncan a basura")
    func clampsExtremePercents() throws {
        #expect(try #require(DownloadProgress.parse("[dl] 999999.0%|1MiB/s|00:00")).percent == 1)
        #expect(try #require(DownloadProgress.parse("[dl] -999999.0%|1MiB/s|00:00")).percent == 0)
    }

    @Test("Cero y valores con muchos decimales se parsean sin perder precisión relevante")
    func parsesZeroAndHighPrecisionValues() throws {
        #expect(try #require(DownloadProgress.parse("[dl] 0.0%|N/A|N/A")).percent == 0)
        let precise = try #require(DownloadProgress.parse("[dl] 33.333333%|1MiB/s|00:01"))
        #expect(abs(precise.percent - 0.33333333) < 0.0001)
    }

    // MARK: - Líneas parciales / cortadas por buffering

    @Test("Línea cortada a mitad de escritura (sin pipes, sin '%' todavía) no crashea")
    func handlesTruncatedLineWithoutPipes() throws {
        // Buffering de pipe puede entregar "[dl]  42.3" antes de que llegue el resto
        // ("%|velocidad|eta"). El parser no distingue "número sin %" de "número con %",
        // así que interpreta 42.3 como 42.3% — comportamiento real documentado aquí,
        // no un crash ni un valor basura.
        let progress = try #require(DownloadProgress.parse("[dl]  42.3"))
        #expect(abs(progress.percent - 0.423) < 0.0001)
        #expect(progress.speed == nil)
        #expect(progress.eta == nil)
    }

    @Test("Línea vacía tras el marcador no crashea")
    func handlesEmptyPayloadAfterMarker() {
        #expect(DownloadProgress.parse("[dl]") == nil)
        #expect(DownloadProgress.parse("[dl] ") == nil)
        #expect(DownloadProgress.parse("[dl]|||") == nil)
    }

    @Test("Pipes de más no rompen el parseo — los campos extra se ignoran")
    func extraPipesAreIgnored() throws {
        let progress = try #require(DownloadProgress.parse("[dl] 50.0%|2MiB/s|00:10|campo_extra|otro_mas"))
        #expect(progress.percent == 0.5)
        #expect(progress.speed == "2MiB/s")
        #expect(progress.eta == "00:10")
    }

    // MARK: - Warnings intercaladas

    @Test("Warnings de yt-dlp intercaladas nunca se confunden con progreso")
    func warningsInterleavedWithProgressAreIgnored() {
        let stream = [
            "[dl] 10.0%|1MiB/s|00:30",
            "WARNING: [youtube] Falling back to generic n function search",
            "[dl] 20.0%|1MiB/s|00:25",
            "ERROR: unable to download video data: HTTP Error 403: Forbidden",
            "[dl] 30.0%|1MiB/s|00:20",
        ]
        let parsed = stream.map(DownloadProgress.parse)
        #expect(parsed[0]?.percent == 0.1)
        #expect(parsed[1] == nil)
        #expect(parsed[2]?.percent == 0.2)
        #expect(parsed[3] == nil)
        #expect(parsed[4]?.percent == 0.3)
    }

    // MARK: - Marcadores mezclados y repetidos

    @Test("Los marcadores [title] y [file] nunca se interpretan como progreso, sin importar el contenido")
    func titleAndFileMarkersNeverParseAsProgress() {
        #expect(DownloadProgress.parse("[title]50.0% not a percent") == nil)
        #expect(DownloadProgress.parse("[file]/Users/me/Downloads/50.0%.mp4") == nil)
    }

    @Test("Marcadores repetidos en secuencia se procesan línea por línea de forma independiente")
    func repeatedMarkersAreProcessedIndependently() {
        let stream = [
            "[title]Primer título",
            "[title]Segundo título (yt-dlp reintentó)",
            "[dl] 5.0%|500KiB/s|01:00",
            "[dl] 5.0%|500KiB/s|01:00",
            "[file]/tmp/a.mp4",
            "[file]/tmp/b.mp4",
        ]
        let progressLines = stream.compactMap(DownloadProgress.parse)
        #expect(progressLines.count == 2)
        #expect(progressLines.allSatisfy { $0.percent == 0.05 })
    }

    // MARK: - UTF-8 raro en velocidad/ETA (el título en sí no lo parsea DownloadProgress)

    @Test("Emoji, CJK y texto RTL en los campos de velocidad/ETA no crashean el parseo")
    func toleratesUnusualUTF8InSpeedAndETAFields() throws {
        let emoji = try #require(DownloadProgress.parse("[dl] 42.0%|🔥3.4MiB/s🔥|00:10"))
        #expect(emoji.percent == 0.42)
        #expect(emoji.speed == "🔥3.4MiB/s🔥")

        let cjk = try #require(DownloadProgress.parse("[dl] 60.0%|1MiB/s|剩余10秒"))
        #expect(cjk.eta == "剩余10秒")

        let rtl = try #require(DownloadProgress.parse("[dl] 15.0%|١MiB/s|٠٠:٠٥"))
        #expect(rtl.percent == 0.15)
        #expect(rtl.speed == "١MiB/s")
    }

    @Test("N/A, NA y variantes de 'unknown' en distintos casing se tratan como ausencia de dato")
    func treatsUnknownVariantsCaseInsensitively() throws {
        #expect(try #require(DownloadProgress.parse("[dl] 1.0%|N/A|N/A")).speed == nil)
        #expect(try #require(DownloadProgress.parse("[dl] 1.0%|NA|NA")).eta == nil)
        #expect(try #require(DownloadProgress.parse("[dl] 1.0%|Unknown speed|Unknown ETA")).speed == nil)
        #expect(try #require(DownloadProgress.parse("[dl] 1.0%|UNKNOWN|unknown")).eta == nil)
    }
}
