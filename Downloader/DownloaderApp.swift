import SwiftUI

@main
struct DownloaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Sin `WindowGroup` y sin `MenuBarExtra`: el launcher es un `NSPanel` y el ícono
    /// de menu bar un `NSStatusItem`, ambos gestionados por `AppDelegate` (TRD §4).
    var body: some Scene {
        Settings {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}
