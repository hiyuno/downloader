import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var updateService = YTDLPUpdateService.shared

    var body: some View {
        Form {
            destinationAppSection
            downloadFolderSection
            qualitySection
            if viewModel.binariesMissing || updateService.updateAvailable {
                statusSection
            }
        }
        .formStyle(.grouped)
        .frame(width: Theme.Size.settings.width, height: Theme.Size.settings.height)
    }

    // MARK: - 1. App destino

    private var destinationAppSection: some View {
        Section {
            HStack(spacing: Theme.Spacing.iconToText) {
                if let icon = viewModel.destinationAppIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: Theme.Size.siteIcon, height: Theme.Size.siteIcon)
                }
                Text(viewModel.destinationAppName ?? "Ninguna — solo se notificará al terminar")
                    .font(Theme.Font.settingsControl)
                    .foregroundStyle(viewModel.destinationAppName == nil ? .secondary : .primary)
                Spacer()
                if viewModel.destinationAppName != nil {
                    Button("Quitar", action: viewModel.clearDestinationApp)
                        .buttonStyle(DownloaderButtonStyle())
                }
                Button("Cambiar…", action: viewModel.changeDestinationApp)
                    .buttonStyle(DownloaderButtonStyle())
            }
            Text("El archivo se abrirá automáticamente aquí al completar la descarga.")
                .font(Theme.Font.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("App destino").font(Theme.Font.settingsHeader)
        }
    }

    // MARK: - 2. Carpeta de descarga

    private var downloadFolderSection: some View {
        Section {
            HStack(spacing: Theme.Spacing.iconToText) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                    .frame(width: Theme.Size.siteIcon, height: Theme.Size.siteIcon)
                Text(viewModel.abbreviatedFolderPath)
                    .font(Theme.Font.settingsControl)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Cambiar…", action: viewModel.changeDownloadFolder)
                    .buttonStyle(DownloaderButtonStyle())
            }
            if let folderError = viewModel.folderError {
                Text(folderError)
                    .font(Theme.Font.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Carpeta de descarga").font(Theme.Font.settingsHeader)
        }
    }

    // MARK: - 3. Calidad default

    private var qualitySection: some View {
        Section {
            Picker("", selection: $viewModel.quality) {
                ForEach(DownloadQuality.allCases) { quality in
                    Text(quality.displayName).tag(quality)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("Se usa siempre — no se pregunta en cada descarga.")
                .font(Theme.Font.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Calidad default").font(Theme.Font.settingsHeader)
        }
    }

    // MARK: - Estado del motor (mínimo funcional, sin UI nueva inventada)

    private var statusSection: some View {
        Section {
            if viewModel.binariesMissing {
                Text("Falta yt-dlp en el bundle. Coloca los binarios en Resources/bin y recompila (ver Resources/bin/README.md).")
                    .font(Theme.Font.footnote)
                    .foregroundStyle(.red)
            } else if updateService.updateAvailable {
                Text("Hay una actualización de yt-dlp disponible (\(updateService.latestVersion ?? "—")). La versión empaquetada es \(updateService.embeddedVersion ?? "—").")
                    .font(Theme.Font.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Motor de descarga").font(Theme.Font.settingsHeader)
        }
    }
}

/// Pill de 28pt. `.glass` en macOS 26+, `.bordered` antes — mismo `#available`
/// pattern que el fondo del panel, sin dispersar checks de versión.
private struct DownloaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26, *) {
            configuration.label
                .font(Theme.Font.settingsControl)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.pill))
                .opacity(configuration.isPressed ? 0.7 : 1)
        } else {
            configuration.label
                .font(Theme.Font.settingsControl)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                        .fill(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08))
                )
        }
    }
}

#Preview {
    SettingsView()
}
