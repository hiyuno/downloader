import AppKit
import OSLog
import UserNotifications

/// Se pide permiso la primera vez que hay algo que notificar, no al lanzar la app.
@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private var didRequestAuthorization = false
    nonisolated static let filePathKey = "filePath"

    private override init() { super.init() }

    func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func notifyCompleted(fileURL: URL) async {
        guard await ensureAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Download completed"
        content.body = fileURL.lastPathComponent
        content.sound = .default
        content.userInfo = [Self.filePathKey: fileURL.path]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.launcher.error("Notificación falló: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            guard !didRequestAuthorization else { return false }
            didRequestAuthorization = true
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let path = userInfo[NotificationService.filePathKey] as? String else { return }
        await MainActor.run {
            FileOpenerService.revealInFinder(URL(fileURLWithPath: path))
        }
    }
}
