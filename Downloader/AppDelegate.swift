import AppKit
import OSLog
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panelController = LauncherPanelController()
    private let hotkeyService = HotkeyService()
    private var statusItem: NSStatusItem!

    private var iconState: MenuBarIconRenderer.State = .idle
    private var lastRenderedState: MenuBarIconRenderer.State = .idle
    private var lastRenderDate = Date.distantPast
    private var throttleTimer: Timer?

    private(set) var hotkeyRegistrationError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationService.shared.activate()

        setUpStatusItem()
        setUpHotkey()

        panelController.viewModel.onAggregateStateChange = { [weak self] state in
            self?.updateIcon(to: state)
        }

        if !BundledBinaries.isReady {
            Logger.ytdlp.error("yt-dlp no está empaquetado — ver Resources/bin/README.md")
        }
        Task { await YTDLPUpdateService.shared.check() }

        // Instrumentación de debug: permite verificar la ventana de Settings sin
        // pantalla, disparando la apertura 1s después de arrancar (ver skill de QA).
        if CommandLine.arguments.contains("--open-settings") {
            Logger.settings.notice("--open-settings detectado — abriendo en 1s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                SettingsWindowController.shared.openSettings()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        throttleTimer?.invalidate()
        hotkeyService.unregister()
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = MenuBarIconRenderer.image(for: .idle)
        statusItem.button?.toolTip = "Downloader — clic para abrir el launcher (⌥⌘Space)"
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Abrir Downloader",
            action: #selector(openLauncher),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "Ajustes…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Salir",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        return menu
    }

    /// Throttle: redibuja solo si el % cambió ≥2pp, si cambió el estado, o cada 400ms.
    private func updateIcon(to state: MenuBarIconRenderer.State) {
        iconState = state

        let now = Date()
        let elapsed = now.timeIntervalSince(lastRenderDate)
        let isSameKind = isSameKind(state, lastRenderedState)
        let percentDelta = abs(percent(of: state) - percent(of: lastRenderedState))

        if !isSameKind || percentDelta >= Theme.StatusItemThrottle.minimumPercentDelta
            || elapsed >= Theme.StatusItemThrottle.minimumInterval {
            render(state, crossfade: !isSameKind)
            return
        }

        guard throttleTimer == nil else { return }
        let remaining = Theme.StatusItemThrottle.minimumInterval - elapsed
        throttleTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.throttleTimer = nil
                self.render(self.iconState, crossfade: false)
            }
        }
    }

    private func render(_ state: MenuBarIconRenderer.State, crossfade: Bool) {
        throttleTimer?.invalidate()
        throttleTimer = nil
        lastRenderedState = state
        lastRenderDate = Date()

        guard let button = statusItem.button else { return }
        // Reduce Motion vive en AppKit aquí, fuera del entorno de SwiftUI.
        if crossfade, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let transition = CATransition()
            transition.type = .fade
            transition.duration = Theme.Motion.menuBarCrossfadeDuration
            button.layer?.add(transition, forKey: "contents")
        }
        button.image = MenuBarIconRenderer.image(for: state)
    }

    private func isSameKind(_ lhs: MenuBarIconRenderer.State, _ rhs: MenuBarIconRenderer.State) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.error, .error), (.downloading, .downloading): true
        default: false
        }
    }

    private func percent(of state: MenuBarIconRenderer.State) -> Double {
        if case .downloading(let percent) = state { return percent }
        return 0
    }

    // MARK: - Hotkey

    private func setUpHotkey() {
        hotkeyService.onHotkeyPressed = { [weak self] in
            self?.panelController.toggle()
        }
        do {
            try hotkeyService.register(
                keyCode: AppSettings.hotkeyKeyCode,
                modifiers: AppSettings.hotkeyModifiers
            )
            hotkeyRegistrationError = nil
        } catch {
            hotkeyRegistrationError = error.localizedDescription
            Logger.hotkey.error("\(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Acciones del menú

    @objc private func openLauncher() {
        panelController.show()
    }

    @objc private func openSettings() {
        Logger.settings.notice("menu item \"Ajustes…\" clickeado")
        SettingsWindowController.shared.openSettings()
    }
}
