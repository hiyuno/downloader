import AppKit
import OSLog
import Sparkle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    private let panelController = LauncherPanelController()
    private let hotkeyService = HotkeyService()
    private var statusItem: NSStatusItem!
    private var updaterController: SPUStandardUpdaterController!

    /// Expuesto para `SettingsView` (botón "Check for Updates…" y `CheckForUpdatesViewModel`,
    /// que necesita el `SPUUpdater` real para observar `canCheckForUpdates` vía KVO).
    var updater: SPUUpdater { updaterController.updater }

    private var iconState: MenuBarIconRenderer.State = .idle
    private var lastRenderedState: MenuBarIconRenderer.State = .idle
    private var lastRenderDate = Date.distantPast
    private var throttleTimer: Timer?

    private(set) var hotkeyRegistrationError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationService.shared.activate()

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )

        setUpStatusItem()
        setUpHotkey()
        configureMainMenu()

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
        statusItem.button?.toolTip = "Downloader — click to open the launcher (⌥⌘Space)"
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Open Downloader",
            action: #selector(openLauncher),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self
        menu.addItem(.separator())
        menu.addItem(makeCheckForUpdatesMenuItem())
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        return menu
    }

    /// `SPUStandardUpdaterController.checkForUpdates(_:)` es un `IBAction` pensado
    /// exactamente para esto: cuando el target/action de un `NSMenuItem` apuntan a él,
    /// Sparkle además habilita/deshabilita el ítem solo, vía `SPUUpdater.canCheckForUpdates`
    /// (ver `SPUStandardUpdaterController.h`) — no hace falta lógica de validación propia
    /// para los menús (a diferencia del botón de Settings, que sí la necesita — ver
    /// `CheckForUpdatesViewModel`).
    private func makeCheckForUpdatesMenuItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        item.target = updaterController
        return item
    }

    // MARK: - Main menu

    /// Esta app no define un `MainMenu.xib` ni usa `.commands` en `DownloaderApp` (ver su
    /// comentario) — el menú "Downloader" (About/Settings…/Services/Hide/Quit) es el que
    /// AppKit/SwiftUI generan por defecto para cualquier `App` sin personalizar. Ya existe
    /// para cuando esto corre — no hay que construirlo desde cero, solo insertar el nuevo
    /// ítem preservando todo lo demás. Convención estándar de Mac: justo debajo de "About",
    /// separado de él y de "Settings…" por separadores.
    private func configureMainMenu() {
        guard let appMenu = NSApp.mainMenu?.items.first?.submenu else {
            Logger.settings.error("configureMainMenu: no se encontró el menú principal de la app")
            return
        }

        guard !appMenu.items.contains(where: {
            $0.action == #selector(SPUStandardUpdaterController.checkForUpdates(_:))
        }) else {
            return
        }

        guard let aboutIndex = appMenu.items.firstIndex(where: {
            $0.action == #selector(NSApplication.orderFrontStandardAboutPanel(_:))
        }) else {
            Logger.settings.error("configureMainMenu: no se encontró el ítem \"About\"")
            return
        }

        appMenu.insertItem(.separator(), at: aboutIndex + 1)
        appMenu.insertItem(makeCheckForUpdatesMenuItem(), at: aboutIndex + 2)

        if CommandLine.arguments.contains("--open-settings") {
            let dump = appMenu.items.enumerated().map { index, item in
                item.isSeparatorItem
                    ? "\(index): ---"
                    : "\(index): \"\(item.title)\" key=\(item.keyEquivalent) action=\(item.action.map(String.init(describing:)) ?? "nil")"
            }.joined(separator: " | ")
            Logger.settings.notice("configureMainMenu dump: \(dump, privacy: .public)")
        }
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

    // MARK: - Sparkle (SPUStandardUserDriverDelegate)

    /// Esta app es `.accessory` (LSUIElement) y no tiene ventana ni ítem de Dock por
    /// defecto, así que el diálogo de Sparkle no puede activarse solo. Se aplica el
    /// mismo patrón que `SettingsWindowController`: activar temporalmente como app
    /// `.regular` mientras el diálogo está visible, y restaurar `.accessory` al cerrarlo.
    func standardUserDriverWillShowModalAlert() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func standardUserDriverDidShowModalAlert() {
        NSApp.setActivationPolicy(.accessory)
    }
}
