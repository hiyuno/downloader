import Foundation
import OSLog

enum YTDLPError: LocalizedError, Sendable {
    case binaryMissing
    case launchFailed(String)
    case processFailed(status: Int32, stderr: String)
    case outputPathUnknown

    var errorDescription: String? {
        switch self {
        case .binaryMissing:
            "Couldn't find the bundled yt-dlp binary."
        case .launchFailed(let message):
            "Couldn't launch yt-dlp: \(message)"
        case .processFailed(let status, _):
            "yt-dlp exited with code \(status)."
        case .outputPathUnknown:
            "The download finished but the file path couldn't be determined."
        }
    }

    var failureReason: DownloadFailureReason {
        switch self {
        case .binaryMissing, .launchFailed:
            .toolingUnavailable
        case .outputPathUnknown:
            .siteBlockedOrChanged
        case .processFailed(let status, let stderr):
            status == SIGTERM + 128 || status == -15
                ? .cancelled
                : DownloadFailureReason.classify(stderr: stderr)
        }
    }
}

extension DownloadFailureReason {
    /// Traduce el stderr de yt-dlp a las causas que el PRD pide distinguir
    /// ("el sitio cambió" nunca se confunde con "el link no es válido").
    static func classify(stderr: String) -> DownloadFailureReason {
        let text = stderr.lowercased()
        if text.contains("interrupted") || text.contains("keyboardinterrupt") { return .cancelled }
        if text.contains("unsupported url") || text.contains("no video formats found") { return .unsupportedSite }
        if text.contains("is not a valid url") || text.contains("invalid url") { return .invalidURL }
        if text.contains("urlopen error") || text.contains("temporary failure in name resolution")
            || text.contains("network is unreachable") || text.contains("connection reset")
            || text.contains("timed out") { return .networkError }
        return .siteBlockedOrChanged
    }
}

actor YTDLPService {
    static let shared = YTDLPService()

    private var runningProcesses: [UUID: Process] = [:]

    /// Descarga y devuelve la ruta final del archivo.
    /// `progress` y `titleUpdate` se invocan desde el hilo de lectura del pipe.
    func download(
        task: DownloadTask,
        quality: DownloadQuality,
        progress: @escaping @Sendable (DownloadProgress) -> Void,
        titleUpdate: @escaping @Sendable (String) -> Void
    ) async throws -> URL {
        guard let executable = BundledBinaries.url(for: .ytdlp) else { throw YTDLPError.binaryMissing }

        let process = Process()
        process.executableURL = executable
        process.arguments = Self.arguments(for: task, quality: quality)

        var environment = ProcessInfo.processInfo.environment
        if let binDirectory = BundledBinaries.binDirectory {
            environment["PATH"] = binDirectory.path + ":" + (environment["PATH"] ?? "/usr/bin:/bin")
        }
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        let collector = OutputCollector()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            for line in collector.appendStdout(data) {
                if let parsed = DownloadProgress.parse(line) {
                    progress(parsed)
                } else if line.hasPrefix(DownloadProgress.Marker.title) {
                    let title = String(line.dropFirst(DownloadProgress.Marker.title.count))
                        .trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        collector.setTitle(title)
                        titleUpdate(title)
                    }
                } else if line.hasPrefix(DownloadProgress.Marker.filePath) {
                    let path = String(line.dropFirst(DownloadProgress.Marker.filePath.count))
                        .trimmingCharacters(in: .whitespaces)
                    if !path.isEmpty { collector.setFilePath(path) }
                }
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            collector.appendStderr(data)
        }

        runningProcesses[task.id] = process
        defer { runningProcesses[task.id] = nil }

        let status: Int32
        do {
            status = try await Self.run(process)
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw YTDLPError.launchFailed(error.localizedDescription)
        }

        collector.drain(stdout: stdoutPipe, stderr: stderrPipe)
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        guard status == 0 else {
            let stderr = collector.stderrText
            Logger.ytdlp.error("yt-dlp falló (\(status)): \(stderr, privacy: .public)")
            throw YTDLPError.processFailed(status: status, stderr: stderr)
        }
        guard let path = collector.filePath else { throw YTDLPError.outputPathUnknown }
        return URL(fileURLWithPath: path)
    }

    func cancel(taskID: UUID) {
        runningProcesses[taskID]?.terminate()
    }

    func embeddedVersion() async -> String? {
        guard let executable = BundledBinaries.url(for: .ytdlp) else { return nil }
        let process = Process()
        process.executableURL = executable
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? await Self.run(process)) == 0 else { return nil }
        let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        let version = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? nil : version
    }

    // MARK: - Privado

    /// `internal` (no `private`) para que los tests verifiquen los argumentos reales
    /// que se le pasan a yt-dlp — p.ej. que `--ffmpeg-location` siempre esté presente.
    static func arguments(for task: DownloadTask, quality: DownloadQuality) -> [String] {
        var arguments = [
            task.sourceURL.absoluteString,
            "-f", quality.formatArgument,
            "--merge-output-format", "mp4",
            "-o", task.destinationFolder.appending(path: "%(title)s.%(ext)s").path,
            "--newline",
            "--no-playlist",
            "--no-color",
            "--no-warnings",
            "--progress",
            "--progress-template",
            "download:\(DownloadProgress.Marker.progress)%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "--print", "before_dl:\(DownloadProgress.Marker.title)%(title)s",
            "--print", "after_move:\(DownloadProgress.Marker.filePath)%(filepath)s",
        ]
        if let ffmpeg = BundledBinaries.url(for: .ffmpeg) {
            arguments.append(contentsOf: ["--ffmpeg-location", ffmpeg.path])
        }
        return arguments
    }

    /// `waitUntilExit()` bloquearía el executor del actor — se usa `terminationHandler`.
    private static func run(_ process: Process) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finished in
                continuation.resume(returning: finished.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}

/// Acumula stdout/stderr desde los `readabilityHandler` (que corren fuera del actor).
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var stdoutBuffer = ""
    private var stderrBuffer = ""
    private var resolvedFilePath: String?
    private var resolvedTitle: String?

    func appendStdout(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        stdoutBuffer += String(decoding: data, as: UTF8.self)
        var lines: [String] = []
        while let range = stdoutBuffer.rangeOfCharacter(from: CharacterSet(charactersIn: "\n\r")) {
            let line = String(stdoutBuffer[stdoutBuffer.startIndex..<range.lowerBound])
            stdoutBuffer.removeSubrange(stdoutBuffer.startIndex..<range.upperBound)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { lines.append(trimmed) }
        }
        return lines
    }

    func appendStderr(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        stderrBuffer += String(decoding: data, as: UTF8.self)
    }

    func setFilePath(_ path: String) {
        lock.lock()
        resolvedFilePath = path
        lock.unlock()
    }

    func setTitle(_ title: String) {
        lock.lock()
        resolvedTitle = title
        lock.unlock()
    }

    /// Lee lo que quedó en los pipes después de que el proceso terminó.
    func drain(stdout: Pipe, stderr: Pipe) {
        if let data = try? stdout.fileHandleForReading.readToEnd(), !data.isEmpty {
            for line in appendStdout(data) where line.hasPrefix(DownloadProgress.Marker.filePath) {
                setFilePath(String(line.dropFirst(DownloadProgress.Marker.filePath.count))
                    .trimmingCharacters(in: .whitespaces))
            }
        }
        if let data = try? stderr.fileHandleForReading.readToEnd(), !data.isEmpty {
            appendStderr(data)
        }
    }

    var filePath: String? {
        lock.lock()
        defer { lock.unlock() }
        return resolvedFilePath
    }

    var stderrText: String {
        lock.lock()
        defer { lock.unlock() }
        return stderrBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
