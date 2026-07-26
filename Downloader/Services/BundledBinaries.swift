import Foundation

/// Resuelve los binarios empaquetados. La Build Phase los copia a
/// `Contents/MacOS/bin` (destino Executables, correcto para firma), pero se busca
/// también en `Contents/Resources/bin` porque el TRD referencia ambas rutas.
enum BundledBinaries {
    enum Tool: String, Sendable {
        case ytdlp = "yt-dlp"
        case ffmpeg = "ffmpeg"
    }

    static var binDirectory: URL? {
        candidateDirectories.first { directory in
            FileManager.default.fileExists(atPath: directory.appending(path: Tool.ytdlp.rawValue).path)
        }
    }

    static func url(for tool: Tool) -> URL? {
        for directory in candidateDirectories {
            let candidate = directory.appending(path: tool.rawValue)
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    static var isReady: Bool { url(for: .ytdlp) != nil }

    private static var candidateDirectories: [URL] {
        var directories: [URL] = []
        if let executable = Bundle.main.executableURL?.deletingLastPathComponent() {
            directories.append(executable.appending(path: "bin"))
        }
        if let resources = Bundle.main.resourceURL {
            directories.append(resources.appending(path: "bin"))
        }
        return directories
    }
}
