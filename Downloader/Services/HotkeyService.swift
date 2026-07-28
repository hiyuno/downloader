import AppKit
import Carbon.HIToolbox
import OSLog

enum HotkeyError: LocalizedError {
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            "Couldn't register the shortcut — it's probably already taken by another app."
        }
    }
}

/// Carbon `RegisterEventHotKey` (TRD §3): registra el atajo a nivel de sistema y
/// falla explícitamente si otra app ya lo tiene, en vez de disparar en silencio junto a ella.
@MainActor
final class HotkeyService {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onHotkeyPressed: (() -> Void)?

    func register(keyCode: UInt32, modifiers: UInt32) throws {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                // Solo cruza el puntero opaco (Sendable); la instancia se recupera en main.
                // QoS explícito: el hilo de despacho de eventos de Carbon corre a QoS
                // Default, no user-interactive. `.async` sin QoS heredaría ese nivel bajo
                // para todo lo que dispara abrir el panel (foco del input incluido),
                // generando inversión de prioridad contra el window server.
                DispatchQueue.main.async(qos: .userInteractive) {
                    let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                    MainActor.assumeIsolated { service.onHotkeyPressed?() }
                }
                return noErr
            },
            1,
            &eventType,
            context,
            &eventHandler
        )
        guard handlerStatus == noErr else { throw HotkeyError.registrationFailed(handlerStatus) }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            Logger.hotkey.error("RegisterEventHotKey falló con \(status)")
            throw HotkeyError.registrationFailed(status)
        }
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
    }

    /// 'Dwnl' como OSType.
    private static let signature: OSType = {
        let characters = Array("Dwnl".utf8)
        return characters.reduce(OSType(0)) { ($0 << 8) + OSType($1) }
    }()

    nonisolated static func describe(keyCode: UInt32, modifiers: UInt32) -> String {
        var description = ""
        if modifiers & UInt32(controlKey) != 0 { description += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { description += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { description += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { description += "⌘" }
        description += keyName(for: keyCode)
        return description
    }

    nonisolated private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: "Space"
        case kVK_Return: "↩"
        case kVK_Escape: "esc"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_V: "V"
        default: "Key \(keyCode)"
        }
    }
}
