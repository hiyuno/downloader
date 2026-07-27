import SwiftUI

/// Valores exactos de DESIGN_LIQUID.md / DESIGN_FROST.md. No inventar aquí.
enum Theme {

    enum Radius {
        static let panel: CGFloat = 24
        static let row: CGFloat = 12          // 24 − 12 de padding del panel
        static let siteTile: CGFloat = 4      // 12 − 8 de inset del ícono
        static let button: CGFloat = 10
        static let settingsSection: CGFloat = 16
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let panelPadding: CGFloat = 12
        static let inputRowHeight: CGFloat = 52
        static let inputHorizontalPadding: CGFloat = 16
        static let inputToList: CGFloat = 8
        static let rowHeight: CGFloat = 48
        static let betweenRows: CGFloat = 4
        static let rowHorizontalPadding: CGFloat = 12
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
        static let panelMaxHeight: CGFloat = 420
        static let rowIcon: CGFloat = 20
        static let siteIcon: CGFloat = 16
        static let progressRing: CGFloat = 18
        static let progressRingLineWidth: CGFloat = 2
        static let menuBarIcon: CGFloat = 18
        static let rowAccessoryIcon: CGFloat = 12
        static let settings = CGSize(width: 480, height: 360)
    }

    enum Font {
        static let input = SwiftUI.Font.system(size: 20, weight: .regular, design: .rounded)
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
    }

    /// Todas las duraciones y curvas vienen de la tabla de Animaciones de DESIGN_LIQUID.md.
    /// Ninguna supera 300ms; ninguna tiene bounce.
    enum Motion {
        static let panelAppear = Animation.easeOut(duration: 0.12)
        static let panelDismiss = Animation.easeIn(duration: 0.08)
        static let heightChange = Animation.spring(response: 0.35, dampingFraction: 1.0)
        static let rowStateCrossfade = Animation.easeOut(duration: 0.2)
        static let progressTick = Animation.linear(duration: 0.2)

        static let panelAppearDuration: TimeInterval = 0.12
        static let panelDismissDuration: TimeInterval = 0.08
        static let heightChangeDuration: TimeInterval = 0.28
        static let menuBarCrossfadeDuration: TimeInterval = 0.15

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
