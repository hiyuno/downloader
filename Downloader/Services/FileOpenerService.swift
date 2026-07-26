import AppKit
import OSLog

@MainActor
enum FileOpenerService {
    /// Abre el archivo en la app configurada. Sin app configurada no hace nada
    /// (criterio de aceptación #7 del PRD: solo notificación).
    static func openIfConfigured(_ fileURL: URL) async {
        guard let bundleID = AppSettings.destinationAppBundleID, !bundleID.isEmpty else { return }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            Logger.launcher.error("App destino \(bundleID, privacy: .public) no encontrada")
            return
        }
        do {
            _ = try await NSWorkspace.shared.open(
                [fileURL],
                withApplicationAt: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } catch {
            Logger.launcher.error("No se pudo abrir el archivo: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func revealInFinder(_ fileURL: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    static func icon(forBundleIdentifier bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    static func name(forBundleIdentifier bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return FileManager.default.displayName(atPath: url.path)
    }
}
