import SwiftUI

@main
struct DownloaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Sin `WindowGroup`, sin `MenuBarExtra` y sin escena `Settings`: el launcher es un
    /// `NSPanel`, el ícono de menu bar un `NSStatusItem`, y Ajustes una `NSWindow`
    /// gestionada a mano por `SettingsWindowController` — todo vive en AppKit puro
    /// porque esta app `.accessory` no tiene una ventana principal que darle a SwiftUI.
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
