import SwiftUI

/// Anillo de progreso de una fila `.downloading`. Mismo concepto visual que el ring
/// del menu bar (`MenuBarIconRenderer`): track tenue + arco de progreso, 12 en punto,
/// sentido horario — pero dibujado en SwiftUI porque aquí sí vive dentro del entorno
/// de la vista (no un `NSImage` de menu bar).
struct ProgressRing: View {
    let percent: Double
    var progressColor: Color = .white

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { max(0, min(percent, 1)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(progressColor.opacity(0.15), lineWidth: Theme.Size.progressRingLineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: Theme.Size.progressRingLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: Theme.Size.progressRing, height: Theme.Size.progressRing)
        .animation(reduceMotion ? nil : Theme.Motion.progressTick, value: clamped)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 12) {
        ProgressRing(percent: 0.02)
        ProgressRing(percent: 0.45)
        ProgressRing(percent: 1.0)
    }
    .padding(40)
}
