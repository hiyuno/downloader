import SwiftUI

/// Único punto de ramificación `#available` de toda la app.
/// macOS 26+: Liquid Glass. macOS 14–15: Frost (`.ultraThinMaterial` + stroke + sombra).
/// Reduce Transparency / Increase Contrast se resuelven aquí también, no en cada vista.
struct GlassPanelBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
    }

    private var wantsOpaque: Bool { reduceTransparency || contrast == .increased }

    func body(content: Content) -> some View {
        if wantsOpaque {
            content
                .background(Theme.Palette.opaquePanel, in: shape)
                .overlay(shape.strokeBorder(Theme.Palette.separator, lineWidth: 1))
        } else if #available(macOS 26, *) {
            content
                .background {
                    shape.glassEffect(.regular, in: shape)
                }
        } else {
            content.frostPanelBackground()
        }
    }
}

extension View {
    func glassPanelBackground() -> some View { modifier(GlassPanelBackground()) }

    /// Frost — solo macOS 14–15. El stroke y la sombra reemplazan la especularidad
    /// dinámica que Liquid Glass sí tiene (DESIGN_FROST.md).
    func frostPanelBackground() -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
        return self
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(Theme.Palette.frostStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 8)
    }
}
