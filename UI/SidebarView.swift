import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo
            HStack {
                if let logo = NSImage(named: "Logo") {
                    Image(nsImage: logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 24)
                } else {
                    Text("CONVERTRA")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundStyle(Theme.Colors.goldPrimary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
            
            // Navigation
            VStack(alignment: .leading, spacing: 4) {
                SidebarItem(title: "Library", icon: "music.note.list", isSelected: appState.selectedSection == .library) {
                    appState.selectedSection = .library
                }
                SidebarItem(title: "Analysis", icon: "waveform", isSelected: false) {}
                SidebarItem(title: "Metadata", icon: "tag", isSelected: appState.selectedSection == .metadata) {
                    appState.selectedSection = .metadata
                }
                SidebarItem(title: "Conversion", icon: "arrow.triangle.2.circlepath", isSelected: appState.selectedSection == .conversion) {
                    appState.selectedSection = .conversion
                }
                SidebarItem(title: "Renamer", icon: "pencil", isSelected: false) {}
                SidebarItem(title: "Duplicates", icon: "square.on.square", isSelected: false) {}
                SidebarItem(title: "Settings", icon: "gearshape", isSelected: false) {}
            }
            .padding(.horizontal, 12)
            
            Spacer().frame(height: 32)
            
            // Collections
            HStack {
                Text("COLLECTIONS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 4) {
                SidebarCollectionItem(title: "All Tracks", icon: "folder", isSelected: true, count: appState.library.count) {}
                SidebarCollectionItem(title: "Converted", icon: "folder", isSelected: false, count: 0) {}
                SidebarCollectionItem(title: "To Convert", icon: "folder", isSelected: false, count: 0) {}
                
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .frame(width: 16)
                    Text("Loved")
                    Image(systemName: "star.fill")
                        .foregroundStyle(Theme.Colors.goldPrimary)
                        .font(.system(size: 10))
                    Spacer()
                    Text("0")
                        .font(.system(size: 12))
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                SidebarCollectionItem(title: "Deep House", icon: "folder", isSelected: false, count: 0) {}
                SidebarCollectionItem(title: "Tech House", icon: "folder", isSelected: false, count: 0) {}
            }
            .padding(.horizontal, 12)
            
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
            .font(.system(size: 14, weight: isSelected ? .medium : .regular))
            .foregroundStyle(isSelected ? Theme.Colors.goldPrimary : (isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary))
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
                        .font(.system(size: 12))
                }
            }
            .font(.system(size: 13, weight: isSelected ? .medium : .regular))
            .foregroundStyle(isSelected ? Theme.Colors.goldPrimary : (isHovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary))
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
