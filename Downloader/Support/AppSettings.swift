import Carbon.HIToolbox
import Foundation

enum DownloadQuality: String, CaseIterable, Sendable, Identifiable {
    case best
    case max1080
    case max720

    var id: String { rawValue }

    /// Nunca se expone esta sintaxis al usuario (TRD "Qué NO hacer").
    var formatArgument: String {
        switch self {
        case .best:
            "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/b"
        case .max1080:
            "bv*[ext=mp4][height<=1080]+ba[ext=m4a]/b[ext=mp4][height<=1080]/b[height<=1080]/b"
        case .max720:
            "bv*[ext=mp4][height<=720]+ba[ext=m4a]/b[ext=mp4][height<=720]/b[height<=720]/b"
        }
    }

    var displayName: String {
        switch self {
        case .best: "Mejor calidad"
        case .max1080: "1080p máx"
        case .max720: "720p máx"
        }
    }
}

enum AppSettings {
    static let downloadFolderKey = "downloadFolderBookmark"
    static let destinationAppBundleIDKey = "destinationAppBundleID"
    static let defaultQualityKey = "defaultQuality"
    static let hotkeyKeyCodeKey = "hotkeyKeyCode"
    static let hotkeyModifiersKey = "hotkeyModifiers"

    /// ⌥⌘Space — no choca con Spotlight (⌘Space) ni con Raycast (⌥Space).
    static let defaultHotkeyKeyCode = UInt32(kVK_Space)
    static let defaultHotkeyModifiers = UInt32(optionKey | cmdKey)

    static var defaultDownloadFolder: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Downloads")
    }

    static var quality: DownloadQuality {
        get {
            guard let raw = UserDefaults.standard.string(forKey: defaultQualityKey),
                  let value = DownloadQuality(rawValue: raw)
            else { return .best }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultQualityKey) }
    }

    static var destinationAppBundleID: String? {
        get { UserDefaults.standard.string(forKey: destinationAppBundleIDKey) }
        set { UserDefaults.standard.set(newValue, forKey: destinationAppBundleIDKey) }
    }

    static var hotkeyKeyCode: UInt32 {
        get {
            let stored = UserDefaults.standard.integer(forKey: hotkeyKeyCodeKey)
            return stored == 0 ? defaultHotkeyKeyCode : UInt32(stored)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: hotkeyKeyCodeKey) }
    }

    static var hotkeyModifiers: UInt32 {
        get {
            let stored = UserDefaults.standard.integer(forKey: hotkeyModifiersKey)
            return stored == 0 ? defaultHotkeyModifiers : UInt32(stored)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: hotkeyModifiersKey) }
    }

    // MARK: - Carpeta de descarga (security-scoped bookmark, no path plano)

    /// Devuelve la carpeta configurada. El acceso security-scoped se inicia y se detiene
    /// en el llamador vía `withDownloadFolderAccess`; esta propiedad solo resuelve la URL.
    static var downloadFolder: URL {
        resolveDownloadFolder()?.url ?? defaultDownloadFolder
    }

    static func setDownloadFolder(_ url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmark, forKey: downloadFolderKey)
    }

    /// Ejecuta `body` con el bookmark security-scoped activo, si existe.
    /// Sin sandbox no es estrictamente necesario, pero mantiene el código correcto
    /// si la app se sandboxea en el futuro (TRD §9).
    static func withDownloadFolderAccess<T>(_ body: (URL) throws -> T) rethrows -> T {
        guard let resolved = resolveDownloadFolder() else { return try body(defaultDownloadFolder) }
        let started = resolved.url.startAccessingSecurityScopedResource()
        defer { if started { resolved.url.stopAccessingSecurityScopedResource() } }
        return try body(resolved.url)
    }

    private static func resolveDownloadFolder() -> (url: URL, isStale: Bool)? {
        guard let data = UserDefaults.standard.data(forKey: downloadFolderKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale { try? setDownloadFolder(url) }
        return (url, isStale)
    }
}
