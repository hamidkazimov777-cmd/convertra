import SwiftUI
import UniformTypeIdentifiers

struct MetadataEditorView: View {
    @EnvironmentObject private var appState: AppViewModel
    @State private var isArtworkImporterPresented = false

    var body: some View {
        Group {
            if appState.selectedAudioFileCount == 0 {
                emptyState
            } else {
                editor
            }
        }
        .onAppear(perform: appState.prepareMetadataEditDraft)
        .onChange(of: appState.selectedAudioFileIDs) { _ in
            appState.prepareMetadataEditDraft()
        }
        .fileImporter(
            isPresented: $isArtworkImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false,
            onCompletion: appState.handleArtworkImport
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text("Select tracks to edit metadata")
                .font(.title2.weight(.semibold))
            Text("Choose one or more tracks in Library, then return here for single or batch edits.")
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }

    private var editor: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Metadata Editor")
                        .font(.title2.weight(.semibold))
                    Text("\(appState.selectedAudioFileCount) selected track\(appState.selectedAudioFileCount == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if appState.isApplyingMetadataEdits {
                    ProgressView()
                        .controlSize(.small)
                    Text("Applying…")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Form {
                Section("Fields to apply") {
                    MetadataTextFieldRow(title: "Title", field: binding(\.title))
                    MetadataTextFieldRow(title: "Artist", field: binding(\.artist))
                    MetadataTextFieldRow(title: "Album", field: binding(\.album))
                    MetadataTextFieldRow(title: "Genre", field: binding(\.genre))
                    MetadataTextFieldRow(title: "Year", field: binding(\.year), placeholder: "YYYY")
                    MetadataTextFieldRow(title: "Track Number", field: binding(\.trackNumber), placeholder: "1")
                    MetadataTextFieldRow(title: "Comments", field: binding(\.comments))
                    MetadataTextFieldRow(title: "ISRC", field: binding(\.isrc))
                    MetadataTextFieldRow(title: "Composer", field: binding(\.composer))
                }

                Section("Artwork") {
                    Picker("Artwork", selection: binding(\.artworkMode)) {
                        ForEach(ArtworkEditMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    if appState.metadataEditDraft.artworkMode == .replace {
                        HStack {
                            Text(appState.metadataEditDraft.artworkData == nil ? "No image selected" : "Image selected")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Choose Image…") {
                                isArtworkImporterPresented = true
                            }
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Changes are saved to Convertra's local library. Writing them back to source audio files requires a separate approved cross-format tag writer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Discard Changes") {
                        appState.prepareMetadataEditDraft()
                    }
                    Spacer()
                    Button("Apply to Library") {
                        appState.applyMetadataEditDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.isApplyingMetadataEdits || !appState.metadataEditDraft.hasChanges)
                }
            }
            .padding()
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<MetadataEditDraft, T>) -> Binding<T> {
        Binding(
            get: { appState.metadataEditDraft[keyPath: keyPath] },
            set: { appState.metadataEditDraft[keyPath: keyPath] = $0 }
        )
    }
}

private struct MetadataTextFieldRow: View {
    let title: String
    @Binding var field: MetadataEditField
    var placeholder = ""

    var body: some View {
        HStack {
            Toggle(title, isOn: $field.isEnabled)
                .frame(width: 150, alignment: .leading)
            TextField(placeholder, text: $field.value)
                .disabled(!field.isEnabled)
        }
    }
}
