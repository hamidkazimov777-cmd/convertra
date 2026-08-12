import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var loc: Localization

    @State private var folderToDelete: URL?
    @State private var showingDeleteAlert = false
    
    @State private var folderToRename: URL?
    @State private var showingRenameSheet = false
    @State private var newFolderName = ""
    @State private var expandedFolders: Set<URL> = []

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

                    let folderTree = appState.folderTree
                    if !folderTree.isEmpty {
                        SectionLabel(text: loc["Папки"])
                            .padding(.top, 18)
                            .padding(.bottom, 6)
                            .padding(.horizontal, 14)

                        ForEach(folderTree) { node in
                            FolderTreeRow(node: node, depth: 0, expandedFolders: $expandedFolders)
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

// MARK: - Folder tree row (recursive, expandable)

struct FolderTreeRow: View {
    let node: LibraryFolderNode
    let depth: Int
    @Binding var expandedFolders: Set<URL>

    @EnvironmentObject private var appState: AppViewModel
    @EnvironmentObject private var loc: Localization
    @State private var isHovered = false

    private var isExpanded: Bool { expandedFolders.contains(node.url) }
    private var isSelected: Bool { appState.selectedSection == .folder(node.url) }
    private var hasChildren: Bool { !node.children.isEmpty }
    private var title: String { appState.folderAliases[node.url] ?? node.name }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            rowLabel
            if isExpanded {
                ForEach(node.children) { child in
                    FolderTreeRow(node: child, depth: depth + 1, expandedFolders: $expandedFolders)
                }
            }
        }
    }

    private var rowLabel: some View {
        HStack(spacing: 6) {
            Group {
                if hasChildren {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12)
                        .contentShape(Rectangle())
                        .onTapGesture { toggle() }
                } else {
                    Color.clear.frame(width: 12)
                }
            }

            Image(systemName: "folder")
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .frame(width: 16)
                .foregroundStyle(isSelected ? Theme.Colors.accentBright : (isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary))
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .font(.inter(size: 13, weight: isSelected ? .semibold : .medium))
        .foregroundStyle(isSelected ? Theme.Colors.textPrimary : (isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary))
        .padding(.vertical, 7)
        .padding(.trailing, 10)
        .padding(.leading, 10 + CGFloat(depth) * 14)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Theme.Colors.bgSecondary : (isHovered ? Theme.Colors.bgHover : Color.clear))
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.Colors.border, lineWidth: 1)
                    Capsule().fill(Theme.Colors.accentGradient)
                        .frame(width: 3, height: 14)
                        .padding(.leading, 1)
                }
            }
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { select() }
        .contextMenu { menu }
    }

    @ViewBuilder private var menu: some View {
        Button {
            appState.selectedSection = .folder(node.url)
        } label: { Label(loc["Открыть"], systemImage: "arrow.right.circle") }
        Button {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appState.folderToRename = node.url
                appState.newFolderName = title
                appState.showingRenameSheet = true
            }
        } label: { Label(loc["Переименовать…"], systemImage: "pencil") }
        Divider()
        Button(role: .destructive) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appState.folderToDelete = node.url
                appState.showingDeleteAlert = true
            }
        } label: { Label(loc["Удалить…"], systemImage: "trash") }
    }

    private func select() {
        appState.selectedSection = .folder(node.url)
        // Selecting a parent also reveals its children (never collapses on tap;
        // use the chevron for that).
        if hasChildren && !isExpanded {
            withAnimation(.easeOut(duration: 0.15)) { expandedFolders.insert(node.url) }
        }
    }

    private func toggle() {
        withAnimation(.easeOut(duration: 0.15)) {
            if isExpanded { expandedFolders.remove(node.url) } else { expandedFolders.insert(node.url) }
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
