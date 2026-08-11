import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppViewModel
    
    @State private var folderToDelete: URL?
    @State private var showingDeleteAlert = false
    
    @State private var folderToRename: URL?
    @State private var showingRenameSheet = false
    @State private var newFolderName = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo
            HStack {
                Text("CONVERTRA")
                    .font(.inter(size: 20, weight: .bold))
                    .foregroundStyle(Theme.Colors.accentPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
            
            // Navigation
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    SidebarItem(title: "Library", icon: "music.note.list", isSelected: appState.selectedSection == .library) {
                        appState.selectedSection = .library
                    }
                    SidebarItem(title: "Conversion", icon: "arrow.triangle.2.circlepath", isSelected: appState.selectedSection == .conversion) {
                        appState.selectedSection = .conversion
                    }
                    SidebarCollectionItem(title: "Duplicates", icon: "doc.on.doc", isSelected: appState.selectedSection == .duplicates, count: appState.duplicateGroups.reduce(0) { $0 + $1.tracks.count }) {
                        appState.selectedSection = .duplicates
                    }
                    
                    if !appState.libraryFolders.isEmpty {
                        Text("FOLDERS")
                            .font(.inter(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                            .padding(.horizontal, 12)
                        
                        ForEach(appState.libraryFolders, id: \.self) { url in
                            let title = appState.folderAliases[url] ?? url.lastPathComponent
                            SidebarItem(
                                title: title,
                                icon: "folder",
                                isSelected: appState.selectedSection == .folder(url)
                            ) {
                                appState.selectedSection = .folder(url)
                            }
                            .contextMenu {
                                Button("Select") {
                                    appState.selectedSection = .folder(url)
                                }
                                Button("Rename...") {
                                    folderToRename = url
                                    newFolderName = title
                                    showingRenameSheet = true
                                }
                                Divider()
                                Button("Delete...") {
                                    folderToDelete = url
                                    showingDeleteAlert = true
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
        }
        .frame(width: Theme.Layout.sidebarWidth)
        .background(Theme.Colors.bgBase)
        .alert("Delete Folder", isPresented: $showingDeleteAlert, presenting: folderToDelete) { url in
            Button("Remove from App Only") {
                appState.deleteFolder(url: url, moveToTrash: false)
            }
            Button("Move to Mac Trash", role: .destructive) {
                appState.deleteFolder(url: url, moveToTrash: true)
            }
            Button("Cancel", role: .cancel) { }
        } message: { url in
            Text("Do you want to remove this folder only from the app library, or also move it to the Mac Trash?")
        }
        .sheet(isPresented: $showingRenameSheet) {
            if let url = folderToRename {
                VStack(spacing: 20) {
                    Text("Rename Folder")
                        .font(.headline)
                    
                    TextField("New Name", text: $newFolderName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                    
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            showingRenameSheet = false
                        }
                        
                        Button("Rename in App Only") {
                            appState.renameFolder(url: url, newName: newFolderName, onMac: false)
                            showingRenameSheet = false
                        }
                        .disabled(newFolderName.isEmpty || newFolderName == (appState.folderAliases[url] ?? url.lastPathComponent))
                        
                        Button("Rename on Mac") {
                            appState.renameFolder(url: url, newName: newFolderName, onMac: true)
                            showingRenameSheet = false
                        }
                        .disabled(newFolderName.isEmpty || newFolderName == url.lastPathComponent)
                        .buttonStyle(AccentButtonStyle())
                    }
                }
                .padding(24)
                .background(Theme.Colors.bgPrimary)
                .frame(width: 450)
            }
        }
    }
}

struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(title)
                Spacer()
            }
            .font(.inter(size: 14, weight: isSelected ? .medium : .regular))
            .foregroundStyle(isSelected ? Theme.Colors.accentPrimary : (isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.Colors.bgSelected : (isHovered ? Theme.Colors.bgHover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct SidebarCollectionItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(title)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.inter(size: 12))
                }
            }
            .font(.inter(size: 13, weight: isSelected ? .medium : .regular))
            .foregroundStyle(isSelected ? Theme.Colors.accentPrimary : (isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.Colors.bgSelected : (isHovered ? Theme.Colors.bgHover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
