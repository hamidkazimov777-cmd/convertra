import SwiftUI

struct MainLayoutView: View {
    @EnvironmentObject private var appState: AppViewModel
    
    var body: some View {
        ZStack {
            Theme.Colors.bgBase.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top area: Sidebar + Content + Inspector
                HStack(spacing: 0) {
                    SidebarView()
                    
                    // Divider
                    Rectangle()
                        .fill(Theme.Colors.border)
                        .frame(width: 1)
                    
                    // Center Content
                    VStack(spacing: 0) {
                        Group {
                            switch appState.selectedSection {
                            case .library:
                                LibraryView()
                            case .conversion:
                                ConversionQueueView()
                            case .duplicates:
                                DuplicatesView()
                            case .folder(let url):
                                LibraryView(filterFolder: url)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .background(Theme.Colors.bgPrimary)
                    
                    // Divider
                    Rectangle()
                        .fill(Theme.Colors.border)
                        .frame(width: 1)
                    
                    // Right Inspector
                    InspectorView()
                }
                
                // Divider
                Rectangle()
                    .fill(Theme.Colors.border)
                    .frame(height: 1)
                
                // Bottom Player
                BottomPlayerView()
            }
        }
        .alert("Delete Folder", isPresented: $appState.showingDeleteAlert, presenting: appState.folderToDelete) { url in
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
        .sheet(isPresented: $appState.showingRenameSheet) {
            if let url = appState.folderToRename {
                VStack(spacing: 20) {
                    Text("Rename Folder")
                        .font(.headline)
                    
                    TextField("New Name", text: $appState.newFolderName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                    
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            appState.showingRenameSheet = false
                        }
                        
                        Button("Rename in App Only") {
                            appState.renameFolder(url: url, newName: appState.newFolderName, onMac: false)
                            appState.showingRenameSheet = false
                        }
                        .disabled(appState.newFolderName.isEmpty || appState.newFolderName == (appState.folderAliases[url] ?? url.lastPathComponent))
                        
                        Button("Rename on Mac") {
                            appState.renameFolder(url: url, newName: appState.newFolderName, onMac: true)
                            appState.showingRenameSheet = false
                        }
                        .disabled(appState.newFolderName.isEmpty || appState.newFolderName == url.lastPathComponent)
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
