import Combine
import Sparkle

/// `SPUUpdater.canCheckForUpdates` es KVO-compliant, no `@Observable`-compatible —
/// este es el wrapper documentado por Sparkle para exponerlo a SwiftUI (ver
/// `CheckForUpdatesView.swift` en los samples oficiales del proyecto): `ObservableObject`
/// + `@Published`, puenteado desde KVO vía `publisher(for:)` de Combine.
@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    private var cancellable: AnyCancellable?

    init(updater: SPUUpdater) {
        cancellable = updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.canCheckForUpdates = value }
    }
}
