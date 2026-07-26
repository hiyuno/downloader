import AppKit
import SwiftUI

/// Única fuente de verdad de "qué ventana está visible". El panel se reutiliza
/// entre aperturas (nunca se destruye) para que reabrir sea instantáneo (<200ms).
@MainActor
final class LauncherPanelController: NSObject, NSWindowDelegate {
    let viewModel = LauncherViewModel()

    private let panel: LauncherPanel
    private var isDismissing = false

    override init() {
        panel = LauncherPanel()
        super.init()

        let hostingView = NSHostingView(rootView: LauncherView(viewModel: viewModel))
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.delegate = self

        viewModel.onHeightChange = { [weak self] height in
            self?.resize(to: height)
        }
        viewModel.onRequestClose = { [weak self] in
            self?.hide()
        }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible && !isDismissing ? hide() : show()
    }

    func show() {
        isDismissing = false
        viewModel.clearFinishedFailures()
        viewModel.panelWillShow()

        panel.setContentSize(NSSize(width: Theme.Size.panelWidth, height: viewModel.panelHeight))
        centerOnScreenWithCursor()

        viewModel.isVisible = false
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // El caret ya está puesto por el focusToken del view model; esto solo dispara
        // la animación de entrada de 120ms sobre una vista ya montada.
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.isVisible = true
        }
    }

    func hide() {
        guard panel.isVisible, !isDismissing else { return }
        isDismissing = true
        viewModel.isVisible = false

        DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Motion.panelDismissDuration) { [weak self] in
            guard let self else { return }
            panel.orderOut(nil)
            viewModel.panelDidHide()
            isDismissing = false
        }
    }

    // MARK: - Geometría

    /// Centrado en la pantalla donde está el cursor, no en la principal (TRD §2).
    private func centerOnScreenWithCursor() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let frame = screen?.visibleFrame else {
            panel.center()
            return
        }
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            // Ligeramente arriba del centro óptico, como Spotlight.
            y: frame.midY + frame.height * 0.12 - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }

    /// Crece/encoge anclado al borde superior — el panel nunca "salta" verticalmente.
    private func resize(to height: CGFloat) {
        let current = panel.frame
        guard abs(current.height - height) > 0.5 else { return }
        let target = NSRect(
            x: current.origin.x,
            y: current.maxY - height,
            width: Theme.Size.panelWidth,
            height: height
        )
        guard panel.isVisible, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(target, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Theme.Motion.heightChangeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
        }
    }

    // MARK: - NSWindowDelegate

    /// Se oculta al perder el foco; la descarga sigue viva en el actor.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
