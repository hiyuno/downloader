import SwiftUI

/// Un solo componente con un `switch` sobre `DownloadState` — no cuatro vistas.
/// El layout no cambia de tamaño entre estados, por eso la transición es crossfade
/// puro sin desplazamiento (DESIGN_LIQUID, tabla de Animaciones).
struct DownloadRowView: View {
    let task: DownloadTask
    var onReveal: (URL) -> Void = { _ in }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Theme.Spacing.iconToText) {
            icon
                .frame(width: Theme.Size.rowIcon, height: Theme.Size.rowIcon)
                .id(iconID)
                .transition(.opacity)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.displayTitle)
                    .font(Theme.Font.rowTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(Theme.Font.rowSubtitle)
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
                    .id(subtitle)
                    .transition(.opacity)
            }

            Spacer(minLength: 8)

            trailingAccessory
        }
        .padding(.horizontal, Theme.Spacing.rowHorizontalPadding)
        .frame(height: Theme.Spacing.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(rowFill)
        )
        .onHover { isHovering = $0 }
        .animation(Theme.Motion.rowStateCrossfade, value: iconID)
        .animation(Theme.Motion.rowStateCrossfade, value: subtitle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.displayTitle). \(subtitle)")
    }

    // MARK: - Estados

    @ViewBuilder
    private var icon: some View {
        switch task.state {
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .downloading:
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(Color.accentColor)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    private var iconID: String {
        switch task.state {
        case .queued: "queued"
        case .downloading: "downloading"
        case .completed: "completed"
        case .failed: "failed"
        }
    }

    private var subtitle: String {
        switch task.state {
        case .queued:
            "En cola"
        case .downloading(_, let speed, let eta):
            if let speed, let eta { "\(speed) · \(eta)" }
            else if let speed { speed }
            else { "Descargando… (sin progreso detallado)" }
        case .completed:
            "Completado"
        case .failed(let reason):
            reason.message
        }
    }

    private var subtitleColor: Color {
        if case .failed = task.state { return .red }
        return .secondary
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        switch task.state {
        case .downloading(let percent, _, _):
            ProgressPill(percent: percent)
        case .completed(let fileURL):
            if isHovering {
                Button {
                    onReveal(fileURL)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .regular))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: Theme.Spacing.minimumTapTarget, height: Theme.Spacing.minimumTapTarget)
                .contentShape(Rectangle())
                .accessibilityLabel("Mostrar en Finder")
                .transition(.opacity)
            }
        case .queued, .failed:
            EmptyView()
        }
    }

    private var rowFill: Color {
        if case .failed = task.state { return Theme.Palette.failedRowFill }
        return reduceTransparency ? Theme.Palette.rowFillReduceTransparency : Theme.Palette.rowFill
    }
}

#Preview {
    let folder = URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Downloads")
    return VStack(spacing: Theme.Spacing.betweenRows) {
        DownloadRowView(task: DownloadTask(
            sourceURL: URL(string: "https://youtu.be/abc")!,
            site: .youtube,
            destinationFolder: folder
        ))
        DownloadRowView(task: DownloadTask(
            sourceURL: URL(string: "https://youtu.be/abc")!,
            site: .youtube,
            destinationFolder: folder,
            title: "Un video con un título bastante largo para truncar",
            state: .downloading(percent: 0.42, speed: "3.4MiB/s", eta: "00:12")
        ))
        DownloadRowView(task: DownloadTask(
            sourceURL: URL(string: "https://youtu.be/abc")!,
            site: .youtube,
            destinationFolder: folder,
            state: .completed(fileURL: folder.appending(path: "clip.mp4"))
        ))
        DownloadRowView(task: DownloadTask(
            sourceURL: URL(string: "https://youtu.be/abc")!,
            site: .youtube,
            destinationFolder: folder,
            state: .failed(reason: .siteBlockedOrChanged)
        ))
    }
    .padding(Theme.Spacing.panelPadding)
    .frame(width: Theme.Size.panelWidth)
}
