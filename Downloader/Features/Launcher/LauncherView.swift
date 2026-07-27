import SwiftUI

struct LauncherView: View {
    @Bindable var viewModel: LauncherViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            inputRow

            if let chip = viewModel.chip {
                Spacer().frame(height: Theme.Spacing.inputToChip)
                InlineChip(kind: chip.kind, symbolName: chip.symbol, text: chip.text)
                    .padding(.horizontal, Theme.Spacing.inputHorizontalPadding)
                    .transition(.opacity)
            }

            if !viewModel.activeDownloads.isEmpty {
                Spacer().frame(height: Theme.Spacing.inputToList)
                downloadList
            }
        }
        .padding(Theme.Spacing.panelPadding)
        .frame(width: Theme.Size.panelWidth, height: viewModel.panelHeight, alignment: .top)
        .glassPanelBackground()
        .opacity(viewModel.isVisible ? 1 : 0)
        .scaleEffect(scale)
        .animation(Theme.Motion.heightChange(reduceMotion: reduceMotion), value: viewModel.panelHeight)
        .animation(
            viewModel.isVisible ? Theme.Motion.panelAppear : Theme.Motion.panelDismiss,
            value: viewModel.isVisible
        )
    }

    /// Reduce Motion: solo opacity, sin scale (tabla de Reduce Motion).
    private var scale: CGFloat {
        guard !reduceMotion else { return 1 }
        return viewModel.isVisible ? 1 : 0.96
    }

    private var inputRow: some View {
        HStack(spacing: Theme.Spacing.iconToText) {
            if let site = viewModel.detectedSite, site.isRecognized {
                Text(site.displayName)
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(site.displayName)
                    .transition(.opacity)
            }

            URLInputField(
                text: $viewModel.inputText,
                focusToken: viewModel.focusToken,
                placeholder: viewModel.placeholder,
                onSubmit: viewModel.submit,
                onCancel: viewModel.requestClose
            )
        }
        .padding(.horizontal, Theme.Spacing.inputHorizontalPadding)
        .frame(height: Theme.Spacing.inputRowHeight)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(Theme.Palette.rowFill)
        )
        .animation(Theme.Motion.rowStateCrossfade, value: viewModel.detectedSite)
    }

    @ViewBuilder
    private var downloadList: some View {
        let rows = VStack(spacing: Theme.Spacing.betweenRows) {
            ForEach(viewModel.activeDownloads) { task in
                DownloadRowView(
                    task: task,
                    onReveal: FileOpenerService.revealInFinder,
                    onOpenInApp: { fileURL in
                        Task { await FileOpenerService.openIfConfigured(fileURL) }
                    }
                )
                .transition(.opacity)
            }
        }

        if viewModel.listExceedsPanel {
            ScrollView(.vertical) { rows }
                .scrollIndicators(.never)
        } else {
            rows
        }
    }
}

#Preview {
    let viewModel = LauncherViewModel()
    viewModel.isVisible = true
    return LauncherView(viewModel: viewModel)
        .padding(60)
}
