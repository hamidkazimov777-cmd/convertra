import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct InspectorView: View {
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var loc: Localization

    var body: some View {
        VStack(spacing: 0) {
            // Табы — сегментированный контрол на hairline-стекле
            HStack(spacing: 4) {
                InspectorTabButton(title: loc["Инфо"], isSelected: appState.inspectorTab == .info) { appState.inspectorTab = .info }
                InspectorTabButton(title: loc["Метаданные"], isSelected: appState.inspectorTab == .metadata) { appState.inspectorTab = .metadata }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius + 2, style: .continuous)
                    .fill(Theme.Colors.bgBase.opacity(0.6))
            )
            .hairline(Theme.Layout.buttonRadius + 2, color: Theme.Colors.borderSubtle)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().background(Theme.Colors.border)

            if appState.selectedAudioFileCount == 0 {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "square.dashed")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Theme.Colors.textMuted)
                    Text(loc["Трек не выбран"])
                        .font(.inter(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        switch appState.inspectorTab {
                        case .info:
                            InspectorInfoTab()
                        case .metadata:
                            InspectorMetadataTab()
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: Theme.Layout.inspectorWidth)
        .background(Theme.Colors.bgBase)
    }
}

// MARK: - Tabs

struct InspectorInfoTab: View {
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var loc: Localization

    private func channelsText(_ channels: Int?) -> String {
        switch channels {
        case 1: return loc["Моно"]
        case 2: return loc["Стерео"]
        case let .some(n) where n > 0: return "\(n) ch"
        default: return "—"
        }
    }

    var body: some View {
        if let file = appState.library.first(where: { appState.selectedAudioFileIDs.contains($0.id) }) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top, spacing: 12) {
                    if let artworkURL = file.metadata.artworkLocation, let nsImage = NSImage(contentsOf: artworkURL) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .hairline(10, color: Theme.Colors.border)
                            .softShadow(0.6)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Theme.Colors.bgHover)
                            Image(systemName: "music.note")
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .frame(width: 64, height: 64)
                        .hairline(10, color: Theme.Colors.border)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.displayTitle)
                            .font(.inter(size: 14, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(file.displayArtist)
                            .font(.inter(size: 13, weight: .medium))
                            .foregroundStyle(Theme.Colors.accentBright)
                        Text(file.metadata.album?.isEmpty == false ? file.metadata.album! : loc["Неизвестный альбом"])
                            .font(.inter(size: 12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                // Тех-сетка — только поля, для которых реально есть данные.
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 14) {
                    TechInfoCell(label: "Key", value: file.analysis?.musicalKey?.rawValue ?? "—")
                    TechInfoCell(label: "BPM", value: file.analysis?.bpm.map { String(format: "%.0f", $0) } ?? "—")
                    TechInfoCell(label: loc["Формат"], value: file.displayCodec)
                    TechInfoCell(label: loc["Частота"], value: file.displaySampleRate)
                    TechInfoCell(label: loc["Битрейт"], value: file.displayBitrate)
                    TechInfoCell(label: loc["Каналы"], value: channelsText(file.analysis?.channels))
                }
                .padding(14)
                .djPanel(radius: 12)
            }
        }
    }
}

struct InspectorMetadataTab: View {
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var loc: Localization

    var body: some View {
        VStack(spacing: 18) {
            ArtworkWell()

            VStack(spacing: 12) {
                MetadataField(label: loc["Название"], field: field(\.title))
                MetadataField(label: loc["Артист"], field: field(\.artist))
                MetadataField(label: loc["Альбом"], field: field(\.album))
                MetadataField(label: loc["Артист альбома"], field: field(\.albumArtist))
                MetadataField(label: loc["Жанр"], field: field(\.genre))

                HStack(spacing: 10) {
                    MetadataField(label: loc["Год"], field: field(\.year), compact: true)
                    MetadataField(label: loc["Трек"], field: field(\.trackNumber), compact: true)
                    MetadataField(label: loc["Диск"], field: field(\.discNumber), compact: true)
                }
                HStack(spacing: 10) {
                    MetadataField(label: "BPM", field: field(\.bpmTag), compact: true)
                    MetadataField(label: "Key", field: field(\.initialKey), compact: true)
                }

                MetadataField(label: loc["Композитор"], field: field(\.composer))
                MetadataField(label: loc["Группа"], field: field(\.grouping))
                MetadataField(label: loc["Лейбл"], field: field(\.publisher))
                MetadataField(label: loc["Комментарий"], field: field(\.comments))
                MetadataField(label: "ISRC", field: field(\.isrc))
                MetadataField(label: loc["Копирайт"], field: field(\.copyright))
            }

            VStack(spacing: 10) {
                Text(loc["В файл записываются только изменённые поля."])
                    .font(.inter(size: 10))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .multilineTextAlignment(.center)

                Button(appState.isApplyingMetadataEdits ? loc["Сохранение…"] : loc["Сохранить метаданные"]) {
                    appState.applyMetadataEditDraft()
                }
                .buttonStyle(AccentButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(!appState.metadataEditDraft.hasChanges || appState.isApplyingMetadataEdits)
                .opacity(appState.metadataEditDraft.hasChanges ? 1 : 0.5)
            }
        }
        .onAppear(perform: appState.prepareMetadataEditDraft)
        .onChange(of: appState.selectedAudioFileIDs) { _ in
            appState.prepareMetadataEditDraft()
        }
    }

    /// A binding that also flags the field as "edited" whenever the user types,
    /// so only touched fields are written (mp3tag-style, no per-field toggles).
    private func field(_ keyPath: WritableKeyPath<MetadataEditDraft, MetadataEditField>) -> Binding<MetadataEditField> {
        Binding(
            get: { appState.metadataEditDraft[keyPath: keyPath] },
            set: { newValue in
                var updated = newValue
                if updated.value != appState.metadataEditDraft[keyPath: keyPath].value {
                    updated.isEnabled = true
                }
                appState.metadataEditDraft[keyPath: keyPath] = updated
            }
        )
    }
}

// MARK: - Artwork

struct ArtworkWell: View {
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var loc: Localization
    @State private var isTargeted = false

    private var currentArtwork: NSImage? {
        let draft = appState.metadataEditDraft
        if draft.artworkMode == .remove { return nil }
        if draft.artworkMode == .replace, let data = draft.artworkData {
            return NSImage(data: data)
        }
        if let url = appState.selectedAudioFiles.first?.metadata.artworkLocation {
            return NSImage(contentsOf: url)
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Colors.bgPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isTargeted ? Theme.Colors.accentHover : Theme.Colors.border,
                                          style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: currentArtwork == nil ? [4] : []))
                    )

                if let artwork = currentArtwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 26, weight: .light))
                        Text(appState.metadataEditDraft.artworkMode == .remove ? loc["Обложка удалена"] : loc["Перетащите или нажмите «Заменить»"])
                            .font(.inter(size: 10))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(12)
                }
            }
            .frame(height: 180)
            .onTapGesture { appState.presentArtworkImporter() }
            .onDrop(of: [.image, .fileURL], isTargeted: $isTargeted) { providers in
                loadDroppedImage(providers)
            }

            HStack(spacing: 8) {
                Button {
                    appState.presentArtworkImporter()
                } label: {
                    Label(loc["Заменить"], systemImage: "square.and.arrow.down")
                        .font(.inter(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle())

                Button {
                    appState.removeArtwork()
                } label: {
                    Label(loc["Удалить"], systemImage: "trash")
                        .font(.inter(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DestructiveGhostButtonStyle())
            }
        }
    }

    private func loadDroppedImage(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.canLoadObject(ofClass: NSImage.self) {
            _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                guard let image = object as? NSImage,
                      let data = image.pngData else { return }
                DispatchQueue.main.async { appState.setArtwork(data: data) }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      let imageData = try? Data(contentsOf: url) else { return }
                DispatchQueue.main.async { appState.setArtwork(data: imageData) }
            }
            return true
        }
        return false
    }
}

extension NSImage {
    var pngData: Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - Components

struct InspectorTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.inter(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius, style: .continuous)
                        .fill(isSelected ? Theme.Colors.bgHover : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius, style: .continuous)
                        .strokeBorder(isSelected ? Theme.Colors.border : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

struct TechInfoCell: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.inter(size: 9, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
            Text(value)
                .font(.inter(size: 13, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }
}

struct MetadataField: View {
    let label: String
    @Binding var field: MetadataEditField
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Text(label.uppercased())
                    .font(.inter(size: 9, weight: .semibold))
                    .foregroundStyle(field.isEnabled ? Theme.Colors.accentBright : Theme.Colors.textMuted)
                if field.isEnabled {
                    Circle()
                        .fill(Theme.Colors.accentBright)
                        .frame(width: 4, height: 4)
                }
                Spacer(minLength: 0)
            }

            TextField(compact ? "—" : "", text: $field.value)
                .textFieldStyle(.plain)
                .font(.inter(size: 13))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius, style: .continuous)
                        .fill(Theme.Colors.bgBase)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius, style: .continuous)
                        .strokeBorder(field.isEnabled ? Theme.Colors.accentPrimary.opacity(0.55) : Theme.Colors.border, lineWidth: 1)
                )
        }
    }
}
