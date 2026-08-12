import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var loc: Localization

    @State private var folderToDelete: URL?
    @State private var showingDeleteAlert = false
    
    @State private var folderToRename: URL?
    @State private var showingRenameSheet = false
    @State private var newFolderName = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Логотип
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Theme.Colors.accentGradient)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .accentGlow(0.5)
                Text("Convertra")
                    .font(.inter(size: 18, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 40)
            .padding(.bottom, 26)

            // Навигация
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    SidebarItem(title: loc["Библиотека"], icon: "music.note.list", isSelected: appState.selectedSection == .library) {
                        appState.selectedSection = .library
                    }
                    SidebarItem(title: loc["Конвертация"], icon: "arrow.triangle.2.circlepath", isSelected: appState.selectedSection == .conversion) {
                        appState.selectedSection = .conversion
                    }
                    SidebarCollectionItem(title: loc["Дубликаты"], icon: "doc.on.doc", isSelected: appState.selectedSection == .duplicates, count: appState.duplicateGroups.reduce(0) { $0 + $1.tracks.count }) {
                        appState.selectedSection = .duplicates
                    }

                    if !appState.libraryFolders.isEmpty {
                        SectionLabel(text: loc["Папки"])
                            .padding(.top, 18)
                            .padding(.bottom, 6)
                            .padding(.horizontal, 14)

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
                                Button {
                                    appState.selectedSection = .folder(url)
                                } label: { Label(loc["Открыть"], systemImage: "arrow.right.circle") }
                                Button {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        appState.folderToRename = url
                                        appState.newFolderName = title
                                        appState.showingRenameSheet = true
                                    }
                                } label: { Label(loc["Переименовать…"], systemImage: "pencil") }
                                Divider()
                                Button(role: .destructive) {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        appState.folderToDelete = url
                                        appState.showingDeleteAlert = true
                                    }
                                } label: { Label(loc["Удалить…"], systemImage: "trash") }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer()

            // Настройки
            SidebarItem(title: loc["Настройки"], icon: "gearshape", isSelected: appState.selectedSection == .settings) {
                appState.selectedSection = .settings
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            // Переключатель языка
            LanguageSwitcher()
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
        }
        .frame(width: Theme.Layout.sidebarWidth)
        .background(Theme.Colors.bgBase)
    }
}

// MARK: - Переключатель языка (RU · EN · ES)

struct LanguageSwitcher: View {
    @EnvironmentObject private var loc: Localization

    var body: some View {
        HStack(spacing: 3) {
            ForEach(AppLanguage.allCases) { lang in
                let isOn = loc.lang == lang
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { loc.lang = lang }
                } label: {
                    Text(lang.short)
                        .font(.inter(size: 11, weight: .semibold))
                        .foregroundStyle(isOn ? Theme.Colors.textPrimary : Theme.Colors.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(isOn ? Theme.Colors.bgHover : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(isOn ? Theme.Colors.border : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.Colors.bgBase.opacity(0.6))
        )
        .hairline(10, color: Theme.Colors.borderSubtle)
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
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Theme.Colors.accentBright : (isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary))
                Text(title)
                Spacer()
            }
            .font(.inter(size: 13.5, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? Theme.Colors.textPrimary : (isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isSelected ? Theme.Colors.bgSecondary : (isHovered ? Theme.Colors.bgHover : Color.clear))
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Theme.Colors.border, lineWidth: 1)
                        Capsule().fill(Theme.Colors.accentGradient)
                            .frame(width: 3, height: 16)
                            .padding(.leading, 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
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
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Theme.Colors.accentBright : (isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary))
                Text(title)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.inter(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.Colors.bgHover))
                        .overlay(Capsule().strokeBorder(Theme.Colors.border, lineWidth: 1))
                }
            }
            .font(.inter(size: 13.5, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? Theme.Colors.textPrimary : (isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isSelected ? Theme.Colors.bgSecondary : (isHovered ? Theme.Colors.bgHover : Color.clear))
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Theme.Colors.border, lineWidth: 1)
                        Capsule().fill(Theme.Colors.accentGradient)
                            .frame(width: 3, height: 16)
                            .padding(.leading, 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}
