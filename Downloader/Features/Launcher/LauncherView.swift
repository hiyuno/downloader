import SwiftUI

struct LauncherView: View {
    @Bindable var viewModel: LauncherViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Coreografía del accesorio derecho (DESIGN_LIQUID §Animaciones): estos dos flags
    /// controlan la presencia del texto "NN%" y de los botones de acción de forma
    /// independiente del crossfade de ícono/título — permite que la salida del uno y
    /// la entrada del otro queden encadenadas en vez de solaparse (ver `advanceToCompletedActions`).
    @State private var showsProgressAccessory = false
    @State private var showsCompletedActions = false

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
        .onAppear {
            syncAccessoryState(for: viewModel.frameState)
        }
        .onChange(of: viewModel.frameState) { oldValue, newValue in
            guard let text = viewModel.announcement(from: oldValue, to: newValue) else { return }
            AccessibilityNotification.Announcement(text).post()
        }
        .onChange(of: viewModel.frameState) { _, newValue in
            handleFrameStateChange(to: newValue)
        }
        .onChange(of: viewModel.downloadingPercent) { _, newValue in
            handleProgressChange(to: newValue)
        }
    }

    /// Reduce Motion: solo opacity, sin scale (tabla de Reduce Motion).
    private var scale: CGFloat {
        guard !reduceMotion else { return 1 }
        return viewModel.isVisible ? 1 : 0.96
    }

    // MARK: - Coreografía del accesorio derecho

    /// Estado inicial (montaje de la vista / reapertura del panel) — se fija sin animar,
    /// nunca debe verse un slide de entrada para algo que ya estaba ahí antes de que el
    /// usuario viera el frame por primera vez.
    private func syncAccessoryState(for state: LauncherViewModel.FrameState) {
        switch state {
        case .downloading:
            showsProgressAccessory = viewModel.downloadingPercent > 0
            showsCompletedActions = false
        case .completed:
            showsProgressAccessory = false
            showsCompletedActions = true
        case .error, .input:
            showsProgressAccessory = false
            showsCompletedActions = false
        }
    }

    /// Punto 2 de la coreografía: el primer progreso real (`percent` pasa de 0 a >0)
    /// hace entrar el bloque [% + anillo] deslizando desde la derecha.
    private func handleProgressChange(to newValue: Double) {
        guard viewModel.frameState == .downloading else { return }
        guard !showsProgressAccessory, newValue > 0 else { return }
        withAnimation(accessoryAnimation) {
            showsProgressAccessory = true
        }
    }

    private func handleFrameStateChange(to newValue: LauncherViewModel.FrameState) {
        switch newValue {
        case .downloading:
            // Descarga nueva (siempre se llega aquí vía `.input`) — reset instantáneo,
            // sin animar: no hay nada visible todavía que deba "salir".
            showsProgressAccessory = false
            showsCompletedActions = false

        case .completed:
            advanceToCompletedActions()

        case .error:
            // Punto 5: el bloque sale, y el lado derecho queda vacío — nada entra.
            hideProgressAccessory(completion: nil)
            showsCompletedActions = false

        case .input:
            showsProgressAccessory = false
            showsCompletedActions = false
        }
    }

    /// Punto 3: encadenamiento secuencial estricto. Si el bloque de progreso estaba
    /// visible, primero completa su salida y **solo entonces** — vía el `completion`
    /// de `withAnimation(_:completion:)` (macOS 14+) — dispara la entrada de los
    /// íconos de acción. Se prefiere esto a un `DispatchQueue.asyncAfter` con la
    /// duración como número mágico: el completion handler está atado a la animación
    /// real que corrió, no a una estimación de cuánto debería durar, así que no se
    /// desincroniza si la duración del token cambia en el futuro.
    private func advanceToCompletedActions() {
        guard showsProgressAccessory else {
            // El progreso nunca llegó a mostrarse (completó a 0% o instantáneo) —
            // no hay nada que esperar, los botones entran directo.
            withAnimation(accessoryAnimation) {
                showsCompletedActions = true
            }
            return
        }
        hideProgressAccessory {
            withAnimation(accessoryAnimation) {
                showsCompletedActions = true
            }
        }
    }

    private func hideProgressAccessory(completion: (() -> Void)?) {
        guard showsProgressAccessory else {
            completion?()
            return
        }
        withAnimation(accessoryAnimation) {
            showsProgressAccessory = false
        } completion: {
            completion?()
        }
    }

    private var accessoryAnimation: Animation {
        Theme.Motion.accessorySlide
    }

    /// Reduce Motion (punto técnico pedido): mismo token de duración, se sustituye el
    /// desplazamiento por un fade puro — el orden secuencial se mantiene igual.
    private var accessoryTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity)
    }

    // MARK: - El frame — máquina de estados única

    @ViewBuilder
    private var frame: some View {
        Group {
            if viewModel.frameState == .input {
                inputContent
                    .transition(.opacity)
            } else {
                statefulRow
                    .transition(.opacity)
            }
        }
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

    private var frameFill: AnyShapeStyle {
        if viewModel.frameState == .error { return AnyShapeStyle(Theme.Palette.failedRowFill) }
        if viewModel.frameState == .input,
           let site = viewModel.detectedSite,
           let tint = Theme.Palette.siteTint(for: site, reduceTransparency: reduceTransparency) {
            return tint
        }
        return AnyShapeStyle(reduceTransparency ? Theme.Palette.rowFillReduceTransparency : Theme.Palette.rowFill)
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

    // MARK: - `.downloading` / `.completed` / `.error` — fila con accesorio derecho desacoplado

    /// El ícono y el título del lado izquierdo siguen crossfadeando juntos como una
    /// sola unidad al cambiar de estado (punto 4: el ícono nunca se desplaza, solo
    /// cambia por opacity). El accesorio derecho vive fuera de ese `switch` — es la
    /// misma vista persistente en los 3 estados, así que su entrada/salida no se ve
    /// forzada a reiniciarse cada vez que cambia el estado del frame; solo la maneja
    /// la coreografía explícita de arriba.
    private var statefulRow: some View {
        HStack(spacing: Theme.Spacing.iconToText) {
            statefulLeading
            Spacer(minLength: 8)
            trailingAccessorySlot
        }
    }

    @ViewBuilder
    private var statefulLeading: some View {
        Group {
            switch viewModel.frameState {
            case .downloading:
                HStack(spacing: Theme.Spacing.iconToText) {
                    DownloadStateIcon(percent: viewModel.downloadingPercent, color: .white)
                    stateTitle(viewModel.downloadingTitle, color: viewModel.downloadingTitleIsPlaceholder ? .secondary : .primary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(viewModel.downloadingTitle). Downloading, \(Int(viewModel.downloadingPercent * 100)) percent.")

            case .completed:
                HStack(spacing: Theme.Spacing.iconToText) {
                    DownloadStateIcon(percent: 1, color: .green)
                    stateTitle(viewModel.completedTitle, color: .primary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(viewModel.completedTitle). Completed.")

            case .error:
                HStack(spacing: Theme.Spacing.iconToText) {
                    DownloadStateIcon(percent: 0, color: .red)
                    stateTitle(viewModel.errorMessage, color: .red)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Failed: \(viewModel.errorMessage).")
                .accessibilityHint("Type or paste a new link to continue")

            case .input:
                EmptyView()
            }
        }
        .id(viewModel.frameState)
        .transition(.opacity)
    }

    private func stateTitle(_ text: String, color: Color) -> some View {
        Text(text)
            .scaledFont(size: 13, weight: .regular)
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    /// Ancho reservado fijo (`Theme.Size.rowTrailingAccessoryWidth`) para que el título
    /// nunca salte de tamaño cuando el texto "NN%" o los botones aparecen/desaparecen —
    /// el espacio siempre está ahí, solo cambia si hay algo dibujado dentro.
    @ViewBuilder
    private var trailingAccessorySlot: some View {
        ZStack(alignment: .trailing) {
            if showsProgressAccessory {
                progressAccessory
                    .transition(accessoryTransition)
            }
            if showsCompletedActions {
                completedAccessories
                    .transition(accessoryTransition)
            }
        }
        .frame(width: Theme.Size.rowTrailingAccessoryWidth, height: Theme.Size.rowIcon, alignment: .trailing)
        // Cuando el accesorio es el texto "NN%" (o está vacío), toda la información
        // relevante ya está en el label combinado de `statefulLeading` — este slot no
        // debe generar un segundo elemento de VoiceOver redundante. Solo en `.completed`
        // los botones deben quedar navegables de forma independiente (Tab / VO).
        .accessibilityHidden(viewModel.frameState != .completed)
    }

    private var progressAccessory: some View {
        Text("\(Int(viewModel.downloadingPercent * 100))%")
            .scaledFont(size: 11, weight: .regular)
            .foregroundStyle(.white)
            .monospacedDigit()
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
                    .accessibilityLabel("Open \(viewModel.completedTitle) in \(destinationAppName ?? "destination app")")
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
                .accessibilityLabel("Show \(viewModel.completedTitle) in Finder")
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
}

#Preview {
    let viewModel = LauncherViewModel()
    viewModel.isVisible = true
    return LauncherView(viewModel: viewModel)
        .padding(60)
}
