import SwiftUI

/// Anillo de progreso. Mismo concepto visual que el ring del menu bar
/// (`MenuBarIconRenderer`): track tenue + arco de progreso, 12 en punto, sentido
/// horario — pero dibujado en SwiftUI porque aquí sí vive dentro del entorno de la
/// vista (no un `NSImage` de menu bar).
struct ProgressRing: View {
    let percent: Double
    var progressColor: Color = .white
    var diameter: CGFloat = Theme.Size.progressRing

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
        .frame(width: diameter, height: diameter)
        // El llenado es un valor de datos, no decoración (DESIGN_LIQUID §Animaciones)
        // — se mantiene animado incluso bajo Reduce Motion, sin condicional.
        .animation(Theme.Motion.progressTick, value: clamped)
        .accessibilityHidden(true)
    }
}

/// Flecha hacia abajo dibujada a mano (asta + punta en "V"), en vez de un SF Symbol,
/// para que su grosor de trazo pueda igualar exactamente el `lineWidth` del anillo
/// que la rodea — el peso tipográfico de un símbolo no es controlable con precisión.
/// Geometría proporcional al `rect` que SwiftUI le asigna vía `.frame`, así funciona
/// a cualquier diámetro, no solo a los 20pt del frame del launcher.
private struct DownloadArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Proporciones ajustadas a ojo (Woz, 2026-07-27) para que la flecha respire
        // dentro del anillo sin tocarlo, verificado a 20pt vía render offline.
        let halfHeight = radius * 0.42
        let armSpan = radius * 0.30
        let armDrop = radius * 0.34

        let shaftTop = CGPoint(x: center.x, y: center.y - halfHeight)
        let tip = CGPoint(x: center.x, y: center.y + halfHeight)
        let leftArm = CGPoint(x: center.x - armSpan, y: tip.y - armDrop)
        let rightArm = CGPoint(x: center.x + armSpan, y: tip.y - armDrop)

        var path = Path()
        path.move(to: shaftTop)
        path.addLine(to: tip)
        path.move(to: leftArm)
        path.addLine(to: tip)
        path.addLine(to: rightArm)
        return path
    }
}

/// Ícono izquierdo del frame en `.downloading`/`.completed`/`.error` — el mismo
/// lenguaje visual que el ícono de la menu bar (`MenuBarIconRenderer`): flecha
/// dentro de un anillo que se llena con el progreso. Un solo objeto que cambia de
/// color por estado (blanco/verde/rojo); el color crossfadea vía el `.id(frameState)`
/// + `.transition(.opacity)` ya existente en `LauncherView` — este componente no
/// necesita animar su propio color.
struct DownloadStateIcon: View {
    let percent: Double
    let color: Color

    var body: some View {
        ZStack {
            ProgressRing(percent: percent, progressColor: color, diameter: Theme.Size.rowIcon)
            DownloadArrow()
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: Theme.Size.progressRingLineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
        }
        .frame(width: Theme.Size.rowIcon, height: Theme.Size.rowIcon)
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

#Preview("DownloadStateIcon") {
    HStack(spacing: 16) {
        DownloadStateIcon(percent: 0, color: .white)
        DownloadStateIcon(percent: 0.45, color: .white)
        DownloadStateIcon(percent: 1.0, color: .green)
        DownloadStateIcon(percent: 0, color: .red)
    }
    .padding(40)
    .background(Color.black)
}
