import SwiftUI

/// Valores exactos de DESIGN_LIQUID.md / DESIGN_FROST.md. No inventar aquí.
enum Theme {

    enum Radius {
        static let panel: CGFloat = 24
        static let row: CGFloat = 18          // 24 − 6 de padding del panel
        static let siteTile: CGFloat = 10     // 18 − 8 de inset del ícono
        static let button: CGFloat = 10
        static let settingsSection: CGFloat = 16
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let panelPadding: CGFloat = 6
        static let inputRowHeight: CGFloat = 52
        static let inputHorizontalPadding: CGFloat = 16
        static let iconToText: CGFloat = 10
        static let inputToChip: CGFloat = 6
        static let chipHeight: CGFloat = 22
        static let settingsSectionPadding: CGFloat = 16
        static let betweenSettingsSections: CGFloat = 20
        static let minimumTapTarget: CGFloat = 32
        static let betweenRowAccessories: CGFloat = 2
    }

    enum Size {
        static let panelWidth: CGFloat = 560
        /// Único frame, sin lista — DESIGN_LIQUID §1: solo dos alturas de panel posibles.
        static let panelHeightBase: CGFloat = 64
        static let panelHeightWithChip: CGFloat = 86
        static let rowIcon: CGFloat = 20
        static let siteIcon: CGFloat = 16
        static let progressRing: CGFloat = 18
        static let progressRingLineWidth: CGFloat = 2
        static let menuBarIcon: CGFloat = 18
        static let rowAccessoryIcon: CGFloat = 12
        /// Ancho reservado del accesorio derecho del frame (`.downloading`/`.completed`/`.error`)
        /// — constante en los 3 estados para que el título nunca salte al aparecer/ocultarse
        /// el % + ring o los botones de acción. Cubre el contenido más ancho posible: los
        /// 2 botones de `.completed` (2×32pt + 2pt de separación).
        static let rowTrailingAccessoryWidth: CGFloat = 66
        static let settings = CGSize(width: 480, height: 360)
    }

    enum Font {
        static let input = SwiftUI.Font.system(size: 14, weight: .regular, design: .rounded)
        static let siteBadge = SwiftUI.Font.system(size: 12, weight: .medium)
        static let rowTitle = SwiftUI.Font.system(size: 13, weight: .regular)
        static let rowSubtitle = SwiftUI.Font.system(size: 11, weight: .regular)
        static let chip = SwiftUI.Font.system(size: 11, weight: .regular)
        static let settingsHeader = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let settingsControl = SwiftUI.Font.system(size: 13, weight: .regular)
        static let footnote = SwiftUI.Font.system(size: 11, weight: .regular)
    }

    enum Palette {
        static let rowFill = Color.primary.opacity(0.04)
        static let rowFillReduceTransparency = Color.primary.opacity(0.08)
        static let failedRowFill = Color.red.opacity(0.08)
        static let frostStroke = Color.white.opacity(0.15)
        static let separator = Color(nsColor: .separatorColor)
        static let opaquePanel = Color(nsColor: .windowBackgroundColor)

        /// Tinte del fondo del frame con el color de marca del sitio detectado — solo
        /// aplica en `.input` (DESIGN_LIQUID §Color, decisión 2026-07-27). Instagram usa
        /// su gradiente real; el resto un color plano. Opacidad marcada (no sutil, pedido
        /// del usuario) — sigue subiendo con Reduce Transparency para mantener el mismo
        /// salto relativo que ya existía entre `rowFill`/`rowFillReduceTransparency`.
        static func siteTint(for site: SupportedSite, reduceTransparency: Bool) -> AnyShapeStyle? {
            let opacity = reduceTransparency ? 0.28 : 0.18
            if site == .instagram {
                return AnyShapeStyle(instagramGradient.opacity(opacity))
            }
            guard let base = siteBrandColor(for: site) else { return nil }
            return AnyShapeStyle(base.opacity(opacity))
        }

        /// Gradiente oficial de marca de Instagram (5 paradas, diagonal) — DESIGN_LIQUID
        /// §Color: se reemplazó el color plano representativo por el gradiente real.
        private static let instagramGradient = LinearGradient(
            colors: [
                Color(red: 0.996, green: 0.855, blue: 0.459), // #FEDA75
                Color(red: 0.980, green: 0.494, blue: 0.118), // #FA7E1E
                Color(red: 0.839, green: 0.161, blue: 0.463), // #D62976
                Color(red: 0.588, green: 0.184, blue: 0.749), // #962FBF
                Color(red: 0.310, green: 0.357, blue: 0.835), // #4F5BD5
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        private static func siteBrandColor(for site: SupportedSite) -> Color? {
            switch site {
            case .youtube: Color(red: 1.0, green: 0.0, blue: 0.0)            // #FF0000
            case .tiktok: Color(red: 0.996, green: 0.173, blue: 0.333)       // #FE2C55
            case .twitter: Color.black                                       // marca "X"
            case .instagram, .other: nil
            }
        }
    }

    /// Todas las duraciones y curvas vienen de la tabla de Animaciones de DESIGN_LIQUID.md.
    /// Ninguna supera 300ms; ninguna tiene bounce.
    enum Motion {
        static let panelAppear = Animation.easeOut(duration: 0.12)
        static let panelDismiss = Animation.easeIn(duration: 0.08)
        static let heightChange = Animation.spring(response: 0.35, dampingFraction: 1.0)
        static let rowStateCrossfade = Animation.easeOut(duration: 0.2)
        static let progressTick = Animation.linear(duration: 0.2)

        /// Slide + fade del accesorio derecho del frame (% + ring / botones de acción,
        /// DESIGN_LIQUID §Animaciones). Mismo token para entrada y salida — la asimetría
        /// está en la secuencia (salida → entrada encadenada), no en la duración.
        /// Reduce Motion reusa esta misma duración, solo cambia la transición geométrica
        /// (move+opacity → opacity puro), igual patrón que el resto de esta tabla.
        static let accessorySlideDuration: TimeInterval = 0.22
        static let accessorySlide = Animation.easeOut(duration: accessorySlideDuration)

        static let panelAppearDuration: TimeInterval = 0.12
        static let panelDismissDuration: TimeInterval = 0.08
        static let heightChangeDuration: TimeInterval = 0.28
        static let menuBarCrossfadeDuration: TimeInterval = 0.15

        /// Shake de rechazo (input durante `.downloading`): ±4pt, 3 ciclos, 160ms total.
        static let frameShakeDuration: TimeInterval = 0.16
        static let frameShakeOffset: CGFloat = 4
        /// Reduce Motion: pulso de opacity 1→0.6→1 en vez de traslación.
        static let frameRejectionPulseDuration: TimeInterval = 0.15
        static let frameRejectionPulseOpacity: Double = 0.6

        static func heightChange(reduceMotion: Bool) -> Animation {
            reduceMotion ? .linear(duration: 0) : heightChange
        }
    }

    /// Redraw del ícono de menu bar: solo si el % cambió ≥2pp o pasaron 400ms.
    enum StatusItemThrottle {
        static let minimumPercentDelta: Double = 0.02
        static let minimumInterval: TimeInterval = 0.4
    }
}
