import AppKit
import OSLog
import SwiftUI

/// Ventana de Settings gestionada a mano — sin la escena `Settings` de SwiftUI.
///
/// `NSApp.sendAction(Selector(("showSettingsWindow:")))` no confiablemente trae la
/// ventana al frente en esta app `.accessory` (dos intentos previos fallaron). En vez
/// de seguir depurando el mecanismo privado de AppKit/SwiftUI, esta clase crea y posee
/// una única `NSWindow` real, igual que `LauncherPanelController` posee su `NSPanel`.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func openSettings() {
        Logger.settings.notice("openSettings() invocado")

        let window = window ?? makeWindow()
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        Logger.settings.notice(
            "ventana Settings mostrada — frame=\(NSStringFromRect(window.frame), privacy: .public) isVisible=\(window.isVisible, privacy: .public) isKeyWindow=\(window.isKeyWindow, privacy: .public)"
        )
    }

    private func makeWindow() -> NSWindow {
        let size = Theme.Size.settings
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: SettingsView())
        window.setContentSize(size)
        return window
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        Logger.settings.notice("ventana Settings cerrándose — restaurando activation policy .accessory")
        NSApp.setActivationPolicy(.accessory)
    }
}
