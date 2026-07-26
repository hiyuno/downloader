import AppKit

/// Wrappers de `NSOpenPanel`. Se guarda el bundle identifier de la app (no el path)
/// y un security-scoped bookmark de la carpeta (no un String) — TRD §9.
@MainActor
enum AppPicker {
    static func chooseApplication() -> String? {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Elegir"
        panel.message = "Elige la app donde se abrirá el video al terminar."

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }

    static func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.directoryURL = AppSettings.downloadFolder
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Elegir"
        panel.message = "Elige la carpeta donde se guardarán los videos."

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
