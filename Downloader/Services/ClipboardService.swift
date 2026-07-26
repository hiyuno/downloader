import AppKit

@MainActor
enum ClipboardService {
    /// Se llama cada vez que el panel se muestra (TRD §7).
    static func detectURLOnPasteboard() -> URL? {
        guard let raw = NSPasteboard.general.string(forType: .string) else { return nil }
        return URLValidator.validate(raw)
    }
}
