import AppKit
import Observation
import OSLog

@MainActor
@Observable
final class SettingsViewModel {
    private(set) var destinationAppBundleID: String?
    private(set) var downloadFolder: URL
    var quality: DownloadQuality {
        didSet { AppSettings.quality = quality }
    }
    private(set) var folderError: String?

    init() {
        destinationAppBundleID = AppSettings.destinationAppBundleID
        downloadFolder = AppSettings.downloadFolder
        quality = AppSettings.quality
    }

    var destinationAppName: String? {
        guard let destinationAppBundleID else { return nil }
        return FileOpenerService.name(forBundleIdentifier: destinationAppBundleID)
    }

    var destinationAppIcon: NSImage? {
        guard let destinationAppBundleID else { return nil }
        return FileOpenerService.icon(forBundleIdentifier: destinationAppBundleID)
    }

    var abbreviatedFolderPath: String {
        (downloadFolder.path as NSString).abbreviatingWithTildeInPath
    }

    var binariesMissing: Bool { !BundledBinaries.isReady }

    func changeDestinationApp() {
        guard let bundleID = AppPicker.chooseApplication() else { return }
        AppSettings.destinationAppBundleID = bundleID
        destinationAppBundleID = bundleID
    }

    func clearDestinationApp() {
        AppSettings.destinationAppBundleID = nil
        destinationAppBundleID = nil
    }

    func changeDownloadFolder() {
        guard let url = AppPicker.chooseFolder() else { return }
        do {
            try AppSettings.setDownloadFolder(url)
            downloadFolder = url
            folderError = nil
        } catch {
            Logger.settings.error("Bookmark falló: \(error.localizedDescription, privacy: .public)")
            folderError = "No se pudo guardar el acceso a esa carpeta."
        }
    }
}
