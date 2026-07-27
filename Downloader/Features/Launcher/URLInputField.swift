import AppKit
import SwiftUI

/// `NSTextField` puenteado, no `TextField` de SwiftUI: se necesita `becomeFirstResponder()`
/// sincronizado con `makeKeyAndOrderFront` para que el caret parpadee desde el primer
/// frame, y control directo de Enter/Escape (DESIGN_LIQUID §1).
struct URLInputField: NSViewRepresentable {
    @Binding var text: String
    /// Cada incremento fuerza foco + selección total del contenido.
    let focusToken: Int
    let placeholder: String
    let onSubmit: () -> Void
    let onCancel: () -> Void

    /// `NSTextField` no participa del entorno de Dynamic Type de SwiftUI, así que el
    /// tamaño escalado se calcula acá y se aplica a mano al `NSFont`, con el mismo techo
    /// de 1.3x que el resto del texto de la app (DESIGN_LIQUID §Tipografía).
    @ScaledMetric(relativeTo: .body) private var scaledFontSize: CGFloat = 20

    private var cappedFontSize: CGFloat { min(scaledFontSize, 20 * 1.3) }

    func makeNSView(context: Context) -> NSTextField {
        let field = FocusableTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.isBezeled = false
        field.lineBreakMode = .byTruncatingMiddle
        field.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.font = inputFont
        field.textColor = .labelColor
        field.placeholderAttributedString = placeholderString(placeholder)
        field.stringValue = text
        field.setAccessibilityLabel("Ingresa URL de video")
        field.setAccessibilityHelp("Presiona Enter para descargar, Escape para cerrar")
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        if field.font?.pointSize != cappedFontSize {
            field.font = inputFont
            field.placeholderAttributedString = placeholderString(placeholder)
        } else if field.placeholderAttributedString?.string != placeholder {
            field.placeholderAttributedString = placeholderString(placeholder)
        }
        guard context.coordinator.lastFocusToken != focusToken else { return }
        context.coordinator.lastFocusToken = focusToken
        // Mismo ciclo de runloop que makeKeyAndOrderFront — sin delay artificial.
        // QoS explícito: este bloque puede encolarse desde el callback de Carbon del
        // atajo global (HotkeyService), que corre a QoS Default. `.async` sin QoS
        // hereda ese QoS bajo, y como `makeFirstResponder` habla con el window server
        // (que espera a QoS user-interactive), se produce una inversión de prioridad.
        // Fijar `.userInteractive` aquí evita la herencia sin tocar el timing.
        DispatchQueue.main.async(qos: .userInteractive) {
            guard let window = field.window else { return }
            window.makeFirstResponder(field)
            field.currentEditor()?.selectAll(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit, onCancel: onCancel)
    }

    private var inputFont: NSFont {
        let base = NSFont.systemFont(ofSize: cappedFontSize, weight: .regular)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: descriptor, size: cappedFontSize) ?? base
    }

    private func placeholderString(_ value: String) -> NSAttributedString {
        NSAttributedString(
            string: value,
            attributes: [
                .font: inputFont,
                .foregroundColor: NSColor.tertiaryLabelColor,
            ]
        )
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String
        private let onSubmit: () -> Void
        private let onCancel: () -> Void
        var lastFocusToken = Int.min

        init(text: Binding<String>, onSubmit: @escaping () -> Void, onCancel: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
            self.onCancel = onCancel
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                text = control.stringValue
                onSubmit()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                onCancel()
                return true
            default:
                return false
            }
        }
    }
}

/// Un `NSTextField` dentro de un panel `.nonactivatingPanel` necesita aceptar
/// first responder explícitamente en macOS 14/15 (riesgo técnico #1 del TRD).
private final class FocusableTextField: NSTextField {
    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { currentEditor()?.selectAll(nil) }
        return accepted
    }
}
