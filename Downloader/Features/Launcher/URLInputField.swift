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
        field.font = Self.inputFont
        field.textColor = .labelColor
        field.placeholderAttributedString = Self.placeholderString(placeholder)
        field.stringValue = text
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        if field.placeholderAttributedString?.string != placeholder {
            field.placeholderAttributedString = Self.placeholderString(placeholder)
        }
        guard context.coordinator.lastFocusToken != focusToken else { return }
        context.coordinator.lastFocusToken = focusToken
        // Mismo ciclo de runloop que makeKeyAndOrderFront — sin delay artificial.
        DispatchQueue.main.async {
            guard let window = field.window else { return }
            window.makeFirstResponder(field)
            field.currentEditor()?.selectAll(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit, onCancel: onCancel)
    }

    private static var inputFont: NSFont {
        let base = NSFont.systemFont(ofSize: 20, weight: .regular)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: descriptor, size: 20) ?? base
    }

    private static func placeholderString(_ value: String) -> NSAttributedString {
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
