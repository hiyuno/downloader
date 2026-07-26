import SwiftUI

/// Chip inline bajo el input. El caso diseñado es "sitio no reconocido" (naranja,
/// no bloqueante). La variante roja se reutiliza para "faltan los binarios" en vez de
/// inventar una superficie de error nueva que Jonny no diseñó.
struct InlineChip: View {
    enum Kind {
        case warning
        case error

        var tint: Color {
            switch self {
            case .warning: .orange
            case .error: .red
            }
        }
    }

    let kind: Kind
    let symbolName: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .medium))
            Text(text)
                .scaledFont(size: 11, weight: .regular)
        }
        .foregroundStyle(kind.tint)
        .padding(.horizontal, 8)
        .frame(height: Theme.Spacing.chipHeight)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                .fill(kind.tint.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
        .accessibilityValue(accessibilityValueText)
    }

    private var accessibilityValueText: String {
        switch kind {
        case .warning: "Aviso"
        case .error: "Error"
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        InlineChip(
            kind: .warning,
            symbolName: "questionmark.circle",
            text: "Sitio no reconocido — se intentará de todas formas"
        )
        InlineChip(
            kind: .error,
            symbolName: "exclamationmark.triangle",
            text: "Falta yt-dlp en Resources/bin"
        )
    }
    .padding(40)
}
