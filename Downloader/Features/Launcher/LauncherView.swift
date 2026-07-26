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
            if let site = viewModel.detectedSite {
                // 13pt intencional, no 16 (= frame): empareja con el badge "sitio
                // detectado" (12pt Medium) y con el resto de íconos de la app
                // (DownloadRowView usa el mismo ~13pt en frames más grandes). Ver
                // DESIGN_LIQUID.md > Decisiones registradas.
                Image(systemName: site.symbolName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(site.isRecognized ? Color.accentColor : .orange)
                    .frame(width: Theme.Size.siteIcon, height: Theme.Size.siteIcon)
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

            if let site = viewModel.detectedSite, site.isRecognized {
                Text(site.displayName)
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
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
                DownloadRowView(task: task, onReveal: FileOpenerService.revealInFinder)
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
