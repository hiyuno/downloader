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
                Text(viewModel.destinationAppName ?? "None — you'll just be notified when it's done")
                    .scaledFont(size: 13, weight: .regular)
                    .foregroundStyle(viewModel.destinationAppName == nil ? .secondary : .primary)
                Spacer()
                if viewModel.destinationAppName != nil {
                    Button("Remove", action: viewModel.clearDestinationApp)
                        .buttonStyle(DownloaderButtonStyle())
                        .accessibilityLabel("Remove destination app")
                }
                Button("Change…", action: viewModel.changeDestinationApp)
                    .buttonStyle(DownloaderButtonStyle())
                    .accessibilityLabel("Change destination app")
            }
            Text("The file will open here automatically once the download finishes.")
                .scaledFont(size: 11, weight: .regular)
                .foregroundStyle(.secondary)
        } header: {
            Text("Destination App").scaledFont(size: 13, weight: .semibold)
        }
    }

    // MARK: - 2. Carpeta de descarga

    private var downloadFolderSection: some View {
        Section {
            HStack(spacing: Theme.Spacing.iconToText) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                    .frame(width: Theme.Size.siteIcon, height: Theme.Size.siteIcon)
                    .accessibilityHidden(true)
                Text(viewModel.abbreviatedFolderPath)
                    .scaledFont(size: 13, weight: .regular)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Change…", action: viewModel.changeDownloadFolder)
                    .buttonStyle(DownloaderButtonStyle())
                    .accessibilityLabel("Change download folder")
            }
            if let folderError = viewModel.folderError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .regular))
                    Text(folderError)
                        .scaledFont(size: 11, weight: .regular)
                }
                .foregroundStyle(.red)
            }
        } header: {
            Text("Download Folder").scaledFont(size: 13, weight: .semibold)
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
            .accessibilityLabel("Download quality")

            Text("Always used — you won't be asked on every download.")
                .scaledFont(size: 11, weight: .regular)
                .foregroundStyle(.secondary)
        } header: {
            Text("Default Quality").scaledFont(size: 13, weight: .semibold)
        }
    }

    // MARK: - Estado del motor (mínimo funcional, sin UI nueva inventada)

    private var statusSection: some View {
        Section {
            if viewModel.binariesMissing {
                Text("yt-dlp is missing from the bundle. Place the binaries in Resources/bin and rebuild (see Resources/bin/README.md).")
                    .scaledFont(size: 11, weight: .regular)
                    .foregroundStyle(.red)
            } else if updateService.updateAvailable {
                Text("A yt-dlp update is available (\(updateService.latestVersion ?? "—")). The bundled version is \(updateService.embeddedVersion ?? "—").")
                    .scaledFont(size: 11, weight: .regular)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Download Engine").scaledFont(size: 13, weight: .semibold)
        }
    }
}

/// Pill de 28pt. `.glass` en macOS 26+, `.thinMaterial` antes — mismo `#available`
/// pattern que el fondo del panel, sin dispersar checks de versión.
/// Ver DESIGN_FROST.md > Decisiones registradas: material translúcido, no fill plano —
/// coherente con la tabla de compatibilidad de Jonny (botón secundario → `.thinMaterial`).
private struct DownloaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26, *) {
            configuration.label
                .scaledFont(size: 13, weight: .regular)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.pill))
                .opacity(configuration.isPressed ? 0.7 : 1)
        } else {
            configuration.label
                .scaledFont(size: 13, weight: .regular)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous))
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }
}

#Preview {
    SettingsView()
}
