import SwiftUI

/// `@ScaledMetric` con techo de 1.3x (DESIGN_LIQUID §Tipografía): el panel launcher tiene
/// dimensiones fijas calculadas por AppKit, no reflowea como una vista de iOS, así que el
/// texto puede crecer con "Larger Text" del sistema pero no sin límite.
private struct ScaledFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let baseSize: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo textStyle: Font.TextStyle) {
        self.baseSize = size
        self.weight = weight
        self.design = design
        self._scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: min(scaledSize, baseSize * 1.3), weight: weight, design: design))
    }
}

extension View {
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight, design: design, relativeTo: textStyle))
    }
}
