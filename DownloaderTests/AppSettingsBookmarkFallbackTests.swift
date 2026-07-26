import Foundation
import Testing

@testable import Downloader

/// El bookmark security-scoped de la carpeta de descarga es el único estado persistente
/// que puede quedar "roto" externamente (carpeta borrada, movida, permiso revocado).
/// Estos tests aseguran que nunca crashea y siempre cae a ~/Downloads.
@Suite("AppSettings — fallback de carpeta de descarga", .serialized)
struct AppSettingsBookmarkFallbackTests {

    private func resetDownloadFolderKey() {
        UserDefaults.standard.removeObject(forKey: AppSettings.downloadFolderKey)
    }

    @Test("Sin bookmark guardado, downloadFolder cae a ~/Downloads")
    func fallsBackWhenNoBookmarkStored() {
        resetDownloadFolderKey()
        #expect(AppSettings.downloadFolder.lastPathComponent == "Downloads")
        resetDownloadFolderKey()
    }

    @Test("Datos de bookmark corruptos/aleatorios no crashean — cae a ~/Downloads")
    func fallsBackOnCorruptBookmarkData() {
        resetDownloadFolderKey()
        let garbage = Data((0..<64).map { _ in UInt8.random(in: 0...255) })
        UserDefaults.standard.set(garbage, forKey: AppSettings.downloadFolderKey)

        #expect(AppSettings.downloadFolder == AppSettings.defaultDownloadFolder)

        resetDownloadFolderKey()
    }

    @Test("Bookmark con Data vacía no crashea — cae a ~/Downloads")
    func fallsBackOnEmptyBookmarkData() {
        resetDownloadFolderKey()
        UserDefaults.standard.set(Data(), forKey: AppSettings.downloadFolderKey)

        #expect(AppSettings.downloadFolder == AppSettings.defaultDownloadFolder)

        resetDownloadFolderKey()
    }

    @Test("withDownloadFolderAccess sin bookmark ejecuta el body con la carpeta default, sin crash")
    func withDownloadFolderAccessFallsBackWithoutBookmark() {
        resetDownloadFolderKey()
        let used = AppSettings.withDownloadFolderAccess { url in url }
        #expect(used == AppSettings.defaultDownloadFolder)
        resetDownloadFolderKey()
    }

    @Test("withDownloadFolderAccess con bookmark corrupto ejecuta el body con la carpeta default, sin crash")
    func withDownloadFolderAccessFallsBackOnCorruptBookmark() {
        resetDownloadFolderKey()
        UserDefaults.standard.set(Data([0xDE, 0xAD, 0xBE, 0xEF]), forKey: AppSettings.downloadFolderKey)

        let used = AppSettings.withDownloadFolderAccess { url in url }
        #expect(used == AppSettings.defaultDownloadFolder)

        resetDownloadFolderKey()
    }

    @Test("Un bookmark válido de una carpeta real se resuelve a esa carpeta")
    func validBookmarkResolvesToRealFolder() throws {
        resetDownloadFolderKey()
        let tempDir = FileManager.default.temporaryDirectory
            .appending(path: "DownloaderQATests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try AppSettings.setDownloadFolder(tempDir)

        // Comparamos por ruta canónica (resolvingSymlinksInPath) porque /var vs /private/var
        // en macOS puede diferir simbólicamente sin ser un bug real.
        #expect(
            AppSettings.downloadFolder.resolvingSymlinksInPath().path
                == tempDir.resolvingSymlinksInPath().path)

        resetDownloadFolderKey()
    }

    @Test("Carpeta borrada después de guardarse como bookmark no crashea al resolverla")
    func deletedFolderAfterBookmarkDoesNotCrash() throws {
        resetDownloadFolderKey()
        let tempDir = FileManager.default.temporaryDirectory
            .appending(path: "DownloaderQATests-deleted-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        try AppSettings.setDownloadFolder(tempDir)
        try FileManager.default.removeItem(at: tempDir)

        // No debe crashear ni lanzar — o resuelve la ruta (aunque ya no exista en disco)
        // o cae al default. Cualquiera de los dos es un resultado seguro; lo que no es
        // aceptable es un crash o una excepción sin capturar.
        let resolved = AppSettings.downloadFolder
        #expect(resolved.lastPathComponent == tempDir.lastPathComponent || resolved.lastPathComponent == "Downloads")

        // Igual de importante: withDownloadFolderAccess debe poder ejecutar el body
        // sin crashear aunque el startAccessingSecurityScopedResource() falle sobre
        // una carpeta que ya no existe.
        let accessedOK = AppSettings.withDownloadFolderAccess { _ in true }
        #expect(accessedOK)

        resetDownloadFolderKey()
    }
}
