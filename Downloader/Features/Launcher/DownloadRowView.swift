import SwiftUI

/// Un solo componente con un `switch` sobre `DownloadState` — no cuatro vistas.
/// El layout no cambia de tamaño entre estados, por eso la transición es crossfade
/// puro sin desplazamiento (DESIGN_LIQUID, tabla de Animaciones).
struct DownloadRowView: View {
    let task: DownloadTask
    var onReveal: (URL) -> Void = { _ in }
    var onOpenInApp: (URL) -> Void = { _ in }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Theme.Spacing.iconToText) {
            icon
                .frame(width: Theme.Size.rowIcon, height: Theme.Size.rowIcon)
                .id(iconID)
                .transition(.opacity)

            VStack(alignment: .leading, spacing: 1) {
                shouldCenterVertically

                Text(task.displayTitle)
                    .scaledFont(size: 13, weight: .regular)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .scaledFont(size: 11, weight: .regular)
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                        .id(subtitle)
                        .transition(.opacity)
                }

                shouldCenterVertically
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
        .accessibilityLabel(accessibilityStateLabel)
    }

    private var accessibilityStateLabel: String {
        let state: String
        switch task.state {
        case .queued:
            state = "En cola"
        case .downloading(let percent, _, _):
            state = "Descargando \(Int(percent * 100)) por ciento"
        case .completed:
            state = "Completado"
        case .failed(let reason):
            state = "Falló: \(reason.message)"
        }
        return "\(task.displayTitle). \(state)"
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
            ""
        case .downloading:
            ""
        case .completed:
            ""
        case .failed(let reason):
            reason.message
        }
    }

    @ViewBuilder
    private var shouldCenterVertically: some View {
        switch task.state {
        case .downloading, .queued, .completed:
            Spacer(minLength: 0)
        default:
            EmptyView()
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
            HStack(spacing: 4) {
                Text("\(Int(percent * 100))%")
                    .scaledFont(size: 11, weight: .regular)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .accessibilityHidden(true)

                ProgressRing(percent: percent)
            }
        case .completed(let fileURL):
            HStack(spacing: Theme.Spacing.betweenRowAccessories) {
                if let destinationAppIcon {
                    Button {
                        onOpenInApp(fileURL)
                    } label: {
                        Image(nsImage: destinationAppIcon)
                            .resizable()
                            .frame(width: Theme.Size.rowAccessoryIcon, height: Theme.Size.rowAccessoryIcon)
                    }
                    .buttonStyle(.plain)
                    .frame(width: Theme.Spacing.minimumTapTarget, height: Theme.Spacing.minimumTapTarget)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Abrir \(task.displayTitle) en \(destinationAppName ?? "app destino")")
                }

                Button {
                    onReveal(fileURL)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: Theme.Size.rowAccessoryIcon, weight: .regular))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: Theme.Spacing.minimumTapTarget, height: Theme.Spacing.minimumTapTarget)
                .contentShape(Rectangle())
                .accessibilityLabel("Mostrar \(task.displayTitle) en Finder")
            }
            .opacity(isHovering ? 1 : 0)
        case .queued, .failed:
            EmptyView()
        }
    }

    private var destinationAppIcon: NSImage? {
        guard let bundleID = AppSettings.destinationAppBundleID, !bundleID.isEmpty else { return nil }
        return FileOpenerService.icon(forBundleIdentifier: bundleID)
    }

    private var destinationAppName: String? {
        guard let bundleID = AppSettings.destinationAppBundleID, !bundleID.isEmpty else { return nil }
        return FileOpenerService.name(forBundleIdentifier: bundleID)
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
