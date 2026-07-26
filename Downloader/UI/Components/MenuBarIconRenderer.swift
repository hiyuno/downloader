import AppKit

/// Íconos del `NSStatusItem`. Todo es template image (monocromático) — la menu bar
/// nunca lleva color hardcodeado. El ring se dibuja a mano porque no existe un
/// SF Symbol con porcentaje arbitrario.
enum MenuBarIconRenderer {
    enum State: Equatable {
        case idle
        case downloading(percent: Double)
        case error
    }

    static func image(for state: State) -> NSImage {
        switch state {
        case .idle:
            symbol("arrow.down.circle", description: "Downloader — esperando descargas")
        case .error:
            symbol("exclamationmark.circle", description: "Downloader — error en descarga")
        case .downloading(let percent):
            progressRing(percent: percent)
        }
    }

    private static func symbol(_ name: String, description: String) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(
            pointSize: Theme.Size.menuBarIcon,
            weight: .regular
        )
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(configuration) ?? NSImage()
        image.isTemplate = true
        return image
    }

    private static func progressRing(percent: Double) -> NSImage {
        let side = Theme.Size.menuBarIcon
        let size = NSSize(width: side, height: side)
        let clamped = min(max(percent, 0), 1)

        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return true }

            let lineWidth: CGFloat = 2
            let inset = lineWidth / 2 + 0.5
            let center = CGPoint(x: side / 2, y: side / 2)
            let radius = side / 2 - inset

            context.setLineWidth(lineWidth)
            context.setLineCap(.round)

            // Track
            context.setStrokeColor(NSColor.black.withAlphaComponent(0.2).cgColor)
            context.addArc(
                center: center,
                radius: radius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: false
            )
            context.strokePath()

            // Arco de progreso: arranca a las 12 en punto, sentido horario.
            if clamped > 0 {
                context.setStrokeColor(NSColor.black.cgColor)
                let start = CGFloat.pi / 2
                let end = start - CGFloat(clamped) * .pi * 2
                context.addArc(
                    center: center,
                    radius: radius,
                    startAngle: start,
                    endAngle: end,
                    clockwise: true
                )
                context.strokePath()
            }

            // Flecha de 8pt al centro.
            let arrowHeight: CGFloat = 8
            let arrowWidth: CGFloat = 5
            let top = CGPoint(x: center.x, y: center.y + arrowHeight / 2)
            let bottom = CGPoint(x: center.x, y: center.y - arrowHeight / 2)
            context.setLineWidth(1.6)
            context.setLineJoin(.round)
            context.move(to: top)
            context.addLine(to: bottom)
            context.strokePath()
            context.move(to: CGPoint(x: center.x - arrowWidth / 2, y: bottom.y + arrowWidth / 2))
            context.addLine(to: bottom)
            context.addLine(to: CGPoint(x: center.x + arrowWidth / 2, y: bottom.y + arrowWidth / 2))
            context.strokePath()

            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Descargando \(Int(clamped * 100)) por ciento"
        return image
    }
}
