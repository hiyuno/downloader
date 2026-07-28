import Foundation
import Testing

@testable import Downloader

/// Regresión del bug: videos de Instagram descargados con un .mp4 que Finder/QuickLook
/// no puede previsualizar porque el contenedor llevaba video VP9 en vez de H.264.
/// Causa raíz real: el extractor de Instagram no reporta `vcodec`/`acodec` para sus
/// streams progresivos H.264+AAC, así que un selector que exigiera `[vcodec^=avc1]`
/// en todas las ramas los descartaba y caía al único stream con metadata completa
/// (el DASH en VP9). `--ffmpeg-location` ya estaba presente — no era la causa.
@Suite("Argumentos de yt-dlp")
struct YTDLPArgumentsTests {

    private func task(url: String = "https://www.instagram.com/reel/DSIjtEfiYK9/") -> DownloadTask {
        DownloadTask(
            sourceURL: URL(string: url)!,
            site: .instagram,
            destinationFolder: URL(fileURLWithPath: "/tmp")
        )
    }

    @Test("--ffmpeg-location apunta al binario embebido cuando está disponible")
    func includesBundledFfmpegLocation() {
        let arguments = YTDLPService.arguments(for: task(), quality: .best)
        guard let index = arguments.firstIndex(of: "--ffmpeg-location") else {
            Issue.record("Falta --ffmpeg-location en los argumentos de yt-dlp")
            return
        }
        let path = arguments[arguments.index(after: index)]
        #expect(!path.isEmpty)
        #expect(path.hasSuffix("ffmpeg"))
    }

    @Test("El selector de formato no exige vcodec en todas las ramas de fallback")
    func formatSelectorToleratesMissingCodecMetadata() {
        for quality in DownloadQuality.allCases {
            let arguments = YTDLPService.arguments(for: task(), quality: quality)
            guard let formatIndex = arguments.firstIndex(of: "-f") else {
                Issue.record("Falta -f en los argumentos de yt-dlp")
                continue
            }
            let format = arguments[arguments.index(after: formatIndex)]
            let branches = format.split(separator: "/")
            let hasBranchWithoutVcodecFilter = branches.contains { branch in
                !branch.contains("vcodec")
            }
            #expect(
                hasBranchWithoutVcodecFilter,
                "\(quality): todas las ramas exigen vcodec explícito y descartan formatos sin esa metadata (el bug de Instagram)"
            )
        }
    }

    @Test("--merge-output-format sigue siendo mp4")
    func mergeOutputFormatIsMP4() {
        let arguments = YTDLPService.arguments(for: task(), quality: .best)
        guard let index = arguments.firstIndex(of: "--merge-output-format") else {
            Issue.record("Falta --merge-output-format")
            return
        }
        #expect(arguments[arguments.index(after: index)] == "mp4")
    }
}
