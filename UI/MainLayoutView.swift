import SwiftUI

struct MainLayoutView: View {
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var loc: Localization
    
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
                            case .settings:
                                SettingsView()
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
        .alert(loc["Удалить папку"], isPresented: $appState.showingDeleteAlert, presenting: appState.folderToDelete) { url in
            Button(loc["Убрать только из приложения"]) {
                appState.deleteFolder(url: url, moveToTrash: false)
            }
            Button(loc["Переместить в Корзину Mac"], role: .destructive) {
                appState.deleteFolder(url: url, moveToTrash: true)
            }
            Button(loc["Отмена"], role: .cancel) { }
        } message: { url in
            Text(loc["Удалить папку"])
        }
        .sheet(isPresented: $appState.showingRenameSheet) {
            if let url = appState.folderToRename {
                VStack(alignment: .leading, spacing: 0) {
                    // Заголовок
                    HStack(spacing: 11) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Theme.Colors.accentPrimary.opacity(0.14))
                                .frame(width: 38, height: 38)
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.Colors.accentBright)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc["Переименовать папку"])
                                .font(.inter(size: 15, weight: .bold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(appState.folderAliases[url] ?? url.lastPathComponent)
                                .font(.inter(size: 12))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 18)

                    SectionLabel(text: loc["Новое имя"])
                        .padding(.bottom, 6)
                    TextField(loc["Новое имя"], text: $appState.newFolderName)
                        .textFieldStyle(.plain)
                        .font(.inter(size: 14))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Layout.buttonRadius, style: .continuous)
                                .fill(Theme.Colors.bgBase)
                        )
                        .hairline(Theme.Layout.buttonRadius, color: Theme.Colors.border)
                        .padding(.bottom, 22)

                    HStack(spacing: 10) {
                        Button(loc["Отмена"]) {
                            appState.showingRenameSheet = false
                        }
                        .buttonStyle(GhostButtonStyle())

                        Spacer()

                        Button(loc["В приложении"]) {
                            appState.renameFolder(url: url, newName: appState.newFolderName, onMac: false)
                            appState.showingRenameSheet = false
                        }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(appState.newFolderName.isEmpty || appState.newFolderName == (appState.folderAliases[url] ?? url.lastPathComponent))

                        Button(loc["Переименовать на Mac"]) {
                            appState.renameFolder(url: url, newName: appState.newFolderName, onMac: true)
                            appState.showingRenameSheet = false
                        }
                        .disabled(appState.newFolderName.isEmpty || appState.newFolderName == url.lastPathComponent)
                        .buttonStyle(AccentButtonStyle())
                    }
                }
                .padding(24)
                .frame(width: 440)
                .background(Theme.Colors.bgSecondary)
            }
        }
    }
}
