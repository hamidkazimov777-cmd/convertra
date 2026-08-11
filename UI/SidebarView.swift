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
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        appState.selectedSection = .folder(url)
                                    }
                                }
                                Button("Rename...") {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        appState.folderToRename = url
                                        appState.newFolderName = title
                                        appState.showingRenameSheet = true
                                    }
                                }
                                Divider()
                                Button("Delete...") {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        appState.folderToDelete = url
                                        appState.showingDeleteAlert = true
                                    }
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
