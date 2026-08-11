import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct InspectorView: View {
    @EnvironmentObject private var appState: AppViewModel
    @State private var selectedTab: Tab = .info
    
    enum Tab {
        case info
        case metadata
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tabs
            HStack(spacing: 0) {
                InspectorTabButton(title: "Info", isSelected: selectedTab == .info) { selectedTab = .info }
                InspectorTabButton(title: "Metadata", isSelected: selectedTab == .metadata) { selectedTab = .metadata }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Divider().background(Theme.Colors.border).padding(.top, 8)
            
            if appState.selectedAudioFileCount == 0 {
                Spacer()
                Text("No track selected")
                    .foregroundStyle(Theme.Colors.textMuted)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        switch selectedTab {
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
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.Colors.bgHover)
                            VStack(spacing: 4) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 20))
                                Text("No Artwork")
                                    .font(.system(size: 8))
                            }
                            .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .frame(width: 64, height: 64)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.displayTitle)
                            .font(.inter(size: 14, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(file.displayArtist)
                            .font(.inter(size: 13))
                            .foregroundStyle(Theme.Colors.accentPrimary)
                        Text(file.metadata.album?.isEmpty == false ? file.metadata.album! : "Unknown Album")
                            .font(.inter(size: 12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                
                // Waveform Placeholder
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.bgPrimary)
                        .frame(height: 40)
                        .overlay(
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 20))
                                path.addLine(to: CGPoint(x: 260, y: 20))
                            }
                            .stroke(Theme.Colors.accentPrimary, style: StrokeStyle(lineWidth: 1, dash: [2]))
                        )
                    HStack {
                        Text("0:00").font(.inter(size: 10))
                        Spacer()
                        Text(file.displayDuration).font(.inter(size: 10))
                    }
                    .foregroundStyle(Theme.Colors.textMuted)
                }
                
                // Tech Grid
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 16) {
                    TechInfoCell(label: "Key", value: file.analysis?.musicalKey?.rawValue ?? "-")
                    TechInfoCell(label: "BPM", value: file.analysis?.bpm.map { String(format: "%.0f", $0) } ?? "-")
                    TechInfoCell(label: "Loudness", value: "-")
                    TechInfoCell(label: "Format", value: file.displayCodec)
                    TechInfoCell(label: "Sample Rate", value: file.displaySampleRate)
                    TechInfoCell(label: "Bit Depth", value: "-")
                    TechInfoCell(label: "Channels", value: "Stereo")
                    TechInfoCell(label: "Bitrate", value: file.displayBitrate)
                }
            }
        }
    }
}

struct InspectorMetadataTab: View {
    @EnvironmentObject private var appState: AppViewModel

    var body: some View {
        VStack(spacing: 18) {
            ArtworkWell()

            VStack(spacing: 12) {
                MetadataField(label: "Title", field: field(\.title))
                MetadataField(label: "Artist", field: field(\.artist))
                MetadataField(label: "Album", field: field(\.album))
                MetadataField(label: "Album Artist", field: field(\.albumArtist))
                MetadataField(label: "Genre", field: field(\.genre))

                HStack(spacing: 10) {
                    MetadataField(label: "Year", field: field(\.year), compact: true)
                    MetadataField(label: "Track", field: field(\.trackNumber), compact: true)
                    MetadataField(label: "Disc", field: field(\.discNumber), compact: true)
                }
                HStack(spacing: 10) {
                    MetadataField(label: "BPM", field: field(\.bpmTag), compact: true)
                    MetadataField(label: "Key", field: field(\.initialKey), compact: true)
                }

                MetadataField(label: "Composer", field: field(\.composer))
                MetadataField(label: "Grouping", field: field(\.grouping))
                MetadataField(label: "Publisher / Label", field: field(\.publisher))
                MetadataField(label: "Comment", field: field(\.comments))
                MetadataField(label: "ISRC", field: field(\.isrc))
                MetadataField(label: "Copyright", field: field(\.copyright))
            }

            VStack(spacing: 8) {
                Text(appState.selectedAudioFileCount > 1
                     ? "Edited fields will be applied to \(appState.selectedAudioFileCount) tracks."
                     : "Only the fields you edit are written to the file.")
                    .font(.inter(size: 10))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .multilineTextAlignment(.center)

                Button(appState.isApplyingMetadataEdits ? "Saving…" : "Save Metadata") {
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
                        Text(appState.metadataEditDraft.artworkMode == .remove ? "Artwork removed" : "Drop image or click Replace")
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
                    Label("Replace", systemImage: "square.and.arrow.down")
                        .font(.inter(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle())

                Button {
                    appState.removeArtwork()
                } label: {
                    Label("Remove", systemImage: "trash")
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
            VStack(spacing: 6) {
                Text(title)
                    .font(.inter(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Theme.Colors.accentPrimary : Theme.Colors.textSecondary)
                
                Rectangle()
                    .fill(isSelected ? Theme.Colors.accentPrimary : Color.clear)
                    .frame(height: 2)
            }
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label.uppercased())
                    .font(.inter(size: 9, weight: .bold))
                    .foregroundStyle(field.isEnabled ? Theme.Colors.accentHover : Theme.Colors.textMuted)
                if field.isEnabled {
                    Circle()
                        .fill(Theme.Colors.accentHover)
                        .frame(width: 4, height: 4)
                }
                Spacer(minLength: 0)
            }

            TextField(compact ? "—" : "", text: $field.value)
                .textFieldStyle(.plain)
                .font(.inter(size: 13))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Theme.Colors.bgPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(field.isEnabled ? Theme.Colors.accentPrimary.opacity(0.6) : Theme.Colors.border, lineWidth: 1)
                        )
                )
        }
    }
}
