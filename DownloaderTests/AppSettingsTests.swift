import Carbon.HIToolbox
import Foundation
import Testing

@testable import Downloader

@Suite("AppSettings", .serialized)
struct AppSettingsTests {

    private func resetDefaults() {
        let defaults = UserDefaults.standard
        for key in [
            AppSettings.defaultQualityKey,
            AppSettings.destinationAppBundleIDKey,
            AppSettings.hotkeyKeyCodeKey,
            AppSettings.hotkeyModifiersKey,
            AppSettings.downloadFolderKey,
        ] {
            defaults.removeObject(forKey: key)
        }
    }

    @Test("Defaults correctos cuando no hay nada guardado")
    func defaultsAreCorrect() {
        resetDefaults()
        #expect(AppSettings.quality == .best)
        #expect(AppSettings.destinationAppBundleID == nil)
        #expect(AppSettings.hotkeyKeyCode == UInt32(kVK_Space))
        #expect(AppSettings.hotkeyModifiers == UInt32(optionKey | cmdKey))
        #expect(AppSettings.downloadFolder.lastPathComponent == "Downloads")
        resetDefaults()
    }

    @Test("Los cambios persisten y se leen de vuelta")
    func changesPersist() {
        resetDefaults()
        AppSettings.quality = .max720
        AppSettings.destinationAppBundleID = "com.apple.FinalCut"
        #expect(AppSettings.quality == .max720)
        #expect(AppSettings.destinationAppBundleID == "com.apple.FinalCut")
        resetDefaults()
    }

    @Test("Cada calidad mapea a un formato yt-dlp distinto y con fallback")
    func qualityMapsToFormatArguments() {
        let arguments = DownloadQuality.allCases.map(\.formatArgument)
        #expect(Set(arguments).count == DownloadQuality.allCases.count)
        #expect(DownloadQuality.max1080.formatArgument.contains("height<=1080"))
        #expect(DownloadQuality.max720.formatArgument.contains("height<=720"))
        for argument in arguments {
            #expect(argument.contains("/"), "todo formato necesita fallback")
        }
    }

    @Test("Los nombres visibles nunca exponen la sintaxis de yt-dlp")
    func displayNamesHideFormatSyntax() {
        for quality in DownloadQuality.allCases {
            #expect(!quality.displayName.contains("bv*"))
            #expect(!quality.displayName.contains("ext="))
        }
    }

    @Test("El atajo default se describe como ⌥⌘Space")
    func hotkeyDescription() {
        let description = HotkeyService.describe(
            keyCode: AppSettings.defaultHotkeyKeyCode,
            modifiers: AppSettings.defaultHotkeyModifiers
        )
        #expect(description == "⌥⌘Space")
    }
}
