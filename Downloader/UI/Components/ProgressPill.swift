import SwiftUI

/// Barra de progreso de una fila `.downloading`.
/// Pill en ambas capas — el fill nunca queda con una esquina recta.
struct ProgressPill: View {
    let percent: Double

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
        ZStack(alignment: .leading) {
            shape.fill(Theme.Palette.progressTrack)
            shape
                .fill(Color.accentColor)
                .frame(width: max(0, min(percent, 1)) * Theme.Size.progressBarWidth)
        }
        .frame(width: Theme.Size.progressBarWidth, height: Theme.Size.progressBarHeight)
        .animation(Theme.Motion.progressTick, value: percent)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 12) {
        ProgressPill(percent: 0.02)
        ProgressPill(percent: 0.45)
        ProgressPill(percent: 1.0)
    }
    .padding(40)
}
