import SwiftUI

struct LauncherView: View {
    @Bindable var viewModel: LauncherViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            frame

            if let chip = viewModel.chip {
                Spacer().frame(height: Theme.Spacing.inputToChip)
                InlineChip(kind: chip.kind, symbolName: chip.symbol, text: chip.text)
                    .padding(.horizontal, Theme.Spacing.inputHorizontalPadding)
                    .transition(.opacity)
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
        .onChange(of: viewModel.frameState) { oldValue, newValue in
            guard let text = viewModel.announcement(from: oldValue, to: newValue) else { return }
            AccessibilityNotification.Announcement(text).post()
        }
    }

    /// Reduce Motion: solo opacity, sin scale (tabla de Reduce Motion).
    private var scale: CGFloat {
        guard !reduceMotion else { return 1 }
        return viewModel.isVisible ? 1 : 0.96
    }

    // MARK: - El frame — máquina de estados única

    @ViewBuilder
    private var frame: some View {
        Group {
            switch viewModel.frameState {
            case .input: inputContent
            case .downloading: downloadingContent
            case .completed: completedContent
            case .error: errorContent
            }
        }
        .id(viewModel.frameState)
        .transition(.opacity)
        .padding(.horizontal, Theme.Spacing.inputHorizontalPadding)
        .frame(height: Theme.Spacing.inputRowHeight)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(frameFill)
        )
        .keyframeAnimator(
            initialValue: CGFloat(0),
            trigger: viewModel.rejectionTick
        ) { content, offset in
            content.offset(x: reduceMotion ? 0 : offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(0, duration: 0)
                CubicKeyframe(Theme.Motion.frameShakeOffset, duration: Theme.Motion.frameShakeDuration / 6)
                CubicKeyframe(-Theme.Motion.frameShakeOffset, duration: Theme.Motion.frameShakeDuration / 3)
                CubicKeyframe(Theme.Motion.frameShakeOffset, duration: Theme.Motion.frameShakeDuration / 3)
                CubicKeyframe(0, duration: Theme.Motion.frameShakeDuration / 6)
            }
        }
        .keyframeAnimator(
            initialValue: 1.0,
            trigger: viewModel.rejectionTick
        ) { content, opacity in
            content.opacity(reduceMotion ? opacity : 1)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1, duration: 0)
                CubicKeyframe(Theme.Motion.frameRejectionPulseOpacity, duration: Theme.Motion.frameRejectionPulseDuration / 2)
                CubicKeyframe(1, duration: Theme.Motion.frameRejectionPulseDuration / 2)
            }
        }
        .animation(Theme.Motion.rowStateCrossfade, value: viewModel.frameState)
    }

    private var frameFill: Color {
        if viewModel.frameState == .error { return Theme.Palette.failedRowFill }
        return reduceTransparency ? Theme.Palette.rowFillReduceTransparency : Theme.Palette.rowFill
    }

    // MARK: - `.input`

    private var inputContent: some View {
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
        .animation(Theme.Motion.rowStateCrossfade, value: viewModel.detectedSite)
    }

    // MARK: - `.downloading`

    private var downloadingContent: some View {
        HStack(spacing: Theme.Spacing.iconToText) {
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(Color.accentColor)
                .frame(width: Theme.Size.rowIcon, height: Theme.Size.rowIcon)

            Text(viewModel.downloadingTitle)
                .scaledFont(size: 13, weight: .regular)
                .foregroundStyle(viewModel.downloadingTitleIsPlaceholder ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Text("\(Int(viewModel.downloadingPercent * 100))%")
                    .scaledFont(size: 11, weight: .regular)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .accessibilityHidden(true)

                ProgressRing(percent: viewModel.downloadingPercent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.downloadingTitle). Descargando, \(Int(viewModel.downloadingPercent * 100)) por ciento.")
    }

    // MARK: - `.completed`

    private var completedContent: some View {
        HStack(spacing: Theme.Spacing.iconToText) {
            HStack(spacing: Theme.Spacing.iconToText) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .frame(width: Theme.Size.rowIcon, height: Theme.Size.rowIcon)

                Text(viewModel.completedTitle)
                    .scaledFont(size: 13, weight: .regular)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.completedTitle). Completado.")

            Spacer(minLength: 8)

            completedAccessories
        }
    }

    @ViewBuilder
    private var completedAccessories: some View {
        if let fileURL = viewModel.completedFileURL {
            HStack(spacing: Theme.Spacing.betweenRowAccessories) {
                if let destinationAppIcon {
                    Button {
                        Task { await FileOpenerService.openIfConfigured(fileURL) }
                    } label: {
                        Image(nsImage: destinationAppIcon)
                            .resizable()
                            .frame(width: Theme.Size.rowAccessoryIcon, height: Theme.Size.rowAccessoryIcon)
                    }
                    .buttonStyle(.plain)
                    .frame(width: Theme.Spacing.minimumTapTarget, height: Theme.Spacing.minimumTapTarget)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Abrir \(viewModel.completedTitle) en \(destinationAppName ?? "app destino")")
                }

                Button {
                    FileOpenerService.revealInFinder(fileURL)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: Theme.Size.rowAccessoryIcon, weight: .regular))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: Theme.Spacing.minimumTapTarget, height: Theme.Spacing.minimumTapTarget)
                .contentShape(Rectangle())
                .accessibilityLabel("Mostrar \(viewModel.completedTitle) en Finder")
            }
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

    // MARK: - `.error`

    private var errorContent: some View {
        HStack(spacing: Theme.Spacing.iconToText) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .frame(width: Theme.Size.rowIcon, height: Theme.Size.rowIcon)

            Text(viewModel.errorMessage)
                .scaledFont(size: 13, weight: .regular)
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Falló: \(viewModel.errorMessage).")
        .accessibilityHint("Escribe o pega un nuevo link para continuar")
    }
}

#Preview {
    let viewModel = LauncherViewModel()
    viewModel.isVisible = true
    return LauncherView(viewModel: viewModel)
        .padding(60)
}
